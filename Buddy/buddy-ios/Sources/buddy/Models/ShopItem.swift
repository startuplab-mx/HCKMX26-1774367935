import Foundation

enum ShopCategory: String, CaseIterable, Identifiable {
    case food, treats, accessories, cosmetics
    var id: String { rawValue }

    var label: String {
        switch self {
        case .food:        "Comida"
        case .treats:      "Premios"
        case .accessories: "Accesorios"
        case .cosmetics:   "Cosméticos"
        }
    }
}

struct ShopItem: Identifiable, Hashable {
    let id: String
    let category: ShopCategory
    let name: String
    let emoji: String
    let price: Int
    /// Effects when consumed: stat name → delta
    let effects: [String: Int]
}

struct ShopCatalog {
    static let all: [ShopItem] = [
        // Food
        ShopItem(id: "premium_food",  category: .food, name: "Comida premium", emoji: "🍱", price: 15, effects: ["hunger": 60, "happiness": 5]),
        ShopItem(id: "salmon",        category: .food, name: "Salmón fresco",  emoji: "🐟", price: 25, effects: ["hunger": 80, "happiness": 10]),
        ShopItem(id: "milk",          category: .food, name: "Leche",          emoji: "🥛", price: 10, effects: ["thirst": 50, "happiness": 5]),
        ShopItem(id: "energy_drink",  category: .food, name: "Bebida energía", emoji: "⚡", price: 20, effects: ["thirst": 60, "energy": 30]),
        // Treats
        ShopItem(id: "cookie",        category: .treats, name: "Galleta",      emoji: "🍪", price: 8,  effects: ["happiness": 20]),
        ShopItem(id: "ice_cream",     category: .treats, name: "Helado",       emoji: "🍦", price: 12, effects: ["happiness": 30, "energy": -5]),
        ShopItem(id: "ball",          category: .treats, name: "Pelota nueva", emoji: "🎾", price: 18, effects: ["happiness": 40]),
        // Accessories
        ShopItem(id: "hat",           category: .accessories, name: "Sombrero",  emoji: "🎩", price: 50, effects: [:]),
        ShopItem(id: "bowtie",        category: .accessories, name: "Moño",      emoji: "🎀", price: 40, effects: [:]),
        ShopItem(id: "crown",         category: .accessories, name: "Corona",    emoji: "👑", price: 200, effects: [:]),
        // Cosmetics (room/scene unlocks)
        ShopItem(id: "rainbow",       category: .cosmetics,   name: "Aura arcoíris", emoji: "🌈", price: 100, effects: [:]),
        ShopItem(id: "sparkles",      category: .cosmetics,   name: "Brillos",       emoji: "✨", price: 60,  effects: [:])
    ]

    static func items(in category: ShopCategory) -> [ShopItem] {
        all.filter { $0.category == category }
    }
}

/// Inventory of purchased items.
struct InventoryStore {
    private static let key = "buddy.inventory.v1"
    private static let equippedKey = "buddy.equipped.v1"

    static func owned() -> Set<String> {
        guard let arr = UserDefaults.standard.array(forKey: key) as? [String] else { return [] }
        return Set(arr)
    }
    static func add(_ id: String) {
        var set = owned(); set.insert(id)
        UserDefaults.standard.set(Array(set), forKey: key)
    }
    static func has(_ id: String) -> Bool { owned().contains(id) }

    static var equippedAccessoryID: String? {
        get { UserDefaults.standard.string(forKey: equippedKey) }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: equippedKey) }
            else { UserDefaults.standard.removeObject(forKey: equippedKey) }
        }
    }

    static var equippedAccessoryEmoji: String? {
        guard let id = equippedAccessoryID,
              let item = ShopCatalog.all.first(where: { $0.id == id }) else { return nil }
        return item.emoji
    }
}
