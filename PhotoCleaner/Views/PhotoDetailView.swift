import SwiftUI
import Photos

struct PhotoDetailView: View {
    let assets: [PHAsset]
    let initialIndex: Int
    @Binding var isPresented: Bool
    @Binding var selectedAssets: Set<String>
    
    @State private var selectedIndex: Int
    @State private var dragOffset: CGSize = .zero
    @State private var bgOpacity: Double = 1.0 // 用于控制背景淡出效果
    
    init(assets: [PHAsset], initialIndex: Int, isPresented: Binding<Bool>, selectedAssets: Binding<Set<String>>) {
        self.assets = assets
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._selectedAssets = selectedAssets
        self._selectedIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            backgroundView
            imageTabView
            controlsOverlay
        }
        .onAppear {
            selectedIndex = initialIndex
            bgOpacity = 1.0
        }
    }
    
    // MARK: - Subviews
    
    private var backgroundView: some View {
        Color.black
            .opacity(max(0, 1 - Double(abs(dragOffset.height) / 300)) * bgOpacity)
            .ignoresSafeArea()
            .presentationBackground(.clear) // 确保全屏模态背景透明
    }
    
    private var imageTabView: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 20
            let width = proxy.size.width
            
            TabView(selection: $selectedIndex) {
                ForEach(0..<assets.count, id: \.self) { index in
                    AssetDetailImage(
                        asset: assets[index],
                        onDrag: { translation in
                            dragOffset = translation
                        },
                        onDragEnd: { translation in
                            if abs(translation.height) > 100 {
                                // 1. 先淡出背景
                                withAnimation(.easeOut(duration: 0.2)) {
                                    bgOpacity = 0.0
                                }
                                
                                // 2. 然后滑出图片并关闭
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    let screenHeight = proxy.size.height
                                    dragOffset = CGSize(width: translation.width, height: translation.height > 0 ? screenHeight : -screenHeight)
                                }
                                
                                // 3. 延迟关闭视图
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    isPresented = false
                                }
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = .zero
                                }
                            }
                        }
                    )
                    .tag(index)
                    .frame(width: width) // 限制内容宽度为屏幕宽度
                    .ignoresSafeArea()
                    .offset(y: selectedIndex == index ? dragOffset.height : 0)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(width: width + spacing) // TabView 宽度增加间距
            .offset(x: -spacing / 2) // 向左偏移以居中内容
        }
        .ignoresSafeArea()
    }
    
    private var controlsOverlay: some View {
        VStack {
            Spacer()
            
            // Image Counter
            HStack {
                Text("\(selectedIndex + 1) / \(assets.count)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(16)
            }
            .padding(.bottom, 20)
            
            // Bottom Action Bar
            HStack(spacing: 40) {
                if assets.indices.contains(selectedIndex) {
                    let currentAsset = assets[selectedIndex]
                    let isSelected = selectedAssets.contains(currentAsset.localIdentifier)
                    
                    Button(action: { toggleSelection(for: currentAsset) }) {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundColor(isSelected ? .red : .white)
                            
                            Text(isSelected ? "删除" : "保留")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Material.ultraThin)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.bottom, 50)
        }
        .opacity(dragOffset == .zero ? 1 : 0) // 拖拽时隐藏控件
    }
    
    private func toggleSelection(for asset: PHAsset) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if selectedAssets.contains(asset.localIdentifier) {
            selectedAssets.remove(asset.localIdentifier)
        } else {
            selectedAssets.insert(asset.localIdentifier)
        }
    }
}

struct AssetDetailImage: View {
    let asset: PHAsset
    @State private var image: UIImage?
    var onDrag: ((CGSize) -> Void)?
    var onDragEnd: ((CGSize) -> Void)?
    
    var body: some View {
        ZStack {
            if let image = image {
                ZoomableImageView(image: image, onDrag: onDrag, onDragEnd: onDragEnd)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { result, _ in
            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}
