import Foundation
import ActivityKit

// MARK: - Live Activity manager
// Controla el ciclo de vida de la activity: start, update, end.
// Se llama desde el dashboard o desde el pipeline de detección de señales.

@MainActor
final class FluxLiveActivityManager: ObservableObject {
    static let shared = FluxLiveActivityManager()

    @Published private(set) var activityID: String?

    private init() {}

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Start

    func start(childName: String, childAge: Int, state: FluxRiskActivityAttributes.ContentState) {
        guard isAvailable else {
            print("[LiveActivity] ⚠️ Activities no autorizadas")
            return
        }

        // Si ya hay una activity, solo actualizamos
        if activityID != nil {
            Task { await update(state: state) }
            return
        }

        let attrs = FluxRiskActivityAttributes(childName: childName, childAge: childAge)
        let content = ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(3600))

        do {
            let activity = try Activity<FluxRiskActivityAttributes>.request(
                attributes: attrs,
                content: content,
                pushType: nil
            )
            activityID = activity.id
            print("[LiveActivity] ✅ started id=\(activity.id)")
        } catch {
            print("[LiveActivity] ❌ start falló: \(error)")
        }
    }

    // MARK: - Update

    func update(state: FluxRiskActivityAttributes.ContentState) async {
        guard let id = activityID,
              let activity = Activity<FluxRiskActivityAttributes>.activities.first(where: { $0.id == id })
        else { return }

        let content = ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(3600))
        await activity.update(content)
        print("[LiveActivity] 🔄 updated score=\(state.riskScore)")
    }

    // MARK: - End

    func end(finalState: FluxRiskActivityAttributes.ContentState? = nil, dismissAfter: TimeInterval = 4) async {
        guard let id = activityID,
              let activity = Activity<FluxRiskActivityAttributes>.activities.first(where: { $0.id == id })
        else { return }

        let content: ActivityContent<FluxRiskActivityAttributes.ContentState>? = finalState.map {
            ActivityContent(state: $0, staleDate: nil)
        }

        await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(dismissAfter)))
        activityID = nil
        print("[LiveActivity] 🛑 ended")
    }

    // MARK: - Helper para construir state desde datos de dashboard

    static func makeState(from score: RiskScore, weProtectBadge: String, lastSignal: DetectedSignal? = nil) -> FluxRiskActivityAttributes.ContentState {
        let direction: FluxRiskActivityAttributes.ContentState.TrendDirection = {
            guard score.trend.count >= 2,
                  let first = score.trend.first,
                  let last = score.trend.last else { return .flat }
            let delta = last - first
            if delta > 5 { return .up }
            if delta < -5 { return .down }
            return .flat
        }()

        return FluxRiskActivityAttributes.ContentState(
            riskScore: score.value,
            trendDirection: direction,
            activeSignalCount: score.activeCount,
            lastSignalTitle: lastSignal?.title,
            lastSignalTime: lastSignal?.detectedAt,
            weProtectBadge: weProtectBadge
        )
    }
}
