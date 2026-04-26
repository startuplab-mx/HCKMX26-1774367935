import Foundation

enum PetNeed: String, Identifiable, Hashable, CaseIterable {
    case hungry, thirsty, sleepy, dirty, bored

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .hungry:  "🍖"
        case .thirsty: "💧"
        case .sleepy:  "💤"
        case .dirty:   "🧼"
        case .bored:   "🎾"
        }
    }

    var label: String {
        switch self {
        case .hungry:  "Hambre"
        case .thirsty: "Sed"
        case .sleepy:  "Sueño"
        case .dirty:   "Sucio"
        case .bored:   "Aburrido"
        }
    }

    /// Verb for the contextual action button.
    var actionLabel: String {
        switch self {
        case .hungry:  "Alimentar"
        case .thirsty: "Dar agua"
        case .sleepy:  "Dormir"
        case .dirty:   "Bañar"
        case .bored:   "Jugar"
        }
    }

    func severity(for pet: Pet) -> Int {
        switch self {
        case .hungry:  100 - pet.stats.hunger
        case .thirsty: 100 - pet.stats.thirst
        case .sleepy:  100 - pet.stats.energy
        case .dirty:   100 - pet.stats.hygiene
        case .bored:   100 - pet.stats.happiness
        }
    }
}
