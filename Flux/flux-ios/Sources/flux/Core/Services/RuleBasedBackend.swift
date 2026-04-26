import Foundation

// MARK: - Rule-based backend · fallback explicable
// Funciona en cualquier dispositivo sin Apple Intelligence.
// Es determinístico, citable frente al jurado.

enum RuleBasedBackend {

    // MARK: - Patterns db (extraído de reportes públicos de WeProtect Global Alliance, UNICEF, INAI)

    private struct PatternDB {
        let pattern: String
        let triggers: [String]
        let severity: RiskAnalysis.Risk
        let pillar: Int
    }

    private static let patterns: [PatternDB] = [
        // Pilar 1 — contacto y ofertas engañosas
        .init(pattern: "Elogio físico + solicitud de imágenes · grooming",
              triggers: ["eres muy lind", "te ves muy bien", "mándame fotos", "mandame fotos", "pásame una foto", "manda foto"],
              severity: .high, pillar: 1),

        .init(pattern: "Oferta económica / regalo + datos personales",
              triggers: ["tengo un regalo", "te mando dinero", "te doy robux", "robux", "dónde vives", "donde vives", "dame tu dirección"],
              severity: .high, pillar: 1),

        .init(pattern: "Secreto explícito ante padres · aislamiento",
              triggers: ["no le digas a tu mamá", "no le digas a tu papá", "no le digas a nadie", "es sorpresa", "solo entre nosotros", "no le cuentes"],
              severity: .high, pillar: 3),

        .init(pattern: "Propuesta de encuentro físico",
              triggers: ["nos vemos", "te vengo a buscar", "cuándo podemos vernos a solas", "paso por ti"],
              severity: .high, pillar: 1),

        // Pilar 2 — contenidos normalizados
        .init(pattern: "Normalización de contenido de alto riesgo",
              triggers: ["es normal", "todos lo hacen", "nadie se entera", "no pasa nada"],
              severity: .medium, pillar: 2),

        // Pilar 3 — manipulación por pertenencia
        .init(pattern: "Presión emocional / compromiso falso",
              triggers: ["tenemos algo especial", "tú y yo", "nadie me entiende como tú", "si me quisieras"],
              severity: .medium, pillar: 3),

        // Pilar 4 — lenguaje de aislamiento
        .init(pattern: "Solicitud de contacto en plataforma privada",
              triggers: ["agrégame en discord", "mi telegram", "pásate a whatsapp", "hablemos por privado"],
              severity: .medium, pillar: 4)
    ]

    // MARK: - Forum patterns db (huellas del foro simuladas)
    private static let forumIDs: [String: [String]] = [
        "#47": ["no le digas a tu mamá", "mándame fotos", "tengo un regalo"],
        "#62": ["tengo 16", "tengo 15", "soy de tu edad"],
        "#73": ["robux", "amigo especial", "te mando dinero"]
    ]

    // MARK: - analyze(text:)

    static func analyze(text: String) -> RiskAnalysis {
        let t = text.lowercased()
        var insights: [RiskAnalysis.Insight] = []
        var matchedForumIDs: Set<String> = []

        for pdb in patterns {
            for trigger in pdb.triggers where t.contains(trigger) {
                // Extraer excerpt: ~60 chars alrededor del trigger
                let excerpt = extractExcerpt(from: text, around: trigger) ?? trigger
                insights.append(.init(
                    pattern: pdb.pattern,
                    excerpt: excerpt,
                    severity: pdb.severity,
                    pillar: pdb.pillar
                ))
                break // un pattern no se cuenta dos veces
            }
        }

        for (forumID, fingerprints) in forumIDs {
            for fp in fingerprints where t.contains(fp) {
                matchedForumIDs.insert(forumID)
                break
            }
        }

        let overallRisk: RiskAnalysis.Risk = {
            if insights.contains(where: { $0.severity == .high }) { return .high }
            if insights.contains(where: { $0.severity == .medium }) { return .medium }
            return .low
        }()

        let confidence: Double = {
            if insights.isEmpty { return 0.92 }
            return min(0.7 + Double(insights.count) * 0.05, 0.95)
        }()

        return RiskAnalysis(
            overallRisk: overallRisk,
            confidence: confidence,
            insights: insights,
            matchesForumPatterns: Array(matchedForumIDs).sorted()
        )
    }

    // MARK: - generateApproaches

    static func generateApproaches(childName: String) -> [ConversationApproach] {
        [
            ConversationApproach(
                label: "Opción 1 · Directa",
                estimatedTime: "3 min",
                script: "Oye, \(childName), vi que has estado usando Discord de noche. No quiero invadir tu espacio, pero me preocupa que no duermas bien. ¿Todo OK con las personas con las que hablas ahí?",
                tags: ["sin acusar", "cuidado"]
            ),
            ConversationApproach(
                label: "Opción 2 · Contexto",
                estimatedTime: "5 min",
                script: "Leí algo sobre cómo mucha gente nueva se conoce por Discord ahora. ¿Tú cómo lo usas, \(childName)? Me gustaría entenderlo...",
                tags: ["curiosidad", "apertura"]
            ),
            ConversationApproach(
                label: "Opción 3 · Espejo",
                estimatedTime: "2 min",
                script: "Yo también me desvelo viendo videos. Me gustó mucho este de X. ¿Qué ves tú a esa hora, \(childName)?",
                tags: ["vínculo", "ligero"]
            )
        ]
    }

    // MARK: - suggestActions

    static func suggestActions(entry: String) -> [VozSuggestion] {
        [
            .init(title: "Aportar mi huella al foro",
                  subtitle: "anónimo · ayuda a alguien más",
                  action: .contributeToForum),
            .init(title: "Línea de Ayuda · 089",
                  subtitle: "24 horas · anónimo · gratis",
                  action: .call, phoneNumber: "089"),
            .init(title: "Compartir con un adulto",
                  subtitle: "tú eliges quién y qué compartir",
                  action: .share),
            .init(title: "Reporte anónimo INAI",
                  subtitle: "sin dar tu nombre",
                  action: .report)
        ]
    }

    // MARK: - Helpers

    private static func extractExcerpt(from text: String, around trigger: String) -> String? {
        guard let range = text.lowercased().range(of: trigger) else { return nil }
        let start = text.index(range.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 30, limitedBy: text.endIndex) ?? text.endIndex
        let excerpt = String(text[start..<end])
        let prefix = start == text.startIndex ? "" : "…"
        let suffix = end == text.endIndex ? "" : "…"
        return prefix + excerpt.trimmingCharacters(in: .whitespacesAndNewlines) + suffix
    }
}
