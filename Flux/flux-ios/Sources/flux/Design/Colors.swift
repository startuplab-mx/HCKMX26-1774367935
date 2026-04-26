import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum FluxColor {
    // Base
    static let base = Color(hex: 0xFAF8F5)
    static let surface = Color(hex: 0xFFFFFF)
    static let surfaceAlt = Color(hex: 0xF4F0E9)
    static let surfaceElevated = Color(hex: 0xEDE7DB)

    // Ink
    static let ink = Color(hex: 0x1A1D23)
    static let inkMuted = Color(hex: 0x57534E)
    static let inkFaint = Color(hex: 0xA8A29E)
    static let line = Color(hex: 0xE7E5E4)

    // Semánticos
    static let primary = Color(hex: 0x0F766E)
    static let primarySoft = Color(hex: 0x0F766E, alpha: 0.08)
    static let primaryDark = Color(hex: 0x0A5952)
    static let accent = Color(hex: 0xFB7185)
    static let safe = Color(hex: 0x059669)
    static let warn = Color(hex: 0xD97706)
    static let danger = Color(hex: 0xDC2626)
    static let dangerSoft = Color(hex: 0xDC2626, alpha: 0.08)

    // Modo menor — flux voz
    static let voz = Color(hex: 0xFAF6EE)
    static let vozInk = Color(hex: 0x2D2A26)
    static let vozMuted = Color(hex: 0x8B867D)
    static let vozAccent = Color(hex: 0x8B5E3C)
    static let vozSurface = Color(hex: 0xFFFFFF)
    static let vozCard = Color(hex: 0xF3E8D5)
    static let vozLine = Color(hex: 0xE8DFCA)

    // Risk bands
    static func riskColor(for score: Int) -> Color {
        switch score {
        case 0..<30: return safe
        case 30..<65: return warn
        default: return danger
        }
    }
}
