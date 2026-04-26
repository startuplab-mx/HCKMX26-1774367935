import SwiftUI
import UIKit

struct CommunityView: View {
    @StateObject private var store = CommunityStore.shared
    @StateObject private var alertCenter = AlertCenter.shared
    @State private var filter: CommunityFilter = .recommended
    @State private var selectedThread: CommunityThread?
    @State private var showCompose = false
    @State private var showFilterPicker = false

    private var filteredThreads: [CommunityThread] {
        let all = store.threads
        switch filter {
        case .recommended:
            // Hilos que matcheen las señales activas, si hay
            if let topSignal = alertCenter.activeSignals.first {
                let matched = all.filter { $0.matchesSignal(topSignal) }
                return matched.isEmpty ? all : matched
            }
            return all
        case .all:
            return all
        case .resolved:
            return all.filter { $0.statusTag == .resolved }
        case .urgent:
            return all.filter { $0.statusTag == .urgent }
        case .falsePositive:
            return all.filter { $0.statusTag == .falsePositive }
        case .mine:
            return all.filter { $0.isMine }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                filterBar
                threadList
                shareButton
                Color.clear.frame(height: 110)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(FluxColor.base)
        .sheet(item: $selectedThread) { thread in
            ThreadDetailView(thread: thread)
        }
        .sheet(isPresented: $showCompose) {
            ComposeThreadSheet()
        }
        .confirmationDialog("Filtrar hilos", isPresented: $showFilterPicker, titleVisibility: .visible) {
            Button("Recomendados para ti") { filter = .recommended }
            Button("Todos") { filter = .all }
            Button("Urgentes") { filter = .urgent }
            Button("Resueltos") { filter = .resolved }
            Button("Falsos positivos") { filter = .falsePositive }
            Button("Mis publicaciones") { filter = .mine }
            Button("Cancelar", role: .cancel) {}
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("COMUNIDAD · \(store.threads.count) HILOS ACTIVOS")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(FluxColor.primary)
            Text("Padres como tú")
                .font(FluxFont.display(26, weight: .bold))
                .kerning(-0.7)
                .foregroundStyle(FluxColor.ink)
            Text("Otras familias con situaciones parecidas. Anónimo y moderado por StartupLab.")
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.inkMuted)
                .lineSpacing(2)
                .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    // MARK: - Filter bar
    private var filterBar: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showFilterPicker = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("FILTRANDO POR")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.inkFaint)
                HStack {
                    Text(filterLabel)
                        .font(FluxFont.body(14, weight: .semibold))
                        .foregroundStyle(FluxColor.ink)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("cambiar")
                            .font(FluxFont.body(12, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(FluxColor.primary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FluxColor.surfaceAlt)
            )
        }
        .buttonStyle(.plain)
    }

    private var filterLabel: String {
        switch filter {
        case .recommended:
            if let s = alertCenter.activeSignals.first { return s.title }
            return "Recomendados para ti"
        case .all: return "Todos los hilos"
        case .resolved: return "Hilos resueltos"
        case .urgent: return "Hilos urgentes"
        case .falsePositive: return "Falsos positivos"
        case .mine: return "Mis publicaciones"
        }
    }

    // MARK: - Threads
    private var threadList: some View {
        VStack(spacing: 10) {
            if filteredThreads.isEmpty {
                emptyState
            } else {
                ForEach(filteredThreads) { thread in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedThread = thread
                    } label: {
                        threadCard(thread: thread)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundStyle(FluxColor.inkFaint)
            Text("Sin hilos en este filtro")
                .font(FluxFont.body(14, weight: .semibold))
                .foregroundStyle(FluxColor.ink)
            Text("Prueba otro filtro o comparte tu experiencia para iniciar un hilo.")
                .font(FluxFont.body(12))
                .foregroundStyle(FluxColor.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private func threadCard(thread: CommunityThread) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(thread.isMine ? FluxColor.primary.opacity(0.15) : FluxColor.surfaceAlt)
                    Text(thread.authorInitial)
                        .font(FluxFont.display(14, weight: .bold))
                        .foregroundStyle(thread.isMine ? FluxColor.primary : FluxColor.ink)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(thread.author)
                            .font(FluxFont.body(13, weight: .semibold))
                            .foregroundStyle(FluxColor.ink)
                        if thread.isMine {
                            Text("· tú")
                                .font(FluxFont.mono(10))
                                .foregroundStyle(FluxColor.primary)
                        }
                    }
                    Text(thread.timeAgoText)
                        .font(FluxFont.mono(10))
                        .foregroundStyle(FluxColor.inkFaint)
                }
                Spacer()
                if let tag = thread.statusTag {
                    statusTag(tag)
                }
            }

            Text(thread.title)
                .font(FluxFont.display(16, weight: .semibold))
                .kerning(-0.2)
                .foregroundStyle(FluxColor.ink)
                .multilineTextAlignment(.leading)

            Text(thread.preview)
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.inkMuted)
                .lineSpacing(2)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 10))
                    Text("\(thread.replyCount) respuestas")
                        .font(FluxFont.mono(10, weight: .medium))
                }
                .foregroundStyle(FluxColor.inkFaint)

                Spacer()

                Text("leer →")
                    .font(FluxFont.body(12, weight: .semibold))
                    .foregroundStyle(FluxColor.primary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private func statusTag(_ tag: CommunityThread.StatusTag) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tag.color)
                .frame(width: 5, height: 5)
            Text(tag.label.uppercased())
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(1.5)
        }
        .foregroundStyle(tag.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tag.color.opacity(0.12)))
    }

    // MARK: - Share button
    private var shareButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showCompose = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Compartir mi experiencia")
                    .font(FluxFont.body(16, weight: .semibold))
            }
            .foregroundStyle(FluxColor.base)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Capsule().fill(FluxColor.ink))
        }
        .padding(.top, 6)
    }
}

