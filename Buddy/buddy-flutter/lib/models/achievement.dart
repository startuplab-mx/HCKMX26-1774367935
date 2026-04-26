import 'package:shared_preferences/shared_preferences.dart';

import '../core/persistence/coin_wallet.dart';

enum Achievement {
  firstFeed,
  firstPlay,
  firstSleep,
  firstBath,
  fed10,
  fed50,
  played25,
  bath10,
  daysAlive3,
  daysAlive7,
  daysAlive30,
  maxMood,
  fullStats,
  coins100,
  coins500,
  minigame1,
  allMinigames,
  firstReincarnation;

  String get title => switch (this) {
        Achievement.firstFeed         => 'Primera comida',
        Achievement.firstPlay         => 'Primer juego',
        Achievement.firstSleep        => 'Primer sueño',
        Achievement.firstBath         => 'Primer baño',
        Achievement.fed10             => 'Cocinero · 10 comidas',
        Achievement.fed50             => 'Chef · 50 comidas',
        Achievement.played25          => 'Compañero · 25 juegos',
        Achievement.bath10            => 'Limpiador · 10 baños',
        Achievement.daysAlive3        => '3 días vivo',
        Achievement.daysAlive7        => 'Una semana',
        Achievement.daysAlive30       => 'Un mes entero',
        Achievement.maxMood           => 'Máxima felicidad',
        Achievement.fullStats         => 'Cuidado perfecto',
        Achievement.coins100          => '100 monedas',
        Achievement.coins500          => '500 monedas',
        Achievement.minigame1         => 'Primer mini-juego',
        Achievement.allMinigames      => 'Todos los mini-juegos',
        Achievement.firstReincarnation=> 'Primera reencarnación',
      };

  String get emoji => switch (this) {
        Achievement.firstFeed         => '🍖',
        Achievement.firstPlay         => '🎾',
        Achievement.firstSleep        => '💤',
        Achievement.firstBath         => '🛁',
        Achievement.fed10             => '🥄',
        Achievement.fed50             => '👨‍🍳',
        Achievement.played25          => '🎮',
        Achievement.bath10            => '🚿',
        Achievement.daysAlive3        => '🌱',
        Achievement.daysAlive7        => '🌿',
        Achievement.daysAlive30       => '🌳',
        Achievement.maxMood           => '😍',
        Achievement.fullStats         => '⭐',
        Achievement.coins100          => '💰',
        Achievement.coins500          => '💎',
        Achievement.minigame1         => '🎯',
        Achievement.allMinigames      => '🏆',
        Achievement.firstReincarnation=> '🌟',
      };

  int get reward => switch (this) {
        Achievement.firstFeed ||
        Achievement.firstPlay ||
        Achievement.firstSleep ||
        Achievement.firstBath ||
        Achievement.minigame1                                       => 5,
        Achievement.fed10 ||
        Achievement.played25 ||
        Achievement.bath10                                          => 15,
        Achievement.daysAlive3 ||
        Achievement.coins100                                        => 25,
        Achievement.daysAlive7 ||
        Achievement.coins500 ||
        Achievement.maxMood ||
        Achievement.fullStats                                       => 50,
        Achievement.fed50 ||
        Achievement.daysAlive30 ||
        Achievement.allMinigames ||
        Achievement.firstReincarnation                              => 100,
      };
}

class AchievementStore {
  static const _key = 'buddy.achievements.v1';

  static Future<Set<Achievement>> unlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final raws = prefs.getStringList(_key) ?? const [];
    return raws
        .map((r) => Achievement.values.where((a) => a.name == r).firstOrNull)
        .whereType<Achievement>()
        .toSet();
  }

  /// Devuelve `true` si el achievement no estaba desbloqueado y se otorgó la recompensa.
  static Future<bool> unlock(Achievement a) async {
    final set = await unlocked();
    if (set.contains(a)) return false;
    set.add(a);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, set.map((e) => e.name).toList());
    await CoinWallet.add(a.reward);
    return true;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
