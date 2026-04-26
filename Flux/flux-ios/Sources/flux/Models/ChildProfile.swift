import Foundation

struct ChildProfile: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var age: Int
    var baselineApps: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        age: Int,
        baselineApps: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.baselineApps = baselineApps
        self.createdAt = createdAt
    }

    static let preview = ChildProfile(
        name: "Lucía",
        age: 13,
        baselineApps: ["TikTok", "Instagram", "WhatsApp", "YouTube"]
    )
}
