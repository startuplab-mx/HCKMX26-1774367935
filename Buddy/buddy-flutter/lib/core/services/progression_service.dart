import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../persistence/coin_wallet.dart';

/// Bono diario + sistema de XP/level del cuidador.
class ProgressionService {
  static const _xpKey        = 'buddy.caretaker.xp.v1';
  static const _lastLoginKey = 'buddy.lastLogin.v1';
  static const _streakKey    = 'buddy.streak.v1';

  // --- XP / Level -------------------------------------------------------

  static Future<int> xp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_xpKey) ?? 0;
  }

  static Future<void> addXP(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getInt(_xpKey) ?? 0) + amount;
    await prefs.setInt(_xpKey, v < 0 ? 0 : v);
  }

  static Future<int> level() async {
    final x = await xp();
    return math.sqrt(x / 100.0).floor() + 1;
  }

  static Future<int> xpInCurrentLevel() async {
    final lvl = await level();
    final prevReq = math.pow(lvl - 1, 2).toInt() * 100;
    return (await xp()) - prevReq;
  }

  static Future<int> xpForNextLevel() async {
    final lvl = await level();
    final nextReq = math.pow(lvl, 2).toInt() * 100;
    final prevReq = math.pow(lvl - 1, 2).toInt() * 100;
    return nextReq - prevReq;
  }

  // --- Daily login -----------------------------------------------------

  static Future<int?> claimDailyBonusIfAvailable() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastIso = prefs.getString(_lastLoginKey);
    final last = lastIso != null ? DateTime.parse(lastIso) : null;
    var streak = prefs.getInt(_streakKey) ?? 0;

    if (last != null) {
      final sameDay = last.year == now.year && last.month == now.month && last.day == now.day;
      if (sameDay) return null;
      final yesterday = now.subtract(const Duration(days: 1));
      final wasYesterday = last.year == yesterday.year &&
          last.month == yesterday.month &&
          last.day == yesterday.day;
      streak = wasYesterday ? streak + 1 : 1;
    } else {
      streak = 1;
    }

    await prefs.setInt(_streakKey, streak);
    await prefs.setString(_lastLoginKey, now.toIso8601String());
    final bonus = math.min(50, 5 + streak * 2);
    await CoinWallet.add(bonus);
    return bonus;
  }

  static Future<int> streak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_xpKey);
    await prefs.remove(_lastLoginKey);
    await prefs.remove(_streakKey);
  }
}
