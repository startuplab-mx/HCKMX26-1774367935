import Foundation
import SwiftUI

// MARK: - Profile · perfil de usuario en flux (padre o menor)

struct FluxProfile: Identifiable, Hashable, Codable {
    let id: UUID
    var role: Role
    var displayName: String
    var avatarColorHex: UInt32
    var createdAt: Date
    var biometricEnabled: Bool

    // Padre: lista de menores monitoreados
    var monitoredChildren: [ChildProfile]

    // Menor: IDs del pairing activo
    var caseID: UUID?
    var pairedWithParentName: String?
    var childAge: Int?

    enum Role: String, Codable, CaseIterable {
        case parent
        case child

        var label: String {
            switch self {
            case .parent: "padre"
            case .child: "menor"
            }
        }

        var modeLabel: String {
            switch self {
            case .parent: "PADRE"
            case .child: "FLUX VOZ"
            }
        }
    }

    var avatarColor: Color { Color(hex: avatarColorHex) }

    var initial: String { String(displayName.prefix(1)).uppercased() }

    init(
        id: UUID = UUID(),
        role: Role,
        displayName: String,
        avatarColorHex: UInt32,
        createdAt: Date = .now,
        biometricEnabled: Bool = false,
        monitoredChildren: [ChildProfile] = [],
        caseID: UUID? = nil,
        pairedWithParentName: String? = nil,
        childAge: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.displayName = displayName
        self.avatarColorHex = avatarColorHex
        self.createdAt = createdAt
        self.biometricEnabled = biometricEnabled
        self.monitoredChildren = monitoredChildren
        self.caseID = caseID
        self.pairedWithParentName = pairedWithParentName
        self.childAge = childAge
    }
}

// MARK: - Seed data

extension FluxProfile {
    /// 2 perfiles de demostración: una mamá y su hija de 13 años.
    static let seedProfiles: [FluxProfile] = [
        FluxProfile(
            role: .parent,
            displayName: "Camila Vega",
            avatarColorHex: 0x0F766E,          // primary teal
            biometricEnabled: true,
            monitoredChildren: [
                ChildProfile(
                    name: "Lucía",
                    age: 13,
                    baselineApps: ["TikTok", "Instagram", "WhatsApp", "YouTube"]
                )
            ]
        ),
        FluxProfile(
            role: .child,
            displayName: "Lucía Vega",
            avatarColorHex: 0x8B5E3C,          // voz accent
            biometricEnabled: true,
            caseID: UUID(),
            pairedWithParentName: "Camila Vega"
        )
    ]

    static let sampleAvatarColors: [UInt32] = [
        0x0F766E, 0xFB7185, 0x8B5E3C, 0x7C3AED, 0x059669, 0xD97706
    ]
}
