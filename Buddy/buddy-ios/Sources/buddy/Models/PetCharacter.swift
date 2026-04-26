import Foundation

enum PetCharacter: String, CaseIterable, Identifiable {
    case garfield
    case pikachu
    case mario
    case kuromi

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .garfield: "Garfield"
        case .pikachu:  "Pikachu"
        case .mario:    "Mario"
        case .kuromi:   "Kuromi"
        }
    }

    /// Asset name for the sprite sheet PNG. Each character has its own.
    var spriteSheetAsset: String {
        switch self {
        case .garfield: "pet_sheet"
        case .pikachu:  "pet_sheet_pikachu"
        case .mario:    "pet_sheet_mario"
        case .kuromi:   "pet_sheet_kuromi"
        }
    }

    var unlockPrice: Int {
        switch self {
        case .garfield: 0
        case .pikachu:  150
        case .mario:    200
        case .kuromi:   250
        }
    }

    /// No tint — each character has a unique sheet now.
    var tintColor: (r: Double, g: Double, b: Double, a: Double) { (1, 1, 1, 0) }

    var emoji: String {
        switch self {
        case .garfield: "🐱"
        case .pikachu:  "⚡"
        case .mario:    "🍄"
        case .kuromi:   "💀"
        }
    }
}

struct CharacterStore {
    private static let unlockedKey = "buddy.chars.unlocked.v1"
    static func unlocked() -> Set<PetCharacter> {
        let arr = UserDefaults.standard.stringArray(forKey: unlockedKey) ?? [PetCharacter.garfield.rawValue]
        return Set(arr.compactMap { PetCharacter(rawValue: $0) })
    }
    static func unlock(_ c: PetCharacter) {
        var set = unlocked(); set.insert(c)
        UserDefaults.standard.set(set.map(\.rawValue), forKey: unlockedKey)
    }
    static func isUnlocked(_ c: PetCharacter) -> Bool { unlocked().contains(c) }
}
