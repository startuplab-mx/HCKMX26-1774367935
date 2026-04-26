import Foundation

/// Centralizes achievement detection. Call after every relevant event.
struct AchievementUnlocker {
    static func checkAfterAction(_ action: PetAction, pet: Pet, personality: PersonalityTracker) {
        var unlocked: [Achievement] = []
        // First-time actions
        switch action {
        case .eat:
            if AchievementStore.unlock(.firstFeed) { unlocked.append(.firstFeed) }
            if personality.feedCount >= 10, AchievementStore.unlock(.fed10) { unlocked.append(.fed10) }
            if personality.feedCount >= 50, AchievementStore.unlock(.fed50) { unlocked.append(.fed50) }
        case .play:
            if AchievementStore.unlock(.firstPlay) { unlocked.append(.firstPlay) }
            if personality.playCount >= 25, AchievementStore.unlock(.played25) { unlocked.append(.played25) }
        case .sleep:
            if AchievementStore.unlock(.firstSleep) { unlocked.append(.firstSleep) }
        default: break
        }
        // Stats milestones
        if pet.moodLevel >= 3 {
            if AchievementStore.unlock(.maxMood) { unlocked.append(.maxMood) }
        }
        let s = pet.stats
        if s.hunger > 90 && s.thirst > 90 && s.energy > 90 && s.hygiene > 90 && s.happiness > 90 {
            if AchievementStore.unlock(.fullStats) { unlocked.append(.fullStats) }
        }
        // Coin milestones
        if CoinWallet.balance >= 100, AchievementStore.unlock(.coins100) { unlocked.append(.coins100) }
        if CoinWallet.balance >= 500, AchievementStore.unlock(.coins500) { unlocked.append(.coins500) }
        // Age milestones
        switch pet.ageInDays {
        case 3...:  if AchievementStore.unlock(.daysAlive3) { unlocked.append(.daysAlive3) }
        default: break
        }
        if pet.ageInDays >= 7,  AchievementStore.unlock(.daysAlive7)  { unlocked.append(.daysAlive7)  }
        if pet.ageInDays >= 30, AchievementStore.unlock(.daysAlive30) { unlocked.append(.daysAlive30) }

        for ach in unlocked {
            ToastQueue.shared.show(emoji: ach.emoji, title: "Logro: \(ach.title)", detail: "+\(ach.reward)🪙")
        }
    }

    static func bath() {
        if AchievementStore.unlock(.firstBath) {
            ToastQueue.shared.show(emoji: Achievement.firstBath.emoji, title: "Logro: \(Achievement.firstBath.title)", detail: "+\(Achievement.firstBath.reward)🪙")
        }
    }

    static func minigamePlayed() {
        if AchievementStore.unlock(.minigame1) {
            ToastQueue.shared.show(emoji: Achievement.minigame1.emoji, title: "Logro: \(Achievement.minigame1.title)", detail: "+\(Achievement.minigame1.reward)🪙")
        }
        let played = UserDefaults.standard.stringArray(forKey: "buddy.minigames.played.v1") ?? []
        if Set(played).count >= MinigameID.allCases.count, AchievementStore.unlock(.allMinigames) {
            ToastQueue.shared.show(emoji: Achievement.allMinigames.emoji, title: "Logro: \(Achievement.allMinigames.title)", detail: "+\(Achievement.allMinigames.reward)🪙")
        }
    }

    static func reincarnation() {
        if AchievementStore.unlock(.firstReincarnation) {
            ToastQueue.shared.show(emoji: Achievement.firstReincarnation.emoji, title: "Logro: \(Achievement.firstReincarnation.title)", detail: "+\(Achievement.firstReincarnation.reward)🪙")
        }
    }

    static func recordMinigamePlayed(_ id: MinigameID) {
        var played = Set(UserDefaults.standard.stringArray(forKey: "buddy.minigames.played.v1") ?? [])
        played.insert(id.rawValue)
        UserDefaults.standard.set(Array(played), forKey: "buddy.minigames.played.v1")
    }
}
