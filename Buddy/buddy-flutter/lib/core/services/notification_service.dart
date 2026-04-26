import '../../models/pet.dart';

/// STUB · `flutter_local_notifications` ya está en pubspec.yaml.
///
/// Implementación pendiente:
/// 1. Inicializar plugin en `main.dart` (con icono Android + permisos iOS)
/// 2. `requestPermission()` la primera vez (iOS lo requiere; Android 13+ también)
/// 3. `scheduleNeedReminders(pet)` debe leer needs y agendar push locales
///    (ej. "🍖 Tu mascota tiene hambre" cuando hunger < 20).
///
/// Equivalente iOS: `Sources/buddy/Core/Services/NotificationService.swift`.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  Future<void> requestPermission() async {
    // TODO
  }

  Future<void> scheduleNeedReminders(Pet pet) async {
    // TODO
  }
}
