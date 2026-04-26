import Foundation
import SwiftUI

// MARK: - WeProtect · cerebro de IA on-device
// Unifica acceso a análisis de texto y generación de coaching.
// Usa Apple Intelligence Foundation Models (iOS 26+) si está disponible,
// o reglas explicables como fallback. Toda inferencia es on-device.

@MainActor
final class WeProtectAI: ObservableObject {
    static let shared = WeProtectAI()

    @Published var backendKind: BackendKind = .unknown
    @Published var isReady: Bool = false

    enum BackendKind: Equatable {
        case unknown
        case foundationModels   // Apple Intelligence on-device
        case ruleBased          // fallback explicable

        var label: String {
            switch self {
            case .unknown: "detectando..."
            case .foundationModels: "Apple Intelligence · Neural Engine"
            case .ruleBased: "WeProtect Rules · on-device"
            }
        }

        var isOnDevice: Bool { true }
    }

    private init() {
        Task { await detectBackend() }
    }

    // MARK: - Detection

    private func detectBackend() async {
        if #available(iOS 26, *) {
            if await FoundationModelsBackend.isAvailable() {
                self.backendKind = .foundationModels
                self.isReady = true
                print("[WeProtect] ✅ Apple Intelligence disponible — usando Foundation Models")
                return
            }
        }
        self.backendKind = .ruleBased
        self.isReady = true
        print("[WeProtect] ℹ️ fallback a reglas — Foundation Models no disponible")
    }

    // MARK: - Public API

    /// Analiza un texto y devuelve los patrones de riesgo detectados.
    func analyze(text: String) async -> RiskAnalysis {
        if #available(iOS 26, *), backendKind == .foundationModels {
            if let analysis = await FoundationModelsBackend.analyze(text: text) {
                return analysis
            }
        }
        return RuleBasedBackend.analyze(text: text)
    }

    /// Genera 3 abordajes de conversación para el coach.
    func generateApproaches(
        childName: String,
        age: Int,
        context: String
    ) async -> [ConversationApproach] {
        if #available(iOS 26, *), backendKind == .foundationModels {
            if let approaches = await FoundationModelsBackend.generateApproaches(
                childName: childName, age: age, context: context
            ) {
                return approaches
            }
        }
        return RuleBasedBackend.generateApproaches(childName: childName)
    }

    /// Sugiere acciones pasivas para el modo menor tras guardar algo.
    func suggestActions(for entry: String) async -> [VozSuggestion] {
        if #available(iOS 26, *), backendKind == .foundationModels {
            if let s = await FoundationModelsBackend.suggestActions(entry: entry) {
                return s
            }
        }
        return RuleBasedBackend.suggestActions(entry: entry)
    }
}

// MARK: - Shared models

struct RiskAnalysis: Hashable {
    let overallRisk: Risk
    let confidence: Double
    let insights: [Insight]
    let matchesForumPatterns: [String]  // IDs del foro con huellas similares

    enum Risk: String {
        case low, medium, high

        var color: Color {
            switch self {
            case .low: FluxColor.safe
            case .medium: FluxColor.warn
            case .high: FluxColor.danger
            }
        }

        var label: String {
            switch self {
            case .low: "Riesgo bajo"
            case .medium: "Atención"
            case .high: "Riesgo alto"
            }
        }
    }

    struct Insight: Hashable, Identifiable {
        let id = UUID()
        let pattern: String          // ej. "grooming · solicitud de imágenes"
        let excerpt: String          // fragmento que activó la señal
        let severity: Risk
        let pillar: Int              // 1–4 según convocatoria
    }

    static let empty = RiskAnalysis(overallRisk: .low, confidence: 1.0, insights: [], matchesForumPatterns: [])
}

struct VozSuggestion: Hashable, Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let action: ActionType
    let phoneNumber: String?    // solo si action == .call

    init(title: String, subtitle: String, action: ActionType, phoneNumber: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.phoneNumber = phoneNumber
    }

    enum ActionType: String, Hashable {
        case call
        case share
        case report
        case contributeToForum
    }
}
