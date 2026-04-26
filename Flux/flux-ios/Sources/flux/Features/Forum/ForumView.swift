import SwiftUI
import UIKit

struct ForumView: View {
    @StateObject private var store = ForumStore.shared
    @State private var platforms: Set<PatternFootprint.Platform> = []
    @State private var featuredFootprint: PatternFootprint?
    @State private var selectedFootprint: PatternFootprint?
    @State private var showContribute = false

    private var allFootprints: [PatternFootprint] { store.footprints }

    private var displayedFeatured: PatternFootprint {
        featuredFootprint ?? allFootprints.first ?? PatternFootprint.placeholder
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !allFootprints.isEmpty {
                    signatureHero
                }
                filterBar
                caseList
                contributeCTA
                Color.clear.frame(height: 110)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(FluxColor.base)
        .sheet(item: $selectedFootprint) { fp in
            FootprintDetailView(footprint: fp)
        }
        .sheet(isPresented: $showContribute) {
            ContributeFootprintSheet()
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FORO · \(allFootprints.count) CASOS · ANÓNIMO")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(FluxColor.primary)
            Text("Huellas de patrones")
                .font(FluxFont.display(26, weight: .bold))
                .kerning(-0.7)
                .foregroundStyle(FluxColor.ink)
            Text("Sin nombres. Sin identidades. Solo huellas compartidas por otras familias.")
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.inkMuted)
                .lineSpacing(2)
                .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    // MARK: - Hero 3D
    private var signatureHero: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedFootprint = displayedFeatured
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                PatternSignature3DView(footprint: displayedFeatured)
                    .frame(height: 280)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HUELLA DESTACADA")
                            .font(FluxFont.mono(9, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(FluxColor.inkFaint)
                        Text("\(displayedFeatured.id) · \(platformLabel(for: displayedFeatured))")
                            .font(FluxFont.display(14, weight: .semibold))
                            .foregroundStyle(FluxColor.ink)
                    }
                    Spacer()
                    statusPill(footprint: displayedFeatured)
                }
                .padding(14)
                .background(Rectangle().fill(FluxColor.surface))
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24).stroke(FluxColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter bar
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FILTRAR POR PLATAFORMA")
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(label: "todos", isActive: platforms.isEmpty) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        platforms.removeAll()
                    }
                    ForEach(PatternFootprint.Platform.allCases, id: \.self) { p in
                        filterChip(label: p.rawValue, isActive: platforms.contains(p)) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if platforms.contains(p) { platforms.remove(p) }
                            else { platforms.insert(p) }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func filterChip(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(FluxFont.body(12, weight: .semibold))
                .foregroundStyle(isActive ? FluxColor.base : FluxColor.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? FluxColor.ink : FluxColor.surface)
                        .overlay(Capsule().stroke(FluxColor.line, lineWidth: isActive ? 0 : 1))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Case list
    private var caseList: some View {
        VStack(spacing: 10) {
            HStack {
                Text("TODAS LAS HUELLAS · \(filteredFootprints.count)")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.inkFaint)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            if filteredFootprints.isEmpty {
                emptyState
            } else {
                ForEach(filteredFootprints) { footprint in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedFootprint = footprint
                    } label: {
                        caseCard(footprint: footprint)
                    }
                    .buttonStyle(.plain)
                    .onLongPressGesture(minimumDuration: 0.3) {
                        withAnimation(.smooth(duration: 0.4)) {
                            featuredFootprint = footprint
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(FluxColor.inkFaint)
            Text("Sin huellas para este filtro")
                .font(FluxFont.body(14, weight: .semibold))
                .foregroundStyle(FluxColor.ink)
            Text("Quita plataformas o aporta una huella nueva desde una amenaza guardada.")
                .font(FluxFont.body(12))
                .foregroundStyle(FluxColor.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private func caseCard(footprint: PatternFootprint) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(footprint.id + " · " + platformLabel(for: footprint).uppercased())
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(FluxColor.inkFaint)
                Spacer()
                if footprint.isMine {
                    Text("APORTADA POR TI")
                        .font(FluxFont.mono(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(FluxColor.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(FluxColor.primary.opacity(0.1)))
                }
                statusPill(footprint: footprint)
            }

            HStack(spacing: 4) {
                ForEach(Array(footprint.emojis.prefix(3).enumerated()), id: \.offset) { _, emoji in
                    Text(emoji)
                        .font(.system(size: 14))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(FluxColor.accent.opacity(0.1))
                                .overlay(Capsule().stroke(FluxColor.accent.opacity(0.3), lineWidth: 1))
                        )
                }
                ForEach(Array(footprint.approach.prefix(3).enumerated()), id: \.offset) { _, a in
                    Text(a.rawValue)
                        .font(FluxFont.mono(10, weight: .medium))
                        .foregroundStyle(FluxColor.inkMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(FluxColor.surfaceAlt))
                }
            }

            Text("\u{201C}\(footprint.summary)\u{201D}")
                .font(FluxFont.body(13))
                .italic()
                .foregroundStyle(FluxColor.inkMuted)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 9))
                    Text("me pasó también · \(footprint.matchCount)")
                        .font(FluxFont.mono(10, weight: .medium))
                }
                .foregroundStyle(FluxColor.inkFaint)

                Spacer()

                HStack(spacing: 4) {
                    Text("ver huella 3D")
                        .font(FluxFont.body(12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
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

    // MARK: - Contribute CTA
    private var contributeCTA: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showContribute = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Aportar huella anónima")
                    .font(FluxFont.body(15, weight: .semibold))
            }
            .foregroundStyle(FluxColor.base)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(FluxColor.ink))
        }
        .padding(.top, 4)
    }

    // MARK: - Status pill
    private func statusPill(footprint: PatternFootprint) -> some View {
        let (bgColor, fgColor): (Color, Color) = {
            switch footprint.status {
            case .pending:    return (FluxColor.inkFaint.opacity(0.12), FluxColor.inkMuted)
            case .reviewed:   return (FluxColor.primary.opacity(0.12), FluxColor.primary)
            case .escalated:  return (FluxColor.warn.opacity(0.14), FluxColor.warn)
            case .resolved:   return (FluxColor.safe.opacity(0.14), FluxColor.safe)
            }
        }()

        return HStack(spacing: 5) {
            Circle().fill(fgColor).frame(width: 5, height: 5)
            Text(footprint.status.label.uppercased())
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(1.5)
        }
        .foregroundStyle(fgColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(bgColor))
    }

    // MARK: - Helpers
    private var filteredFootprints: [PatternFootprint] {
        if platforms.isEmpty { return allFootprints }
        return allFootprints.filter { !$0.platforms.filter { platforms.contains($0) }.isEmpty }
    }

    private func platformLabel(for footprint: PatternFootprint) -> String {
        if footprint.platforms.count >= 2 {
            return "\(footprint.platforms[0].rawValue) → \(footprint.platforms[1].rawValue)"
        }
        return footprint.platforms.first?.rawValue ?? "—"
    }
}

// MARK: - Footprint Detail
struct FootprintDetailView: View {
    let footprint: PatternFootprint

    @Environment(\.dismiss) var dismiss
    @StateObject private var store = ForumStore.shared

    private var currentFootprint: PatternFootprint {
        store.footprints.first(where: { $0.id == footprint.id }) ?? footprint
    }

    private var hasMatched: Bool { store.matchedIDs.contains(footprint.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    signature3D
                    metadata
                    if !currentFootprint.phrases.isEmpty {
                        phrasesSection
                    }
                    approachSection
                    summaryCard
                    matchButton
                    Color.clear.frame(height: 32)
                }
                .padding(20)
            }
            .background(FluxColor.base.ignoresSafeArea())
            .navigationTitle(currentFootprint.id)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("cerrar") { dismiss() }
                }
            }
        }
    }

