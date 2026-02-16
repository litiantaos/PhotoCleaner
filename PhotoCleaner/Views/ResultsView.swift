import SwiftUI
import Photos

struct ResultsView: View {
    @ObservedObject var photoManager: PhotoManager
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemGroupedBackground) // 整体背景色
                .ignoresSafeArea()
            
            ZStack(alignment: .top) {
                // 内容区域
                ScrollView {
                    // 顶部占位，避免内容被 Header 遮挡
                    Color.clear
                        .frame(height: 60)
                    
                    LazyVStack(alignment: .leading, spacing: 20) {
                        // 顶部统计信息 - 已移至标题旁
                        
                        ForEach(photoManager.similarGroups) { group in
                            SimilarGroupView(group: group, photoManager: photoManager)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 80) // 留出底部删除按钮的空间
                }
                
                // 自定义 Header
                HStack(alignment: .center, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("相似照片")
                            .font(.system(size: 30))
                            .fontWeight(.bold)
                        
                        if !photoManager.similarGroups.isEmpty {
                            Text("\(photoManager.similarGroups.count) 组")
                                .font(.system(size: 16))
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: photoManager.similarGroups.count)
                        }
                    }
                    
                    Spacer()
                    
                    // Rescan Button
                    ZStack {
                        if photoManager.isScanning {
                            ToolbarProgressView(progress: photoManager.progress)
                                .frame(width: 36, height: 36)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(Circle())
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        } else {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    photoManager.scanSimilarPhotos()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .clipShape(Circle())
                            }
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: photoManager.isScanning)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10) // 适配安全区
                .padding(.bottom, 20) // 增加底部 padding 让渐变更自然
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(UIColor.systemGroupedBackground),
                            Color(UIColor.systemGroupedBackground).opacity(0.9),
                            Color(UIColor.systemGroupedBackground).opacity(0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
            
            // 底部悬浮操作栏
            if !photoManager.similarGroups.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // 全选/全不选按钮
                        Button(action: {
                            // 先执行 UI 更新
                            withAnimation {
                                if photoManager.selectedAssetIDs.isEmpty {
                                    photoManager.selectAll()
                                } else {
                                    photoManager.deselectAll()
                                }
                            }
                            HapticManager.shared.impact(style: .medium)
                        }) {
                            HStack(spacing: 6) {
                                ZStack {
                                    Image(systemName: "circle")
                                        .opacity(photoManager.selectedAssetIDs.isEmpty ? 1 : 0)
                                        .scaleEffect(photoManager.selectedAssetIDs.isEmpty ? 1 : 0.5)
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .opacity(photoManager.selectedAssetIDs.isEmpty ? 0 : 1)
                                        .scaleEffect(photoManager.selectedAssetIDs.isEmpty ? 0.5 : 1)
                                }
                                .font(.title3)
                                Text("全选")
                                    .font(.headline)
                                    .fontWeight(.medium)
                            }
                            .frame(height: 50)
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(PrimaryButtonStyle(backgroundColor: Color(UIColor.secondarySystemGroupedBackground), foregroundColor: .primary))
                        
                        // 删除按钮
                        if !photoManager.selectedAssetIDs.isEmpty {
                            Button(action: {
                                photoManager.deleteSelectedAssets()
                                HapticManager.shared.impact(style: .heavy)
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    .font(.headline)
                                    Text("删除 \(photoManager.selectedAssetIDs.count) 张")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .contentTransition(.numericText())
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                            }
                            .buttonStyle(PrimaryButtonStyle(backgroundColor: .red, foregroundColor: .white))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity) // 确保内容区域撑满宽度
                    .padding(.horizontal, 20)
                    .padding(.top, 20) // 渐变过渡区域
                    .padding(.bottom, 0) // 贴底，通过 background 处理安全区
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(UIColor.systemGroupedBackground).opacity(0),
                                Color(UIColor.systemGroupedBackground).opacity(0.9),
                                Color(UIColor.systemGroupedBackground)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: photoManager.selectedAssetIDs.count)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: photoManager.selectedAssetIDs.isEmpty)
        .navigationBarHidden(true) // 隐藏系统默认标题
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule()
                    .fill(Color.black.opacity(configuration.isPressed ? 0.2 : 0))
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ToolbarProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 2.5)
            
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: progress)
        }
        .frame(width: 14, height: 14)
    }
}

struct DetailConfig: Identifiable {
    let id = UUID()
    let initialIndex: Int
}

struct SimilarGroupView: View {
    let group: SimilarGroup
    @ObservedObject var photoManager: PhotoManager
    @State private var detailConfig: DetailConfig?
    
    // 使用中文日期格式化
    private var dateString: String {
        guard let date = group.assets.first?.creationDate else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateString)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(group.assets.count) 张照片")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 组内操作菜单 (预留位置，暂时可以是简单的全选当前组)
                // 这里可以扩展
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Photos Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.assets, id: \.localIdentifier) { asset in
                        let isSelected = photoManager.selectedAssetIDs.contains(asset.localIdentifier)
                        
                        AssetItemView(
                            asset: asset,
                            isSelected: isSelected,
                            onTap: {
                                if let index = group.assets.firstIndex(of: asset) {
                                    detailConfig = DetailConfig(initialIndex: index)
                                }
                            },
                            onSelect: {
                                photoManager.toggleSelection(for: asset)
                                HapticManager.shared.impact(style: .light)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .fullScreenCover(item: $detailConfig) { config in
            PhotoDetailView(
                assets: group.assets,
                initialIndex: config.initialIndex,
                isPresented: Binding(
                    get: { detailConfig != nil },
                    set: { if !$0 { detailConfig = nil } }
                ),
                selectedAssets: $photoManager.selectedAssetIDs
            )
            .presentationBackground(.clear) // iOS 16.4+ 支持，确保全屏背景透明
        }
    }
}

struct AssetItemView: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void
    let onSelect: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Thumbnail
            AssetThumbnail(asset: asset)
                .frame(width: 140, height: 140)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.red : Color.clear, lineWidth: 3)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture(perform: onTap)
            
            // Selection Indicator
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .white) // 勾选时对勾为白色，未勾选时圆圈为白色
                    .background(
                        Circle()
                            .fill(isSelected ? .red : Color.black.opacity(0.3)) // 勾选时背景为红色，未勾选时背景半透黑
                            .frame(width: 24, height: 24)
                    )
                    .shadow(radius: 2)
                    .padding(8)
                    .contentShape(Rectangle()) // 扩大点击响应区域
            }
            .frame(width: 60, height: 60, alignment: .bottomTrailing) // 确保有足够大的点击热区
        }
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

struct AssetThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(UIColor.secondarySystemBackground)
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true // 允许从 iCloud 下载缩略图
        
        manager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: options) { result, _ in
            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}


