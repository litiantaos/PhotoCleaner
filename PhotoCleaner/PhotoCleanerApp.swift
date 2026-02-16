import SwiftUI

@main
struct PhotoCleanerApp: App {
    init() {
        // 预热震动引擎，避免第一次点击卡顿
        HapticManager.shared.prepare()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
