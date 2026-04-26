import Foundation

/// Huella de comportamiento · anónima, sin nombres, sin identidades.
/// Se genera solo si el dueño del caso decide aportarla al foro (opt-in).
struct PatternFootprint: Identifiable, Hashable {
    let id: String           // ej. "#47"
    let emojis: [String]     // ["😍", "🎁", "🤫"]
    let phrases: [String]    // ["no le digas a tu mamá", "tengo un regalo"]
    let platforms: [Platform]
    let approach: [Approach]
    let timeWindow: TimeWindow
    let ageRange: AgeRange
    let status: CaseStatus
    let matchCount: Int      // "me pasó también: N"
    let createdAt: Date
    let summary: String      // texto corto descriptivo, ya censurado
    var isMine: Bool = false // aportada por el usuario

    enum Platform: String, CaseIterable {
        case tiktok = "TikTok"
        case discord = "Discord"
        case instagram = "Instagram"
        case roblox = "Roblox"
        case telegram = "Telegram"
        case whatsapp = "WhatsApp"
        case snapchat = "Snapchat"
    }

    enum Approach: String {
        case compliment = "elogio"
        case gift = "regalo"
        case falseAge = "edad alterada"
        case fakeProfile = "perfil falso"
        case secrecy = "secreto"
        case virtualCurrency = "moneda virtual"
        case isolation = "aislamiento"
        case commitment = "compromiso"
    }

    enum TimeWindow: String {
        case morning = "mañana"
        case afternoon = "tarde"
        case night = "noche"
        case lateNight = "madrugada"
    }

    enum AgeRange: String {
        case preteen = "10–12"
        case earlyTeen = "13–15"
        case lateTeen = "16–17"
    }

    enum CaseStatus: String {
        case pending, reviewed, escalated, resolved

        var label: String {
            switch self {
            case .pending: "pendiente"
            case .reviewed: "revisado"
            case .escalated: "derivado"
            case .resolved: "resuelto"
            }
        }
    }
}

extension PatternFootprint {
    static let mock: [PatternFootprint] = [
        PatternFootprint(
            id: "#47",
            emojis: ["😍", "🎁", "🤫"],
            phrases: ["no le digas a tu mamá", "tengo un regalo"],
            platforms: [.tiktok, .discord],
            approach: [.compliment, .gift, .secrecy],
            timeWindow: .lateNight,
            ageRange: .earlyTeen,
            status: .resolved,
            matchCount: 12,
            createdAt: .now.addingTimeInterval(-60 * 86400),
            summary: "empezó con cumplidos, después pidió fotos. al final lo denuncié."
        ),
        PatternFootprint(
            id: "#62",
            emojis: [],
            phrases: [],
            platforms: [.instagram],
            approach: [.fakeProfile, .falseAge],
            timeWindow: .afternoon,
            ageRange: .earlyTeen,
            status: .reviewed,
            matchCount: 4,
            createdAt: .now.addingTimeInterval(-21 * 86400),
            summary: "decía tener 16, después supe que era alguien del colegio."
        ),
        PatternFootprint(
            id: "#73",
            emojis: ["🎮"],
            phrases: ["amigo especial"],
            platforms: [.roblox],
            approach: [.virtualCurrency, .compliment],
            timeWindow: .night,
            ageRange: .preteen,
            status: .escalated,
            matchCount: 9,
            createdAt: .now.addingTimeInterval(-14 * 86400),
            summary: "me ofreció robux si le mandaba fotos."
        ),
        PatternFootprint(
            id: "#89",
            emojis: ["💸", "🎂", "🎈"],
            phrases: ["es sorpresa para tu cumpleaños"],
            platforms: [.tiktok, .telegram],
            approach: [.gift, .secrecy, .commitment],
            timeWindow: .night,
            ageRange: .earlyTeen,
            status: .escalated,
            matchCount: 7,
            createdAt: .now.addingTimeInterval(-9 * 86400),
            summary: "me decía que tenía una sorpresa, pero nunca podía contarle a nadie."
        ),
        PatternFootprint(
            id: "#102",
            emojis: ["💕"],
            phrases: ["tenemos algo especial tú y yo"],
            platforms: [.snapchat, .whatsapp],
            approach: [.commitment, .isolation],
            timeWindow: .lateNight,
            ageRange: .lateTeen,
            status: .reviewed,
            matchCount: 15,
            createdAt: .now.addingTimeInterval(-4 * 86400),
            summary: "me hacía sentir única. después quería alejarme de mis amigas."
        ),
        PatternFootprint(
            id: "#118",
            emojis: ["📸"],
            phrases: ["foto de buenas noches"],
            platforms: [.discord, .telegram],
            approach: [.compliment, .secrecy],
            timeWindow: .lateNight,
            ageRange: .preteen,
            status: .pending,
            matchCount: 3,
            createdAt: .now.addingTimeInterval(-1 * 86400),
            summary: "pedía una foto mía antes de dormir, cada noche."
        )
    ]
}
