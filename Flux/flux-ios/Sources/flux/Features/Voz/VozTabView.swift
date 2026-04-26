import SwiftUI
import UIKit

struct VozTabView: View {
    @State private var selectedTab: VozLiquidTabBar.VozTab = .buzon
    @State private var showScanner: Bool = false

    var body: some View {
        Group {
            switch selectedTab {
            case .buzon:  VozBuzonView()
            case .forum:  VozForumStub()
            case .myCase: VozMyCaseStub()
            case .help:   VozHelpStub()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FluxColor.voz.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VozLiquidTabBar(selectedTab: $selectedTab) {
                showScanner = true
            }
            .padding(.bottom, 2)
        }
        .fullScreenCover(isPresented: $showScanner) {
            ScannerView()
        }
    }
}

// MARK: - Stubs de tabs (implementación completa en próximas tareas)

struct VozForumStub: View {
    @StateObject private var forumStore = ForumStore.shared
    @State private var filter: VozForumFilter = .resolved
    @State private var selected: PatternFootprint?
    @State private var showContribute = false

    enum VozForumFilter: Hashable {
        case resolved, similar, recent

        var label: String {
            switch self {
            case .resolved: "resueltos"
            case .similar: "como el tuyo"
            case .recent: "recientes"
            }
        }
    }

    private var filtered: [PatternFootprint] {
        switch filter {
        case .resolved:
            return forumStore.footprints.filter { $0.status == .resolved }
        case .similar:
            // matchea con las entries del menor si existen
            let vozText = VozEntryStore.shared.entries
                .prefix(3)
                .map { $0.text.lowercased() }
                .joined(separator: " ")
            if vozText.isEmpty { return forumStore.footprints }
            return forumStore.footprints.filter { fp in
                let haystack = (fp.summary + " " + fp.phrases.joined(separator: " ")).lowercased()
                return fp.phrases.contains { vozText.contains($0.lowercased()) } ||
                       haystack.contains("regalo") && vozText.contains("regalo") ||
                       haystack.contains("secreto") && vozText.contains("secreto")
            }
        case .recent:
            return forumStore.footprints.sorted { $0.createdAt > $1.createdAt }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                filterChips
                if filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(filtered) { fp in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selected = fp
                        } label: {
                            card(fp)
                        }
                        .buttonStyle(.plain)
                    }
                }
                contributeCTA
                Color.clear.frame(height: 30)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .background(FluxColor.voz)
        .sheet(item: $selected) { fp in
            VozFootprintDetailView(footprint: fp)
        }
        .sheet(isPresented: $showContribute) {
            VozContributeSheet()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("FORO · \(forumStore.footprints.count) HUELLAS")
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(2.5)
                    .foregroundStyle(FluxColor.vozAccent)
                Spacer()
            }
            .padding(.top, 12)

            Text("no estás sol@.")
                .font(FluxFont.caveat(48, weight: .semibold))
                .foregroundStyle(FluxColor.vozInk)

            Text("otras personas pasaron por algo parecido. sin nombres, sin identidades.")
                .font(FluxFont.body(14))
                .foregroundStyle(FluxColor.vozMuted)
                .lineSpacing(2)
        }
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach([VozForumFilter.resolved, .similar, .recent], id: \.self) { f in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    filter = f
                } label: {
                    Text(f.label)
                        .font(FluxFont.body(13, weight: .semibold))
                        .foregroundStyle(filter == f ? FluxColor.voz : FluxColor.vozInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(filter == f ? FluxColor.vozInk : FluxColor.vozSurface)
                                .overlay(Capsule().stroke(filter == f ? .clear : FluxColor.vozLine, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func card(_ fp: PatternFootprint) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(fp.id + " · " + (fp.platforms.first.map { $0.rawValue.lowercased() } ?? "—"))
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(FluxColor.vozMuted)
                Spacer()
                statusBadge(fp.status)
            }

            if !fp.emojis.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(fp.emojis.prefix(3).enumerated()), id: \.offset) { _, e in
                        Text(e)
                            .font(.system(size: 20))
                    }
                }
            }

