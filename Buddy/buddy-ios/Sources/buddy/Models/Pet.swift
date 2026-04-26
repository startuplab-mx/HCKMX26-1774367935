import Foundation
import Observation

@Observable
final class Pet {
    var name: String
    var character: PetCharacter
    var bornAt: Date
    var stats: PetStats
    var currentAction: PetAction

    init(
        name: String = "Garfield",
        character: PetCharacter = .garfield,
        bornAt: Date = Date(),
        stats: PetStats = .newborn,
        currentAction: PetAction = .idle
    ) {
        self.name = name
        self.character = character
        self.bornAt = bornAt
        self.stats = stats
        self.currentAction = currentAction
    }

    var ageInDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: bornAt, to: Date()).day ?? 1)
    }

    var moodLevel: Int {
        let avg = (stats.happiness + stats.energy + stats.hygiene) / 3
        switch avg {
        case 80...: return 3
        case 50..<80: return 2
        case 25..<50: return 1
        default: return 0
        }
    }

    var satietyLevel: Int {
        switch stats.hunger {
        case 0..<25: return 0
        case 25..<60: return 1
        default: return 2
        }
    }
}
