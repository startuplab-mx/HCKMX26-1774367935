import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/pet.dart';
import '../../models/pet_action.dart';
import '../../models/pet_need.dart';
import '../../models/pet_character.dart';
import '../../models/pet_stats.dart';

/// Drives autonomous pet behavior:
/// - decay loop sobre stats
/// - emite needs cuando un stat cruza umbral
/// - acciones del usuario (feed, water, play, ...) que mutan stats + animan
class PetService extends ChangeNotifier {
  PetService(this.pet);

  final Pet pet;

  List<PetNeed> needs = const [];
  bool isDead = false;

  Timer? _decayTimer;
  DateTime _lastTick = DateTime.now();

  /// Decay rates por minuto.
  static const _hungerDecay    = 3.0;
  static const _thirstDecay    = 4.0;
  static const _energyDecay    = 1.5;
  static const _hygieneDecay   = 1.0;
  static const _happinessDecay = 1.5;

  void start() {
    stop();
    _lastTick = DateTime.now();
    _decayTimer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  void stop() {
    _decayTimer?.cancel();
    _decayTimer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  void _tick() {
    if (isDead) return;
    final now = DateTime.now();
    final minutes = now.difference(_lastTick).inMilliseconds / 60000.0;
    _lastTick = now;

    final s = pet.stats;
    s.hunger    = max(0, s.hunger    - (_hungerDecay  * minutes).round());
    s.thirst    = max(0, s.thirst    - (_thirstDecay  * minutes).round());
    s.energy    = max(0, s.energy    - (_energyDecay  * minutes).round());
    s.hygiene   = max(0, s.hygiene   - (_hygieneDecay * minutes).round());
    final stress = (s.hunger < 20 || s.thirst < 20) ? 2.5 : 1.0;
    s.happiness = max(0, s.happiness - (_happinessDecay * minutes * stress).round());
    s.clamp();
    pet.stats = s;

    recomputeNeeds();
    _applyAutoAction();
    _checkDeath();
  }

  void recomputeNeeds() {
    final n = <PetNeed>[];
    if (pet.stats.hunger    < 30) n.add(PetNeed.hungry);
    if (pet.stats.thirst    < 30) n.add(PetNeed.thirsty);
    if (pet.stats.hygiene   < 25) n.add(PetNeed.dirty);
    if (pet.stats.energy    < 25) n.add(PetNeed.sleepy);
    if (pet.stats.happiness < 30) n.add(PetNeed.bored);
    n.sort((a, b) => b.severity(pet).compareTo(a.severity(pet)));
    needs = n;
    notifyListeners();
  }

  void _applyAutoAction() {
    if (pet.currentAction != PetAction.idle) return;
    if (pet.stats.energy < 15) {
      pet.currentAction = PetAction.sleep;
    } else if (needs.contains(PetNeed.bored) || needs.contains(PetNeed.hungry)) {
      pet.currentAction = PetAction.sad;
    }
  }

  void _checkDeath() {
    final critical = pet.stats.hunger == 0 || pet.stats.thirst == 0;
    if (critical && pet.stats.happiness == 0) {
      isDead = true;
      stop();
      notifyListeners();
    }
  }

  // --- Acciones de usuario ----------------------------------------------

  void feed() {
    final s = pet.stats
      ..hunger = (pet.stats.hunger + 35).clamp(0, 100)
      ..happiness = (pet.stats.happiness + 8).clamp(0, 100);
    s.clamp();
    pet.stats = s;
    _triggerAction(PetAction.eat);
    recomputeNeeds();
  }

  void giveWater() {
    final s = pet.stats..thirst = (pet.stats.thirst + 40).clamp(0, 100);
    s.clamp();
    pet.stats = s;
    _triggerAction(PetAction.eat);
    recomputeNeeds();
  }

  void playWith() {
    final s = pet.stats
      ..happiness = (pet.stats.happiness + 25).clamp(0, 100)
      ..energy = (pet.stats.energy - 8).clamp(0, 100);
    s.clamp();
    pet.stats = s;
    _triggerAction(PetAction.play);
    recomputeNeeds();
  }

  /// "pet" en iOS — caricia.
  void caress() {
    final s = pet.stats..happiness = (pet.stats.happiness + 15).clamp(0, 100);
    s.clamp();
    pet.stats = s;
    _triggerAction(PetAction.play);
    recomputeNeeds();
  }

  void sleep() {
    final s = pet.stats..energy = (pet.stats.energy + 50).clamp(0, 100);
    s.clamp();
    pet.stats = s;
    _triggerAction(PetAction.sleep);
    recomputeNeeds();
  }

  void bath() {
    final s = pet.stats
      ..hygiene = (pet.stats.hygiene + 60).clamp(0, 100)
      ..happiness = (pet.stats.happiness - 5).clamp(0, 100);
    s.clamp();
    pet.stats = s;
    _triggerAction(PetAction.idle);
    recomputeNeeds();
  }

  void reincarnate({required String name, required PetCharacter character}) {
    pet.name = name;
    pet.character = character;
    pet.bornAt = DateTime.now();
    pet.stats = PetStats.newborn();
    pet.currentAction = PetAction.idle;
    isDead = false;
    recomputeNeeds();
    start();
  }

  void _triggerAction(PetAction action, {Duration returnAfter = const Duration(seconds: 3)}) {
    pet.currentAction = action;
    Timer(returnAfter, () {
      if (pet.currentAction == action) {
        pet.currentAction = PetAction.idle;
      }
    });
  }
}
