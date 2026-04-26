import 'package:shared_preferences/shared_preferences.dart';

import '../../models/pet_character.dart';

class CharacterStore {
  static const _key = 'buddy.chars.unlocked.v1';

  static Future<Set<PetCharacter>> unlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final raws = prefs.getStringList(_key) ?? [PetCharacter.pikachu.name];
    return raws
        .map((r) => PetCharacter.values.where((c) => c.name == r).firstOrNull)
        .whereType<PetCharacter>()
        .toSet();
  }

  static Future<void> unlock(PetCharacter c) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (await unlocked())..add(c);
    await prefs.setStringList(_key, set.map((e) => e.name).toList());
  }

  static Future<bool> isUnlocked(PetCharacter c) async => (await unlocked()).contains(c);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
