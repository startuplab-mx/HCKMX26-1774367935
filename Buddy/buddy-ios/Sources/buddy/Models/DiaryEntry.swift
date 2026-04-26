import Foundation

struct DiaryEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let action: String      // PetAction.rawValue or "system"
    let detail: String      // human-readable
    let emoji: String

    init(action: PetAction, detail: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.action = action.rawValue
        self.detail = detail
        self.emoji = action.emoji
    }

    init(emoji: String, detail: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.action = "system"
        self.detail = detail
        self.emoji = emoji
    }
}

extension PetAction {
    var emoji: String {
        switch self {
        case .idle: "✨"
        case .eat: "🍖"
        case .sleep: "💤"
        case .play: "🎾"
        case .sad: "😢"
        }
    }
}

struct DiaryStore {
    private static let key = "buddy.diary.v1"

    static func entries() -> [DiaryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([DiaryEntry].self, from: data) else { return [] }
        return arr
    }

    static func append(_ entry: DiaryEntry) {
        var arr = entries()
        arr.insert(entry, at: 0)
        // keep last 100
        if arr.count > 100 { arr = Array(arr.prefix(100)) }
        if let data = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
