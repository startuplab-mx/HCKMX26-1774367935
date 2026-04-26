import Foundation
import UserNotifications

/// Schedules local notifications when the pet's needs become critical while the app is backgrounded.
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func scheduleNeedReminders(pet: Pet) {
        cancelAll()
        // Predict when each stat will reach critical (~25) based on decay rates
        let predictions: [(PetNeed, TimeInterval)] = [
            (.hungry,  estimateMinutesUntil(critical: pet.stats.hunger,    decayPerMin: 3.0)),
            (.thirsty, estimateMinutesUntil(critical: pet.stats.thirst,    decayPerMin: 4.0)),
            (.sleepy,  estimateMinutesUntil(critical: pet.stats.energy,    decayPerMin: 1.5)),
            (.dirty,   estimateMinutesUntil(critical: pet.stats.hygiene,   decayPerMin: 1.0)),
            (.bored,   estimateMinutesUntil(critical: pet.stats.happiness, decayPerMin: 1.5))
        ].filter { $0.1 > 1 }

        for (need, minutes) in predictions {
            let delay = minutes * 60
            schedule(
                id: "need.\(need.rawValue)",
                title: "\(pet.name) te necesita",
                body: "\(need.emoji) \(pet.name) tiene \(need.label.lowercased()). Atiéndelo antes de que sea tarde.",
                in: delay
            )
        }

        // Critical death warning (if any stat already below 10)
        if pet.stats.hunger < 10 || pet.stats.thirst < 10 || pet.stats.happiness < 10 {
            schedule(
                id: "critical",
                title: "⚠️ \(pet.name) está muy débil",
                body: "Si no lo atiendes pronto, podrías perderlo.",
                in: 60 * 5
            )
        }
    }

    private func estimateMinutesUntil(critical: Int, decayPerMin: Double) -> TimeInterval {
        let target = 25
        guard critical > target else { return 0 }
        return Double(critical - target) / decayPerMin
    }

    private func schedule(id: String, title: String, body: String, in seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, seconds), repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
}
