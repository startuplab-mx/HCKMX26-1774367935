import AVFoundation
import SwiftUI
import Vision
import UIKit

final class CameraService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isRunning = false
    @Published var torchOn = false
    @Published var detectedRegions: [DetectedTextRegion] = []
    @Published var scanType: ScanContext = .chat

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.flux.camera")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var textRequest: VNRecognizeTextRequest?
    private var lastTime: CFTimeInterval = 0
    private var currentDevice: AVCaptureDevice?

    override init() {
        super.init()
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .fast
        req.usesLanguageCorrection = false
        req.recognitionLanguages = ["es-ES", "en-US"]
        self.textRequest = req
    }

    // MARK: - Torch
    func toggleTorch() {
        guard let device = currentDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
                DispatchQueue.main.async { self.torchOn = false }
            } else {
                try device.setTorchModeOn(level: 1.0)
                DispatchQueue.main.async { self.torchOn = true }
            }
            device.unlockForConfiguration()
        } catch {
            // ignore
        }
    }

    // MARK: - Análisis estático (galería / archivo)
    func analyzeImage(_ image: UIImage, type: ScanContext) async -> [DetectedTextRegion] {
        guard let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let results = (req.results as? [VNRecognizedTextObservation]) ?? []
                let regions: [DetectedTextRegion] = results.compactMap { obs in
                    guard let text = obs.topCandidates(1).first?.string, !text.isEmpty else { return nil }
                    let box = obs.boundingBox
                    let flippedY = 1 - box.maxY
                    return DetectedTextRegion(
                        text: text,
                        boundingBox: CGRect(x: box.minX, y: flippedY, width: box.width, height: box.height),
                        risk: WeProtectOnDevice.riskScore(for: text, context: type)
                    )
                }
                continuation.resume(returning: regions)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["es-ES", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
            try? handler.perform([request])
        }
    }

    func requestAuthorization() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            await MainActor.run { self.isAuthorized = true }
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { self.isAuthorized = granted }
        default:
            await MainActor.run { self.isAuthorized = false }
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async { self.isRunning = true }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async { self.isRunning = false }
            }
        }
    }

    private func configureIfNeeded() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .high

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            self.currentDevice = device
        }

        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        session.commitConfiguration()
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastTime > 0.15 else { return }
        lastTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let request = textRequest else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        do {
            try handler.perform([request])
            guard let results = request.results else { return }

            let ctx = self.scanType
            let regions: [DetectedTextRegion] = results.compactMap { obs in
                guard let text = obs.topCandidates(1).first?.string, !text.isEmpty else { return nil }
                let box = obs.boundingBox
                let flippedY = 1 - box.maxY
                return DetectedTextRegion(
                    text: text,
                    boundingBox: CGRect(x: box.minX, y: flippedY, width: box.width, height: box.height),
                    risk: WeProtectOnDevice.riskScore(for: text, context: ctx)
                )
            }
            DispatchQueue.main.async { [weak self] in
                self?.detectedRegions = regions
            }
        } catch {
            // ignore
        }
    }
}

// MARK: - Detected region
struct DetectedTextRegion: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var boundingBox: CGRect
    var risk: RiskLevel

    enum RiskLevel {
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
            case .low: "ok"
            case .medium: "atención"
            case .high: "alto"
            }
        }
    }
}

// MARK: - Contexto de escaneo
enum ScanContext: String, CaseIterable {
    case chat, doc, profile, link
}

// MARK: - WeProtect on-device · clasificador contextual
enum WeProtectOnDevice {

    // Patrones por contexto (cada uno con su tag explicable)
    struct Pattern {
        let needle: String
        let risk: DetectedTextRegion.RiskLevel
        let tag: String
    }

