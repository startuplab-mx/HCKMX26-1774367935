import ActivityKit
import Foundation

struct BuddyActivityAttributes: ActivityAttributes {
    public typealias ContentState = State

    public struct State: Codable, Hashable {
        var petName: String
        var action: PetAction
        var moodLevel: Int       // 0...3
        var satietyLevel: Int    // 0...2
    }

    var petCharacterRaw: String  // PetCharacter.rawValue
}