// MARK: - Filter enum
enum CommunityFilter: Hashable {
    case recommended
    case all
    case resolved
    case urgent
    case falsePositive
    case mine
}

// MARK: - Thread Detail
struct ThreadDetailView: View {
    let thread: CommunityThread

    @Environment(\.dismiss) var dismiss
    @StateObject private var store = CommunityStore.shared
    @State private var replyText: String = ""
    @FocusState private var replyFocused: Bool

    private var currentThread: CommunityThread {
        store.threads.first(where: { $0.id == thread.id }) ?? thread
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    threadHeader
                    threadBody
                    repliesSection
                    Color.clear.frame(height: 80)
                }
                .padding(20)
            }
            .background(FluxColor.base.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                replyBar
            }
            .navigationTitle("Hilo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("cerrar") { dismiss() }
                }
            }
        }
    }

    private var threadHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(currentThread.isMine ? FluxColor.primary.opacity(0.15) : FluxColor.surfaceAlt)
                Text(currentThread.authorInitial)
                    .font(FluxFont.display(15, weight: .bold))
                    .foregroundStyle(currentThread.isMine ? FluxColor.primary : FluxColor.ink)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(currentThread.author)
                        .font(FluxFont.body(14, weight: .semibold))
                        .foregroundStyle(FluxColor.ink)
                    if currentThread.isMine {
                        Text("· tú")
                            .font(FluxFont.mono(10))
                            .foregroundStyle(FluxColor.primary)
                    }
                }
                Text(currentThread.timeAgoText)
                    .font(FluxFont.mono(11))
                    .foregroundStyle(FluxColor.inkFaint)
            }
            Spacer()
        }
    }

    private var threadBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(currentThread.title)
                .font(FluxFont.display(22, weight: .bold))
                .kerning(-0.4)
                .foregroundStyle(FluxColor.ink)

            Text(currentThread.body)
                .font(FluxFont.body(14))
                .foregroundStyle(FluxColor.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RESPUESTAS · \(currentThread.replyCount)")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)

            if currentThread.replyList.isEmpty {
                Text("Sé el primero en responder.")
                    .font(FluxFont.body(13))
                    .foregroundStyle(FluxColor.inkMuted)
                    .padding(.vertical, 12)
            } else {
                ForEach(currentThread.replyList) { reply in
                    replyCard(reply)
                }
            }
        }
    }

    private func replyCard(_ reply: CommunityReply) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(reply.isMine ? FluxColor.primary.opacity(0.15) : FluxColor.surfaceAlt)
                Text(reply.authorInitial)
                    .font(FluxFont.display(12, weight: .bold))
                    .foregroundStyle(reply.isMine ? FluxColor.primary : FluxColor.ink)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(reply.author)
                        .font(FluxFont.body(12, weight: .semibold))
                        .foregroundStyle(FluxColor.ink)
                    if reply.isMine {
                        Text("· tú")
                            .font(FluxFont.mono(9))
                            .foregroundStyle(FluxColor.primary)
                    }
                    Spacer()
                    Text(reply.timeAgoText)
                        .font(FluxFont.mono(9))
                        .foregroundStyle(FluxColor.inkFaint)
                }
                Text(reply.body)
                    .font(FluxFont.body(13))
                    .foregroundStyle(FluxColor.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private var replyBar: some View {
        HStack(spacing: 8) {
            TextField("Escribe tu respuesta…", text: $replyText, axis: .vertical)
                .font(FluxFont.body(14))
                .foregroundStyle(FluxColor.ink)
                .lineLimit(1...4)
                .focused($replyFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(FluxColor.surface)
                        .overlay(Capsule().stroke(FluxColor.line, lineWidth: 1))
                )

            Button {
                sendReply()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FluxColor.base)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? FluxColor.inkFaint : FluxColor.ink))
            }
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func sendReply() {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        store.addReply(to: thread.id, body: trimmed)
        replyText = ""
        replyFocused = false
    }
}

