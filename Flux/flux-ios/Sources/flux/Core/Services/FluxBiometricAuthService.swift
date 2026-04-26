import Foundation
import LocalAuthentication

// MARK: - Face ID / Touch ID · adaptado de BiometricAuthService de Atenea

final class FluxBiometricAuthService {
    static let shared = FluxBiometricAuthService()
    private init() {}

    enum BiometricType {
        case faceID, touchID, none
    }

    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        default:       return .none
        }
    }

    var biometricName: String {
        switch biometricType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .none:    return ""
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        case .none:    return "lock.fill"
        }
    }

    var isAvailable: Bool { biometricType != .none }

    /// Autentica al usuario con Face ID / Touch ID.
    @MainActor
    func authenticate(reason: String? = nil) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("[flux Biometric] No disponible: \(error?.localizedDescription ?? "unknown")")
            return false
        }

        let localizedReason = reason ?? "Desbloquear con \(biometricName)"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: localizedReason
            )
            print("[flux Biometric] Resultado: \(success ? "OK" : "FAIL")")
            return success
        } catch {
            print("[flux Biometric] Error: \(error.localizedDescription)")
            return false
        }
    }
}