    private var signature3D: some View {
        PatternSignature3DView(footprint: currentFootprint)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(FluxColor.line, lineWidth: 1))
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                metaTag("PLATAFORMAS", value: currentFootprint.platforms.map { $0.rawValue }.joined(separator: ", "))
                Spacer()
                metaTag("VENTANA", value: currentFootprint.timeWindow.rawValue)
            }
            HStack {
                metaTag("EDAD", value: currentFootprint.ageRange.rawValue)
                Spacer()
                metaTag("ESTADO", value: currentFootprint.status.label)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private func metaTag(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(FluxColor.inkFaint)
            Text(value)
                .font(FluxFont.body(13, weight: .semibold))
                .foregroundStyle(FluxColor.ink)
        }
    }

    private var phrasesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FRASES DETECTADAS")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)

            ForEach(currentFootprint.phrases, id: \.self) { phrase in
                HStack(alignment: .top, spacing: 10) {
                    Text("\u{201C}")
                        .font(FluxFont.display(20, weight: .bold))
                        .foregroundStyle(FluxColor.danger.opacity(0.5))
                    Text(phrase)
                        .font(FluxFont.body(14))
                        .italic()
                        .foregroundStyle(FluxColor.ink)
                        .lineSpacing(2)
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FluxColor.danger.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FluxColor.danger.opacity(0.15), lineWidth: 1))
                )
            }
        }
    }

    private var approachSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ABORDAJES IDENTIFICADOS")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)

            FlowLayout(spacing: 6) {
                ForEach(currentFootprint.emojis, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 16))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(FluxColor.accent.opacity(0.1))
                                .overlay(Capsule().stroke(FluxColor.accent.opacity(0.3), lineWidth: 1))
                        )
                }
                ForEach(currentFootprint.approach, id: \.self) { a in
                    Text(a.rawValue)
                        .font(FluxFont.body(12, weight: .semibold))
                        .foregroundStyle(FluxColor.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(FluxColor.surfaceAlt))
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TESTIMONIO")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)

            Text("\u{201C}\(currentFootprint.summary)\u{201D}")
                .font(FluxFont.body(14))
                .italic()
                .foregroundStyle(FluxColor.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private var matchButton: some View {
        Button {
            guard !hasMatched else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            store.incrementMatch(for: footprint.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: hasMatched ? "checkmark.circle.fill" : "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(hasMatched
                     ? "ya marcaste esta huella · \(currentFootprint.matchCount)"
                     : "me pasó también · \(currentFootprint.matchCount)")
                    .font(FluxFont.body(15, weight: .semibold))
            }
            .foregroundStyle(hasMatched ? FluxColor.safe : FluxColor.base)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Capsule().fill(hasMatched ? FluxColor.safe.opacity(0.12) : FluxColor.ink)
                    .overlay(Capsule().stroke(hasMatched ? FluxColor.safe.opacity(0.4) : .clear, lineWidth: 1))
            )
        }
        .disabled(hasMatched)
    }
}

