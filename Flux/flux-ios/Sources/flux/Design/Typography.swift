import SwiftUI

enum FluxFont {
    // MARK: - Display (Geist)
    static func display(_ size: CGFloat, weight: Geist = .bold) -> Font {
        .custom(weight.rawValue, size: size)
    }

    enum Geist: String {
        case light = "Geist-Light"
        case regular = "Geist-Regular"
        case medium = "Geist-Medium"
        case semibold = "Geist-SemiBold"
        case bold = "Geist-Bold"
        case extrabold = "Geist-ExtraBold"
        case black = "Geist-Black"
    }

    // MARK: - Body (Inter)
    static func body(_ size: CGFloat, weight: Inter = .regular) -> Font {
        .custom(weight.rawValue, size: size)
    }

    enum Inter: String {
        case regular = "Inter-Regular"
        case medium = "Inter-Medium"
        case semibold = "Inter-SemiBold"
        case bold = "Inter-Bold"
    }

    // MARK: - Mono (Geist Mono)
    static func mono(_ size: CGFloat, weight: Mono = .medium) -> Font {
        .custom(weight.rawValue, size: size)
    }

    enum Mono: String {
        case regular = "GeistMono-Regular"
        case medium = "GeistMono-Medium"
        case bold = "GeistMono-Bold"
    }

    // MARK: - Caveat (variable font — solo modo menor flux voz)
    static func caveat(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Caveat", size: size).weight(weight)
    }

    // MARK: - Semantic Styles — usa estos, no los raw
    static let displayXL = display(56, weight: .extrabold)   // Score hero
    static let displayLG = display(40, weight: .bold)        // Section titles
    static let title1 = display(28, weight: .bold)           // Pantalla
    static let title2 = display(22, weight: .semibold)       // Card title
    static let title3 = display(18, weight: .semibold)

    static let bodyLG = body(17, weight: .regular)
    static let bodyRG = body(15, weight: .regular)
    static let bodyMD = body(15, weight: .medium)
    static let bodySM = body(13, weight: .regular)
    static let callout = body(14, weight: .medium)

    static let caption = body(12, weight: .medium)
    static let monoSM = mono(11, weight: .medium)            // Labels uppercase

    // Voz
    static let vozGreet = caveat(56, weight: .semibold)      // "buenas noches."
    static let vozGreetSM = caveat(36, weight: .semibold)
}

// Uppercase helper para labels tipo Geist Mono
extension Text {
    func fluxLabel() -> some View {
        self
            .font(FluxFont.monoSM)
            .tracking(2)
            .textCase(.uppercase)
            .foregroundStyle(FluxColor.inkFaint)
    }
}
