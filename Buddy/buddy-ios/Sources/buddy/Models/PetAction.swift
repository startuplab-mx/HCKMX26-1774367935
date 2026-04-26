import Foundation

enum PetAction: String, Codable, CaseIterable {
    case idle
    case eat
    case sleep
    case play
    case sad

    var label: String {
        switch self {
        case .idle:  "tranquilo"
        case .eat:   "comiendo"
        case .sleep: "durmiendo"
        case .play:  "jugando"
        case .sad:   "triste"
        }
    }

    /// 4×4 sheet layout: row 0 idle | row 1 walk | row 2 eat | row 3 sleep
    /// Other actions (play, sad) reuse closest visual fit.
    var spriteFrames: (row: Int, frames: [Int]) {
        switch self {
        case .idle:  (0, [0, 1, 2, 3])
        case .eat:   (2, [0, 1, 2, 3])
        case .sleep: (3, [0, 1, 2, 3])
        case .play:  (1, [0, 1, 2, 3])  // walk frames look energetic
        case .sad:   (0, [0, 1])         // idle slow
        }
    }
}
