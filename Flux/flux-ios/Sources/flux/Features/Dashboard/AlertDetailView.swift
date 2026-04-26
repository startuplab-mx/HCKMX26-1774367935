import SwiftUI
import UIKit

struct AlertDetailView: View {
    let signal: DetectedSignal

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var profileStore: ProfileStore
    @ObservedObject private var alertCenter = AlertCenter.shared
    @State private var showCoaching = false
    @State private var showReviewedToast = false

    private var childName: String {
        profileStore.activeProfile?.monitoredChildren.first?.name
            ?? session.activeChildProfile?.name
            ?? "tu hij@"
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    timelineCard
                    whyCard
                    ctaButtons
                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(FluxColor.base)

            if showReviewedToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FluxColor.safe)
                    Text("Marcado como revisado")
                        .font(FluxFont.body(13, weight: .semibold))
                        .foregroundStyle(FluxColor.ink)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(FluxColor.surface).shadow(color: .black.opacity(0.1), radius: 12, y: 4))
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("volver")
                            .font(FluxFont.body(14, weight: .medium))
                    }
                    .foregroundStyle(FluxColor.ink)
                }
            }
        }
        .sheet(isPresented: $showCoaching) {
            WeProtectCoachingSheet(signal: signal)
                .environmentObject(session)
        }
    }

    private var isReviewed: Bool {
        !alertCenter.activeSignals.contains(where: { $0.id == signal.id })
    }

    private func markReviewed() {
        guard !isReviewed else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        alertCenter.markReviewed(signal)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showReviewedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }

    // MARK: - Header
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("PATRÓN")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                Text("·")
                Text(String(format: "CONFIANZA %.2f", signal.confidence))
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
            }
            .foregroundStyle(FluxColor.danger)

            Text(signal.title)
                .font(FluxFont.display(28, weight: .bold))
                .kerning(-0.6)
                .foregroundStyle(FluxColor.danger)

            Text(signal.summary)
                .font(FluxFont.body(14))
                .foregroundStyle(FluxColor.ink)
                .padding(.top, 4)
                .lineSpacing(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(FluxColor.danger.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(FluxColor.danger.opacity(0.2), lineWidth: 1))
        )
    }

    // MARK: - Timeline
    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LÍNEA DE TIEMPO")
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)

            VStack(alignment: .leading, spacing: 14) {
                timelineEvent(time: "02:47 AM · hoy", detail: "TikTok 14m → Discord 8m")
                timelineEvent(time: "03:12 AM · lunes", detail: "TikTok 22m → Discord 14m")
                timelineEvent(time: "02:30 AM · sábado", detail: "TikTok 9m → Discord 18m")
            }
            .padding(.leading, 16)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(FluxColor.line)
                    .frame(width: 1)
                    .padding(.leading, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private func timelineEvent(time: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(FluxColor.ink)
                .frame(width: 10, height: 10)
                .offset(x: -15, y: 4)
                .overlay(
                    Circle()
                        .stroke(FluxColor.base, lineWidth: 2)
                        .frame(width: 10, height: 10)
                        .offset(x: -15, y: 4)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(time)
                    .font(FluxFont.body(14, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)
                Text(detail)
                    .font(FluxFont.mono(11))
                    .foregroundStyle(FluxColor.inkMuted)
            }
        }
    }

    // MARK: - Why
    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("POR QUÉ ESTA SEÑAL")
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)

            whyItem(number: 1, text: "Discord no estaba en la línea base de \(childName).")
            whyItem(number: 2, text: "Transición pública → privada es un patrón documentado (WeProtect Global Alliance 2024).")
            whyItem(number: 3, text: "El horario 2–4 AM es atípico para ella.")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(FluxColor.surfaceAlt)
        )
    }

    private func whyItem(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .font(FluxFont.display(14, weight: .bold))
                .foregroundStyle(FluxColor.ink)
            Text(text)
                .font(FluxFont.body(14))
                .foregroundStyle(FluxColor.ink)
                .lineSpacing(2)
        }
    }

    // MARK: - CTAs
    private var ctaButtons: some View {
        VStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showCoaching = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Preguntar a WeProtect")
                        .font(FluxFont.body(16, weight: .semibold))
                }
                .foregroundStyle(FluxColor.base)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Capsule().fill(FluxColor.ink))
            }

            Button { markReviewed() } label: {
                HStack(spacing: 6) {
                    if isReviewed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(FluxColor.safe)
                    }
                    Text(isReviewed ? "Revisado" : "Marcar como revisado")
                        .font(FluxFont.body(16, weight: .semibold))
                        .foregroundStyle(isReviewed ? FluxColor.safe : FluxColor.ink)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    Capsule().fill(isReviewed ? FluxColor.safe.opacity(0.08) : FluxColor.surface)
                        .overlay(Capsule().stroke(isReviewed ? FluxColor.safe.opacity(0.35) : FluxColor.line, lineWidth: 1))
                )
            }
            .disabled(isReviewed)
        }
    }
}

