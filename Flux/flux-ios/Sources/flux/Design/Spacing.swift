import SwiftUI

enum FluxSpace {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let base: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let h3: CGFloat = 40
    static let h2: CGFloat = 48
    static let h1: CGFloat = 64
    static let hero: CGFloat = 80
}

enum FluxRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let card: CGFloat = 22
    static let pill: CGFloat = 100
    static let device: CGFloat = 42
}

enum FluxShadow {
    case sm, md, lg, card

    var radius: CGFloat {
        switch self {
        case .sm: return 2
        case .md: return 12
        case .lg: return 32
        case .card: return 24
        }
    }

    var y: CGFloat {
        switch self {
        case .sm: return 1
        case .md: return 4
        case .lg: return 12
        case .card: return 16
        }
    }

    var opacity: Double {
        switch self {
        case .sm: return 0.04
        case .md: return 0.06
        case .lg: return 0.10
        case .card: return 0.08
        }
    }
}

extension View {
    func fluxShadow(_ kind: FluxShadow = .md) -> some View {
        self.shadow(
            color: FluxColor.ink.opacity(kind.opacity),
            radius: kind.radius,
            x: 0,
            y: kind.y
        )
    }
}
