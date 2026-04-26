import 'package:shared_preferences/shared_preferences.dart';

import '../../models/achievement.dart';
import '../../models/pet.dart';
import '../../models/pet_action.dart';
import '../../models/personality.dart';
import '../persistence/coin_wallet.dart';
import 'toast_queue.dart';

/// Centraliza la detección de achievements.
class AchievementUnlocker {
  static Future<void> checkAfterAction({
    required PetAction action,
    required Pet pet,
    required PersonalityTracker personality,
  }) async {
    final unlocked = <Achievement>[];

    Future<void> tryUnlock(Achievement a) async {
      if (await AchievementStore.unlock(a)) unlocked.add(a);
    }

    switch (action) {
      case PetAction.eat:
        await tryUnlock(Achievement.firstFeed);
        if (personality.feedCount >= 10) await tryUnlock(Achievement.fed10);
        if (personality.feedCount >= 50) await tryUnlock(Achievement.fed50);
        break;
      case PetAction.play:
        await tryUnlock(Achievement.firstPlay);
        if (personality.playCount >= 25) await tryUnlock(Achievement.played25);
        break;
      case PetAction.sleep:
        await tryUnlock(Achievement.firstSleep);
        break;
      default:
        break;
    }

    if (pet.moodLevel >= 3) await tryUnlock(Achievement.maxMood);

    final s = pet.stats;
    if (s.hunger > 90 && s.thirst > 90 && s.energy > 90 && s.hygiene > 90 && s.happiness > 90) {
      await tryUnlock(Achievement.fullStats);
    }

    final coins = await CoinWallet.balance();
    if (coins >= 100) await tryUnlock(Achievement.coins100);
    if (coins >= 500) await tryUnlock(Achievement.coins500);

    if (pet.ageInDays >= 3)  await tryUnlock(Achievement.daysAlive3);
    if (pet.ageInDays >= 7)  await tryUnlock(Achievement.daysAlive7);
    if (pet.ageInDays >= 30) await tryUnlock(Achievement.daysAlive30);

    for (final a in unlocked) {
      ToastQueue.instance.show(emoji: a.emoji, title: 'Logro: ${a.title}', detail: '+${a.reward}🪙');
    }
  }

  static Future<void> bath() async {
    if (await AchievementStore.unlock(Achievement.firstBath)) {
      ToastQueue.instance.show(
        emoji: Achievement.firstBath.emoji,
        title: 'Logro: ${Achievement.firstBath.title}',
        detail: '+${Achievement.firstBath.reward}🪙',
      );
    }
  }

  static Future<void> minigamePlayed() async {
    if (await AchievementStore.unlock(Achievement.minigame1)) {
      ToastQueue.instance.show(
        emoji: Achievement.minigame1.emoji,
        title: 'Logro: ${Achievement.minigame1.title}',
        detail: '+${Achievement.minigame1.reward}🪙',
      );
    }
  }

  static Future<void> reincarnation() async {
    if (await AchievementStore.unlock(Achievement.firstReincarnation)) {
      ToastQueue.instance.show(
        emoji: Achievement.firstReincarnation.emoji,
        title: 'Logro: ${Achievement.firstReincarnation.title}',
        detail: '+${Achievement.firstReincarnation.reward}🪙',
      );
    }
  }

  static Future<void> recordMinigamePlayed(String minigameId) async {
    final prefs = await SharedPreferences.getInstance();
    final played = (prefs.getStringList('buddy.minigames.played.v1') ?? const []).toSet()
      ..add(minigameId);
    await prefs.setStringList('buddy.minigames.played.v1', played.toList());
  }
}
