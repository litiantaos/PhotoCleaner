import SwiftUI

struct EmptyStateView: View {
    @ObservedObject var photoManager: PhotoManager
    @Namespace private var animation
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            VStack(spacing: 10) {
                Text("照片清理")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("一键扫描并清理相似照片")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ZStack {
                Button(action: {
                    // 触发动画和扫描
                    photoManager.scanSimilarPhotos()
                }) {
                    ZStack {
                        // 背景
                        Capsule()
                            .fill(photoManager.isScanning ? Color.accentColor.opacity(0.1) : Color.accentColor)
                            .frame(height: 60)
                            .frame(maxWidth: photoManager.isScanning ? 180 : .infinity)
                            .shadow(color: photoManager.isScanning ? .clear : .accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        // 内容
                        ZStack {
                            // 扫描中文本
                            HStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                
                                Text("正在扫描...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .opacity(photoManager.isScanning ? 1 : 0)
                            .scaleEffect(photoManager.isScanning ? 1 : 0.8)
                            
                            // 按钮文本
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("开始扫描")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .opacity(photoManager.isScanning ? 0 : 1)
                            .scaleEffect(photoManager.isScanning ? 0.8 : 1)
                        }
                    }
                }
                .buttonStyle(DarkenButtonStyle())
                .disabled(photoManager.isScanning)
                .padding(.horizontal, 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: photoManager.isScanning)
            }
            .padding(.bottom, 50)
        }
        .alert("未发现相似照片", isPresented: $photoManager.showNoResultsAlert) {
            Button("好的", role: .cancel) { }
        }
    }
}

struct DarkenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
