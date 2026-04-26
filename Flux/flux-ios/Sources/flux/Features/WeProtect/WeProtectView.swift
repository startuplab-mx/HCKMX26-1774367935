import SwiftUI

struct WeProtectView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var profileStore: ProfileStore
    @StateObject private var ai = WeProtectAI.shared
    @StateObject private var alertCenter = AlertCenter.shared
    @State private var approaches: [ConversationApproach] = []
    @State private var isGenerating = false

    private var profile: ChildProfile {
        profileStore.activeProfile?.monitoredChildren.first
            ?? session.activeChildProfile
            ?? ChildProfile(name: "tu hij@", age: 13, baselineApps: [])
    }

    private var activeSignals: [DetectedSignal] { alertCenter.activeSignals }

    /// Contexto generado dinámicamente a partir de las señales activas.
    private var signalsContext: String {
        guard !activeSignals.isEmpty else {
            return "No hay señales activas en este momento. Usa la conversación como prevención."
        }
        return activeSignals.prefix(3).map { s in
            "\(s.title): \(s.summary) (patrón \(s.patternID), confianza \(Int(s.confidence * 100))%)"
        }.joined(separator: ". ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                Text(activeSignals.isEmpty ? "Conversación preventiva con \(profile.name)" : "Cómo hablar con \(profile.name)")
                    .font(FluxFont.title1)
                    .kerning(-0.6)
                    .foregroundStyle(FluxColor.ink)

                Text(activeSignals.isEmpty
                     ? "Sin señales activas. Usa estos abordajes para fortalecer la confianza."
                     : "Abordajes basados en \(activeSignals.count) señal\(activeSignals.count == 1 ? "" : "es") activa\(activeSignals.count == 1 ? "" : "s").")
                    .font(FluxFont.body(14))
                    .foregroundStyle(FluxColor.inkMuted)

                if !activeSignals.isEmpty {
                    signalsContextCard
                }

                if isGenerating {
                    generatingCard
                } else {
                    ForEach(approaches) { approach in
                        ApproachCard(approach: approach)
                    }
                }

                regenerateButton
                generatedFooter

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(FluxColor.base)
        .task {
            await loadApproaches()
        }
        .onChange(of: activeSignals.count) { _, _ in
            Task { await loadApproaches(forceRegenerate: true) }
        }
    }

    // Card que resume las señales que alimentan los abordajes
    private var signalsContextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("BASADO EN ESTAS SEÑALES")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
            }
            .foregroundStyle(FluxColor.danger)

            ForEach(activeSignals.prefix(3)) { s in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(severityColor(s.severity)).frame(width: 6, height: 6).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title)
                            .font(FluxFont.body(13, weight: .semibold))
                            .foregroundStyle(FluxColor.ink)
                        Text(s.summary)
                            .font(FluxFont.body(12))
                            .foregroundStyle(FluxColor.inkMuted)
                            .lineLimit(2)
                    }
                }
            }

            if activeSignals.count > 3 {
                Text("+ \(activeSignals.count - 3) señal\(activeSignals.count - 3 == 1 ? "" : "es") más")
                    .font(FluxFont.mono(10))
                    .foregroundStyle(FluxColor.inkFaint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FluxColor.danger.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(FluxColor.danger.opacity(0.15), lineWidth: 1))
        )
    }

    private func severityColor(_ severity: DetectedSignal.Severity) -> Color {
        switch severity {
        case .low: return FluxColor.safe
        case .medium: return FluxColor.warn
        case .high: return FluxColor.danger
        }
    }

    // MARK: - Header con backend status

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
                Circle()
                    .fill(ai.isReady ? FluxColor.safe : FluxColor.warn)
                    .frame(width: 6, height: 6)
                Text(ai.isReady ? "ON-DEVICE" : "INIT...")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(FluxColor.inkMuted)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Generating card

    private var generatingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(FluxColor.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Generando en el dispositivo...")
                    .font(FluxFont.body(14, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)
                Text("nada sale de tu teléfono")
                    .font(FluxFont.body(12))
                    .foregroundStyle(FluxColor.inkMuted)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    // MARK: - Regenerate

    private var regenerateButton: some View {
        Button {
            Task { await loadApproaches(forceRegenerate: true) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                Text("regenerar")
                    .font(FluxFont.body(13, weight: .semibold))
            }
            .foregroundStyle(FluxColor.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(FluxColor.primarySoft)
            )
        }
        .disabled(isGenerating)
        .opacity(isGenerating ? 0.5 : 1)
    }

    private var generatedFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundStyle(FluxColor.primary)
            Text("Generado por WeProtect · \(ai.backendKind == .foundationModels ? "Apple Intelligence" : "editable antes de usar")")
                .font(FluxFont.mono(10))
                .foregroundStyle(FluxColor.inkMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FluxColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(FluxColor.line)
                )
        )
    }

    // MARK: - Async load

    private func loadApproaches(forceRegenerate: Bool = false) async {
        if !forceRegenerate && !approaches.isEmpty { return }
        isGenerating = true
        defer { isGenerating = false }

        let result = await ai.generateApproaches(
            childName: profile.name,
            age: profile.age,
            context: signalsContext
        )
        withAnimation(.smooth(duration: 0.35)) {
            approaches = result
        }
    }
}

// MARK: - Approach card

struct ApproachCard: View {
    let approach: ConversationApproach

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(approach.label.uppercased())
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.inkFaint)
                Spacer()
                Text(approach.estimatedTime)
                    .font(FluxFont.mono(10))
                    .foregroundStyle(FluxColor.inkFaint)
            }

            Text("\u{201C}\(approach.script)\u{201D}")
                .font(FluxFont.body(14))
                .italic()
                .foregroundStyle(FluxColor.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if !approach.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(approach.tags, id: \.self) { tag in
                        Text(tag)
                            .font(FluxFont.body(11, weight: .medium))
                            .foregroundStyle(FluxColor.inkMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(FluxColor.surfaceAlt)
                            )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
        )
    }
}

// MARK: - Model

struct ConversationApproach: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let estimatedTime: String
    let script: String
    let tags: [String]
}

#Preview {
    WeProtectView()
        .environmentObject(AppSession())
}
