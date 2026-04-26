import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pet_action.dart';

enum PersonalityTrait {
  carinoso,
  glotton,
  dormilon,
  jugueton,
  neutral;

  String get emoji => switch (this) {
        PersonalityTrait.carinoso => '🥰',
        PersonalityTrait.glotton  => '🍽',
        PersonalityTrait.dormilon => '😴',
        PersonalityTrait.jugueton => '🎉',
        PersonalityTrait.neutral  => '😐',
      };

  String get label => switch (this) {
        PersonalityTrait.carinoso => 'Cariñoso',
        PersonalityTrait.glotton  => 'Glotón',
        PersonalityTrait.dormilon => 'Dormilón',
        PersonalityTrait.jugueton => 'Juguetón',
        PersonalityTrait.neutral  => 'Neutral',
      };
}

class PersonalityTracker {
  int feedCount;
  int playCount;
  int petCount;
  int sleepCount;

  PersonalityTracker({
    this.feedCount = 0,
    this.playCount = 0,
    this.petCount = 0,
    this.sleepCount = 0,
  });

  void record(PetAction action) {
    switch (action) {
      case PetAction.eat:   feedCount++; break;
      case PetAction.play:  playCount++; petCount++; break;
      case PetAction.sleep: sleepCount++; break;
      default: break;
    }
  }

  PersonalityTrait get derivedTrait {
    final total = feedCount + playCount + petCount + sleepCount;
    if (total <= 5) return PersonalityTrait.neutral;
    final counts = <PersonalityTrait, int>{
      PersonalityTrait.glotton:  feedCount,
      PersonalityTrait.jugueton: playCount,
      PersonalityTrait.carinoso: petCount,
      PersonalityTrait.dormilon: sleepCount,
    };
    final maxEntry = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return maxEntry.value / total > 0.4 ? maxEntry.key : PersonalityTrait.neutral;
  }

  Map<String, dynamic> toJson() => {
        'feedCount': feedCount,
        'playCount': playCount,
        'petCount': petCount,
        'sleepCount': sleepCount,
      };

  factory PersonalityTracker.fromJson(Map<String, dynamic> j) => PersonalityTracker(
        feedCount: j['feedCount'] as int? ?? 0,
        playCount: j['playCount'] as int? ?? 0,
        petCount: j['petCount'] as int? ?? 0,
        sleepCount: j['sleepCount'] as int? ?? 0,
      );

  static const _key = 'buddy.personality.v1';

  static Future<PersonalityTracker> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return PersonalityTracker();
    try {
      return PersonalityTracker.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PersonalityTracker();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
