import Foundation
import ActivityKit

// MARK: - Live Activity attributes (shared entre app y widget extension)
// Datos estáticos de la activity vs dinámicos (en ContentState).

struct FluxRiskActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var riskScore: Int              // 0–100
        var trendDirection: TrendDirection
        var activeSignalCount: Int
        var lastSignalTitle: String?    // ej. "Transición TikTok → Discord"
        var lastSignalTime: Date?
        var weProtectBadge: String      // "Apple Intelligence" o "WeProtect Rules"

        var band: Band {
            switch riskScore {
            case 0..<30: .safe
            case 30..<65: .moderate
            default: .elevated
            }
        }

        enum Band: String, Codable {
            case safe, moderate, elevated
        }

        enum TrendDirection: String, Codable {
            case up, flat, down

            var symbol: String {
                switch self {
                case .up: "↑"
                case .flat: "→"
                case .down: "↓"
                }
            }
        }
    }

    var childName: String               // ej. "Lucía"
    var childAge: Int
}