            Text("\u{201C}\(fp.summary)\u{201D}")
                .font(FluxFont.body(14))
                .italic()
                .foregroundStyle(FluxColor.vozInk)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 9))
                Text("le pasó a \(fp.matchCount) personas más")
                    .font(FluxFont.mono(10, weight: .medium))
                Spacer()
                Text("leer →")
                    .font(FluxFont.body(12, weight: .semibold))
                    .foregroundStyle(FluxColor.vozAccent)
            }
            .foregroundStyle(FluxColor.vozMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(FluxColor.vozSurface)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(FluxColor.vozLine, lineWidth: 1))
        )
    }

    private func statusBadge(_ status: PatternFootprint.CaseStatus) -> some View {
        let (bg, fg): (Color, Color) = {
            switch status {
            case .resolved: return (FluxColor.safe.opacity(0.14), FluxColor.safe)
            case .escalated: return (FluxColor.warn.opacity(0.14), FluxColor.warn)
            case .reviewed: return (FluxColor.vozAccent.opacity(0.14), FluxColor.vozAccent)
            case .pending: return (FluxColor.vozMuted.opacity(0.14), FluxColor.vozMuted)
            }
        }()
        return HStack(spacing: 5) {
            Circle().fill(fg).frame(width: 5, height: 5)
            Text(status.label.uppercased())
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(1.5)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(bg))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundStyle(FluxColor.vozMuted)
            Text("sin huellas en este filtro")
                .font(FluxFont.caveat(28, weight: .semibold))
                .foregroundStyle(FluxColor.vozInk)
            Text("prueba otro filtro o comparte tu huella.")
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.vozMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(FluxColor.vozSurface)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(FluxColor.vozLine, lineWidth: 1))
        )
    }

    private var contributeCTA: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showContribute = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("aportar desde mi buzón")
                    .font(FluxFont.body(15, weight: .semibold))
            }
            .foregroundStyle(FluxColor.voz)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(FluxColor.vozInk))
        }
    }
}

// MARK: - Voz footprint detail
struct VozFootprintDetailView: View {
    let footprint: PatternFootprint
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = ForumStore.shared

    private var current: PatternFootprint {
        store.footprints.first(where: { $0.id == footprint.id }) ?? footprint
    }

    private var hasMatched: Bool { store.matchedIDs.contains(footprint.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroEmojis
                    summaryCard
                    if !current.phrases.isEmpty { phrasesCard }
                    metaCard
                    matchButton
                    Color.clear.frame(height: 32)
                }
                .padding(20)
            }
            .background(FluxColor.voz.ignoresSafeArea())
            .navigationTitle(current.id)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("cerrar") { dismiss() }
                }
            }
        }
    }

    private var heroEmojis: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Array(current.emojis.enumerated()), id: \.offset) { _, e in
                    Text(e).font(.system(size: 44))
                }
            }
            Text(current.status.label)
                .font(FluxFont.caveat(28, weight: .semibold))
                .foregroundStyle(FluxColor.vozInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(FluxColor.vozCard)
        )
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ASÍ LO CONTARON")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.vozMuted)
            Text("\u{201C}\(current.summary)\u{201D}")
                .font(FluxFont.body(15))
                .italic()
                .foregroundStyle(FluxColor.vozInk)
                .lineSpacing(3)
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

    private var phrasesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FRASES QUE APARECIERON")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.vozMuted)
            ForEach(current.phrases, id: \.self) { phrase in
                Text("\u{201C}\(phrase)\u{201D}")
                    .font(FluxFont.body(14))
                    .italic()
                    .foregroundStyle(FluxColor.vozInk)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FluxColor.vozCard)
                    )
            }
        }
    }

    private var metaCard: some View {
        HStack(spacing: 12) {
            metaItem(label: "plataforma", value: current.platforms.first?.rawValue ?? "—")
            metaItem(label: "momento", value: current.timeWindow.rawValue)
            metaItem(label: "edad", value: current.ageRange.rawValue)
        }
    }

    private func metaItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(FluxColor.vozMuted)
            Text(value)
                .font(FluxFont.body(13, weight: .semibold))
                .foregroundStyle(FluxColor.vozInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FluxColor.vozSurface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(FluxColor.vozLine, lineWidth: 1))
        )
    }

    private var matchButton: some View {
        Button {
            guard !hasMatched else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            store.incrementMatch(for: footprint.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: hasMatched ? "checkmark.circle.fill" : "heart.fill")
                Text(hasMatched
                     ? "gracias · \(current.matchCount) personas más"
                     : "a mí también · \(current.matchCount)")
                    .font(FluxFont.body(15, weight: .semibold))
            }
            .foregroundStyle(hasMatched ? FluxColor.safe : FluxColor.voz)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Capsule().fill(hasMatched ? FluxColor.safe.opacity(0.12) : FluxColor.vozInk)
                    .overlay(Capsule().stroke(hasMatched ? FluxColor.safe.opacity(0.4) : .clear, lineWidth: 1))
            )
        }
        .disabled(hasMatched)
    }
}

