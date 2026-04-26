import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var alertCenter = AlertCenter.shared
    @State private var score = RiskScore.mock
    @State private var ringProgress: CGFloat = 0
    @State private var showSettings = false
    @State private var selectedSignal: DetectedSignal?
    @State private var showBaseline = false
    @State private var showTrend = false

    private var signals: [DetectedSignal] { alertCenter.activeSignals }
    private var activeCount: Int { alertCenter.activeSignals.count }
    private var currentScoreValue: Int { alertCenter.currentScore }
    private var currentBand: RiskScore.Band { alertCenter.currentBand }

    private var bandColor: Color {
        switch currentBand {
        case .safe: return FluxColor.safe
        case .moderate: return FluxColor.warn
        case .elevated: return FluxColor.danger
        }
    }

    private var bandHeroTitle: String {
        switch currentBand {
        case .safe: return "Todo tranquilo"
        case .moderate: return "Atención moderada"
        case .elevated: return "Alerta activa"
        }
    }

    @EnvironmentObject var profileStore: ProfileStore

    private var child: ChildProfile? {
        session.activeChildProfile ?? profileStore.activeProfile?.monitoredChildren.first
    }

    private var headerLine: String {
        if let c = child {
            return "\(c.name.uppercased()) · \(c.age) AÑOS"
        }
        return "SIN MENOR VINCULADO"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    riskHero
                    trendCard
                    signalsSection
                    Color.clear.frame(height: 100) // tabbar space
                }
                .padding(.horizontal, FluxSpace.lg)
                .padding(.top, FluxSpace.sm)
            }
            .background(FluxColor.base)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).delay(0.1)) {
                    ringProgress = CGFloat(currentScoreValue) / 100
                }
            }
            .onChange(of: currentScoreValue) { _, newValue in
                withAnimation(.easeOut(duration: 0.6)) {
                    ringProgress = CGFloat(newValue) / 100
                }
            }
            .navigationDestination(item: $selectedSignal) { signal in
                AlertDetailView(signal: signal)
            }
            .navigationDestination(isPresented: $showBaseline) {
                BaselineView()
            }
        }
        .overlay(alignment: .topTrailing) {
            settingsButton
                .padding(.trailing, FluxSpace.lg + 4)
                .padding(.top, 8)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(session)
                .environmentObject(ProfileStore.shared)
        }
        .sheet(isPresented: $showTrend) {
            TrendDetailView()
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headerLine)
                    .font(FluxFont.monoSM)
                    .tracking(2)
                    .foregroundStyle(FluxColor.inkFaint)
                Text("Resumen · 7 días")
                    .font(FluxFont.display(22, weight: .bold))
                    .kerning(-0.4)
                    .foregroundStyle(FluxColor.ink)
            }
            Spacer()
            // Placeholder para mantener el layout · el botón real va en overlay
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private var settingsButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(FluxColor.ink)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(FluxColor.surface)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(FluxColor.line, lineWidth: 1))
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Risk Hero
    private var riskHero: some View {
        HStack(spacing: FluxSpace.lg) {
            ZStack {
                Circle()
                    .stroke(bandColor.opacity(0.15), lineWidth: 9)
                    .frame(width: 128, height: 128)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        LinearGradient(
                            colors: [bandColor.opacity(0.85), bandColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .frame(width: 128, height: 128)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: bandColor.opacity(0.3), radius: 6, y: 2)
                    .animation(.easeOut(duration: 0.6), value: ringProgress)

                VStack(spacing: 0) {
                    Text("\(currentScoreValue)")
                        .font(FluxFont.display(48, weight: .extrabold))
                        .kerning(-2)
                        .foregroundStyle(bandColor)
                        .contentTransition(.numericText())
                        .animation(.smooth(duration: 0.5), value: currentScoreValue)
                    Text("/ 100")
                        .font(FluxFont.mono(10))
                        .tracking(1)
                        .foregroundStyle(bandColor.opacity(0.7))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(currentBand.label)
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(bandColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(bandColor.opacity(0.1))
                    )
                Text(bandHeroTitle)
                    .font(FluxFont.display(20, weight: .bold))
                    .kerning(-0.4)
                    .foregroundStyle(FluxColor.ink)
                Text("\(activeCount) señales detectadas en las últimas 48 horas.")
                    .font(FluxFont.bodySM)
                    .foregroundStyle(FluxColor.inkMuted)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(FluxSpace.lg)
        .background(
            ZStack {
                LinearGradient(
                    colors: [bandColor.opacity(0.08), bandColor.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(bandColor.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .offset(x: 100, y: -80)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: FluxRadius.xxl))
        .overlay(
            RoundedRectangle(cornerRadius: FluxRadius.xxl)
                .stroke(bandColor.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Trend card
    private var trendCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showTrend = true
        } label: {
            trendCardContent
        }
        .buttonStyle(.plain)
    }

    private var trendCardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TENDENCIA · 7D")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.inkFaint)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FluxColor.inkFaint)
            }

            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Text(alertCenter.trendDirection.label)
                        .font(FluxFont.display(15, weight: .bold))
                        .foregroundStyle(FluxColor.ink)
                        .contentTransition(.opacity)
                    Text(alertCenter.trendDirection.arrow)
                        .font(FluxFont.mono(12, weight: .medium))
                        .foregroundStyle(trendArrowColor)
                        .contentTransition(.numericText())
                }
                .animation(.smooth(duration: 0.4), value: currentScoreValue)

                Spacer()

                TrendSparkline(values: alertCenter.currentTrend, color: bandColor)
                    .frame(width: 110, height: 36)
                    .animation(.easeOut(duration: 0.6), value: currentScoreValue)
            }
        }
        .padding(.horizontal, FluxSpace.base)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private var trendArrowColor: Color {
        switch alertCenter.trendDirection {
        case .up: return FluxColor.danger
        case .down: return FluxColor.safe
        case .flat: return FluxColor.inkMuted
        }
    }

    // MARK: - Signals
    private var signalsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("SEÑALES ACTIVAS · \(activeCount)")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.inkFaint)
                Spacer()
                Text("ver todas")
                    .font(FluxFont.body(12, weight: .semibold))
                    .foregroundStyle(FluxColor.primary)
            }
            .padding(.horizontal, 4)

            if signals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(FluxColor.safe)
                    Text("Todo revisado")
                        .font(FluxFont.display(16, weight: .bold))
                        .foregroundStyle(FluxColor.ink)
                    Text("No hay señales pendientes de atención.")
                        .font(FluxFont.body(13))
                        .foregroundStyle(FluxColor.inkMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(FluxColor.safe.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FluxColor.safe.opacity(0.2), lineWidth: 1))
                )
            } else {
                ForEach(signals) { signal in
                    Button { selectedSignal = signal } label: {
                        SignalRow(signal: signal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Trend sparkline

struct TrendSparkline: View {
    let values: [Double]
    var color: Color = FluxColor.danger

    private let insetX: CGFloat = 4
    private let insetY: CGFloat = 6
    private let dotSize: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let availableW = max(geo.size.width - insetX * 2, 1)
            let availableH = max(geo.size.height - insetY * 2, 1)
            let maxV = max(values.max() ?? 1, 1)
            let minV = min(values.min() ?? 0, maxV)
            let range = max(maxV - minV, 1)
            let stepX = availableW / CGFloat(max(values.count - 1, 1))

            Path { path in
                for (i, v) in values.enumerated() {
                    let x = insetX + CGFloat(i) * stepX
                    let normalized = (v - minV) / range
                    let y = insetY + availableH * (1 - CGFloat(normalized))
                    if i == 0 { path.move(to: .init(x: x, y: y)) }
                    else { path.addLine(to: .init(x: x, y: y)) }
                }
            }
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            )

            if let last = values.last {
                let normalized = (last - minV) / range
                let y = insetY + availableH * (1 - CGFloat(normalized))
                let x = insetX + CGFloat(values.count - 1) * stepX
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .position(x: x, y: y)
                    .shadow(color: color.opacity(0.5), radius: 4)
            }
        }
    }
}

// MARK: - Signal row

struct SignalRow: View {
    let signal: DetectedSignal

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(signalColor)
                .frame(width: 10, height: 10)
                .background(
                    Circle()
                        .fill(signalColor.opacity(0.12))
                        .frame(width: 18, height: 18)
                )
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(signal.title)
                    .font(FluxFont.display(14, weight: .semibold))
                    .kerning(-0.1)
                    .foregroundStyle(FluxColor.ink)
                Text("\(relativeTime) · patrón \(signal.patternID)")
                    .font(FluxFont.mono(10))
                    .foregroundStyle(FluxColor.inkFaint)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FluxColor.inkFaint)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private var signalColor: Color {
        switch signal.severity {
        case .low: FluxColor.safe
        case .medium: FluxColor.warn
        case .high: FluxColor.danger
        }
    }

    private var relativeTime: String {
        let interval = Date.now.timeIntervalSince(signal.detectedAt)
        let hours = Int(interval / 3600)
        if hours < 1 { return "ahora" }
        if hours < 24 { return "hace \(hours)h" }
        return "hace \(hours / 24) días"
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppSession())
}

