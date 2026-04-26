import Foundation
import UIKit

/// "Espejo de hábitos" — refleja el comportamiento del usuario en la mascota.
///
/// Por qué esta implementación y no DNS-monitoring:
/// - Monitorear DNS del celular requiere un VPN profile + NetworkExtension entitlement aprobado por Apple
/// - El usuario tendría que aceptar manualmente el VPN (fricción enorme)
/// - Apple ya tiene API oficial: FamilyControls + DeviceActivity (Screen Time API), pero requiere
///   entitlement aprobado caso por caso
///
/// En su lugar este servicio mide TU uso de Buddy (sesiones, tiempo total, hora del día) y lo
/// refleja en la mascota: si juegas demasiado seguido tu mascota se sobreestimula, si la abandonas
/// está triste cuando vuelves, etc.
///
/// Cuando Apple apruebe el entitlement de FamilyControls podemos extender este servicio para que
/// monitoree el uso del teléfono completo. La API de hooks ya está lista para esa extensión.
final class HabitMirrorService {
    static let shared = HabitMirrorService()
    private init() {
        registerObservers()
    }

    // MARK: - Tracking

    private struct Session: Codable {
        let start: Date
        var end: Date?
    }

    private static let sessionsKey = "buddy.habit.sessions.v1"
    private static let lastBackgroundKey = "buddy.habit.lastBackground.v1"

    private var currentSession: Session?

    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(didEnterForeground),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
    }

    @objc private func didEnterForeground() {
        currentSession = Session(start: Date())
    }

    @objc private func didEnterBackground() {
        guard var session = currentSession else { return }
        session.end = Date()
        appendSession(session)
        currentSession = nil
        UserDefaults.standard.set(Date(), forKey: Self.lastBackgroundKey)
    }

    private func appendSession(_ session: Session) {
        var arr = loadSessions()
        arr.append(session)
        // Keep last 7 days only
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        arr = arr.filter { $0.start > cutoff }
        if let data = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(data, forKey: Self.sessionsKey)
        }
    }

    private func loadSessions() -> [Session] {
        guard let data = UserDefaults.standard.data(forKey: Self.sessionsKey),
              let arr = try? JSONDecoder().decode([Session].self, from: data) else { return [] }
        return arr
    }

    // MARK: - Reflections

    /// Hours since the user last opened Buddy.
    var hoursSinceLastSession: Double {
        guard let last = UserDefaults.standard.object(forKey: Self.lastBackgroundKey) as? Date else { return 0 }
        return Date().timeIntervalSince(last) / 3600
    }

    /// Total foreground minutes today.
    var minutesUsedToday: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sessions = loadSessions().filter { $0.start >= today }
        let totalSeconds = sessions.reduce(0.0) { acc, s in
            let end = s.end ?? Date()
            return acc + end.timeIntervalSince(s.start)
        }
        return Int(totalSeconds / 60)
    }

    /// Number of distinct sessions today.
    var sessionsToday: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return loadSessions().filter { $0.start >= today }.count
    }

    /// Apply mirror effects to the pet:
    /// - If the user abandoned the pet > 6h: drop happiness (pet missed you)
    /// - If the user has been on the app > 30 min today: pet over-stimulated (drop energy)
    /// - If first session of the day: pet excited (boost happiness)
    func applyMirror(to pet: Pet) -> [String] {
        var messages: [String] = []
        var s = pet.stats

        if hoursSinceLastSession > 6 {
            let drop = min(20, Int(hoursSinceLastSession - 6) * 3)
            s.happiness = max(0, s.happiness - drop)
            messages.append("\(pet.name) te extrañó (-\(drop) felicidad)")
        }

        if minutesUsedToday > 30 {
            s.energy = max(0, s.energy - 10)
            messages.append("\(pet.name) está sobreestimulado (-10 energía)")
        }

        if sessionsToday == 1 {
            s.happiness = min(100, s.happiness + 8)
            messages.append("¡\(pet.name) está feliz de verte! (+8 felicidad)")
        }

        s.clamp()
        pet.stats = s
        return messages
    }
}