    private static let chatPatterns: [Pattern] = [
        // Aislamiento / secretismo
        .init(needle: "no le digas a tu", risk: .high, tag: "aislamiento"),
        .init(needle: "no le digas a nadie", risk: .high, tag: "aislamiento"),
        .init(needle: "no le cuentes", risk: .high, tag: "aislamiento"),
        .init(needle: "es nuestro secreto", risk: .high, tag: "aislamiento"),
        .init(needle: "secreto entre tu y yo", risk: .high, tag: "aislamiento"),
        .init(needle: "nadie lo sabra", risk: .high, tag: "aislamiento"),
        .init(needle: "es sorpresa", risk: .high, tag: "aislamiento"),
        .init(needle: "guarda el secreto", risk: .high, tag: "aislamiento"),
        .init(needle: "borra este mensaje", risk: .high, tag: "aislamiento"),
        .init(needle: "entre nosotros", risk: .medium, tag: "aislamiento"),

        // Solicitud de imágenes
        .init(needle: "mandame fotos", risk: .high, tag: "imágenes íntimas"),
        .init(needle: "manda fotos", risk: .high, tag: "imágenes íntimas"),
        .init(needle: "mandame mas", risk: .high, tag: "imágenes íntimas"),
        .init(needle: "manda mas", risk: .high, tag: "imágenes íntimas"),
        .init(needle: "manda una foto tuya", risk: .high, tag: "imágenes íntimas"),
        .init(needle: "envia foto", risk: .high, tag: "imágenes íntimas"),
        .init(needle: "envia una foto", risk: .high, tag: "imágenes íntimas"),
        .init(needle: "en esa foto", risk: .medium, tag: "imágenes íntimas"),
        .init(needle: "foto tuya", risk: .medium, tag: "imágenes íntimas"),
        .init(needle: "sin ropa", risk: .high, tag: "imágenes íntimas"),
        .init(needle: "en calzones", risk: .high, tag: "imágenes íntimas"),

        // Encuentro / localización
        .init(needle: "donde vives", risk: .high, tag: "localización"),
        .init(needle: "en que colonia", risk: .high, tag: "localización"),
        .init(needle: "en que calle", risk: .high, tag: "localización"),
        .init(needle: "a que escuela vas", risk: .high, tag: "localización"),
        .init(needle: "en que escuela", risk: .high, tag: "localización"),
        .init(needle: "nos vemos a solas", risk: .high, tag: "encuentro"),
        .init(needle: "te paso a ver", risk: .high, tag: "encuentro"),
        .init(needle: "paso por ti", risk: .high, tag: "encuentro"),
        .init(needle: "en persona", risk: .medium, tag: "encuentro"),
        .init(needle: "que no se entere", risk: .high, tag: "encuentro"),

        // Regalos / soborno
        .init(needle: "tengo un regalo", risk: .medium, tag: "regalo"),
        .init(needle: "te mando un regalo", risk: .medium, tag: "regalo"),
        .init(needle: "regalo que darte", risk: .medium, tag: "regalo"),
        .init(needle: "te compro", risk: .medium, tag: "regalo"),
        .init(needle: "te envio dinero", risk: .high, tag: "regalo"),
        .init(needle: "te deposito", risk: .high, tag: "regalo"),
        .init(needle: "robux", risk: .medium, tag: "regalo digital"),
        .init(needle: "v-bucks", risk: .medium, tag: "regalo digital"),
        .init(needle: "vbucks", risk: .medium, tag: "regalo digital"),
        .init(needle: "gift card", risk: .medium, tag: "regalo digital"),
        .init(needle: "tarjeta de regalo", risk: .medium, tag: "regalo digital"),

        // Afecto inapropiado
        .init(needle: "mi amor", risk: .medium, tag: "afecto inapropiado"),
        .init(needle: "princesa", risk: .medium, tag: "afecto inapropiado"),
        .init(needle: "bebe", risk: .medium, tag: "afecto inapropiado"),
        .init(needle: "mi bebe", risk: .medium, tag: "afecto inapropiado"),
        .init(needle: "eres muy lind", risk: .medium, tag: "afecto inapropiado"),
        .init(needle: "estas muy lind", risk: .medium, tag: "afecto inapropiado"),
        .init(needle: "estas muy bonita", risk: .medium, tag: "afecto inapropiado"),
        .init(needle: "te ves muy bien", risk: .medium, tag: "afecto inapropiado"),
        .init(needle: "te ves preciosa", risk: .medium, tag: "afecto inapropiado"),
        .init(needle: "tenemos algo especial", risk: .medium, tag: "afecto inapropiado"),
        .init(needle: "tu y yo", risk: .medium, tag: "afecto inapropiado"),
        .init(needle: "eres especial para mi", risk: .medium, tag: "afecto inapropiado")
    ]

