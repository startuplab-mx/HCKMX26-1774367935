import 'package:shared_preferences/shared_preferences.dart';

/// Wallet de monedas — persiste aunque la mascota muera/reencarne.
class CoinWallet {
  static const _key = 'buddy.coins.v1';

  static Future<int> balance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  static Future<void> add(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getInt(_key) ?? 0) + amount;
    await prefs.setInt(_key, v < 0 ? 0 : v);
  }

  /// Devuelve `true` si había saldo suficiente y se gastó.
  static Future<bool> spend(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final cur = prefs.getInt(_key) ?? 0;
    if (cur < amount) return false;
    await prefs.setInt(_key, cur - amount);
    return true;
  }
}
