import Foundation

enum EvolutionStage: String, Codable, CaseIterable {
    case baby, kid, teen, adult, elder

    var label: String {
        switch self {
        case .baby:  "Bebé"
        case .kid:   "Cachorro"
        case .teen:  "Joven"
        case .adult: "Adulto"
        case .elder: "Anciano"
        }
    }

    var spriteScale: CGFloat {
        switch self {
        case .baby:  0.6
        case .kid:   0.75
        case .teen:  0.9
        case .adult: 1.0
        case .elder: 1.0
        }
    }

    var emoji: String {
        switch self {
        case .baby:  "🍼"
        case .kid:   "🐾"
        case .teen:  "🌟"
        case .adult: "👑"
        case .elder: "🎩"
        }
    }

    /// Derived from the pet's age in days, plus average care quality.
    static func stage(forAgeDays days: Int) -> EvolutionStage {
        switch days {
        case ..<2:    .baby
        case 2..<5:   .kid
        case 5..<10:  .teen
        case 10..<25: .adult
        default:      .elder
        }
    }
}

import CoreGraphics
