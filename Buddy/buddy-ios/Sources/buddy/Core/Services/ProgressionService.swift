import Foundation

/// Daily login bonus + caretaker XP/level system.
struct ProgressionService {
    private static let xpKey = "buddy.caretaker.xp.v1"
    private static let lastLoginKey = "buddy.lastLogin.v1"
    private static let streakKey = "buddy.streak.v1"

    // MARK: - Caretaker XP / Level

    static var xp: Int {
        get { UserDefaults.standard.integer(forKey: xpKey) }
        set { UserDefaults.standard.set(newValue, forKey: xpKey) }
    }

    static func addXP(_ amount: Int) {
        xp = max(0, xp + amount)
    }

    static var level: Int {
        // Level n requires n*100 XP to reach
        Int((Double(xp) / 100.0).squareRoot()) + 1
    }

    static var xpInCurrentLevel: Int {
        let lvl = level
        let prevReq = Int(pow(Double(lvl - 1), 2)) * 100
        return xp - prevReq
    }

    static var xpForNextLevel: Int {
        let lvl = level
        let nextReq = Int(pow(Double(lvl), 2)) * 100
        let prevReq = Int(pow(Double(lvl - 1), 2)) * 100
        return nextReq - prevReq
    }

    // MARK: - Daily login

    static var lastLogin: Date? {
        get { UserDefaults.standard.object(forKey: lastLoginKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastLoginKey) }
    }

    static var streak: Int {
        get { UserDefaults.standard.integer(forKey: streakKey) }
        set { UserDefaults.standard.set(newValue, forKey: streakKey) }
    }

    /// Returns the bonus amount if a new day has started, otherwise nil.
    @discardableResult
    static func claimDailyBonusIfAvailable() -> Int? {
        let cal = Calendar.current
        let now = Date()
        if let last = lastLogin {
            if cal.isDate(last, inSameDayAs: now) { return nil }
            // Continuous streak only if yesterday
            if let yesterday = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(last, inSameDayAs: yesterday) {
                streak += 1
            } else {
                streak = 1
            }
        } else {
            streak = 1
        }
        lastLogin = now
        let bonus = min(50, 5 + streak * 2) // 5,7,9,11... cap 50
        CoinWallet.add(bonus)
        return bonus
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: xpKey)
        UserDefaults.standard.removeObject(forKey: lastLoginKey)
        UserDefaults.standard.removeObject(forKey: streakKey)
    }
}
