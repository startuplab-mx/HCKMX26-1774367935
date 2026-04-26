import Foundation
import SwiftUI

// MARK: - ProfileStore · manejo de perfiles + persistencia

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var profiles: [FluxProfile] = []
    @Published var activeProfile: FluxProfile?
    @Published var isLocked: Bool = true

    private let defaults = UserDefaults.standard
    private let profilesKey = "flux.profiles"
    private let activeProfileIDKey = "flux.activeProfileID"

    private init() {
        load()
        seedIfNeeded()
    }

    // MARK: - Public API

    func selectProfile(_ profile: FluxProfile) {
        activeProfile = profile
        defaults.set(profile.id.uuidString, forKey: activeProfileIDKey)
        FluxKeychainService.shared.lastUnlockedProfileID = profile.id
        isLocked = false
    }

    func lock() {
        isLocked = true
        activeProfile = nil
    }

    func addProfile(_ profile: FluxProfile) {
        profiles.append(profile)
        persist()
    }

    func updateProfile(_ profile: FluxProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
            if activeProfile?.id == profile.id {
                activeProfile = profile
            }
            persist()
        }
    }

    func deleteProfile(_ profile: FluxProfile) {
        profiles.removeAll { $0.id == profile.id }
        if activeProfile?.id == profile.id {
            activeProfile = nil
            isLocked = true
        }
        persist()
    }

    func toggleBiometric(for profile: FluxProfile, enabled: Bool) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx].biometricEnabled = enabled
            persist()
        }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(profiles) else {
            print("[ProfileStore] ⚠️ no se pudo codificar perfiles")
            return
        }
        defaults.set(data, forKey: profilesKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: profilesKey),
              let decoded = try? JSONDecoder().decode([FluxProfile].self, from: data)
        else {
            self.profiles = []
            return
        }
        self.profiles = decoded
    }

    private func seedIfNeeded() {
        guard profiles.isEmpty else { return }
        profiles = FluxProfile.seedProfiles
        persist()
        print("[ProfileStore] ✨ perfiles seed creados: \(profiles.count)")
    }

    func resetAndReseed() {
        profiles = FluxProfile.seedProfiles
        activeProfile = nil
        isLocked = true
        persist()
    }
}
