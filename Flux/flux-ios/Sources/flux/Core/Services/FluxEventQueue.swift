import Foundation

/// Cola persistente de eventos de uso, compartida entre la app principal y
/// la extensión `fluxMonitor` (DeviceActivityMonitor) vía App Group.
///
/// La extensión encola eventos cuando iOS la despierta por thresholds y la
/// app principal los drena cuando puede enviarlos al backend.
final class FluxEventQueue {

    static let appGroupID = "group.com.emiliocruz.flux"
    static let storageKey = "flux.usage.queue.v1"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    static let shared = FluxEventQueue()

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: FluxEventQueue.appGroupID)
            ?? .standard
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    /// Encola un evento. Thread-safe via serial queue.
    func enqueue(_ event: FluxUsageEvent) {
        queueSync {
            var current = loadUnsafe()
            current.append(event)
            saveUnsafe(current)
        }
    }

    func enqueue(_ events: [FluxUsageEvent]) {
        guard !events.isEmpty else { return }
        queueSync {
            var current = loadUnsafe()
            current.append(contentsOf: events)
            saveUnsafe(current)
        }
    }

    /// Lee todos los eventos pendientes sin borrarlos.
    func peekAll() -> [FluxUsageEvent] {
        queueSync { loadUnsafe() }
    }

    /// Elimina los eventos indicados por id. Se llama tras confirmación del backend.
    func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        queueSync {
            let filtered = loadUnsafe().filter { !ids.contains($0.id) }
            saveUnsafe(filtered)
        }
    }

    func removeAll() {
        queueSync { saveUnsafe([]) }
    }

    // MARK: - private

    private let serial = DispatchQueue(label: "flux.event.queue.serial")

    private func queueSync<T>(_ block: () -> T) -> T {
        serial.sync(execute: block)
    }

    private func loadUnsafe() -> [FluxUsageEvent] {
        guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
        return (try? decoder.decode([FluxUsageEvent].self, from: data)) ?? []
    }

    private func saveUnsafe(_ events: [FluxUsageEvent]) {
        guard let data = try? encoder.encode(events) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
