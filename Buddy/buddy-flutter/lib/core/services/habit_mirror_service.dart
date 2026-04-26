import '../../models/pet.dart';

/// STUB · Espejo de hábitos: refleja el comportamiento del usuario en la mascota.
///
/// La versión iOS lee Screen Time API + Family Controls (uso del celular).
/// En Flutter requiere implementaciones distintas por plataforma:
///   - Android: `UsageStatsManager` vía MethodChannel (permiso `PACKAGE_USAGE_STATS`).
///   - iOS:     mantener equivalente a la versión SwiftUI con DeviceActivity.
///
/// Decisión pendiente. Mientras tanto, devuelve mensajes vacíos.
///
/// Equivalente iOS: `Sources/buddy/Core/Services/HabitMirrorService.swift`.
class HabitMirrorService {
  static final HabitMirrorService instance = HabitMirrorService._();
  HabitMirrorService._();

  Future<List<String>> applyMirror(Pet pet) async => const [];
}
