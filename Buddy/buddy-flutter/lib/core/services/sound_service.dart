import 'package:flutter/services.dart';

import '../../models/pet_action.dart';

/// Wrapper minimalista. Usa SystemSound (ya disponible en cualquier device)
/// para los clicks. Para sonidos de pet por acción → TODO usar audioplayers
/// con assets cuando el equipo decida los archivos definitivos.
class SoundService {
  static final SoundService instance = SoundService._();
  SoundService._();

  bool isEnabled = true;

  void play(PetAction action) {
    if (!isEnabled) return;
    // TODO: cargar assets WAV/MP3 cortos por acción y reproducirlos con audioplayers.
    if (action == PetAction.idle) return;
    SystemSound.play(SystemSoundType.click);
  }

  void playClick() {
    if (!isEnabled) return;
    SystemSound.play(SystemSoundType.click);
  }

  void playReward() {
    if (!isEnabled) return;
    SystemSound.play(SystemSoundType.click);
  }
}
