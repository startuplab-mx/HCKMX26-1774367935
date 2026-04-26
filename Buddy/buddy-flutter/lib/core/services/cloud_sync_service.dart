import '../../models/pet.dart';

/// STUB · sync multi-cuidador.
///
/// La versión iOS usa CloudKit. En Flutter las dos opciones realistas son:
///   - Firebase (Firestore + Auth)
///   - Supabase (Postgres + RLS)
///
/// Decisión pendiente con Emilio antes de implementar. Mientras tanto, esta
/// clase es no-op para que el resto del código pueda llamarla sin romper.
///
/// Equivalente iOS: `Sources/buddy/Core/Cloud/CloudKitService.swift`.
class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._();
  CloudSyncService._();

  Future<bool> available() async => false;

  Future<void> uploadPet(Pet pet) async {
    // TODO Firebase/Supabase
  }

  Future<Pet?> fetchLatestPet() async => null;

  Future<void> subscribeToChanges() async {
    // TODO
  }
}