// MARK: - Contribute Sheet (desde amenazas guardadas)
struct ContributeFootprintSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var threatStore = ThreatStore.shared
    @StateObject private var forumStore = ForumStore.shared
    @State private var selectedThreatID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    intro

                    if threatStore.threats.isEmpty {
                        emptyCasesState
                    } else {
                        Text("TUS AMENAZAS GUARDADAS")
                            .font(FluxFont.mono(10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(FluxColor.inkFaint)

                        ForEach(threatStore.threats) { threat in
                            threatOption(threat)
                        }
                    }

                    Color.clear.frame(height: 80)
                }
                .padding(20)
            }
            .background(FluxColor.base.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if selectedThreatID != nil {
                    contributeButton
                }
            }
            .navigationTitle("Aportar huella")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("cerrar") { dismiss() }
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(FluxColor.primary)
                Text("COMPARTIR ANÓNIMAMENTE")
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.primary)
            }
            Text("Tu amenaza se transforma en una huella sin nombres ni datos identificables. Solo patrones que pueden ayudar a otras familias a reconocer señales tempranas.")
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.inkMuted)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FluxColor.primary.opacity(0.06))
        )
    }

    private var emptyCasesState: some View {
        VStack(spacing: 10) {
            Image(systemName: "viewfinder")
                .font(.system(size: 36))
                .foregroundStyle(FluxColor.inkFaint)
            Text("No tienes amenazas guardadas")
                .font(FluxFont.body(14, weight: .semibold))
                .foregroundStyle(FluxColor.ink)
            Text("Escanea una conversación sospechosa y guárdala como amenaza. Después podrás aportarla al foro.")
                .font(FluxFont.body(12))
                .foregroundStyle(FluxColor.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private func threatOption(_ threat: SavedThreat) -> some View {
        let isSelected = selectedThreatID == threat.id
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedThreatID = isSelected ? nil : threat.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 5) {
                        Circle().fill(threat.verdictColor).frame(width: 6, height: 6)
                        Text(threat.verdictLabel.uppercased())
                            .font(FluxFont.mono(9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(threat.verdictColor)
                    }
                    Spacer()
                    Text(threat.date, style: .date)
                        .font(FluxFont.mono(10))
                        .foregroundStyle(FluxColor.inkFaint)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(FluxColor.primary)
                    }
                }
                Text(threat.scanType.uppercased() + " · score \(threat.score)/100")
                    .font(FluxFont.body(13, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)
                Text(threat.summary)
                    .font(FluxFont.body(12))
                    .foregroundStyle(FluxColor.inkMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !threat.findings.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(threat.findings.prefix(3)) { f in
                            Text(f.tag)
                                .font(FluxFont.mono(9, weight: .medium))
                                .foregroundStyle(FluxColor.inkMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(FluxColor.surfaceAlt))
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(FluxColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? FluxColor.primary : FluxColor.line, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var contributeButton: some View {
        Button {
            guard let id = selectedThreatID,
                  let threat = threatStore.threats.first(where: { $0.id == id }) else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            forumStore.contribute(from: threat)
            dismiss()
        } label: {
            Text("Aportar al foro")
                .font(FluxFont.body(15, weight: .semibold))
                .foregroundStyle(FluxColor.base)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(FluxColor.ink))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Store
@MainActor
final class ForumStore: ObservableObject {
    static let shared = ForumStore()

    @Published var footprints: [PatternFootprint] = []
    @Published private(set) var matchedIDs: Set<String> = []

    private init() {}

    func clearAll() {
        footprints.removeAll()
        matchedIDs.removeAll()
    }

    func incrementMatch(for id: String) {
        guard !matchedIDs.contains(id) else { return }
        matchedIDs.insert(id)
        if let idx = footprints.firstIndex(where: { $0.id == id }) {
            let old = footprints[idx]
            footprints[idx] = PatternFootprint(
                id: old.id, emojis: old.emojis, phrases: old.phrases,
                platforms: old.platforms, approach: old.approach,
                timeWindow: old.timeWindow, ageRange: old.ageRange,
                status: old.status, matchCount: old.matchCount + 1,
                createdAt: old.createdAt, summary: old.summary,
                isMine: old.isMine
            )
        }
    }

    func contribute(from threat: SavedThreat) {
        let nextID = "#\((footprints.compactMap { Int($0.id.dropFirst()) }.max() ?? 0) + 1)"
        let platforms = inferPlatforms(from: threat)
        let approach = inferApproach(from: threat)
        let emojis = inferEmojis(from: approach)

        let fp = PatternFootprint(
            id: nextID,
            emojis: emojis,
            phrases: threat.findings.map { $0.quote }.prefix(3).map { String($0) },
            platforms: platforms,
            approach: approach,
            timeWindow: .night,
            ageRange: .earlyTeen,
            status: .pending,
            matchCount: 0,
            createdAt: .now,
            summary: threat.summary,
            isMine: true
        )
        footprints.insert(fp, at: 0)
    }

    // MARK: - Inference helpers
    private func inferPlatforms(from threat: SavedThreat) -> [PatternFootprint.Platform] {
        let haystack = (threat.summary + " " + threat.evidence.joined(separator: " ")).lowercased()
        var result: [PatternFootprint.Platform] = []
        if haystack.contains("discord") { result.append(.discord) }
        if haystack.contains("tiktok") { result.append(.tiktok) }
        if haystack.contains("instagram") { result.append(.instagram) }
        if haystack.contains("whatsapp") { result.append(.whatsapp) }
        if haystack.contains("telegram") { result.append(.telegram) }
        if haystack.contains("snap") { result.append(.snapchat) }
        if haystack.contains("roblox") { result.append(.roblox) }
        return result.isEmpty ? [.tiktok] : result
    }

    private func inferApproach(from threat: SavedThreat) -> [PatternFootprint.Approach] {
        var result: Set<PatternFootprint.Approach> = []
        for f in threat.findings {
            let tag = f.tag.lowercased()
            if tag.contains("afecto") { result.insert(.compliment) }
            if tag.contains("regalo") { result.insert(.gift) }
            if tag.contains("digital") { result.insert(.virtualCurrency) }
            if tag.contains("aislamiento") { result.insert(.secrecy) }
            if tag.contains("encuentro") || tag.contains("localización") { result.insert(.commitment) }
            if tag.contains("íntimas") { result.insert(.isolation) }
        }
        return Array(result.prefix(4))
    }

    private func inferEmojis(from approaches: [PatternFootprint.Approach]) -> [String] {
        var result: [String] = []
        for a in approaches {
            switch a {
            case .compliment: result.append("😍")
            case .gift: result.append("🎁")
            case .virtualCurrency: result.append("💸")
            case .secrecy: result.append("🤫")
            case .commitment: result.append("📍")
            case .isolation: result.append("📸")
            case .falseAge: result.append("🎭")
            case .fakeProfile: result.append("👤")
            }
        }
        return Array(result.prefix(3))
    }
}

extension PatternFootprint {
    static let placeholder = PatternFootprint(
        id: "#0", emojis: [], phrases: [],
        platforms: [.tiktok], approach: [],
        timeWindow: .night, ageRange: .earlyTeen,
        status: .pending, matchCount: 0,
        createdAt: .now, summary: "—"
    )
}

#Preview {
    ForumView()
        .background(FluxColor.base)
}
