import Foundation
import Photos
import Vision
import UIKit
import SwiftUI
import Combine

// 相似组模型
struct SimilarGroup: Identifiable {
    let id = UUID()
    let assets: [PHAsset]
    var keepAsset: PHAsset? // 默认保留的那一张
}

class PhotoManager: ObservableObject {
    @Published var permissionStatus: PHAuthorizationStatus = .notDetermined
    @Published var isScanning = false
    @Published var shouldShowResults = false // 控制是否显示结果页
    @Published var progress: Double = 0.0
    @Published var similarGroups: [SimilarGroup] = []
    @Published var selectedAssetIDs: Set<String> = []
    @Published var showNoResultsAlert = false
    
    private let imageManager = PHCachingImageManager()
    
    // 扫描配置
    private let scanLimit: Int? = nil // 默认扫描所有照片
    private let similarityThreshold: Float = 10.0 // 越小越相似 (Vision FeaturePrint 距离)
    
    init() {
        checkPermission()
    }
    
    func checkPermission() {
        permissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                self.permissionStatus = status
            }
        }
    }
    
    @MainActor
    func scanSimilarPhotos() {
        // 确保有权限
        guard permissionStatus == .authorized || permissionStatus == .limited else {
            requestPermission()
            return
        }
        
        // 1. 立即更新 UI 状态
        isScanning = true
        shouldShowResults = false // 扫描开始时不显示结果页
        showNoResultsAlert = false
        // similarGroups = [] // 不立即清空，等动画过渡完
        selectedAssetIDs = []
        
        // 2. 使用 Task.detached 将繁重工作（包括数据重置）完全移出当前 RunLoop
        Task.detached(priority: .userInitiated) {
            // 微小的延迟，让主线程先完成按钮点击动画和震动反馈，以及视图切换动画
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s，给足够的时间让视图切换回 EmptyStateView
            await self.performScan()
        }
    }
    
    private func performScan() async {
        // 3. 在后台任务开始后，再回到主线程重置数据 (scanSimilarPhotos 已提前重置)
        await MainActor.run {
            self.progress = 0.0
            // 确保数据已清空
            if !self.similarGroups.isEmpty {
                self.similarGroups = []
            }
        }
        
        let assets = await Task { () -> [PHAsset] in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            if let limit = self.scanLimit {
                fetchOptions.fetchLimit = limit
            }
            
            let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var fetchedAssets: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in
                fetchedAssets.append(asset)
            }
            return fetchedAssets
        }.value
        
        guard assets.count > 1 else {
            await MainActor.run {
                self.isScanning = false
                self.shouldShowResults = false
                self.showNoResultsAlert = true
            }
            return
        }

        let count = assets.count
        var currentGroupAssets: [PHAsset] = []
        var lastAsset: PHAsset?
        var lastObservation: VNFeaturePrintObservation?
        
        // 核心扫描逻辑
        for (index, asset) in assets.enumerated() {
            // 更新进度 (回到主线程)
            if index % 5 == 0 {
                let p = Double(index) / Double(count)
                await MainActor.run {
                    self.progress = p
                    
                    // 检查是否满足跳转条件：进度超过10%
                    if !self.shouldShowResults && !self.similarGroups.isEmpty {
                        if p >= 0.1 {
                            self.shouldShowResults = true
                        }
                    }
                }
            }
            
            // 计算当前特征
            let observation = await self.computeFeature(for: asset)
            
            if let currentObs = observation, let lastObs = lastObservation, let lastAss = lastAsset {
                // 计算距离
                var distance: Float = 100.0
                try? currentObs.computeDistance(&distance, to: lastObs)
                
                if distance < self.similarityThreshold {
                    // 相似！
                    if currentGroupAssets.isEmpty {
                        currentGroupAssets.append(lastAss)
                    }
                    currentGroupAssets.append(asset)
                } else {
                    // 不相似，结算上一组
                    if !currentGroupAssets.isEmpty {
                        let newGroup = SimilarGroup(assets: currentGroupAssets, keepAsset: currentGroupAssets.first)
                        // 实时更新 UI
                        await MainActor.run {
                            self.similarGroups.append(newGroup)
                            self.autoSelectAssets(for: newGroup)
                        }
                        currentGroupAssets = []
                    }
                }
            } else {
                 // 无法比较
                if !currentGroupAssets.isEmpty {
                    let newGroup = SimilarGroup(assets: currentGroupAssets, keepAsset: currentGroupAssets.first)
                    await MainActor.run {
                        self.similarGroups.append(newGroup)
                        self.autoSelectAssets(for: newGroup)
                    }
                    currentGroupAssets = []
                }
            }
            
            lastAsset = asset
            lastObservation = observation
        }
        
        // 处理最后一组
        if !currentGroupAssets.isEmpty {
            let newGroup = SimilarGroup(assets: currentGroupAssets, keepAsset: currentGroupAssets.first)
            await MainActor.run {
                self.similarGroups.append(newGroup)
                self.autoSelectAssets(for: newGroup)
            }
        }
        
        await MainActor.run {
            self.isScanning = false
            self.progress = 1.0
            if self.similarGroups.isEmpty {
                self.showNoResultsAlert = true
                self.shouldShowResults = false
            } else {
                self.shouldShowResults = true // 扫描完成，如果有结果，必须显示
            }
        }
    }
    
    // 异步计算特征值
    private func computeFeature(for asset: PHAsset) async -> VNFeaturePrintObservation? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat 
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            options.isSynchronous = false
            
            let targetSize = CGSize(width: 256, height: 256)
            
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, info in
                // 放到后台线程执行 Vision 请求，避免阻塞主线程（因为 requestImage 的回调可能在主线程执行）
                Task.detached(priority: .userInitiated) {
                    guard let image = image, let cgImage = image.cgImage else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let request = VNGenerateImageFeaturePrintRequest()
                    #if targetEnvironment(simulator)
                    request.revision = VNGenerateImageFeaturePrintRequestRevision1
                    #else
                    request.revision = VNGenerateImageFeaturePrintRequestRevision1
                    #endif
                    
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    do {
                        try handler.perform([request])
                        if let result = request.results?.first as? VNFeaturePrintObservation {
                            continuation.resume(returning: result)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    } catch {
                        print("Vision error for asset \(asset.localIdentifier): \(error)")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    // 删除照片
    func deleteAssets(assets: [PHAsset]) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        } completionHandler: { success, error in
            if success {
                DispatchQueue.main.async {
                    // 移除已删除的照片
                    let deletedIds = Set(assets.map { $0.localIdentifier })
                    
                    self.similarGroups = self.similarGroups.map { group in
                        let remaining = group.assets.filter { !deletedIds.contains($0.localIdentifier) }
                        var newGroup = SimilarGroup(assets: remaining, keepAsset: group.keepAsset)
                        
                        // 如果保留的照片被删除了，重新选一张
                        if let keep = newGroup.keepAsset, deletedIds.contains(keep.localIdentifier) {
                            newGroup.keepAsset = remaining.first
                        }
                        return newGroup
                    }.filter { $0.assets.count > 1 } // 只保留还有相似组的
                    
                    self.selectedAssetIDs.subtract(deletedIds)
                }
            }
        }
    }
    
    // 自动选择（除了保留的一张，其他都选）
    func autoSelectAssets(for group: SimilarGroup) {
        if let keep = group.keepAsset {
            let others = group.assets.filter { $0.localIdentifier != keep.localIdentifier }
            others.forEach { selectedAssetIDs.insert($0.localIdentifier) }
        } else if let first = group.assets.first {
             let others = group.assets.filter { $0.localIdentifier != first.localIdentifier }
            others.forEach { selectedAssetIDs.insert($0.localIdentifier) }
        }
    }
    
    func toggleSelection(for asset: PHAsset) {
        if selectedAssetIDs.contains(asset.localIdentifier) {
            selectedAssetIDs.remove(asset.localIdentifier)
        } else {
            selectedAssetIDs.insert(asset.localIdentifier)
        }
    }
    
    func deleteSelectedAssets() {
        let allAssets = similarGroups.flatMap { $0.assets }
        let assetsToDelete = allAssets.filter { selectedAssetIDs.contains($0.localIdentifier) }
        
        guard !assetsToDelete.isEmpty else { return }
        
        deleteAssets(assets: assetsToDelete)
    }
    
    // 全选（自动选择建议删除的照片）
    func selectAll() {
        selectedAssetIDs.removeAll()
        for group in similarGroups {
            autoSelectAssets(for: group)
        }
    }
    
    // 全不选
    func deselectAll() {
        selectedAssetIDs.removeAll()
    }
}