// MARK: - Voz contribute (desde entries de buzón)
struct VozContributeSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var vozStore = VozEntryStore.shared
    @StateObject private var forumStore = ForumStore.shared
    @State private var selectedEntryID: UUID?

    private var eligibleEntries: [VozEntry] {
        // Solo entries analizadas por WeProtect con resultado medium/high
        vozStore.entries.filter { $0.result?.risk == "medium" || $0.result?.risk == "high" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    intro
                    if eligibleEntries.isEmpty {
                        emptyState
                    } else {
                        Text("ENTRIES DE TU BUZÓN")
                            .font(FluxFont.mono(10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(FluxColor.vozMuted)
                        ForEach(eligibleEntries) { entry in
                            entryOption(entry)
                        }
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(20)
            }
            .background(FluxColor.voz.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if selectedEntryID != nil { contributeButton }
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
        VStack(alignment: .leading, spacing: 6) {
            Text("sin nombres.")
                .font(FluxFont.caveat(36, weight: .semibold))
                .foregroundStyle(FluxColor.vozInk)
            Text("tu huella se comparte anónima. solo patrones que pueden ayudar a otras personas a reconocer señales.")
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.vozMuted)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.vozCard)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "envelope")
                .font(.system(size: 30))
                .foregroundStyle(FluxColor.vozMuted)
            Text("aún no tienes entries analizadas")
                .font(FluxFont.body(14, weight: .semibold))
                .foregroundStyle(FluxColor.vozInk)
            Text("guarda algo en tu buzón con WeProtect activo para poder aportarlo aquí.")
                .font(FluxFont.body(12))
                .foregroundStyle(FluxColor.vozMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.vozSurface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.vozLine, lineWidth: 1))
        )
    }

    private func entryOption(_ entry: VozEntry) -> some View {
        let selected = selectedEntryID == entry.id
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedEntryID = selected ? nil : entry.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.date, format: .dateTime.day().month())
                        .font(FluxFont.mono(10))
                        .foregroundStyle(FluxColor.vozMuted)
                    Spacer()
                    if let r = entry.result?.risk {
                        Text(r.uppercased())
                            .font(FluxFont.mono(9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(riskColor(r))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(riskColor(r).opacity(0.14)))
                    }
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(FluxColor.vozAccent)
                    }
                }
                Text(entry.text)
                    .font(FluxFont.body(13))
                    .foregroundStyle(FluxColor.vozInk)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FluxColor.vozSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selected ? FluxColor.vozAccent : FluxColor.vozLine, lineWidth: selected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var contributeButton: some View {
        Button {
            guard let id = selectedEntryID,
                  let entry = vozStore.entries.first(where: { $0.id == id }) else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            contribute(entry)
            dismiss()
        } label: {
            Text("aportar al foro")
                .font(FluxFont.body(15, weight: .semibold))
                .foregroundStyle(FluxColor.voz)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(FluxColor.vozInk))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func contribute(_ entry: VozEntry) {
        let nextID = "#\((forumStore.footprints.compactMap { Int($0.id.dropFirst()) }.max() ?? 0) + 1)"
        let phrases = entry.result?.insights ?? []
        let fp = PatternFootprint(
            id: nextID,
            emojis: ["💬"],
            phrases: phrases,
            platforms: [.whatsapp],
            approach: [.secrecy],
            timeWindow: .night,
            ageRange: .earlyTeen,
            status: .pending,
            matchCount: 0,
            createdAt: .now,
            summary: String(entry.text.prefix(140)),
            isMine: true
        )
        forumStore.footprints.insert(fp, at: 0)
    }

    private func riskColor(_ risk: String) -> Color {
        switch risk {
        case "high": return FluxColor.danger
        case "medium": return FluxColor.warn
        default: return FluxColor.safe
        }
    }
}

// MARK: - Tu caso (derivado del buzón)
struct VozMyCaseStub: View {
    @StateObject private var vozStore = VozEntryStore.shared
    @State private var showContactAdult = false
    @State private var showReport = false

    private var caseEntries: [VozEntry] {
        vozStore.entries.filter { $0.result?.risk == "medium" || $0.result?.risk == "high" }
    }

