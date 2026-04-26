import Foundation
import Security

// MARK: - Keychain wrapper · adaptado del KeychainService de Atenea
// Guarda estado de biometría y último perfil desbloqueado.

final class FluxKeychainService {
    static let shared = FluxKeychainService()
    private init() {}

    private let serviceName = "com.emiliocruz.flux.auth"

    private enum Key: String {
        case biometricEnabled = "biometricEnabled"
        case lastUnlockedProfileID = "lastUnlockedProfileID"
    }

    // MARK: - Public API

    /// Biometría habilitada globalmente
    var isBiometricEnabled: Bool {
        get { read(key: .biometricEnabled) == "true" }
        set { save(key: .biometricEnabled, value: newValue ? "true" : "false") }
    }

    /// ID del último perfil desbloqueado con biometría
    var lastUnlockedProfileID: UUID? {
        get {
            guard let str = read(key: .lastUnlockedProfileID) else { return nil }
            return UUID(uuidString: str)
        }
        set {
            if let id = newValue {
                save(key: .lastUnlockedProfileID, value: id.uuidString)
            } else {
                delete(key: .lastUnlockedProfileID)
            }
        }
    }

    func clearAll() {
        delete(key: .biometricEnabled)
        delete(key: .lastUnlockedProfileID)
    }

    // MARK: - Private keychain ops

    private func save(key: Key, value: String) {
        let data = Data(value.utf8)
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[flux Keychain] Error guardando \(key.rawValue): \(status)")
        }
    }

    private func read(key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}
