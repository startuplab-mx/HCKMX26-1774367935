import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct VozBuzonView: View {
    @StateObject private var store = VozEntryStore.shared
    @State private var text: String = ""
    @State private var weProtectConsent: WeProtectChoice? = nil
    @FocusState private var textFocused: Bool

    @State private var showScanner = false
    @State private var showFileImporter = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPhotosPicker = false
    @State private var isSaving = false
    @State private var showSavedToast = false
    @State private var lastSuggestions: [VozSuggestion] = []
    @State private var showSuggestions = false
    @State private var showSettings = false

    enum WeProtectChoice { case yes, no }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topMeta
                greeting
                sub
                textArea
                tools
                weProtectCard
                saveButton
                if !store.entries.isEmpty { recentEntries }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FluxColor.voz)
        .overlay(alignment: .top) {
            if showSavedToast {
                savedToast
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            ScannerView()
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await extractTextFromImage(image)
                }
                pickerItem = nil
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .pdf, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await handleFileImport(url: url) }
            }
        }
        .sheet(isPresented: $showSuggestions) {
            VozSuggestionsSheet(suggestions: lastSuggestions)
        }
        .sheet(isPresented: $showSettings) {
            VozSettingsSheet()
        }
    }

    private var savedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(FluxColor.safe)
            Text(lastToastMessage)
                .font(FluxFont.body(13, weight: .semibold))
                .foregroundStyle(FluxColor.vozInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(FluxColor.vozSurface)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        )
    }
    @State private var lastToastMessage: String = "guardado"

    // MARK: - Top meta

    private var topMeta: some View {
        HStack {
            Text("MI · \(timeString)")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(FluxColor.vozAccent)
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FluxColor.vozInk)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(FluxColor.vozSurface)
                            .overlay(Circle().stroke(FluxColor.vozLine, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    // MARK: - Greeting

    private var greeting: some View {
        Text("\(greetingWord).")
            .font(.custom("Caveat", size: 56).weight(.semibold))
            .foregroundStyle(FluxColor.vozInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var sub: some View {
        Text("cuéntame sin apuro. lo que quieras.")
            .font(FluxFont.body(15))
            .foregroundStyle(FluxColor.vozMuted)
            .padding(.bottom, 6)
    }

    // MARK: - Text area

    private var textArea: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(FluxColor.vozSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.3, dash: [5, 4])
                        )
                        .foregroundStyle(Color(hex: 0xC8BFAE))
                )

            if text.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("escribe aquí...")
                        .font(FluxFont.body(15))
                        .foregroundStyle(FluxColor.vozMuted)
                    Text("(puede ser una frase, un párrafo, o nada. nadie te juzga.)")
                        .font(FluxFont.body(13))
                        .italic()
                        .foregroundStyle(Color(hex: 0xB8AF9E))
                }
                .padding(22)
                .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .focused($textFocused)
                .font(FluxFont.body(15))
                .foregroundStyle(FluxColor.vozInk)
                .scrollContentBackground(.hidden)
                .padding(14)
        }
        .frame(minHeight: 140)
    }

    // MARK: - Tools row (escanear · galería · archivo · limpiar)

    private var tools: some View {
        HStack(spacing: 10) {
            ToolButton(icon: "viewfinder", label: "escanear", isPrimary: true) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showScanner = true
            }
            ToolButton(icon: "photo.fill", label: "galería") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPhotosPicker = true
            }
            ToolButton(icon: "paperclip", label: "archivo") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showFileImporter = true
            }
            ToolButton(icon: "trash", label: "limpiar") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                text = ""
                weProtectConsent = nil
                textFocused = false
            }
        }
    }

    // MARK: - WeProtect opcional

    private var weProtectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(FluxColor.vozCard)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FluxColor.vozAccent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("WEPROTECT · OPCIONAL")
                        .font(FluxFont.mono(9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(FluxColor.vozAccent)
                    Text("si quieres, reviso lo que subas")
                        .font(FluxFont.body(13, weight: .semibold))
                        .foregroundStyle(FluxColor.vozInk)
                }
                Spacer()
            }

            Text("te digo si veo algo raro. tú decides, sin presión.")
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.vozMuted)
                .lineSpacing(2)

            HStack(spacing: 8) {
                Chip(label: "sí, revísalo", isSelected: weProtectConsent == .yes) {
                    weProtectConsent = .yes
                }
                Chip(label: "no, solo guardar", isSelected: weProtectConsent == .no, style: .ghost) {
                    weProtectConsent = .no
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(FluxColor.vozSurface)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(FluxColor.vozLine, lineWidth: 1))
        )
    }

    // MARK: - Save button

    private var saveButton: some View {
        let canSave = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button {
            save()
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(FluxColor.voz)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(isSaving ? "guardando..." : "guardar aquí")
                    .font(FluxFont.body(15, weight: .semibold))
            }
            .foregroundStyle(FluxColor.voz)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(canSave ? FluxColor.vozInk : FluxColor.vozInk.opacity(0.4))
            )
        }
        .disabled(!canSave || isSaving)
    }

    private func save() {
        let entry = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.isEmpty else { return }

        isSaving = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            var weProtectResult: VozEntry.WeProtectResult? = nil
            if weProtectConsent == .yes {
                let analysis = await WeProtectAI.shared.analyze(text: entry)
                let suggestions = await WeProtectAI.shared.suggestActions(for: entry)
                weProtectResult = .init(
                    risk: analysis.overallRisk.rawValue,
                    insights: analysis.insights.map { $0.pattern },
                    suggestions: suggestions
                )
                await MainActor.run {
                    lastSuggestions = suggestions
                }
            }

            await MainActor.run {
                let saved = VozEntry(
                    id: UUID(),
                    date: .now,
                    text: entry,
                    wantsWeProtect: weProtectConsent == .yes,
                    result: weProtectResult
                )
                store.save(saved)
                text = ""
                weProtectConsent = nil
                isSaving = false
                textFocused = false
                triggerSavedToast("guardado en tu buzón")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if !lastSuggestions.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showSuggestions = true
                    }
                }
            }
        }
    }

    private func triggerSavedToast(_ message: String) {
        lastToastMessage = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSavedToast = false
            }
        }
    }

    // MARK: - Recent entries
    private var recentEntries: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TU BUZÓN · \(store.entries.count)")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.vozMuted)
                Spacer()
            }
            .padding(.top, 8)

            ForEach(store.entries.prefix(5)) { entry in
                entryRow(entry)
            }
        }
    }

    private func entryRow(_ entry: VozEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.date, format: .dateTime.day().month().hour().minute())
                    .font(FluxFont.mono(10))
                    .foregroundStyle(FluxColor.vozMuted)
                Spacer()
                if let risk = entry.result?.risk {
                    HStack(spacing: 4) {
                        Circle().fill(riskColor(risk)).frame(width: 6, height: 6)
                        Text(riskLabel(risk))
                            .font(FluxFont.mono(9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(riskColor(risk))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(riskColor(risk).opacity(0.12)))
                } else if entry.wantsWeProtect {
                    Text("ANALIZADO")
                        .font(FluxFont.mono(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(FluxColor.vozAccent)
                } else {
                    Text("PRIVADO")
                        .font(FluxFont.mono(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(FluxColor.vozMuted)
                }
            }
            Text(entry.text)
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.vozInk)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.vozSurface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.vozLine, lineWidth: 1))
        )
    }

    private func riskColor(_ risk: String) -> Color {
        switch risk {
        case "high": return FluxColor.danger
        case "medium": return FluxColor.warn
        default: return FluxColor.safe
        }
    }

    private func riskLabel(_ risk: String) -> String {
        switch risk {
        case "high": return "riesgo alto"
        case "medium": return "atención"
        default: return "tranquilo"
        }
    }

    // MARK: - OCR helpers
    private func extractTextFromImage(_ image: UIImage) async {
        let service = CameraService()
        let regions = await service.analyzeImage(image, type: .chat)
        let extracted = regions.map { $0.text }.joined(separator: "\n")
        await MainActor.run {
            if extracted.isEmpty {
                triggerSavedToast("no se encontró texto")
            } else {
                if text.isEmpty {
                    text = extracted
                } else {
                    text += "\n\n" + extracted
                }
                triggerSavedToast("texto extraído")
            }
        }
    }

    private func handleFileImport(url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        if url.pathExtension.lowercased() == "txt" {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                await MainActor.run {
                    if text.isEmpty { text = content }
                    else { text += "\n\n" + content }
                    triggerSavedToast("texto añadido")
                }
            }
        } else if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            await extractTextFromImage(image)
        }
    }

    // MARK: - Helpers

    private var greetingWord: String {
        let h = Calendar.current.component(.hour, from: .now)
        switch h {
        case 5..<12:  return "buenos días"
        case 12..<19: return "buenas tardes"
        default:      return "buenas noches"
        }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: .now)
    }
}