// MARK: - Compose sheet
struct ComposeThreadSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = CommunityStore.shared
    @State private var title: String = ""
    @State private var content: String = ""
    @FocusState private var focus: Field?

    enum Field { case title, content }

    private var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TÍTULO")
                            .font(FluxFont.mono(10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(FluxColor.inkFaint)
                        TextField("Describe tu situación en una línea", text: $title, axis: .vertical)
                            .font(FluxFont.body(16, weight: .semibold))
                            .foregroundStyle(FluxColor.ink)
                            .lineLimit(1...3)
                            .focused($focus, equals: .title)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(FluxColor.surface)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(FluxColor.line, lineWidth: 1))
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("TU EXPERIENCIA")
                            .font(FluxFont.mono(10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(FluxColor.inkFaint)
                        TextField("Cuenta qué pasó, qué hiciste, qué funcionó. Sin nombres, sin datos identificables.", text: $content, axis: .vertical)
                            .font(FluxFont.body(14))
                            .foregroundStyle(FluxColor.ink)
                            .lineLimit(6...20)
                            .focused($focus, equals: .content)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(FluxColor.surface)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(FluxColor.line, lineWidth: 1))
                    )

                    privacyNote

                    Color.clear.frame(height: 40)
                }
                .padding(20)
            }
            .background(FluxColor.base.ignoresSafeArea())
            .navigationTitle("Compartir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("publicar") { publish() }
                        .disabled(!canPublish)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { focus = .title }
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(FluxColor.primary)
            Text("Tu publicación es anónima. No se muestra tu identidad. Todo se modera por StartupLab antes de publicarse.")
                .font(FluxFont.body(12))
                .foregroundStyle(FluxColor.inkMuted)
                .lineSpacing(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(FluxColor.primary.opacity(0.08))
        )
    }

    private func publish() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !c.isEmpty else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        store.publishThread(title: t, body: c)
        dismiss()
    }
}

