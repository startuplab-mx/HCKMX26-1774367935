import CloudKit
import Foundation
import UIKit

/// Multi-cuidador de Buddy via CloudKit (CKShare).
/// - El "owner" crea un CKRecord del pet en su `privateCloudDatabase`
/// - Comparte el record con un CKShare → genera URL invitable
/// - Los invitados aceptan el share desde Mensajes/correo → reciben el record en su `sharedCloudDatabase`
/// - Cualquier cuidador edita el record y CloudKit propaga via CKQuerySubscription
final class CloudKitService {
    static let shared = CloudKitService()
    private init() {}

    // MARK: - Containers

    private let container = CKContainer(identifier: "iCloud.com.emiliocruz.buddy")
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB:  CKDatabase { container.sharedCloudDatabase }

    private let zoneID = CKRecordZone.ID(zoneName: "BuddyZone")
    private let recordType = "Pet"

    // MARK: - Public API

    /// Verifica si el usuario está logged-in en iCloud.
    func iCloudAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch { return false }
    }

    /// Garantiza que existe la zona privada (idempotente).
    func ensureZone() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        do { _ = try await privateDB.save(zone) }
        catch let err as CKError where err.code == .serverRecordChanged { /* ya existía */ }
    }

    /// Sube el snapshot del pet al iCloud privado del usuario.
    @discardableResult
    func uploadPet(_ pet: Pet) async throws -> CKRecord {
        try await ensureZone()
        let recordID = CKRecord.ID(recordName: "primary-pet", zoneID: zoneID)
        let record: CKRecord
        if let existing = try? await privateDB.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }
        applyPet(pet, to: record)
        return try await privateDB.save(record)
    }

    /// Genera un CKShare URL para invitar a otros cuidadores.
    /// Devuelve la URL para mandarla por iMessage/WhatsApp/etc.
    func makeShareURL() async throws -> URL {
        try await ensureZone()
        let recordID = CKRecord.ID(recordName: "primary-pet", zoneID: zoneID)
        let record = try await privateDB.record(for: recordID)

        if let existing = record.share, let share = try? await privateDB.record(for: existing.recordID) as? CKShare {
            return share.url ?? URL(string: "https://icloud.com")!
        }
        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "Cuida a \(record["name"] as? String ?? "Buddy") conmigo" as CKRecordValue
        share.publicPermission = .none
        let (saved, _) = try await privateDB.modifyRecords(saving: [record, share], deleting: [])
        // Obtener share guardado
        for result in saved {
            if case .success(let rec) = result.1, let s = rec as? CKShare {
                return s.url ?? URL(string: "https://icloud.com")!
            }
        }
        throw NSError(domain: "Buddy", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create share"])
    }

    /// Suscripción para recibir actualizaciones cuando otro cuidador cambia el pet.
    func subscribeToChanges() async throws {
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "pet-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.alertBody = "Tu mascota cambió"
        subscription.notificationInfo = info
        do { _ = try await privateDB.save(subscription) } catch { /* ya existía */ }
        do { _ = try await sharedDB.save(subscription) }  catch { /* ya existía */ }
    }

    /// Descarga el último snapshot del pet (busca en privada y compartida).
    func fetchLatestPet() async -> Pet? {
        for db in [privateDB, sharedDB] {
            let recordID = CKRecord.ID(recordName: "primary-pet", zoneID: zoneID)
            if let record = try? await db.record(for: recordID) {
                return petFrom(record)
            }
        }
        return nil
    }

    // MARK: - Mapping

    private func applyPet(_ pet: Pet, to record: CKRecord) {
        record["name"]         = pet.name as CKRecordValue
        record["character"]    = pet.character.rawValue as CKRecordValue
        record["bornAt"]       = pet.bornAt as CKRecordValue
        record["hunger"]       = pet.stats.hunger as CKRecordValue
        record["thirst"]       = pet.stats.thirst as CKRecordValue
        record["energy"]       = pet.stats.energy as CKRecordValue
        record["hygiene"]      = pet.stats.hygiene as CKRecordValue
        record["happiness"]    = pet.stats.happiness as CKRecordValue
        record["currentAction"] = pet.currentAction.rawValue as CKRecordValue
        record["lastEditor"]   = (UIDevice.current.name) as CKRecordValue
        record["updatedAt"]    = Date() as CKRecordValue
    }

    private func petFrom(_ record: CKRecord) -> Pet {
        Pet(
            name: record["name"] as? String ?? "Buddy",
            character: PetCharacter(rawValue: record["character"] as? String ?? "garfield") ?? .garfield,
            bornAt: record["bornAt"] as? Date ?? Date(),
            stats: PetStats(
                hunger:    record["hunger"]    as? Int ?? 70,
                thirst:    record["thirst"]    as? Int ?? 70,
                energy:    record["energy"]    as? Int ?? 100,
                hygiene:   record["hygiene"]   as? Int ?? 100,
                happiness: record["happiness"] as? Int ?? 80
            ),
            currentAction: PetAction(rawValue: record["currentAction"] as? String ?? "idle") ?? .idle
        )
    }
}
