import 'package:flutter/foundation.dart';

import 'pet_action.dart';
import 'pet_character.dart';
import 'pet_stats.dart';

/// Equivalente al `@Observable Pet` de iOS. ChangeNotifier emite cambios
/// para que la UI (HomeView) se reconstruya.
class Pet extends ChangeNotifier {
  String _name;
  PetCharacter _character;
  DateTime _bornAt;
  PetStats _stats;
  PetAction _currentAction;

  Pet({
    String name = 'Garfield',
    PetCharacter character = PetCharacter.pikachu,
    DateTime? bornAt,
    PetStats? stats,
    PetAction currentAction = PetAction.idle,
  })  : _name = name,
        _character = character,
        _bornAt = bornAt ?? DateTime.now(),
        _stats = stats ?? PetStats.newborn(),
        _currentAction = currentAction;

  String        get name          => _name;
  PetCharacter  get character     => _character;
  DateTime      get bornAt        => _bornAt;
  PetStats      get stats         => _stats;
  PetAction     get currentAction => _currentAction;

  set name(String v)              { _name = v; notifyListeners(); }
  set character(PetCharacter v)   { _character = v; notifyListeners(); }
  set bornAt(DateTime v)          { _bornAt = v; notifyListeners(); }
  set stats(PetStats v)           { _stats = v; notifyListeners(); }
  set currentAction(PetAction v)  { _currentAction = v; notifyListeners(); }

  /// Para mutaciones internas que ya van seguidas de `notify()`.
  void notify() => notifyListeners();

  int get ageInDays {
    final diff = DateTime.now().difference(_bornAt).inDays;
    return diff < 1 ? 1 : diff;
  }

  /// 0..3
  int get moodLevel {
    final avg = (_stats.happiness + _stats.energy + _stats.hygiene) ~/ 3;
    if (avg >= 80) return 3;
    if (avg >= 50) return 2;
    if (avg >= 25) return 1;
    return 0;
  }

  /// 0..2
  int get satietyLevel {
    if (_stats.hunger < 25) return 0;
    if (_stats.hunger < 60) return 1;
    return 2;
  }
}
