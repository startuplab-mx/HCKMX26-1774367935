import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/pet.dart';
import '../../models/pet_action.dart';
import '../../models/pet_character.dart';
import '../../models/pet_stats.dart';

/// Snapshot del Pet → JSON en SharedPreferences. Equivalente al `PetStore` de iOS.
class PetStore {
  static const _key = 'buddy.pet.v1';

  static Future<Pet?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return Pet(
        name: j['name'] as String,
        character: PetCharacter.fromRaw(j['characterRaw'] as String?),
        bornAt: DateTime.parse(j['bornAt'] as String),
        stats: PetStats(
          hunger:    j['hunger']    as int,
          thirst:    j['thirst']    as int,
          energy:    j['energy']    as int,
          hygiene:   j['hygiene']   as int,
          happiness: j['happiness'] as int,
        ),
        currentAction: PetAction.fromRaw(j['actionRaw'] as String?),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Pet pet) async {
    final prefs = await SharedPreferences.getInstance();
    final j = {
      'name': pet.name,
      'characterRaw': pet.character.name,
      'bornAt': pet.bornAt.toIso8601String(),
      'hunger':    pet.stats.hunger,
      'thirst':    pet.stats.thirst,
      'energy':    pet.stats.energy,
      'hygiene':   pet.stats.hygiene,
      'happiness': pet.stats.happiness,
      'actionRaw': pet.currentAction.name,
    };
    await prefs.setString(_key, jsonEncode(j));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
