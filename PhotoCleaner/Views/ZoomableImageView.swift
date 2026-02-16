import SwiftUI
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    var onDrag: ((CGSize) -> Void)?
    var onDragEnd: ((CGSize) -> Void)?
    
    func makeUIView(context: Context) -> ImageScrollView {
        let scrollView = ImageScrollView(frame: .zero)
        scrollView.display(image: image)
        scrollView.onDrag = onDrag
        scrollView.onDragEnd = onDragEnd
        return scrollView
    }
    
    func updateUIView(_ uiView: ImageScrollView, context: Context) {
        if uiView.imageZoomView?.image != image {
            uiView.display(image: image)
        }
        uiView.onDrag = onDrag
        uiView.onDragEnd = onDragEnd
    }
}

class ImageScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var imageZoomView: UIImageView?
    private var isZoomInitialized = false
    var onDrag: ((CGSize) -> Void)?
    var onDragEnd: ((CGSize) -> Void)?
    
    lazy var zoomingTap: UITapGestureRecognizer = {
        let zoomingTap = UITapGestureRecognizer(target: self, action: #selector(handleZoomingTap(_:)))
        zoomingTap.numberOfTapsRequired = 2
        return zoomingTap
    }()
    
    lazy var dragGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleDragGesture(_:)))
        gesture.delegate = self
        gesture.maximumNumberOfTouches = 1
        return gesture
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.delegate = self
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
        self.decelerationRate = .fast
        self.backgroundColor = .clear
        self.addGestureRecognizer(zoomingTap)
        self.addGestureRecognizer(dragGesture)
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func display(image: UIImage) {
        // 重置缩放
        self.zoomScale = 1.0
        
        if let imageView = imageZoomView {
            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: image.size)
        } else {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            self.addSubview(imageView)
            self.imageZoomView = imageView
        }
        
        // 标记需要重新初始化缩放
        isZoomInitialized = false
        
        configureFor(imageSize: image.size)
    }
    
    func configureFor(imageSize: CGSize) {
        self.contentSize = imageSize
        configureZoomScales()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if !isZoomInitialized && bounds.width > 0 && bounds.height > 0 {
            configureZoomScales()
        }
        
        centerImage()
    }
    
    func configureZoomScales() {
        guard let imageZoomView = imageZoomView else { return }
        
        let boundsSize = self.bounds.size
        let imageSize = imageZoomView.bounds.size
        
        guard imageSize.width > 0, imageSize.height > 0, boundsSize.width > 0, boundsSize.height > 0 else { return }
        
        let xScale = boundsSize.width / imageSize.width
        let yScale = boundsSize.height / imageSize.height
        let minScale = min(xScale, yScale)
        
        self.minimumZoomScale = minScale
        // 调整最大缩放比例：
        // 如果图片本身比屏幕小，最大放大到图片原始大小的2倍或者屏幕宽度的2倍，取较小值
        // 如果图片本身很大，最大放大到原始大小
        self.maximumZoomScale = max(minScale * 2.5, 3.0)
        
        // If we want to fit the image initially
        if !isZoomInitialized {
            self.zoomScale = minScale
            isZoomInitialized = true
        }
        
        // Center initially
        centerImage()
    }
    
    func centerImage() {
        guard let imageZoomView = imageZoomView else { return }
        
        let boundsSize = self.bounds.size
        var frameToCenter = imageZoomView.frame
        
        // Center horizontally
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }
        
        // Center vertically
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }
        
        imageZoomView.frame = frameToCenter
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageZoomView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }
    
    @objc func handleZoomingTap(_ sender: UITapGestureRecognizer) {
        guard let imageZoomView = imageZoomView else { return }
        let location = sender.location(in: imageZoomView)
        self.zoom(to: location, animated: true)
    }
    
    func zoom(to point: CGPoint, animated: Bool) {
        let currentScale = self.zoomScale
        let minScale = self.minimumZoomScale
        let maxScale = self.maximumZoomScale
        
        // 如果无法缩放，直接返回
        if minScale >= maxScale { return }
        
        // 判断当前是否已经放大
        let isZoomedIn = currentScale > minScale * 1.1
        
        // 计算目标缩放比例：放大则还原，未放大则放大到合适比例
        let finalScale = isZoomedIn ? minScale : min(minScale * 2.0, maxScale)
        
        let zoomRect = self.zoomRect(for: finalScale, withCenter: point)
        self.zoom(to: zoomRect, animated: animated)
    }
    
    func zoomRect(for scale: CGFloat, withCenter center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        let bounds = self.bounds
        
        zoomRect.size.width = bounds.size.width / scale
        zoomRect.size.height = bounds.size.height / scale
        
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
        
        return zoomRect
    }
    
    @objc func handleDragGesture(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: self)
        
        switch sender.state {
        case .changed:
            onDrag?(CGSize(width: translation.x, height: translation.y))
        case .ended, .cancelled:
            onDragEnd?(CGSize(width: translation.x, height: translation.y))
        default:
            break
        }
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == dragGesture {
            // 1. 只有当缩放比例为最小（或非常接近最小）时才允许拖动关闭
            if zoomScale > minimumZoomScale * 1.01 {
                return false
            }
            
            if let pan = gestureRecognizer as? UIPanGestureRecognizer {
                let velocity = pan.velocity(in: self)
                
                // 4. 只有垂直速度明显大于水平速度时才允许 (避免水平切换误触)
                if abs(velocity.y) <= abs(velocity.x) {
                    return false
                }
                
                if velocity.y > 0 {
                    // 向下拖拽：只有当内容滚动到顶部（或接近顶部）时才允许
                    if contentOffset.y > 1 {
                        return false
                    }
                } else {
                    // 向上拖拽：只有当内容滚动到底部（或接近底部）时才允许
                    let maxOffsetY = max(0, contentSize.height - bounds.height)
                    if contentOffset.y < maxOffsetY - 1 {
                        return false
                    }
                }
            }
            return true
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == dragGesture {
            // 如果是我们的下拉手势，不允许和其他手势（比如 TabView 的滑动手势）同时识别
            // 这样一旦下拉手势识别成功，TabView 就不会动了
            return false
        }
        return true
    }
}
