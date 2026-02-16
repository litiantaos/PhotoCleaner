import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var photoManager = PhotoManager()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack {
                    if photoManager.shouldShowResults {
                        ResultsView(photoManager: photoManager)
                            .transition(.move(edge: .trailing))
                    } else {
                        EmptyStateView(photoManager: photoManager)
                            .toolbar(.hidden, for: .navigationBar)
                            .transition(.move(edge: .leading))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: !photoManager.similarGroups.isEmpty)
            }
        }
        .onAppear {
            if photoManager.permissionStatus == .notDetermined {
                photoManager.requestPermission()
            }
        }
    }
}
