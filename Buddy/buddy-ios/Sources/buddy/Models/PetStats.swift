import Foundation

struct PetStats {
    var hunger: Int
    var thirst: Int
    var energy: Int
    var hygiene: Int
    var happiness: Int

    static let newborn = PetStats(
        hunger: 70,
        thirst: 70,
        energy: 100,
        hygiene: 100,
        happiness: 80
    )

    mutating func clamp() {
        hunger = min(100, max(0, hunger))
        thirst = min(100, max(0, thirst))
        energy = min(100, max(0, energy))
        hygiene = min(100, max(0, hygiene))
        happiness = min(100, max(0, happiness))
    }
}