// MARK: - Tool button

struct ToolButton: View {
    let icon: String
    let label: String
    var isPrimary: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isPrimary ? FluxColor.vozInk : FluxColor.vozCard)
                    Image(systemName: icon)
                        .font(.system(size: isPrimary ? 18 : 15, weight: .semibold))
                        .foregroundStyle(isPrimary ? FluxColor.voz : FluxColor.vozInk)
                }
                .frame(width: isPrimary ? 44 : 36, height: isPrimary ? 44 : 36)

                Text(label)
                    .font(FluxFont.body(11, weight: isPrimary ? .semibold : .medium))
                    .foregroundStyle(isPrimary ? FluxColor.vozInk : FluxColor.vozMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(FluxColor.vozSurface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.vozLine, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chip

struct Chip: View {
    let label: String
    let isSelected: Bool
    var style: Style = .filled
    let action: () -> Void

    enum Style { case filled, ghost }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(FluxFont.body(12, weight: .semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(background)
                        .overlay(Capsule().stroke(border, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        if isSelected && style == .filled { return FluxColor.voz }
        return FluxColor.vozInk
    }

    private var background: Color {
        if isSelected && style == .filled { return FluxColor.vozInk }
        return FluxColor.vozSurface
    }

    private var border: Color {
        isSelected ? FluxColor.vozInk : FluxColor.vozLine
    }
}

#Preview {
    VozBuzonView()
        .background(FluxColor.voz)
}

// MARK: - Voz Entry
struct VozEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let text: String
    let wantsWeProtect: Bool
    var result: WeProtectResult?
    var attachments: [Attachment] = []

    struct WeProtectResult: Codable, Hashable {
        let risk: String
        let insights: [String]
        let suggestions: [VozSuggestion]
    }

    struct Attachment: Identifiable, Codable, Hashable {
        var id = UUID()
        let kind: Kind
        let filename: String
        let size: Int

        enum Kind: String, Codable { case image, file }
    }
}

extension VozSuggestion.ActionType: Codable {}

extension VozSuggestion: Codable {
    private enum CodingKeys: String, CodingKey {
        case title, subtitle, action, phoneNumber
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            title: try c.decode(String.self, forKey: .title),
            subtitle: try c.decode(String.self, forKey: .subtitle),
            action: try c.decode(ActionType.self, forKey: .action),
            phoneNumber: try c.decodeIfPresent(String.self, forKey: .phoneNumber)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(subtitle, forKey: .subtitle)
        try c.encode(action, forKey: .action)
        try c.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
    }
}

// MARK: - Store (persistencia en Documents)
@MainActor
final class VozEntryStore: ObservableObject {
    static let shared = VozEntryStore()

    @Published private(set) var entries: [VozEntry] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("flux_voz_entries.json")
    }()

    private let seedFlagKey = "flux_voz_seeded_v1"

    private init() {
        load()
    }

    /// Reinicia con datos de muestra (útil para demo).
    func resetToMock() {
        seedMockData()
        persist()
    }

    private func seedMockData() {
        let now = Date.now
        entries = [
            // Entry 1 — HIGH: grooming reciente (más arriba)
            VozEntry(
                id: UUID(),
                date: now.addingTimeInterval(-2 * 3600),
                text: "hoy me pidió una foto sin ropa. dice que es nuestro secreto y que no le cuente a mi mamá porque se enoja. también me dijo que si le mando fotos me manda robux.",
                wantsWeProtect: true,
                result: .init(
                    risk: "high",
                    insights: [
                        "solicitud de imágenes íntimas",
                        "aislamiento · pedir secreto",
                        "soborno con moneda virtual"
                    ],
                    suggestions: [
                        VozSuggestion(
                            title: "llama al 089",
                            subtitle: "denuncia anónima gratuita. no tienes que dar tu nombre.",
                            action: .call,
                            phoneNumber: "089"
                        ),
                        VozSuggestion(
                            title: "cuéntale a un adulto de confianza",
                            subtitle: "puedes compartir lo que guardaste aquí desde tu caso.",
                            action: .share,
                            phoneNumber: nil
                        ),
                        VozSuggestion(
                            title: "aporta tu huella al foro",
                            subtitle: "sin nombres. puede ayudar a alguien más a darse cuenta.",
                            action: .contributeToForum,
                            phoneNumber: nil
                        )
                    ]
                )
            ),
            // Entry 2 — MEDIUM: afecto + regalo (hace 1 día)
            VozEntry(
                id: UUID(),
                date: now.addingTimeInterval(-26 * 3600),
                text: "me dijo que soy muy linda y que tenemos algo especial tú y yo. me quiere mandar un regalo pero le tengo que dar mi dirección. no sé si está bien.",
                wantsWeProtect: true,
                result: .init(
                    risk: "medium",
                    insights: [
                        "afecto inapropiado",
                        "solicitud de localización",
                        "regalo con condición"
                    ],
                    suggestions: [
                        VozSuggestion(
                            title: "habla con alguien de confianza",
                            subtitle: "estos mensajes parecen patrones conocidos. no estás sol@.",
                            action: .share,
                            phoneNumber: nil
                        ),
                        VozSuggestion(
                            title: "SAPTEL · si necesitas hablar",
                            subtitle: "escuchan sin juzgar. 24 horas.",
                            action: .call,
                            phoneNumber: "5552598121"
                        )
                    ]
                )
            ),
            // Entry 3 — LOW: diario común (hace 2 días)
            VozEntry(
                id: UUID(),
                date: now.addingTimeInterval(-2 * 86400),
                text: "hoy saqué 9 en mate. la maestra me felicitó enfrente de todos y me dio pena. después fuimos por helado con ana y marce.",
                wantsWeProtect: false,
                result: nil
            ),
            // Entry 4 — MEDIUM: primera señal (hace 3 días)
            VozEntry(
                id: UUID(),
                date: now.addingTimeInterval(-3 * 86400),
                text: "un chavo del equipo del juego me empezó a escribir por fuera del discord. dice que tiene 15 pero su foto se ve más grande. pregunta mucho por mí, qué hago, dónde estudio.",
                wantsWeProtect: true,
                result: .init(
                    risk: "medium",
                    insights: [
                        "posible edad alterada",
                        "preguntas sobre localización",
                        "contacto fuera de plataforma"
                    ],
                    suggestions: [
                        VozSuggestion(
                            title: "no compartas tu escuela",
                            subtitle: "si alguien pregunta mucho por datos personales, guarda distancia.",
                            action: .share,
                            phoneNumber: nil
                        ),
                        VozSuggestion(
                            title: "aporta al foro anónimo",
                            subtitle: "otras personas pueden reconocer este patrón.",
                            action: .contributeToForum,
                            phoneNumber: nil
                        )
                    ]
                )
            ),
            // Entry 5 — LOW: reflexión (hace 5 días)
            VozEntry(
                id: UUID(),
                date: now.addingTimeInterval(-5 * 86400),
                text: "a veces siento que nadie me entiende en casa. no es nada grave pero quería guardarlo.",
                wantsWeProtect: false,
                result: nil
            ),
            // Entry 6 — LOW (hace 1 semana)
            VozEntry(
                id: UUID(),
                date: now.addingTimeInterval(-7 * 86400),
                text: "mi papá me preguntó cómo me fue en la escuela y por primera vez me dieron ganas de contarle todo. pero no supe cómo.",
                wantsWeProtect: false,
                result: nil
            )
        ]
        persist()
    }

    func save(_ entry: VozEntry) {
        entries.insert(entry, at: 0)
        persist()
    }

    func delete(_ entry: VozEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clearAll() {
        entries.removeAll()
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([VozEntry].self, from: data)
        else { return }
        self.entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

// MARK: - Suggestions sheet
struct VozSuggestionsSheet: View {
    @Environment(\.dismiss) var dismiss
    let suggestions: [VozSuggestion]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WEPROTECT · SUGIERE")
                            .font(FluxFont.mono(10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(FluxColor.vozAccent)
                        Text("Lo que puedes hacer ahora")
                            .font(FluxFont.display(24, weight: .bold))
                            .kerning(-0.5)
                            .foregroundStyle(FluxColor.vozInk)
                        Text("Sin presión. Tú decides si haces algo o solo lo guardas.")
                            .font(FluxFont.body(13))
                            .foregroundStyle(FluxColor.vozMuted)
                    }

                    ForEach(suggestions) { s in
                        suggestionCard(s)
                    }
                }
                .padding(20)
            }
            .background(FluxColor.voz.ignoresSafeArea())
            .navigationTitle("Sugerencias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("cerrar") { dismiss() }
                }
            }
        }
    }

    private func suggestionCard(_ s: VozSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon(for: s.action))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FluxColor.vozAccent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(FluxColor.vozCard))
                Text(s.title)
                    .font(FluxFont.body(15, weight: .semibold))
                    .foregroundStyle(FluxColor.vozInk)
            }
            Text(s.subtitle)
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.vozMuted)
                .lineSpacing(2)

            if s.action == .call, let phone = s.phoneNumber {
                Button {
                    if let url = URL(string: "tel://\(phone)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("llamar \(phone)")
                    }
                    .font(FluxFont.body(13, weight: .semibold))
                    .foregroundStyle(FluxColor.voz)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(FluxColor.vozInk))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.vozSurface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.vozLine, lineWidth: 1))
        )
    }

    private func icon(for action: VozSuggestion.ActionType) -> String {
        switch action {
        case .call: return "phone.fill"
        case .share: return "square.and.arrow.up"
        case .report: return "exclamationmark.triangle.fill"
        case .contributeToForum: return "circle.grid.hex.fill"
        }
    }
}