    private var highestRisk: String {
        if caseEntries.contains(where: { $0.result?.risk == "high" }) { return "high" }
        if caseEntries.contains(where: { $0.result?.risk == "medium" }) { return "medium" }
        return "low"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if caseEntries.isEmpty {
                    emptyCase
                } else {
                    statusHero
                    timeline
                    actionsCard
                }
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .background(FluxColor.voz)
        .sheet(isPresented: $showContactAdult) {
            VozContactAdultSheet(entries: caseEntries)
        }
        .sheet(isPresented: $showReport) {
            VozReportSheet(entries: caseEntries)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TU CASO · \(caseEntries.count) SEÑAL\(caseEntries.count == 1 ? "" : "ES")")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(FluxColor.vozAccent)
                .padding(.top, 12)

            Text("tu caso.")
                .font(FluxFont.caveat(48, weight: .semibold))
                .foregroundStyle(FluxColor.vozInk)

            Text("lo que guardaste con WeProtect activo. solo tú lo ves.")
                .font(FluxFont.body(14))
                .foregroundStyle(FluxColor.vozMuted)
                .lineSpacing(2)
        }
    }

    private var emptyCase: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(FluxColor.vozAccent)
            Text("todo tranquilo.")
                .font(FluxFont.caveat(36, weight: .semibold))
                .foregroundStyle(FluxColor.vozInk)
            Text("no hay nada marcado como señal en tu buzón. si algo te preocupa, guárdalo en el buzón con WeProtect activo.")
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.vozMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(FluxColor.vozSurface)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(FluxColor.vozLine, lineWidth: 1))
        )
    }

    private var statusHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(riskColor(highestRisk))
                    .frame(width: 10, height: 10)
                    .shadow(color: riskColor(highestRisk).opacity(0.6), radius: 6)
                Text(statusLabel.uppercased())
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(riskColor(highestRisk))
                Spacer()
            }

            Text(heroTitle)
                .font(FluxFont.caveat(30, weight: .semibold))
                .foregroundStyle(FluxColor.vozInk)

            Text(heroSubtitle)
                .font(FluxFont.body(14))
                .foregroundStyle(FluxColor.vozMuted)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(riskColor(highestRisk).opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(riskColor(highestRisk).opacity(0.3), lineWidth: 1))
        )
    }

    private var statusLabel: String {
        switch highestRisk {
        case "high": "atención alta"
        case "medium": "atención media"
        default: "revisión"
        }
    }

    private var heroTitle: String {
        switch highestRisk {
        case "high": "hay algo que vale la pena contarle a alguien."
        case "medium": "hay señales que conviene revisar."
        default: "tu caso está en calma."
        }
    }

    private var heroSubtitle: String {
        "\(caseEntries.count) entr\(caseEntries.count == 1 ? "y" : "ies") con señales detectadas. todo lo que aparece aquí viene de tu buzón."
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LO QUE PASÓ")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.vozMuted)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(caseEntries) { entry in
                    timelineRow(entry)
                }
            }
            .padding(.leading, 14)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(FluxColor.vozLine)
                    .frame(width: 1)
                    .padding(.leading, 4)
            }
        }
    }

    private func timelineRow(_ entry: VozEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(riskColor(entry.result?.risk ?? "low"))
                .frame(width: 10, height: 10)
                .offset(x: -15, y: 6)
                .overlay(
                    Circle()
                        .stroke(FluxColor.voz, lineWidth: 2)
                        .frame(width: 10, height: 10)
                        .offset(x: -15, y: 6)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.date, format: .dateTime.day().month().hour().minute())
                        .font(FluxFont.mono(10, weight: .bold))
                        .foregroundStyle(FluxColor.vozInk)
                    Spacer()
                    if let r = entry.result?.risk {
                        Text(r.uppercased())
                            .font(FluxFont.mono(9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(riskColor(r))
                    }
                }
                Text(entry.text)
                    .font(FluxFont.body(13))
                    .foregroundStyle(FluxColor.vozInk)
                    .lineLimit(3)

                if let insights = entry.result?.insights, !insights.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(insights.prefix(2), id: \.self) { ins in
                            Text(ins)
                                .font(FluxFont.mono(9, weight: .medium))
                                .foregroundStyle(FluxColor.vozMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(FluxColor.vozCard))
                        }
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUÉ PUEDES HACER")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.vozMuted)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showContactAdult = true
            } label: {
                actionRow(icon: "heart.fill", title: "contarle a un adulto de confianza",
                         subtitle: "comparte lo guardado de forma segura")
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showReport = true
            } label: {
                actionRow(icon: "exclamationmark.shield.fill", title: "reportar a una línea oficial",
                         subtitle: "089 · CyberTipline · INAI", primary: true)
            }
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String, primary: Bool = false) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(primary ? FluxColor.vozInk : FluxColor.vozCard)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(primary ? FluxColor.voz : FluxColor.vozAccent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FluxFont.body(14, weight: .semibold))
                    .foregroundStyle(FluxColor.vozInk)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(FluxFont.body(12))
                    .foregroundStyle(FluxColor.vozMuted)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FluxColor.vozMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
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
}

