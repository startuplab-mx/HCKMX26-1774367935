import Foundation

/// Evento de uso que el agente del menor envía al backend.
/// Schema 1:1 con `UsageEventIn` de backend/models.py.
struct FluxUsageEvent: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case sessionStart = "session_start"
        case sessionEnd = "session_end"
        case appInstall = "app_install"
        case appUninstall = "app_uninstall"
        case thresholdHit = "threshold_hit"
    }

    enum Category: String, Codable {
        case gaming, chat, social, video, adult, vpn, education, productivity, other
    }

    var id = UUID()
    let kind: Kind
    let appBundle: String
    let appName: String
    let category: Category?
    let ts: Date
    let durationS: Int

    enum CodingKeys: String, CodingKey {
        case kind, ts
        case appBundle = "app_bundle"
        case appName = "app_name"
        case category
        case durationS = "duration_s"
    }
}

struct FluxUsageBatchRequest: Codable {
    let events: [FluxUsageEvent]
}

struct FluxUsageBatchResponse: Codable {
    let accepted: Int
    let signalsGenerated: Int
    let signalIds: [UUID]

    enum CodingKeys: String, CodingKey {
        case accepted
        case signalsGenerated = "signals_generated"
        case signalIds = "signal_ids"
    }
}
