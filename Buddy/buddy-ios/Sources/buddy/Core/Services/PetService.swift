import Foundation
import Observation

/// Drives the autonomous behavior of the pet:
/// - decays stats over time (hunger, thirst, energy, hygiene, happiness)
/// - emits "needs" when a stat crosses a critical threshold
/// - feeds back to LiveActivityManager when state changes
@Observable
final class PetService {
    let pet: Pet

    /// Current critical needs the pet has, in priority order. Drives both UI bubbles and
    /// the contextual button label.
    var needs: [PetNeed] = []

    /// Whether the pet is dead (any stat reached 0 for too long).
    private(set) var isDead = false

    private var decayTask: Task<Void, Never>?
    private var lastTick: Date = Date()

    init(pet: Pet) {
        self.pet = pet
    }

    // MARK: - Lifecycle

    func start() {
        stop()
        lastTick = Date()
        decayTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                self?.tick()
            }
        }
    }

    func stop() {
        decayTask?.cancel()
        decayTask = nil
    }

    // MARK: - Tick

    /// Decay rates per minute. Tuned so stats drain in ~30–60 min realtime.
    private struct DecayRate {
        static let hunger:    Double = 3.0
        static let thirst:    Double = 4.0
        static let energy:    Double = 1.5
        static let hygiene:   Double = 1.0
        static let happiness: Double = 1.5
    }

    private func tick() {
        guard !isDead else { return }
        let now = Date()
        let minutes = now.timeIntervalSince(lastTick) / 60.0
        lastTick = now

        var s = pet.stats
        s.hunger    = max(0, s.hunger    - Int((Double(DecayRate.hunger)    * minutes).rounded()))
        s.thirst    = max(0, s.thirst    - Int((Double(DecayRate.thirst)    * minutes).rounded()))
        s.energy    = max(0, s.energy    - Int((Double(DecayRate.energy)    * minutes).rounded()))
        s.hygiene   = max(0, s.hygiene   - Int((Double(DecayRate.hygiene)   * minutes).rounded()))
        // Happiness drops faster when other stats are low
        let stressMultiplier: Double = (s.hunger < 20 || s.thirst < 20) ? 2.5 : 1.0
        s.happiness = max(0, s.happiness - Int((Double(DecayRate.happiness) * minutes * stressMultiplier).rounded()))
        s.clamp()
        pet.stats = s

        recomputeNeeds()
        applyAutoAction()
        checkDeath()
    }

    // MARK: - Needs

    func recomputeNeeds() {
        var n: [PetNeed] = []
        if pet.stats.hunger    < 30 { n.append(.hungry) }
        if pet.stats.thirst    < 30 { n.append(.thirsty) }
        if pet.stats.hygiene   < 25 { n.append(.dirty) }
        if pet.stats.energy    < 25 { n.append(.sleepy) }
        if pet.stats.happiness < 30 { n.append(.bored) }
        // Sort by severity (lowest stat first)
        needs = n.sorted { $0.severity(for: pet) > $1.severity(for: pet) }
    }

    /// Switches `pet.currentAction` automatically based on most urgent need or default to idle.
    private func applyAutoAction() {
        guard pet.currentAction == .idle else { return }
        if pet.stats.energy < 15 {
            pet.currentAction = .sleep
        } else if needs.contains(.bored) || needs.contains(.hungry) {
            pet.currentAction = .sad
        }
    }

    // MARK: - Death

    private func checkDeath() {
        let critical = pet.stats.hunger == 0 || pet.stats.thirst == 0
        if critical && pet.stats.happiness == 0 {
            isDead = true
            stop()
        }
    }

    // MARK: - Actions (called from UI)

    func feed() {
        pet.stats.hunger = min(100, pet.stats.hunger + 35)
        pet.stats.happiness = min(100, pet.stats.happiness + 8)
        pet.stats.clamp()
        triggerAction(.eat)
        recomputeNeeds()
    }

    func giveWater() {
        pet.stats.thirst = min(100, pet.stats.thirst + 40)
        pet.stats.clamp()
        triggerAction(.eat) // reuse eat anim for now (bowl)
        recomputeNeeds()
    }

    func playWith() {
        pet.stats.happiness = min(100, pet.stats.happiness + 25)
        pet.stats.energy = max(0, pet.stats.energy - 8)
        pet.stats.clamp()
        triggerAction(.play)
        recomputeNeeds()
    }

    func pet_() {
        pet.stats.happiness = min(100, pet.stats.happiness + 15)
        pet.stats.clamp()
        triggerAction(.play)
        recomputeNeeds()
    }

    func sleep() {
        pet.stats.energy = min(100, pet.stats.energy + 50)
        pet.stats.clamp()
        triggerAction(.sleep)
        recomputeNeeds()
    }

    func bath() {
        pet.stats.hygiene = min(100, pet.stats.hygiene + 60)
        pet.stats.happiness = max(0, pet.stats.happiness - 5)
        pet.stats.clamp()
        triggerAction(.idle)
        recomputeNeeds()
    }

    func reincarnate(name: String, character: PetCharacter) {
        pet.name = name
        pet.character = character
        pet.bornAt = Date()
        pet.stats = .newborn
        pet.currentAction = .idle
        isDead = false
        recomputeNeeds()
        start()
    }

    private func triggerAction(_ action: PetAction, returnToIdleAfter: TimeInterval = 3.0) {
        pet.currentAction = action
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(returnToIdleAfter))
            guard let self else { return }
            if self.pet.currentAction == action {
                self.pet.currentAction = .idle
            }
        }
    }
}