// MARK: - Contact adult sheet
struct VozContactAdultSheet: View {
    @Environment(\.dismiss) var dismiss
    let entries: [VozEntry]
    @State private var showShareSheet = false

    private var summary: String {
        let header = "Hola, quiero contarte algo que estoy guardando en flux voz. Son \(entries.count) cosas que me preocuparon:\n\n"
        let body = entries.prefix(5).enumerated().map { (i, e) in
            let when = e.date.formatted(.dateTime.day().month().hour().minute())
            return "\(i + 1). [\(when)] \(e.text)"
        }.joined(separator: "\n\n")
        return header + body + "\n\n(generado desde flux voz · on-device)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("preparé un mensaje.")
                            .font(FluxFont.caveat(36, weight: .semibold))
                            .foregroundStyle(FluxColor.vozInk)
                        Text("tú decides a quién se lo mandas y cuándo. puedes editarlo antes.")
                            .font(FluxFont.body(13))
                            .foregroundStyle(FluxColor.vozMuted)
                    }

                    Text(summary)
                        .font(FluxFont.body(14))
                        .foregroundStyle(FluxColor.vozInk)
                        .lineSpacing(3)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(FluxColor.vozSurface)
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.vozLine, lineWidth: 1))
                        )

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showShareSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("compartir mensaje")
                                .font(FluxFont.body(15, weight: .semibold))
                        }
                        .foregroundStyle(FluxColor.voz)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(FluxColor.vozInk))
                    }

                    Color.clear.frame(height: 20)
                }
                .padding(20)
            }
            .background(FluxColor.voz.ignoresSafeArea())
            .navigationTitle("Contactar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("cerrar") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                VozShareActivity(text: summary)
            }
        }
    }
}

