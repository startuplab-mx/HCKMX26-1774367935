import DeviceActivity
import Foundation
import ManagedSettings

/// Extensión DeviceActivityMonitor. iOS la despierta en respuesta a los
/// thresholds y ventanas que configura `FluxMonitorService`.
///
/// Aquí NO hablamos con la red (iOS mata las extensiones muy rápido). Sólo
/// encolamos eventos en `FluxEventQueue`, y la app principal los drena.
class FluxDeviceActivityMonitor: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        enqueue(kind: .sessionStart, bundle: "unknown", name: activity.rawValue)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        enqueue(kind: .sessionEnd, bundle: "unknown", name: activity.rawValue)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        enqueue(
            kind: .thresholdHit,
            bundle: event.rawValue,         // el servicio padre codifica bundle en el event name
            name: event.rawValue
        )
    }

    private func enqueue(
        kind: FluxUsageEvent.Kind,
        bundle: String,
        name: String
    ) {
        let ev = FluxUsageEvent(
            kind: kind,
            appBundle: bundle,
            appName: name,
            category: nil,                  // el backend clasifica
            ts: Date(),
            durationS: 0
        )
        FluxEventQueue.shared.enqueue(ev)
    }
}