    private static let docPatterns: [Pattern] = [
        .init(needle: "curp", risk: .high, tag: "dato personal"),
        .init(needle: "rfc", risk: .high, tag: "dato personal"),
        .init(needle: "ine", risk: .high, tag: "identificación"),
        .init(needle: "pasaporte", risk: .high, tag: "identificación"),
        .init(needle: "tarjeta de credito", risk: .high, tag: "financiero"),
        .init(needle: "tarjeta de crédito", risk: .high, tag: "financiero"),
        .init(needle: "cvv", risk: .high, tag: "financiero"),
        .init(needle: "clabe", risk: .high, tag: "financiero"),
        .init(needle: "número de cuenta", risk: .high, tag: "financiero"),
        .init(needle: "numero de cuenta", risk: .high, tag: "financiero"),
        .init(needle: "contraseña", risk: .medium, tag: "credencial"),
        .init(needle: "password", risk: .medium, tag: "credencial"),
        .init(needle: "confidencial", risk: .medium, tag: "confidencialidad"),
        .init(needle: "no compartir", risk: .medium, tag: "confidencialidad")
    ]

    private static let profilePatterns: [Pattern] = [
        .init(needle: "snap:", risk: .medium, tag: "contacto externo"),
        .init(needle: "snapchat", risk: .medium, tag: "contacto externo"),
        .init(needle: "telegram", risk: .medium, tag: "contacto externo"),
        .init(needle: "whatsapp", risk: .medium, tag: "contacto externo"),
        .init(needle: "discord", risk: .medium, tag: "contacto externo"),
        .init(needle: "onlyfans", risk: .high, tag: "contenido adulto"),
        .init(needle: "nsfw", risk: .high, tag: "contenido adulto"),
        .init(needle: "+18", risk: .high, tag: "contenido adulto"),
        .init(needle: "18+", risk: .high, tag: "contenido adulto"),
        .init(needle: "dm me", risk: .medium, tag: "invitación privada"),
        .init(needle: "mándame dm", risk: .medium, tag: "invitación privada")
    ]

    private static let linkPatterns: [Pattern] = [
        .init(needle: "bit.ly", risk: .medium, tag: "acortador"),
        .init(needle: "tinyurl", risk: .medium, tag: "acortador"),
        .init(needle: "t.co/", risk: .medium, tag: "acortador"),
        .init(needle: "goo.gl", risk: .medium, tag: "acortador"),
        .init(needle: "is.gd", risk: .medium, tag: "acortador"),
        .init(needle: "ow.ly", risk: .medium, tag: "acortador"),
        .init(needle: "verify-", risk: .high, tag: "phishing"),
        .init(needle: "login-", risk: .high, tag: "phishing"),
        .init(needle: "secure-", risk: .high, tag: "phishing"),
        .init(needle: "account-", risk: .high, tag: "phishing"),
        .init(needle: ".xyz", risk: .medium, tag: "TLD sospechoso"),
        .init(needle: ".top", risk: .medium, tag: "TLD sospechoso"),
        .init(needle: ".click", risk: .medium, tag: "TLD sospechoso")
    ]

    static func patterns(for context: ScanContext) -> [Pattern] {
        switch context {
        case .chat: return chatPatterns
        case .doc: return docPatterns
        case .profile: return profilePatterns
        case .link: return linkPatterns
        }
    }