// MARK: - Share activity wrapper
struct VozShareActivity: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Report sheet (líneas oficiales)
struct VozReportSheet: View {
    @Environment(\.dismiss) var dismiss
    let entries: [VozEntry]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("líneas oficiales.")
                            .font(FluxFont.caveat(36, weight: .semibold))
                            .foregroundStyle(FluxColor.vozInk)
                        Text("son gratuitas, anónimas y atienden menores de edad. ellos saben qué hacer.")
                            .font(FluxFont.body(13))
                            .foregroundStyle(FluxColor.vozMuted)
                            .lineSpacing(2)
                    }

                    lineRow(
                        name: "089 · denuncia anónima",
                        phone: "089",
                        note: "reportas sin dar tu nombre. funciona en todo México.",
                        urgent: true
                    )
                    lineRow(
                        name: "SAPTEL · crisis emocional",
                        phone: "5552598121",
                        note: "te escuchan cuando estás abrumad@. 24/7.",
                        urgent: false
                    )
                    lineRow(
                        name: "CyberTipline (EE.UU.)",
                        phone: "18008435678",
                        note: "para explotación y grooming en línea. también acepta reportes de México.",
                        urgent: true
                    )
                    lineRow(
                        name: "INAI · protección de datos",
                        phone: "8008354324",
                        note: "si alguien publicó algo tuyo sin permiso.",
                        urgent: false
                    )

                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CUANDO LLAMES, PUEDES DECIR")
                                .font(FluxFont.mono(10, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(FluxColor.vozMuted)
                            Text("\u{201C}hola, tengo algo guardado en una app que detectó \(entries.count) señal\(entries.count == 1 ? "" : "es") de riesgo. ¿pueden ayudarme?\u{201D}")
                                .font(FluxFont.body(14))
                                .italic()
                                .foregroundStyle(FluxColor.vozInk)
                                .lineSpacing(3)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(FluxColor.vozCard)
                                )
                        }
                    }

                    Color.clear.frame(height: 20)
                }
                .padding(20)
            }
            .background(FluxColor.voz.ignoresSafeArea())
            .navigationTitle("Reportar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("cerrar") { dismiss() }
                }
            }
        }
    }

    private func lineRow(name: String, phone: String, note: String, urgent: Bool) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if let url = URL(string: "tel://\(phone)") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(urgent ? FluxColor.danger.opacity(0.1) : FluxColor.vozCard)
                    Image(systemName: "phone.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(urgent ? FluxColor.danger : FluxColor.vozAccent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(FluxFont.body(14, weight: .semibold))
                        .foregroundStyle(FluxColor.vozInk)
                        .multilineTextAlignment(.leading)
                    Text(note)
                        .font(FluxFont.body(12))
                        .foregroundStyle(FluxColor.vozMuted)
                        .lineSpacing(1)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Text(displayPhone(phone))
                    .font(FluxFont.mono(11, weight: .bold))
                    .foregroundStyle(urgent ? FluxColor.danger : FluxColor.vozAccent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(FluxColor.vozSurface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.vozLine, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func displayPhone(_ phone: String) -> String {
        if phone == "089" { return "089" }
        // formatear como (XXX) XXX-XXXX aproximado
        if phone.count >= 10 {
            return String(phone.suffix(10)).replacingOccurrences(of: "^(\\d{3})(\\d{3})(\\d{4})$", with: "$1 $2 $3", options: .regularExpression)
        }
        return phone
    }
}

// MARK: - Ayuda
struct VozHelpStub: View {
    @EnvironmentObject var profileStore: ProfileStore
    @State private var showReport = false
    @State private var showContact = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                quickAction(
                    icon: "exclamationmark.shield.fill",
                    title: "089 · denuncia anónima",
                    subtitle: "marca directo. es gratis, no piden datos.",
                    tint: FluxColor.danger
                ) {
                    callNumber("089")
                }

                quickAction(
                    icon: "phone.fill",
                    title: "SAPTEL · te escuchan",
                    subtitle: "crisis emocional · 24 horas",
                    tint: FluxColor.vozAccent
                ) {
                    callNumber("5552598121")
                }

                quickAction(
                    icon: "heart.fill",
                    title: "contactar adulto de confianza",
                    subtitle: "comparte tu caso con alguien seguro",
                    tint: FluxColor.safe
                ) {
                    showContact = true
                }

                quickAction(
                    icon: "list.bullet.clipboard",
                    title: "ver todas las líneas",
                    subtitle: "089, SAPTEL, CyberTipline, INAI",
                    tint: FluxColor.vozMuted
                ) {
                    showReport = true
                }

                privacyNote

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    profileStore.lock()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                        Text("cerrar sesión · cambiar perfil")
                    }
                    .font(FluxFont.body(14, weight: .semibold))
                    .foregroundStyle(FluxColor.voz)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(FluxColor.vozInk))
                }
                .padding(.top, 8)

                Color.clear.frame(height: 30)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .background(FluxColor.voz)
        .sheet(isPresented: $showReport) {
            VozReportSheet(entries: VozEntryStore.shared.entries.filter { $0.result?.risk == "medium" || $0.result?.risk == "high" })
        }
        .sheet(isPresented: $showContact) {
            VozContactAdultSheet(entries: VozEntryStore.shared.entries.filter { $0.result?.risk == "medium" || $0.result?.risk == "high" })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AYUDA · SIEMPRE DISPONIBLE")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(FluxColor.vozAccent)
                .padding(.top, 12)

            Text("aquí estoy.")
                .font(FluxFont.caveat(48, weight: .semibold))
                .foregroundStyle(FluxColor.vozInk)

            Text("todo lo que ves aquí es gratuito, anónimo y atiende menores.")
                .font(FluxFont.body(14))
                .foregroundStyle(FluxColor.vozMuted)
                .lineSpacing(2)
        }
    }

    private func quickAction(icon: String, title: String, subtitle: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(tint.opacity(0.12))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(FluxFont.body(14, weight: .semibold))
                        .foregroundStyle(FluxColor.vozInk)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(FluxFont.body(12))
                        .foregroundStyle(FluxColor.vozMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FluxColor.vozMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(FluxColor.vozSurface)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(FluxColor.vozLine, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(FluxColor.vozAccent)
            Text("nada de lo que haces aquí se comparte. ni siquiera con quien instaló flux en tu teléfono.")
                .font(FluxFont.body(12))
                .foregroundStyle(FluxColor.vozMuted)
                .lineSpacing(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FluxColor.vozCard)
        )
    }

    private func callNumber(_ phone: String) {
        if let url = URL(string: "tel://\(phone)") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    VozTabView()
}
