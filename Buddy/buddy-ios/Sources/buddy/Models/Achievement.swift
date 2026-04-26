import Foundation

enum Achievement: String, CaseIterable, Identifiable, Codable {
    case firstFeed
    case firstPlay
    case firstSleep
    case firstBath
    case fed10
    case fed50
    case played25
    case bath10
    case daysAlive3
    case daysAlive7
    case daysAlive30
    case maxMood
    case fullStats
    case coins100
    case coins500
    case minigame1
    case allMinigames
    case firstReincarnation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstFeed:        "Primera comida"
        case .firstPlay:        "Primer juego"
        case .firstSleep:       "Primer sueño"
        case .firstBath:        "Primer baño"
        case .fed10:            "Cocinero · 10 comidas"
        case .fed50:            "Chef · 50 comidas"
        case .played25:         "Compañero · 25 juegos"
        case .bath10:           "Limpiador · 10 baños"
        case .daysAlive3:       "3 días vivo"
        case .daysAlive7:       "Una semana"
        case .daysAlive30:      "Un mes entero"
        case .maxMood:          "Máxima felicidad"
        case .fullStats:        "Cuidado perfecto"
        case .coins100:         "100 monedas"
        case .coins500:         "500 monedas"
        case .minigame1:        "Primer mini-juego"
        case .allMinigames:     "Todos los mini-juegos"
        case .firstReincarnation: "Primera reencarnación"
        }
    }

    var emoji: String {
        switch self {
        case .firstFeed:        "🍖"
        case .firstPlay:        "🎾"
        case .firstSleep:       "💤"
        case .firstBath:        "🛁"
        case .fed10:            "🥄"
        case .fed50:            "👨‍🍳"
        case .played25:         "🎮"
        case .bath10:           "🚿"
        case .daysAlive3:       "🌱"
        case .daysAlive7:       "🌿"
        case .daysAlive30:      "🌳"
        case .maxMood:          "😍"
        case .fullStats:        "⭐"
        case .coins100:         "💰"
        case .coins500:         "💎"
        case .minigame1:        "🎯"
        case .allMinigames:     "🏆"
        case .firstReincarnation: "🌟"
        }
    }

    var reward: Int {
        switch self {
        case .firstFeed, .firstPlay, .firstSleep, .firstBath, .minigame1: 5
        case .fed10, .played25, .bath10:                                  15
        case .daysAlive3, .coins100:                                      25
        case .daysAlive7, .coins500, .maxMood, .fullStats:                50
        case .fed50, .daysAlive30, .allMinigames, .firstReincarnation:    100
        }
    }
}

struct AchievementStore {
    private static let key = "buddy.achievements.v1"

    static func unlocked() -> Set<Achievement> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let raws = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(raws.compactMap { Achievement(rawValue: $0) })
    }

    @discardableResult
    static func unlock(_ a: Achievement) -> Bool {
        var set = unlocked()
        guard !set.contains(a) else { return false }
        set.insert(a)
        save(set)
        CoinWallet.add(a.reward)
        return true
    }

    private static func save(_ set: Set<Achievement>) {
        let raws = set.map(\.rawValue)
        if let data = try? JSONEncoder().encode(raws) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