// MARK: - Alert Center (estado global de señales)
@MainActor
final class AlertCenter: ObservableObject {
    static let shared = AlertCenter()

    @Published var activeSignals: [DetectedSignal] = [] { didSet { persist() } }
    @Published private(set) var reviewedSignals: [DetectedSignal] = [] { didSet { persist() } }
    @Published var demoMode: Bool = false

    /// Todas las señales alguna vez registradas · ordenadas de más nueva a más vieja.
    var allSignals: [DetectedSignal] {
        (activeSignals + reviewedSignals).sorted { $0.detectedAt > $1.detectedAt }
    }

    /// Rango total del historial (fecha de la señal más antigua).
    var historyStart: Date? {
        allSignals.map(\.detectedAt).min()
    }

    private let activeKey = "flux.alerts.active"
    private let reviewedKey = "flux.alerts.reviewed"
    private var suppressPersistence = false

    private init() {
        load()
    }

    func markReviewed(_ signal: DetectedSignal) {
        activeSignals.removeAll { $0.id == signal.id }
        if !reviewedSignals.contains(where: { $0.id == signal.id }) {
            reviewedSignals.insert(signal, at: 0)
        }
    }

    func restore(_ signal: DetectedSignal) {
        reviewedSignals.removeAll { $0.id == signal.id }
        if !activeSignals.contains(where: { $0.id == signal.id }) {
            activeSignals.insert(signal, at: 0)
        }
    }

    /// Añade una nueva señal detectada. El score sube automáticamente.
    func addSignal(_ signal: DetectedSignal) {
        guard !activeSignals.contains(where: { $0.id == signal.id }) else { return }
        activeSignals.insert(signal, at: 0)
    }

    /// Reinicia el estado con las señales mock (útil para debugging/demo).
    func resetToMock() {
        activeSignals = DetectedSignal.mockActive
        reviewedSignals = []
    }

    func clearAll() {
        suppressPersistence = true
        activeSignals = []
        reviewedSignals = []
        suppressPersistence = false
        UserDefaults.standard.removeObject(forKey: activeKey)
        UserDefaults.standard.removeObject(forKey: reviewedKey)
    }

    // MARK: - Persistence

    private func persist() {
        guard !suppressPersistence else { return }
        let encoder = JSONEncoder()
        if let active = try? encoder.encode(activeSignals) {
            UserDefaults.standard.set(active, forKey: activeKey)
        }
        if let reviewed = try? encoder.encode(reviewedSignals) {
            UserDefaults.standard.set(reviewed, forKey: reviewedKey)
        }
    }

