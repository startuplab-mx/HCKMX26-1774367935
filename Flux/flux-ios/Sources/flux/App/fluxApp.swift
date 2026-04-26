import SwiftUI

@main
struct fluxApp: App {
    @StateObject private var session = AppSession()
    @StateObject private var profileStore = ProfileStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(profileStore)
                .preferredColorScheme(.light)
                .tint(FluxColor.primary)
                .onOpenURL { url in
                    if url.host == "stop-activity" {
                        session.endLiveActivity()
                        let gen = UINotificationFeedbackGenerator()
                        gen.notificationOccurred(.success)
                    }
                }
        }
    }
}

// MARK: - App Session

@MainActor
final class AppSession: ObservableObject {
    @Published var mode: AppMode = .parent
    @Published var activeChildProfile: ChildProfile?

    enum AppMode {
        case parent
        case voz
    }

    /// Sincroniza AppSession con el perfil activo del ProfileStore.
    func applyProfile(_ profile: FluxProfile) {
        switch profile.role {
        case .parent:
            mode = .parent
            activeChildProfile = profile.monitoredChildren.first
        case .child:
            mode = .voz
            activeChildProfile = ChildProfile(
                name: profile.displayName.components(separatedBy: " ").first ?? profile.displayName,
                age: profile.childAge ?? 13,
                baselineApps: []
            )
        }

        hydrateStores(for: profile)

        if mode == .parent, activeChildProfile != nil {
            startLiveActivity()
        } else {
            endLiveActivity()
        }
    }

    /// Los únicos perfiles con datos de prueba son los seed "Camila Vega" y "Lucía Vega".
    private func isDemoProfile(_ profile: FluxProfile) -> Bool {
        profile.displayName == "Camila Vega" || profile.displayName == "Lucía Vega"
    }

    private func hydrateStores(for profile: FluxProfile) {
        if isDemoProfile(profile) {
            AlertCenter.shared.demoMode = true
            if AlertCenter.shared.activeSignals.isEmpty {
                AlertCenter.shared.activeSignals = DetectedSignal.mockActive
            }
            if ForumStore.shared.footprints.isEmpty {
                ForumStore.shared.footprints = PatternFootprint.mock
            }
            if VozEntryStore.shared.entries.isEmpty {
                VozEntryStore.shared.resetToMock()
            }
        } else {
            AlertCenter.shared.demoMode = false
            AlertCenter.shared.clearAll()
            ForumStore.shared.clearAll()
            VozEntryStore.shared.clearAll()
        }
    }

    func startLiveActivity() {
        guard let profile = activeChildProfile else { return }
        let score = RiskScore.mock
        let signal = DetectedSignal.mockActive.first
        let badge = WeProtectAI.shared.backendKind == .foundationModels
            ? "Apple Intelligence"
            : "WeProtect Rules"
        let state = FluxLiveActivityManager.makeState(
            from: score, weProtectBadge: badge, lastSignal: signal
        )
        FluxLiveActivityManager.shared.start(
            childName: profile.name, childAge: profile.age, state: state
        )
    }

    func endLiveActivity() {
        Task { await FluxLiveActivityManager.shared.end() }
    }
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var profileStore: ProfileStore

    var body: some View {
        Group {
            if profileStore.isLocked || profileStore.activeProfile == nil {
                ProfilePickerView()
            } else if let profile = profileStore.activeProfile {
                content(for: profile)
            }
        }
        .animation(.smooth(duration: 0.4), value: profileStore.isLocked)
        .animation(.smooth(duration: 0.4), value: profileStore.activeProfile?.id)
        .onChange(of: profileStore.activeProfile) { _, newProfile in
            if let p = newProfile { session.applyProfile(p) }
        }
    }

    @ViewBuilder
    private func content(for profile: FluxProfile) -> some View {
        switch profile.role {
        case .parent: ParentTabView()
        case .child:  VozTabView()
        }
    }
}