// MARK: - Models
struct CommunityThread: Identifiable, Hashable {
    let id: UUID
    let author: String
    let authorInitial: String
    let timestamp: Date
    let title: String
    let preview: String
    let body: String
    var replyList: [CommunityReply]
    let tags: [String]
    let statusTag: StatusTag?
    let isMine: Bool

    var replyCount: Int { replyList.count }
    var timeAgoText: String { CommunityThread.relativeTime(from: timestamp) }

    init(
        id: UUID = UUID(),
        author: String,
        authorInitial: String,
        timestamp: Date,
        title: String,
        preview: String,
        body: String,
        replyList: [CommunityReply] = [],
        tags: [String] = [],
        statusTag: StatusTag? = nil,
        isMine: Bool = false
    ) {
        self.id = id
        self.author = author
        self.authorInitial = authorInitial
        self.timestamp = timestamp
        self.title = title
        self.preview = preview
        self.body = body
        self.replyList = replyList
        self.tags = tags
        self.statusTag = statusTag
        self.isMine = isMine
    }

    func matchesSignal(_ signal: DetectedSignal) -> Bool {
        let haystack = (title + " " + preview + " " + body + " " + tags.joined(separator: " ")).lowercased()
        let keywords: [String]
        switch signal.kind {
        case .platformTransition: keywords = ["tiktok", "discord", "snapchat", "transición", "transicion"]
        case .atypicalHours: keywords = ["madrugada", "horario", "noche", "2 am", "3 am"]
        case .reactiveInstall: keywords = ["telegram", "instaló", "instalo", "app nueva", "mensajería"]
        case .digitalIsolation: keywords = ["aislamiento", "se alejó", "se alejo", "dejó de"]
        case .groomingPattern: keywords = ["grooming", "patrón", "patron", "adulto"]
        }
        return keywords.contains(where: haystack.contains)
    }

    enum StatusTag: String {
        case resolved, falsePositive, urgent

        var label: String {
            switch self {
            case .resolved: "resuelto"
            case .falsePositive: "falso positivo"
            case .urgent: "urgente"
            }
        }

        var color: Color {
            switch self {
            case .resolved: FluxColor.safe
            case .falsePositive: FluxColor.warn
            case .urgent: FluxColor.danger
            }
        }
    }

    static func relativeTime(from date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        let minutes = Int(interval / 60)
        if minutes < 1 { return "hace un momento" }
        if minutes < 60 { return "hace \(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "hace \(hours)h" }
        let days = hours / 24
        if days < 7 { return "hace \(days) día\(days == 1 ? "" : "s")" }
        let weeks = days / 7
        if weeks < 4 { return "hace \(weeks) semana\(weeks == 1 ? "" : "s")" }
        let months = days / 30
        return "hace \(months) mes\(months == 1 ? "" : "es")"
    }
}

struct CommunityReply: Identifiable, Hashable {
    let id: UUID
    let author: String
    let authorInitial: String
    let timestamp: Date
    let body: String
    let isMine: Bool

    var timeAgoText: String { CommunityThread.relativeTime(from: timestamp) }

    init(id: UUID = UUID(), author: String, authorInitial: String, timestamp: Date = .now, body: String, isMine: Bool = false) {
        self.id = id
        self.author = author
        self.authorInitial = authorInitial
        self.timestamp = timestamp
        self.body = body
        self.isMine = isMine
    }
}

// MARK: - Store
@MainActor
final class CommunityStore: ObservableObject {
    static let shared = CommunityStore()

    @Published var threads: [CommunityThread]

    private init() {
        self.threads = CommunityStore.seedThreads()
    }

    func publishThread(title: String, body: String) {
        let preview = String(body.prefix(140))
        let thread = CommunityThread(
            author: "tú (anónimo)",
            authorInitial: "T",
            timestamp: .now,
            title: title,
            preview: preview,
            body: body,
            replyList: [],
            tags: [],
            statusTag: nil,
            isMine: true
        )
        threads.insert(thread, at: 0)
    }

