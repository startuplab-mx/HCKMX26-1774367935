import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Apple Intelligence backend · Foundation Models on-device
// Corre modelos LLM directamente en el Neural Engine de Apple Silicon.
// Nada sale del dispositivo. Requiere iOS 26+ con Apple Intelligence activo
// y dispositivo compatible (iPhone 15 Pro+).

@available(iOS 26, *)
enum FoundationModelsBackend {

    static func isAvailable() async -> Bool {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return true
        default:         return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Analyze

    static func analyze(text: String) async -> RiskAnalysis? {
        #if canImport(FoundationModels)
        do {
            let instructions = """
            Eres WeProtect, un analista de seguridad digital infantil. \
            Tu tarea es detectar patrones de riesgo en conversaciones dirigidas a menores: \
            grooming, ofertas engañosas, manipulación por aislamiento, solicitudes de encuentro físico, \
            normalización de contenido de alto riesgo. \
            Responde SIEMPRE en español. Sé preciso, no especulativo. \
            Si el texto no tiene patrones de riesgo, responde con overallRisk = low y lista vacía.
            """
            let session = LanguageModelSession(instructions: instructions)
            let prompt = "Analiza este texto y detecta patrones de riesgo:\n\n\"\(text)\""
            let response = try await session.respond(to: prompt, generating: GenerableRiskAnalysis.self)
            return response.content.toRiskAnalysis()
        } catch {
            print("[WeProtect FM] ⚠️ analyze falló: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Generate approaches

    static func generateApproaches(
        childName: String,
        age: Int,
        context: String
    ) async -> [ConversationApproach]? {
        #if canImport(FoundationModels)
        do {
            let instructions = """
            Eres WeProtect, un coach de conversación para padres de menores en riesgo digital. \
            Generas 3 abordajes distintos de conversación, cada uno con un tono diferente: \
            (1) directa y cuidadosa, (2) contextual con curiosidad, (3) espejo con vínculo ligero. \
            Nunca acusar. Nunca confrontar. Siempre buscar apertura. \
            Responde en español, usando el nombre del menor en el script.
            """
            let session = LanguageModelSession(instructions: instructions)
            let prompt = """
            El menor se llama \(childName), tiene \(age) años. \
            Contexto detectado: \(context). \
            Genera 3 scripts de conversación con tono distinto.
            """
            let response = try await session.respond(to: prompt, generating: GenerableApproaches.self)
            return response.content.approaches.map { $0.toConversationApproach() }
        } catch {
            print("[WeProtect FM] ⚠️ approaches falló: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Suggest actions (modo menor)

    static func suggestActions(entry: String) async -> [VozSuggestion]? {
        #if canImport(FoundationModels)
        // Para el modo menor preferimos reglas estables (lista fija de recursos).
        // Foundation Models solo reordena y prioriza.
        return nil
        #else
        return nil
        #endif
    }
}

// MARK: - Generable structured outputs

#if canImport(FoundationModels)

@available(iOS 26, *)
@Generable
struct GenerableRiskAnalysis: Equatable {
    @Guide(description: "Nivel de riesgo general: low, medium, o high")
    var overallRisk: String

    @Guide(description: "Confianza del análisis, 0.0 a 1.0")
    var confidence: Double

    @Guide(description: "Lista de patrones de riesgo detectados con su severidad y pilar")
    var insights: [GenerableInsight]

    func toRiskAnalysis() -> RiskAnalysis {
        RiskAnalysis(
            overallRisk: parseRisk(overallRisk),
            confidence: confidence,
            insights: insights.map { $0.toInsight() },
            matchesForumPatterns: []
        )
    }

    private func parseRisk(_ s: String) -> RiskAnalysis.Risk {
        switch s.lowercased() {
        case "high": return .high
        case "medium": return .medium
        default: return .low
        }
    }
}

@available(iOS 26, *)
@Generable
struct GenerableInsight: Equatable {
    @Guide(description: "Nombre del patrón detectado, ej: 'grooming · solicitud de imágenes'")
    var pattern: String

    @Guide(description: "Fragmento del texto original que activó este patrón")
    var excerpt: String

    @Guide(description: "Severidad: low, medium, high")
    var severity: String

    @Guide(description: "Pilar de la convocatoria: 1 (contacto engañoso), 2 (contenidos normalizados), 3 (manipulación), 4 (aislamiento)")
    var pillar: Int

    func toInsight() -> RiskAnalysis.Insight {
        let sev: RiskAnalysis.Risk = {
            switch severity.lowercased() {
            case "high": return .high
            case "medium": return .medium
            default: return .low
            }
        }()
        return .init(pattern: pattern, excerpt: excerpt, severity: sev, pillar: pillar)
    }
}

@available(iOS 26, *)
@Generable
struct GenerableApproaches: Equatable {
    @Guide(description: "3 abordajes distintos de conversación")
    var approaches: [GenerableApproach]
}

@available(iOS 26, *)
@Generable
struct GenerableApproach: Equatable {
    @Guide(description: "Etiqueta corta con tono, ej: 'Opción 1 · Directa'")
    var label: String

    @Guide(description: "Tiempo estimado de la conversación en formato 'N min'")
    var estimatedTime: String

    @Guide(description: "Script completo de la conversación, 2-3 oraciones, usando el nombre del menor")
    var script: String

    @Guide(description: "2-3 tags cortos en español que describen el tono, ej: ['sin acusar', 'cuidado']")
    var tags: [String]

    func toConversationApproach() -> ConversationApproach {
        ConversationApproach(label: label, estimatedTime: estimatedTime, script: script, tags: tags)
    }
}

#endif