    static func riskScore(for text: String, context: ScanContext) -> DetectedTextRegion.RiskLevel {
        let t = text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        var result: DetectedTextRegion.RiskLevel = .low
        for p in patterns(for: context) {
            let needle = p.needle.folding(options: .diacriticInsensitive, locale: .current)
            if t.contains(needle) {
                if p.risk == .high { return .high }
                if p.risk == .medium { result = .medium }
            }
        }
        return result
    }

    static func matchingTag(for text: String, context: ScanContext) -> String? {
        let t = text.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        for p in patterns(for: context) {
            let needle = p.needle.folding(options: .diacriticInsensitive, locale: .current)
            if t.contains(needle) { return p.tag }
        }
        return nil
    }

    // MARK: - Diagnóstico global
    struct Diagnosis {
        let verdict: Verdict
        let score: Int // 0-100
        let summary: String
        let findings: [Finding]
        let recommendations: [String]

        enum Verdict: String {
            case safe, caution, danger
            var label: String {
                switch self {
                case .safe: return "Sin señales de riesgo"
                case .caution: return "Revisa con cuidado"
                case .danger: return "Riesgo alto detectado"
                }
            }
            var color: Color {
                switch self {
                case .safe: return FluxColor.safe
                case .caution: return FluxColor.warn
                case .danger: return FluxColor.danger
                }
            }
        }

        struct Finding: Identifiable {
            let id = UUID()
            let tag: String
            let quote: String
            let risk: DetectedTextRegion.RiskLevel
        }
    }

    static func diagnose(regions: [DetectedTextRegion], context: ScanContext) -> Diagnosis {
        let highs = regions.filter { $0.risk == .high }
        let mediums = regions.filter { $0.risk == .medium }

        // Score ponderado
        let raw = highs.count * 28 + mediums.count * 10
        let score = min(100, max(0, raw + (regions.isEmpty ? 0 : 5)))

        let verdict: Diagnosis.Verdict
        if !highs.isEmpty || score >= 65 { verdict = .danger }
        else if !mediums.isEmpty || score >= 30 { verdict = .caution }
        else { verdict = .safe }

        // Findings (agrupados por tag)
        var tagMap: [String: Diagnosis.Finding] = [:]
        for r in highs + mediums {
            if let tag = matchingTag(for: r.text, context: context), tagMap[tag] == nil {
                tagMap[tag] = .init(tag: tag, quote: r.text, risk: r.risk)
            }
        }
        let findings = Array(tagMap.values).sorted { ($0.risk == .high ? 0 : 1) < ($1.risk == .high ? 0 : 1) }

        let summary = buildSummary(verdict: verdict, context: context, findings: findings, total: regions.count)
        let recs = recommendations(for: verdict, context: context, findings: findings)

        return Diagnosis(verdict: verdict, score: score, summary: summary, findings: findings, recommendations: recs)
    }

    private static func buildSummary(verdict: Diagnosis.Verdict, context: ScanContext, findings: [Diagnosis.Finding], total: Int) -> String {
        switch verdict {
        case .safe:
            return "Analizamos \(total) fragmentos y no detectamos patrones de riesgo para \(contextLabel(context))."
        case .caution:
            let tags = findings.prefix(3).map { $0.tag }.joined(separator: ", ")
            return "Hay señales que merecen atención: \(tags). Revisa el contexto completo antes de actuar."
        case .danger:
            let tags = findings.filter { $0.risk == .high }.prefix(3).map { $0.tag }.joined(separator: ", ")
            return "Detectamos patrones de riesgo alto: \(tags). Recomendamos guardar evidencia y hablar con un adulto de confianza."
        }
    }

    private static func contextLabel(_ c: ScanContext) -> String {
        switch c {
        case .chat: return "conversaciones"
        case .doc: return "documentos"
        case .profile: return "perfiles"
        case .link: return "enlaces"
        }
    }