    func addReply(to threadID: UUID, body: String) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        let reply = CommunityReply(
            author: "tú (anónimo)",
            authorInitial: "T",
            body: body,
            isMine: true
        )
        var t = threads[idx]
        t.replyList.insert(reply, at: 0)
        threads[idx] = t
    }

    // MARK: - Seed data
    private static func seedThreads() -> [CommunityThread] {
        let now = Date.now
        return [
            CommunityThread(
                author: "mamá_anónima",
                authorInitial: "M",
                timestamp: now.addingTimeInterval(-3 * 86400),
                title: "Me pasó igual con mi hijo (14)",
                preview: "flux me marcó el mismo patrón en enero. Al principio entré en pánico, pero después de leer las sugerencias del coach empecé con la Opción 2...",
                body: "flux me marcó el mismo patrón en enero: transición de TikTok a Discord entre las 2 y 4 AM. Al principio entré en pánico y casi le confronto directo, pero leí las sugerencias del coach y empecé con la Opción 2, la de preguntar sin juzgar. Le hablé al día siguiente en el carro, camino a la escuela, sin mirarlo directo. Resultó que un amigo del colegio lo había invitado a un servidor de un juego nuevo y charlaban ahí porque los papás del amigo le quitaban el celular en la noche. No era grooming, era FOMO. Lo importante fue abrir el canal sin romperlo. Tres semanas después él mismo me contó que otro server le parecía raro y lo bloqueó.",
                replyList: [
                    CommunityReply(author: "consejera", authorInitial: "C", timestamp: now.addingTimeInterval(-2 * 86400), body: "Gracias por compartir. La Opción 2 funciona mejor cuando es contextual (en el carro, mientras cocinas). Evita la cena o la habitación."),
                    CommunityReply(author: "papá_primerizo", authorInitial: "P", timestamp: now.addingTimeInterval(-86400), body: "Estoy pasando por lo mismo esta semana. ¿Cuánto tiempo esperaste antes de confrontar?")
                ],
                tags: ["tiktok", "discord", "transición"],
                statusTag: .resolved
            ),
            CommunityThread(
                author: "papá_de_2",
                authorInitial: "P",
                timestamp: now.addingTimeInterval(-7 * 86400),
                title: "Cómo abordé la conversación sin que se cerrara",
                preview: "La Opción 2 del WeProtect coach funcionó mejor de lo esperado. Lo que hice distinto fue esperar a que ella misma sacara el tema...",
                body: "La Opción 2 del WeProtect coach funcionó mejor de lo esperado. Lo que hice distinto fue esperar a que ella misma sacara el tema. En lugar de decirle 'vi en flux que...', dejé pistas: puse una nota sobre la mesa que decía 'si alguna vez necesitas hablar, aquí estoy'. Tardó 5 días en acercarse, pero cuando lo hizo ya venía con la información. Fue más fácil para ella y para mí.",
                replyList: [],
                tags: ["conversación", "coach"],
                statusTag: nil
            ),
            CommunityThread(
                author: "tutora_reciente",
                authorInitial: "T",
                timestamp: now.addingTimeInterval(-14 * 86400),
                title: "Al final era un grupo del colegio",
                preview: "Falso positivo real. Dejen que la conversación respire antes de actuar. flux solo detecta patrones — el contexto siempre lo pone la familia...",
                body: "Falso positivo real. flux marcó transición Instagram → Snapchat con alta confianza. Casi les escribo a los papás de la otra familia. Antes de actuar, pregunté casualmente y resultó que era un grupo del equipo de futbol del colegio. Todos saltaron a Snapchat porque Instagram les 'daba pena'. Dejen que la conversación respire antes de actuar. flux solo detecta patrones — el contexto siempre lo pone la familia.",
                replyList: [
                    CommunityReply(author: "madre_atenta", authorInitial: "M", timestamp: now.addingTimeInterval(-13 * 86400), body: "Gracias. Esto me pasó hace 2 semanas, idéntico. El coach ayuda pero la familia decide.")
                ],
                tags: ["instagram", "snapchat", "falso positivo"],
                statusTag: .falsePositive
            ),
            CommunityThread(
                author: "abuela_cuidadora",
                authorInitial: "A",
                timestamp: now.addingTimeInterval(-4 * 86400),
                title: "Mi nieta me pidió ayuda por flux voz",
                preview: "No soy madre, soy abuela. Mi nieta activó flux voz desde la escuela y me pidió hablar conmigo antes de contarle a sus papás. La app nos dio el espacio que necesitábamos...",
                body: "No soy madre, soy abuela. Mi nieta de 12 activó flux voz desde la escuela y me pidió hablar conmigo antes de contarle a sus papás. La app nos dio el espacio que necesitábamos. Ella grabó una nota de voz contándome que un adulto del club de natación le había pedido fotos. Yo no sabía qué hacer al principio, pero el modo voz te deja escuchar sin responder inmediatamente. Con calma, hablamos con sus papás juntas esa misma tarde y reportamos al club. El adulto fue separado del programa 48 horas después.",
                replyList: [
                    CommunityReply(author: "psicóloga_infantil", authorInitial: "P", timestamp: now.addingTimeInterval(-3 * 86400), body: "Lo que describes es exactamente por qué existe el modo voz: un adulto de confianza que NO es el padre. Gracias por actuar tan rápido."),
                    CommunityReply(author: "tío_preocupado", authorInitial: "T", timestamp: now.addingTimeInterval(-2 * 86400), body: "Mi sobrina me activó como contacto. No sabía que esto era posible.")
                ],
                tags: ["flux voz", "grooming", "adulto"],
                statusTag: .resolved
            ),
            CommunityThread(
                author: "madre_primeriza",
                authorInitial: "M",
                timestamp: now.addingTimeInterval(-2 * 86400),
                title: "¿Cuándo es momento de revisar personalmente?",
                preview: "La transparencia está bien pero tengo dudas sobre cuándo cruzar la línea. Mi hija tiene 11 y el coach me sugirió la Opción 3 pero no estoy segura...",
                body: "La transparencia está bien pero tengo dudas sobre cuándo cruzar la línea. Mi hija tiene 11 y el coach me sugirió la Opción 3 (revisión conjunta del teléfono) pero no estoy segura. ¿Alguien ha usado esa opción con éxito? ¿Cómo plantearlo sin que se sienta vigilancia?",
                replyList: [],
                tags: ["privacidad", "edad", "coach"],
                statusTag: nil
            ),
            CommunityThread(
                author: "tía_soltera",
                authorInitial: "T",
                timestamp: now.addingTimeInterval(-6 * 86400),
                title: "Urgente · usuario reportado por varias familias",
                preview: "flux detectó el mismo patrón en 7 familias del mismo código postal. Lo reportamos juntas al INAI. Actualizo después de la reunión...",
                body: "flux detectó el mismo patrón en 7 familias del mismo código postal (CDMX, Benito Juárez). El usuario se presentaba como 'coach de gaming' en Discord y pedía fotos a niñas de 10-13 años. Lo reportamos juntas al INAI y a CyberTipline. Actualizo después de la reunión del viernes. Si alguien de la zona tiene un caso parecido, escríbanme por DM de la app.",
                replyList: [
                    CommunityReply(author: "madre_cdmx", authorInitial: "M", timestamp: now.addingTimeInterval(-5 * 86400), body: "Estoy en la zona. Te escribo por DM."),
                    CommunityReply(author: "consejera", authorInitial: "C", timestamp: now.addingTimeInterval(-4 * 86400), body: "Excelente que coordinaron como grupo. Cuando son varias familias la denuncia pesa mucho más."),
                    CommunityReply(author: "padre_testigo", authorInitial: "P", timestamp: now.addingTimeInterval(-3 * 86400), body: "Nosotros también. ¿Puedo sumarme al grupo?")
                ],
                tags: ["urgente", "grooming", "denuncia"],
                statusTag: .urgent
            )
        ]
    }
}

#Preview {
    CommunityView()
}
