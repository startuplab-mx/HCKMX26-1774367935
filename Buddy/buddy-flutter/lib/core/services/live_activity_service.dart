import 'package:flutter/services.dart';

import '../../models/pet.dart';
import '../../models/pet_action.dart';

/// STUB · Live Activities + Dynamic Island (solo iOS).
///
/// Android NO tiene equivalente system-level. La estrategia es:
///   - iOS: implementar via `MethodChannel` que llame a un módulo Swift nativo
///     que use la API `ActivityKit` (igual que `LiveActivityManager.swift` actual).
///     El módulo nativo se mete en `ios/Runner/` después de `flutter create .`.
///   - Android: noop. La presencia visual del pet en el área de la cámara
///     se logra con `BuddyCutoutSpot` (widget interno), ver `lib/widgets/buddy_cutout_spot.dart`.
///
/// Equivalente iOS: `Sources/buddy/Core/LiveActivity/LiveActivityManager.swift`.
class LiveActivityService {
  static final LiveActivityService instance = LiveActivityService._();
  LiveActivityService._();

  static const _channel = MethodChannel('buddy/live_activity');

  Future<void> start({required Pet pet, required PetAction action}) async {
    try {
      await _channel.invokeMethod('start', {
        'name': pet.name,
        'character': pet.character.name,
        'action': action.name,
      });
    } on MissingPluginException {
      // Esperado en Android — no-op.
    } catch (_) {}
  }

  Future<void> update({required Pet pet, required PetAction action}) async {
    try {
      await _channel.invokeMethod('update', {
        'action': action.name,
        'mood': pet.moodLevel,
      });
    } on MissingPluginException {
      // Esperado en Android — no-op.
    } catch (_) {}
  }

  Future<void> end() async {
    try {
      await _channel.invokeMethod('end');
    } on MissingPluginException {
      // Esperado en Android — no-op.
    } catch (_) {}
  }
}
