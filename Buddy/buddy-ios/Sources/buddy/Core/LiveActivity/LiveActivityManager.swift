import ActivityKit
import Foundation
import Observation

@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private var current: Activity<BuddyActivityAttributes>?

    func start(pet: Pet, action: PetAction = .idle) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // If an activity already exists, just update.
        if let current {
            Task { await update(current, pet: pet, action: action) }
            return
        }
        let attrs = BuddyActivityAttributes(petCharacterRaw: pet.character.rawValue)
        let state = makeState(pet: pet, action: action)
        do {
            let activity = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            current = activity
        } catch {
            print("LiveActivity start error:", error)
        }
    }

    func update(pet: Pet, action: PetAction) {
        guard let current else {
            start(pet: pet, action: action)
            return
        }
        Task { await update(current, pet: pet, action: action) }
    }

    func end() {
        guard let current else { return }
        Task {
            await current.end(nil, dismissalPolicy: .immediate)
            self.current = nil
        }
    }

    private func update(_ activity: Activity<BuddyActivityAttributes>, pet: Pet, action: PetAction) async {
        let state = makeState(pet: pet, action: action)
        await activity.update(.init(state: state, staleDate: nil))
    }

    private func makeState(pet: Pet, action: PetAction) -> BuddyActivityAttributes.State {
        .init(
            petName: pet.name,
            action: action,
            moodLevel: pet.moodLevel,
            satietyLevel: pet.satietyLevel
        )
    }
}
