import Foundation

enum PersonalityTrait: String, Codable {
    case carinoso     // mucho pet/play
    case glotton      // mucha comida
    case dormilon     // mucho sueño
    case juguetón     // mucho play
    case neutral

    var emoji: String {
        switch self {
        case .carinoso: "🥰"
        case .glotton:  "🍽"
        case .dormilon: "😴"
        case .juguetón: "🎉"
        case .neutral:  "😐"
        }
    }

    var label: String {
        switch self {
        case .carinoso: "Cariñoso"
        case .glotton:  "Glotón"
        case .dormilon: "Dormilón"
        case .juguetón: "Juguetón"
        case .neutral:  "Neutral"
        }
    }
}

/// Tracks interactions to derive emerging personality.
struct PersonalityTracker: Codable {
    var feedCount: Int = 0
    var playCount: Int = 0
    var petCount: Int = 0
    var sleepCount: Int = 0

    mutating func record(_ action: PetAction) {
        switch action {
        case .eat:   feedCount += 1
        case .play:  playCount += 1; petCount += 1
        case .sleep: sleepCount += 1
        default: break
        }
    }

    var derivedTrait: PersonalityTrait {
        let total = feedCount + playCount + petCount + sleepCount
        guard total > 5 else { return .neutral }
        let counts: [(PersonalityTrait, Int)] = [
            (.glotton, feedCount),
            (.juguetón, playCount),
            (.carinoso, petCount),
            (.dormilon, sleepCount)
        ]
        let max = counts.max(by: { $0.1 < $1.1 })!
        return Double(max.1) / Double(total) > 0.4 ? max.0 : .neutral
    }

    private static let key = "buddy.personality.v1"
    static func load() -> PersonalityTracker {
        guard let data = UserDefaults.standard.data(forKey: key),
              let tracker = try? JSONDecoder().decode(PersonalityTracker.self, from: data) else {
            return PersonalityTracker()
        }
        return tracker
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
