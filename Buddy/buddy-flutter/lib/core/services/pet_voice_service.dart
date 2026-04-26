import '../../models/pet_action.dart';

/// STUB · Sonidos de criatura por estado de ánimo (no voz humana).
/// Implementación pendiente: usar `audioplayers` con clips cortos por personaje.
class PetVoiceService {
  static final PetVoiceService instance = PetVoiceService._();
  PetVoiceService._();

  bool isEnabled = true;

  void say({required PetAction forAction, required String name}) {
    // TODO: reproducir clip según character + action
  }
}