    private static func recommendations(for verdict: Diagnosis.Verdict, context: ScanContext, findings: [Diagnosis.Finding]) -> [String] {
        switch (verdict, context) {
        case (.safe, _):
            return ["Guarda el escaneo como referencia si necesitas comparar más tarde."]
        case (.caution, .chat):
            return [
                "Pregunta a tu hijo/a quién es la persona del chat y desde cuándo hablan.",
                "Evita confrontar antes de entender el contexto; preserva la conversación."
            ]
        case (.danger, .chat):
            return [
                "Captura y guarda la conversación completa (no la borres).",
                "Bloquea el contacto desde la app donde ocurrió.",
                "Reporta a CyberTipline (800-843-5678) o denuncia@alumbra.org.mx si estás en México.",
                "Considera acompañamiento psicológico para el menor."
            ]
        case (.caution, .doc), (.danger, .doc):
            return [
                "No compartas este documento por canales no cifrados.",
                "Tapa manualmente los campos sensibles antes de enviarlo.",
                "Si fue expuesto, notifica al banco o institución emisora."
            ]
        case (.caution, .profile), (.danger, .profile):
            return [
                "Revisa que el perfil no tenga contactos fuera de la plataforma original.",
                "Ajusta la privacidad para que solo personas conocidas puedan escribir.",
                "Reporta y bloquea cuentas con contenido +18 dirigido a menores."
            ]
        case (.caution, .link), (.danger, .link):
            return [
                "No abras el enlace; copia la URL y verifícala en VirusTotal.",
                "Si ya lo abriste, no ingreses credenciales y cierra la pestaña.",
                "Reporta el mensaje a la plataforma donde lo recibiste."
            ]
        }
    }
}

// MARK: - Caso guardado (amenaza archivada)
struct SavedThreat: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var scanType: String
    var verdict: String
    var score: Int
    var summary: String
    var findings: [SavedFinding]
    var evidence: [String]
    var note: String?

    struct SavedFinding: Codable, Identifiable {
        var id = UUID()
        var tag: String
        var quote: String
        var risk: String
    }
}

// MARK: - Threat Store
final class ThreatStore: ObservableObject {
    static let shared = ThreatStore()

    @Published private(set) var threats: [SavedThreat] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("flux_threats.json")
    }()

    private init() { load() }

    func save(_ threat: SavedThreat) {
        threats.insert(threat, at: 0)
        persist()
    }

    func delete(_ threat: SavedThreat) {
        threats.removeAll { $0.id == threat.id }
        persist()
    }

    func clearAll() {
        threats.removeAll()
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([SavedThreat].self, from: data)
        else { return }
        self.threats = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(threats) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

extension SavedThreat {
    static func from(
        diagnosis: WeProtectOnDevice.Diagnosis,
        regions: [DetectedTextRegion],
        context: ScanContext
    ) -> SavedThreat {
        let verdictString: String = {
            switch diagnosis.verdict {
            case .safe: return "safe"
            case .caution: return "caution"
            case .danger: return "danger"
            }
        }()
        let findings: [SavedFinding] = diagnosis.findings.map { f in
            let riskStr: String
            switch f.risk {
            case .low: riskStr = "low"
            case .medium: riskStr = "medium"
            case .high: riskStr = "high"
            }
            return SavedFinding(tag: f.tag, quote: f.quote, risk: riskStr)
        }
        return SavedThreat(
            date: Date(),
            scanType: context.rawValue,
            verdict: verdictString,
            score: diagnosis.score,
            summary: diagnosis.summary,
            findings: findings,
            evidence: regions.prefix(20).map { $0.text },
            note: nil
        )
    }

    var verdictColor: Color {
        switch verdict {
        case "safe": return FluxColor.safe
        case "caution": return FluxColor.warn
        case "danger": return FluxColor.danger
        default: return FluxColor.inkMuted
        }
    }

    var verdictLabel: String {
        switch verdict {
        case "safe": return "Sin riesgo"
        case "caution": return "Revisar"
        case "danger": return "Riesgo alto"
        default: return "—"
        }
    }
}
