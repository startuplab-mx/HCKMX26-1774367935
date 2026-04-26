import SwiftUI
import Charts

struct TrendDetailView: View {
    @ObservedObject var alertCenter = AlertCenter.shared
    @Environment(\.dismiss) var dismiss
    @State private var range: Range = .today

    enum Range: String, CaseIterable, Identifiable {
        case today = "Hoy"
        case history = "Historial"
        var id: String { rawValue }
    }

    private var todaySignals: [DetectedSignal] {
        let cal = Calendar.current
        return alertCenter.allSignals.filter { cal.isDateInToday($0.detectedAt) }
    }

    private var historySignals: [DetectedSignal] { alertCenter.allSignals }

    private var currentSignals: [DetectedSignal] {
        range == .today ? todaySignals : historySignals
    }


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerBlock
                    rangePicker
                    trendChart
                    incidentsSection
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(FluxColor.base)
            .navigationTitle("Tendencia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("listo") { dismiss() }
                        .foregroundStyle(FluxColor.primary)
                }
            }
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SCORE AHORA")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.inkFaint)
                Text("\(alertCenter.currentScore)")
                    .font(FluxFont.display(42, weight: .black))
                    .foregroundStyle(bandColor)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.4), value: alertCenter.currentScore)
                Text(alertCenter.currentBand.label)
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(bandColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(range == .today ? "INCIDENTES HOY" : "TOTAL HISTORIAL")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.inkFaint)
                Text("\(currentSignals.count)")
                    .font(FluxFont.display(42, weight: .black))
                    .foregroundStyle(FluxColor.ink)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.4), value: currentSignals.count)
                if let last = currentSignals.first {
                    Text(last.detectedAt, style: .time)
                        .font(FluxFont.mono(10, weight: .medium))
                        .foregroundStyle(FluxColor.inkMuted)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    // MARK: - Range picker

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(Range.allCases) { r in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.smooth(duration: 0.3)) { range = r }
                } label: {
                    Text(r.rawValue)
                        .font(FluxFont.body(13, weight: .semibold))
                        .foregroundStyle(range == r ? FluxColor.surface : FluxColor.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(range == r ? FluxColor.ink : FluxColor.surface)
                                .overlay(Capsule().stroke(FluxColor.line, lineWidth: range == r ? 0 : 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(range == .today ? "ACTIVIDAD POR HORA" : "HISTORIAL COMPLETO")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.inkFaint)
                Spacer()
                Text("\(currentSignals.count) eventos")
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(FluxColor.inkMuted)
            }

            chartBody
                .frame(height: 200)
                .animation(.smooth(duration: 0.45), value: currentSignals.count)
                .animation(.smooth(duration: 0.45), value: range)

            severityLegend
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    @ViewBuilder
    private var chartBody: some View {
        if range == .today {
            todayChart
        } else {
            historyChart
        }
    }

    private var todayChart: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: today) ?? .now
        let points = todaySignals.sorted { $0.detectedAt < $1.detectedAt }

        return Chart {
            areaAndLine(for: points)
            signalPoints(for: points)
        }
        .chartXScale(domain: today...endOfDay)
        .chartYScale(domain: 0...3.6)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { v in
                AxisGridLine().foregroundStyle(FluxColor.line.opacity(0.5))
                AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
            }
        }
        .chartYAxis { yAxis }
    }

    private var historyChart: some View {
        let points = historySignals.sorted { $0.detectedAt < $1.detectedAt }
        let (start, end) = historyBounds
        let totalDays = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
        let visibleDays = min(7, totalDays)
        let visibleSeconds: TimeInterval = TimeInterval(visibleDays) * 86_400

        return Chart {
            areaAndLine(for: points)
            signalPoints(for: points)
        }
        .chartYScale(domain: 0...3.6)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleSeconds)
        .chartScrollPosition(initialX: end.addingTimeInterval(-visibleSeconds))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, visibleDays / 5))) { _ in
                AxisGridLine().foregroundStyle(FluxColor.line.opacity(0.5))
                AxisValueLabel(format: .dateTime.day(.twoDigits).month(.abbreviated))
            }
        }
        .chartYAxis { yAxis }
    }

    private var historyBounds: (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date.now
        let earliest = alertCenter.historyStart ?? cal.date(byAdding: .day, value: -6, to: now) ?? now
        let start = cal.startOfDay(for: earliest)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        return (start, end)
    }

    @ChartContentBuilder
    private func areaAndLine(for points: [DetectedSignal]) -> some ChartContent {
        if points.count >= 2 {
            ForEach(points) { s in
                AreaMark(
                    x: .value("t", s.detectedAt),
                    yStart: .value("min", 0),
                    yEnd: .value("sev", Double(s.severity.weight))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [FluxColor.primary.opacity(0.22), FluxColor.primary.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }
        }
        ForEach(points) { s in
            LineMark(
                x: .value("t", s.detectedAt),
                y: .value("sev", Double(s.severity.weight)),
                series: .value("s", "incidentes")
            )
            .foregroundStyle(FluxColor.primary.opacity(0.9))
            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)
        }
    }

    @ChartContentBuilder
    private func signalPoints(for points: [DetectedSignal]) -> some ChartContent {
        ForEach(points) { s in
            PointMark(
                x: .value("t", s.detectedAt),
                y: .value("sev", Double(s.severity.weight))
            )
            .symbolSize(severitySymbolSize(s.severity))
            .foregroundStyle(severityColor(s.severity))
            .annotation(position: .overlay) {
                Circle()
                    .stroke(FluxColor.surface, lineWidth: 1.5)
                    .frame(width: pointDotSize(s.severity), height: pointDotSize(s.severity))
            }
        }
    }

    private var yAxis: AxisMarks<some AxisMark> {
        AxisMarks(position: .leading, values: [1, 2, 3]) { v in
            AxisGridLine().foregroundStyle(FluxColor.line.opacity(0.4))
            AxisValueLabel {
                if let d = v.as(Double.self) {
                    Text(severityYLabel(Int(d)))
                        .font(FluxFont.mono(9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(FluxColor.inkFaint)
                }
            }
        }
    }

    private func severityYLabel(_ w: Int) -> String {
        switch w {
        case 1: "LOW"
        case 2: "MED"
        case 3: "HIGH"
        default: ""
        }
    }

    private var severityLegend: some View {
        HStack(spacing: 14) {
            legendDot(color: FluxColor.safe, label: "low")
            legendDot(color: FluxColor.warn, label: "medium")
            legendDot(color: FluxColor.danger, label: "high")
            Spacer()
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(FluxFont.mono(9, weight: .bold))
                .foregroundStyle(FluxColor.inkMuted)
        }
    }

    // MARK: - Incidents list

    private var incidentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(range == .today ? "EVENTOS DE HOY" : "HISTORIAL DE EVENTOS")
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)
                .padding(.leading, 4)

            if currentSignals.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(currentSignals.enumerated()), id: \.element.id) { idx, signal in
                        signalRow(signal)
                        if idx < currentSignals.count - 1 {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(FluxColor.surface)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
                )
            }
        }
    }

    private func signalRow(_ signal: DetectedSignal) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(severityColor(signal.severity).opacity(0.15))
                    .frame(width: 36, height: 36)
                Circle()
                    .fill(severityColor(signal.severity))
                    .frame(width: 10, height: 10)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if range == .history {
                        Text(signal.detectedAt, format: .dateTime.day().month(.abbreviated))
                            .font(FluxFont.mono(10, weight: .bold))
                            .foregroundStyle(FluxColor.inkMuted)
                        Text("·")
                            .foregroundStyle(FluxColor.inkFaint)
                    }
                    Text(signal.detectedAt, style: .time)
                        .font(FluxFont.mono(11, weight: .bold))
                        .foregroundStyle(FluxColor.ink)
                    Text("·")
                        .foregroundStyle(FluxColor.inkFaint)
                    Text(signal.severity.rawValue.uppercased())
                        .font(FluxFont.mono(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(severityColor(signal.severity))
                }
                Text(signal.title)
                    .font(FluxFont.body(14, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)
                Text(signal.summary)
                    .font(FluxFont.body(12))
                    .foregroundStyle(FluxColor.inkMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20))
                .foregroundStyle(FluxColor.safe)
            VStack(alignment: .leading, spacing: 2) {
                Text("sin incidentes hoy")
                    .font(FluxFont.display(14, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)
                Text("las señales aparecen en tiempo real")
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

    // MARK: - Helpers

    private var bandColor: Color {
        switch alertCenter.currentBand {
        case .safe: FluxColor.safe
        case .moderate: FluxColor.warn
        case .elevated: FluxColor.danger
        }
    }

    private func severityColor(_ s: DetectedSignal.Severity) -> Color {
        switch s {
        case .low: FluxColor.safe
        case .medium: FluxColor.warn
        case .high: FluxColor.danger
        }
    }

    private func severitySymbolSize(_ s: DetectedSignal.Severity) -> CGFloat {
        switch s {
        case .low: 80
        case .medium: 140
        case .high: 210
        }
    }

    private func pointDotSize(_ s: DetectedSignal.Severity) -> CGFloat {
        switch s {
        case .low: 5
        case .medium: 7
        case .high: 9
        }
    }

}

#Preview {
    TrendDetailView()
}
