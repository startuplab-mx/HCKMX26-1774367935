import Foundation

struct DetectedSignal: Identifiable, Hashable, Codable {
    let id: UUID
    let kind: Kind
    let severity: Severity
    let title: String
    let summary: String
    let detectedAt: Date
    let patternID: String
    let confidence: Double

    enum Kind: String, CaseIterable, Codable {
        case platformTransition   // TikTok → Discord
        case atypicalHours        // 2–4 AM
        case reactiveInstall      // mensajería nueva
        case digitalIsolation     // abandono repentino
        case groomingPattern      // detectado en contenido subido
    }

    enum Severity: String, Codable {
        case low, medium, high

        var weight: Int {
            switch self {
            case .low: 1
            case .medium: 2
            case .high: 3
            }
        }
    }

    init(
        id: UUID = UUID(),
        kind: Kind,
        severity: Severity,
        title: String,
        summary: String,
        detectedAt: Date = .now,
        patternID: String,
        confidence: Double
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.title = title
        self.summary = summary
        self.detectedAt = detectedAt
        self.patternID = patternID
        self.confidence = confidence
    }
}

// MARK: - Mock data
extension DetectedSignal {
    static let mockActive: [DetectedSignal] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func todayAt(_ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(byAdding: .minute, value: hour * 60 + minute, to: today) ?? .now
        }
        func dayAgoAt(_ days: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let base = cal.date(byAdding: .day, value: -days, to: today) ?? today
            return cal.date(byAdding: .minute, value: hour * 60 + minute, to: base) ?? .now
        }
        return [
            // Hace 6 días
            DetectedSignal(kind: .atypicalHours, severity: .low,
                           title: "Uso nocturno moderado",
                           summary: "22:00 - 23:10, dentro del rango normal",
                           detectedAt: dayAgoAt(6, 22, 30),
                           patternID: "P-11", confidence: 0.44),
            // Hace 5 días
            DetectedSignal(kind: .platformTransition, severity: .medium,
                           title: "Instagram → WhatsApp",
                           summary: "Cambio repetido 3 veces en 20 min",
                           detectedAt: dayAgoAt(5, 19, 10),
                           patternID: "P-07", confidence: 0.62),
            DetectedSignal(kind: .digitalIsolation, severity: .low,
                           title: "Baja en interacción social",
                           summary: "Instagram cayó 30% vs semana pasada",
                           detectedAt: dayAgoAt(5, 21, 0),
                           patternID: "P-09", confidence: 0.49),
            // Hace 4 días
            DetectedSignal(kind: .reactiveInstall, severity: .medium,
                           title: "App nueva · Snapchat",
                           summary: "Instalada tras conversación entrante",
                           detectedAt: dayAgoAt(4, 15, 45),
                           patternID: "P-03", confidence: 0.68),
            // Hace 3 días
            DetectedSignal(kind: .atypicalHours, severity: .medium,
                           title: "Horario atípico · 2 AM",
                           summary: "Actividad inesperada madrugada",
                           detectedAt: dayAgoAt(3, 2, 15),
                           patternID: "P-11", confidence: 0.65),
            DetectedSignal(kind: .platformTransition, severity: .high,
                           title: "TikTok → Discord (1ª vez)",
                           summary: "Invitación por DM externo",
                           detectedAt: dayAgoAt(3, 23, 40),
                           patternID: "P-07", confidence: 0.81),
            // Hace 2 días
            DetectedSignal(kind: .digitalIsolation, severity: .medium,
                           title: "Abandono abrupto de redes",
                           summary: "Uso total cayó 60% en un día",
                           detectedAt: dayAgoAt(2, 14, 0),
                           patternID: "P-09", confidence: 0.71),
            DetectedSignal(kind: .reactiveInstall, severity: .low,
                           title: "App nueva · WhatsApp Business",
                           summary: "Primera vez en el dispositivo",
                           detectedAt: dayAgoAt(2, 18, 20),
                           patternID: "P-03", confidence: 0.42),
            // Ayer
            DetectedSignal(kind: .atypicalHours, severity: .high,
                           title: "Uso de 4h entre 1 y 5 AM",
                           summary: "Patrón repetido de 3 noches",
                           detectedAt: dayAgoAt(1, 2, 55),
                           patternID: "P-11", confidence: 0.87),
            DetectedSignal(kind: .platformTransition, severity: .medium,
                           title: "Discord → Telegram",
                           summary: "Conversación migrada a otro canal",
                           detectedAt: dayAgoAt(1, 20, 10),
                           patternID: "P-07", confidence: 0.66),
            // Hoy
            DetectedSignal(
                kind: .atypicalHours,
                severity: .medium,
                title: "Horario atípico · 1:40 AM",
                summary: "Actividad entre 1 y 2 AM",
                detectedAt: todayAt(1, 40),
                patternID: "P-11",
                confidence: 0.62
            ),
            DetectedSignal(
                kind: .atypicalHours,
                severity: .high,
                title: "Horario atípico · 3.2h",
                summary: "Uso intenso entre 2 y 4 AM",
                detectedAt: todayAt(3, 15),
                patternID: "P-11",
                confidence: 0.78
            ),
            DetectedSignal(
                kind: .platformTransition,
                severity: .high,
                title: "Transición TikTok → Discord",
                summary: "3ª vez esta semana entre 2 y 4 AM",
                detectedAt: todayAt(3, 42),
                patternID: "P-07",
                confidence: 0.84
            ),
            DetectedSignal(
                kind: .digitalIsolation,
                severity: .low,
                title: "Caída brusca de Instagram",
                summary: "Uso bajó 70% respecto al promedio",
                detectedAt: todayAt(9, 5),
                patternID: "P-09",
                confidence: 0.51
            ),
            DetectedSignal(
                kind: .reactiveInstall,
                severity: .medium,
                title: "App nueva · Telegram",
                summary: "Instalada tras 40 min de TikTok",
                detectedAt: todayAt(14, 20),
                patternID: "P-03",
                confidence: 0.72
            ),
            DetectedSignal(
                kind: .platformTransition,
                severity: .medium,
                title: "Transición Snapchat → Discord",
                summary: "Mensaje entrante fuera de contactos",
                detectedAt: todayAt(17, 10),
                patternID: "P-07",
                confidence: 0.66
            ),
            DetectedSignal(
                kind: .reactiveInstall,
                severity: .low,
                title: "App nueva · BeReal",
                summary: "Instalada tras invitación recibida",
                detectedAt: todayAt(19, 45),
                patternID: "P-03",
                confidence: 0.48
            ),
            DetectedSignal(
                kind: .atypicalHours,
                severity: .high,
                title: "Horario atípico · 22:50",
                summary: "Mensajería activa tras hora de dormir",
                detectedAt: todayAt(22, 50),
                patternID: "P-11",
                confidence: 0.81
            )
        ]
    }()

    /// Historial de señales resueltas de las últimas 2 semanas
    static let mockHistory: [DetectedSignal] = [
        DetectedSignal(
            kind: .platformTransition,
            severity: .medium,
            title: "Transición Instagram → Snapchat",
            summary: "Falso positivo · era un grupo del colegio",
            detectedAt: .now.addingTimeInterval(-3 * 86400),
            patternID: "P-07",
            confidence: 0.64
        ),
        DetectedSignal(
            kind: .digitalIsolation,
            severity: .low,
            title: "Disminución de Instagram",
            summary: "Uso bajó 30% por tarea escolar",
            detectedAt: .now.addingTimeInterval(-5 * 86400),
            patternID: "P-09",
            confidence: 0.52
        ),
        DetectedSignal(
            kind: .atypicalHours,
            severity: .low,
            title: "Noche de examen",
            summary: "Uso extenso de YouTube Music · contexto identificado",
            detectedAt: .now.addingTimeInterval(-7 * 86400),
            patternID: "P-11",
            confidence: 0.45
        ),
        DetectedSignal(
            kind: .groomingPattern,
            severity: .high,
            title: "Patrón resuelto · derivado a 089",
            summary: "Usuario reportado por múltiples familias",
            detectedAt: .now.addingTimeInterval(-12 * 86400),
            patternID: "P-22",
            confidence: 0.91
        )
    ]
}

struct RiskScore: Hashable {
    let value: Int         // 0–100
    let trend: [Double]    // últimos 7 días
    let activeCount: Int
    let lastUpdated: Date

    var band: Band {
        switch value {
        case 0..<30: .safe
        case 30..<65: .moderate
        default: .elevated
        }
    }

    enum Band {
        case safe, moderate, elevated

        var label: String {
            switch self {
            case .safe: "Riesgo bajo"
            case .moderate: "Riesgo moderado"
            case .elevated: "Riesgo elevado"
            }
        }
    }

    static let mock = RiskScore(
        value: 72,
        trend: [12, 18, 22, 28, 35, 54, 72],
        activeCount: 3,
        lastUpdated: .now
    )
}