    private func load() {
        suppressPersistence = true
        defer { suppressPersistence = false }
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: activeKey),
           let decoded = try? decoder.decode([DetectedSignal].self, from: data) {
            activeSignals = decoded
        }
        if let data = UserDefaults.standard.data(forKey: reviewedKey),
           let decoded = try? decoder.decode([DetectedSignal].self, from: data) {
            reviewedSignals = decoded
        }
    }

    /// Score dinámico 0–100 basado en severidad de las señales activas
    var currentScore: Int {
        let high = activeSignals.filter { $0.severity == .high }.count
        let medium = activeSignals.filter { $0.severity == .medium }.count
        let low = activeSignals.filter { $0.severity == .low }.count
        let base = activeSignals.isEmpty ? 8 : 12
        return min(100, high * 28 + medium * 16 + low * 6 + base)
    }

    var currentBand: RiskScore.Band {
        switch currentScore {
        case 0..<30: return .safe
        case 30..<65: return .moderate
        default: return .elevated
        }
    }

    /// Tendencia de 7 días. Historial solo en modo demo; en perfiles reales la gráfica queda plana hasta que haya actividad.
    var currentTrend: [Double] {
        if demoMode {
            let history: [Double] = [12, 18, 22, 28, 35, 54]
            return history + [Double(currentScore)]
        }
        return Array(repeating: Double(currentScore), count: 7)
    }

    /// Dirección de la tendencia comparando el score actual vs el día anterior.
    var trendDirection: TrendDirection {
        let trend = currentTrend
        guard trend.count >= 2 else { return .flat(0) }
        let last = trend[trend.count - 1]
        let prev = trend[trend.count - 2]
        if prev == 0 { return .flat(0) }
        let delta = Int(((last - prev) / prev * 100).rounded())
        if delta > 3 { return .up(delta) }
        if delta < -3 { return .down(abs(delta)) }
        return .flat(0)
    }

    enum TrendDirection {
        case up(Int)     // % de subida
        case down(Int)   // % de bajada
        case flat(Int)

        var label: String {
            switch self {
            case .up: "subiendo"
            case .down: "bajando"
            case .flat: "estable"
            }
        }

        var arrow: String {
            switch self {
            case .up(let d): "↑ \(d)%"
            case .down(let d): "↓ \(d)%"
            case .flat: "→ 0%"
            }
        }
    }
}

// MARK: - WeProtect Coaching Sheet
struct WeProtectCoachingSheet: View {
    let signal: DetectedSignal

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var profileStore: ProfileStore
    @StateObject private var ai = WeProtectAI.shared
    @State private var approaches: [ConversationApproach] = []
    @State private var isGenerating = false

    private var profile: ChildProfile {
        profileStore.activeProfile?.monitoredChildren.first
            ?? session.activeChildProfile
            ?? ChildProfile(name: "tu hij@", age: 13, baselineApps: [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    Text("Cómo hablar con \(profile.name) sobre esto")
                        .font(FluxFont.title1)
                        .kerning(-0.6)
                        .foregroundStyle(FluxColor.ink)

                    Text("Contexto: \(signal.title) · \(signal.summary)")
                        .font(FluxFont.body(13))
                        .foregroundStyle(FluxColor.inkMuted)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12).fill(FluxColor.surfaceAlt)
                        )

                    if isGenerating {
                        HStack(spacing: 12) {
                            ProgressView().tint(FluxColor.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Generando en el dispositivo…")
                                    .font(FluxFont.body(14, weight: .semibold))
                                    .foregroundStyle(FluxColor.ink)
                                Text("nada sale de tu teléfono")
                                    .font(FluxFont.body(12))
                                    .foregroundStyle(FluxColor.inkMuted)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(FluxColor.surface).overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1)))
                    } else {
                        ForEach(approaches) { approach in
                            ApproachCard(approach: approach)
                        }
                    }

                    Button {
                        Task { await load(forceRegenerate: true) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Generar otras 3")
                        }
                        .font(FluxFont.body(14, weight: .semibold))
                        .foregroundStyle(FluxColor.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(FluxColor.primary.opacity(0.1))
                        )
                    }
                    .disabled(isGenerating)

                    Color.clear.frame(height: 20)
                }
                .padding(20)
            }
            .background(FluxColor.base.ignoresSafeArea())
            .navigationTitle("WeProtect · Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("cerrar") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(FluxColor.primary.opacity(0.12))
                Image(systemName: ai.backendKind == .foundationModels ? "cpu" : "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FluxColor.primary)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text("WEPROTECT · COACH")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.inkFaint)
                Text(ai.backendKind.label)
                    .font(FluxFont.body(12, weight: .medium))
                    .foregroundStyle(FluxColor.ink)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(FluxColor.safe).frame(width: 6, height: 6)
                Text("ON-DEVICE")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(FluxColor.inkMuted)
            }
        }
    }

    private func load(forceRegenerate: Bool = false) async {
        if !forceRegenerate && !approaches.isEmpty { return }
        isGenerating = true
        defer { isGenerating = false }

        let context = "\(signal.title). \(signal.summary). Patrón \(signal.patternID), confianza \(Int(signal.confidence * 100))%."
        let result = await ai.generateApproaches(
            childName: profile.name,
            age: profile.age,
            context: context
        )
        withAnimation(.smooth(duration: 0.35)) {
            approaches = result
        }
    }
}

#Preview {
    NavigationStack {
        AlertDetailView(signal: DetectedSignal.mockActive[0])
    }
}
