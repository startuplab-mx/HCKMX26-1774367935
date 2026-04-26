import Foundation

// MARK: - Role

enum PairingRole: String, Codable {
    case parent    // ofrece la invitación · advertise
    case child     // recibe la invitación · scan
}

// MARK: - Pairing phase

enum PairingPhase: Equatable {
    case preparing
    case waitingForPeer
    case reading         // cerca, intercambiando
    case processing
    case approved
    case declined(String)

    var isActive: Bool {
        switch self {
        case .preparing, .waitingForPeer, .reading, .processing: true
        case .approved, .declined: false
        }
    }
}

// MARK: - Voz invitation · payload que envía el padre al menor

struct VozInvitation: Codable, Hashable {
    let id: UUID                    // ID de la invitación
    let parentDeviceName: String    // ej. "iPhone de Camila"
    let parentName: String          // displayName real del perfil padre · ej. "Camila Vega"
    let childName: String           // ej. "Lucía" (configurado por el padre)
    let childAge: Int
    let caseID: UUID                // ID del caso persistente en flux voz
    let sharedSecret: Data          // 32 bytes — clave de cifrado local del menor
    let issuedAt: Date
    let expiresAt: Date             // 2 minutos de validez

    init(
        id: UUID = UUID(),
        parentDeviceName: String,
        parentName: String,
        childName: String,
        childAge: Int,
        caseID: UUID = UUID(),
        sharedSecret: Data,
        issuedAt: Date = .now,
        expiresAt: Date = .now.addingTimeInterval(120)
    ) {
        self.id = id
        self.parentDeviceName = parentDeviceName
        self.parentName = parentName
        self.childName = childName
        self.childAge = childAge
        self.caseID = caseID
        self.sharedSecret = sharedSecret
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }

    var isExpired: Bool { Date.now > expiresAt }

    static func generate(
        parentDeviceName: String,
        parentName: String,
        childName: String,
        childAge: Int
    ) -> VozInvitation {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        return VozInvitation(
            parentDeviceName: parentDeviceName,
            parentName: parentName,
            childName: childName,
            childAge: childAge,
            sharedSecret: Data(bytes)
        )
    }
}

// MARK: - Acknowledgement · payload que envía el menor al padre

struct VozAcknowledgement: Codable, Hashable {
    let invitationID: UUID
    let childDeviceName: String
    let childName: String           // displayName real del perfil menor · ej. "Lucía Vega"
    let childAge: Int               // edad que el menor reporta desde su perfil
    let acceptedAt: Date
    let success: Bool

    init(
        invitationID: UUID,
        childDeviceName: String,
        childName: String,
        childAge: Int,
        success: Bool,
        acceptedAt: Date = .now
    ) {
        self.invitationID = invitationID
        self.childDeviceName = childDeviceName
        self.childName = childName
        self.childAge = childAge
        self.acceptedAt = acceptedAt
        self.success = success
    }
}
