import 'package:shared_preferences/shared_preferences.dart';

enum SceneTheme {
  livingRoom,
  bedroom,
  garden,
  kitchen,
  beach;

  String get displayName => switch (this) {
        SceneTheme.livingRoom => 'Sala',
        SceneTheme.bedroom    => 'Recámara',
        SceneTheme.garden     => 'Jardín',
        SceneTheme.kitchen    => 'Cocina',
        SceneTheme.beach      => 'Playa',
      };

  String get emoji => switch (this) {
        SceneTheme.livingRoom => '🛋️',
        SceneTheme.bedroom    => '🛏️',
        SceneTheme.garden     => '🌳',
        SceneTheme.kitchen    => '🍳',
        SceneTheme.beach      => '🏖️',
      };

  String get assetName => switch (this) {
        SceneTheme.livingRoom => 'background_living_room',
        SceneTheme.bedroom    => 'background_bedroom',
        SceneTheme.garden     => 'background_garden',
        SceneTheme.kitchen    => 'background_kitchen',
        SceneTheme.beach      => 'background_beach',
      };

  int get unlockPrice => switch (this) {
        SceneTheme.livingRoom => 0,
        SceneTheme.bedroom    => 50,
        SceneTheme.garden     => 80,
        SceneTheme.kitchen    => 120,
        SceneTheme.beach      => 200,
      };
}

class SceneStore {
  static const _unlockedKey = 'buddy.scenes.unlocked.v1';
  static const _activeKey   = 'buddy.scene.active.v1';

  static Future<Set<SceneTheme>> unlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final raws = prefs.getStringList(_unlockedKey) ?? [SceneTheme.livingRoom.name];
    return raws
        .map((r) => SceneTheme.values.where((s) => s.name == r).firstOrNull)
        .whereType<SceneTheme>()
        .toSet();
  }

  static Future<void> unlock(SceneTheme s) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (await unlocked())..add(s);
    await prefs.setStringList(_unlockedKey, set.map((e) => e.name).toList());
  }

  static Future<SceneTheme> active() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeKey);
    return SceneTheme.values.where((s) => s.name == raw).firstOrNull ?? SceneTheme.livingRoom;
  }

  static Future<void> setActive(SceneTheme s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, s.name);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
