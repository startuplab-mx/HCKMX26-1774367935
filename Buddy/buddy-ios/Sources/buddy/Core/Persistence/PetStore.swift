import Foundation

/// Lightweight UserDefaults-backed persistence (we'll migrate to SwiftData later if needed).
/// Stores the active pet snapshot so it survives app restarts.
struct PetStore {
    private static let key = "buddy.pet.v1"

    static func load() -> Pet? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return nil
        }
        let pet = Pet(
            name: snap.name,
            character: PetCharacter(rawValue: snap.characterRaw) ?? .garfield,
            bornAt: snap.bornAt,
            stats: PetStats(
                hunger: snap.hunger,
                thirst: snap.thirst,
                energy: snap.energy,
                hygiene: snap.hygiene,
                happiness: snap.happiness
            ),
            currentAction: PetAction(rawValue: snap.actionRaw) ?? .idle
        )
        return pet
    }

    static func save(_ pet: Pet) {
        let snap = Snapshot(
            name: pet.name,
            characterRaw: pet.character.rawValue,
            bornAt: pet.bornAt,
            hunger: pet.stats.hunger,
            thirst: pet.stats.thirst,
            energy: pet.stats.energy,
            hygiene: pet.stats.hygiene,
            happiness: pet.stats.happiness,
            actionRaw: pet.currentAction.rawValue
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private struct Snapshot: Codable {
        var name: String
        var characterRaw: String
        var bornAt: Date
        var hunger, thirst, energy, hygiene, happiness: Int
        var actionRaw: String
    }
}

/// Coin wallet — separate so wallet survives even when pet dies/reincarnates.
struct CoinWallet {
    private static let key = "buddy.coins.v1"
    static var balance: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    static func add(_ amount: Int) { balance = max(0, balance + amount) }
    static func spend(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }
}
