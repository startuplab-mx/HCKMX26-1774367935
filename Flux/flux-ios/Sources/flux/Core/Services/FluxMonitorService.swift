import Foundation

#if os(iOS)
import FamilyControls
import DeviceActivity
import ManagedSettings

/// Orquesta el monitoreo del dispositivo del menor:
///   1. Autorización de Family Controls (se pide con Apple ID del padre).
///   2. Programa una `DeviceActivitySchedule` 24/7.
///   3. La extensión `fluxMonitor` (DeviceActivityMonitor) recibe los eventos,
///      los encola en `FluxEventQueue` y esta clase los drena al backend.
///
/// Solo disponible en el target de la app principal (no en extensiones).
@available(iOS 16.0, *)
@MainActor
final class FluxMonitorService: ObservableObject {

    static let shared = FluxMonitorService()

    static let activityName = DeviceActivityName("flux.always")

    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastFlushError: String?
    @Published private(set) var lastFlushAt: Date?

    private let center = DeviceActivityCenter()
    private let backend = FluxBackendClient.shared
    private let queue = FluxEventQueue.shared

    /// Pide autorización. En un dispositivo vinculado a Family Sharing, el
    /// padre la aprueba con su Apple ID y queda protegida por parentalControls.
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            lastFlushError = "auth: \(error.localizedDescription)"
        }
    }

    /// Arranca la observación 24/7. La extensión despertará por cambios.
    func startMonitoring() throws {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        try center.startMonitoring(Self.activityName, during: schedule)
        isMonitoring = true
    }

    func stopMonitoring() {
        center.stopMonitoring([Self.activityName])
        isMonitoring = false
    }

    // MARK: - Demo mode (mock events)
    // Family Controls requiere Developer Program + aprobación de Apple.
    // Mientras Apple aprueba, inyectamos eventos sintéticos para demo.

    /// Inyecta un escenario completo en la cola y lo envía al backend.
    func injectMockScenario(_ scenario: MockScenario, childID: UUID) async {
        FluxEventQueue.shared.enqueue(scenario.events())
        await flushPendingEvents(childID: childID)
    }

    /// Envía al backend todos los eventos que la extensión ha encolado.
    /// Llamar al abrir la app, periódicamente, o al recibir background refresh.
    func flushPendingEvents(childID: UUID) async {
        do {
            _ = try await backend.flushQueue(childID: childID, queue: queue)
            lastFlushAt = Date()
            lastFlushError = nil
        } catch {
            lastFlushError = String(describing: error)
        }
    }
}

#else

/// Stub cuando los frameworks de Screen Time no están disponibles
/// (tests unitarios, simulator sin capability, macOS, etc.).
@MainActor
final class FluxMonitorService: ObservableObject {
    static let shared = FluxMonitorService()
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastFlushError: String? = "FamilyControls no disponible en este build"
    @Published private(set) var lastFlushAt: Date?

    func requestAuthorization() async {}
    func startMonitoring() throws {}
    func stopMonitoring() {}
    func flushPendingEvents(childID: UUID) async {}
    func injectMockScenario(_ scenario: MockScenario, childID: UUID) async {}
}

#endif
