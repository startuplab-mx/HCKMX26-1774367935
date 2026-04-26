import Foundation

enum RandomEvent: String, CaseIterable {
    case giftBox            // bonus coins
    case foundFood          // hunger boost free
    case visitor            // happiness boost
    case stormyMood         // happiness drop (drama)
    case gustOfWind         // hygiene drop
    case lazyMode           // energy drop

    var emoji: String {
        switch self {
        case .giftBox:    "🎁"
        case .foundFood:  "🍱"
        case .visitor:    "👋"
        case .stormyMood: "⛈"
        case .gustOfWind: "🌬"
        case .lazyMode:   "😴"
        }
    }

    var title: String {
        switch self {
        case .giftBox:    "Caja sorpresa"
        case .foundFood:  "Comida encontrada"
        case .visitor:    "Tu mascota recibió una visita"
        case .stormyMood: "Cambio de humor"
        case .gustOfWind: "Polvo en el ambiente"
        case .lazyMode:   "Día flojo"
        }
    }

    var detail: String {
        switch self {
        case .giftBox:    "+15 monedas"
        case .foundFood:  "+25 hambre"
        case .visitor:    "+20 felicidad"
        case .stormyMood: "-15 felicidad"
        case .gustOfWind: "-15 higiene"
        case .lazyMode:   "-20 energía"
        }
    }

    var isPositive: Bool {
        switch self {
        case .giftBox, .foundFood, .visitor: true
        default: false
        }
    }
}

struct RandomEventService {
    static func maybeTrigger(pet: Pet) -> RandomEvent? {
        // 8% chance per call
        guard Int.random(in: 0..<100) < 8 else { return nil }
        let event = RandomEvent.allCases.randomElement()!
        apply(event, to: pet)
        return event
    }

    private static func apply(_ event: RandomEvent, to pet: Pet) {
        switch event {
        case .giftBox:    CoinWallet.add(15)
        case .foundFood:  pet.stats.hunger = min(100, pet.stats.hunger + 25)
        case .visitor:    pet.stats.happiness = min(100, pet.stats.happiness + 20)
        case .stormyMood: pet.stats.happiness = max(0, pet.stats.happiness - 15)
        case .gustOfWind: pet.stats.hygiene = max(0, pet.stats.hygiene - 15)
        case .lazyMode:   pet.stats.energy = max(0, pet.stats.energy - 20)
        }
        pet.stats.clamp()
    }
}
