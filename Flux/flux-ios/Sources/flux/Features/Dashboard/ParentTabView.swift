import SwiftUI

struct ParentTabView: View {
    @State private var selectedTab: FluxLiquidTabBar.FluxTab = .home
    @State private var showScanner: Bool = false

    var body: some View {
        Group {
            switch selectedTab {
            case .home:      DashboardView()
            case .weProtect: WeProtectView()
            case .community: CommunityView()
            case .forum:     ForumView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FluxColor.base.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FluxLiquidTabBar(selectedTab: $selectedTab) {
                showScanner = true
            }
            .padding(.bottom, 2)
        }
        .fullScreenCover(isPresented: $showScanner) {
            ScannerView()
        }
    }
}

// MARK: - Stubs para tabs que se implementan en próximas tareas

