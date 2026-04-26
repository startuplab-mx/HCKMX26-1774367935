import SwiftUI

@main
struct BuddyApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
                .persistentSystemOverlays(.hidden)
                .statusBarHidden(true)
        }
    }
}
