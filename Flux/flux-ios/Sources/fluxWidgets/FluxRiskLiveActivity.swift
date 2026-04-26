import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity · Dynamic Island + Lock Screen
// Visible mientras flux está monitoreando activamente al menor.

struct FluxRiskLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FluxRiskActivityAttributes.self) { context in
            // MARK: - Lock screen / banner
            LockScreenView(state: context.state, attrs: context.attributes)
                .activityBackgroundTint(bgTint(for: context.state.band))
                .activitySystemActionForegroundColor(.primary)
                .widgetURL(URL(string: "flux://stop-activity"))

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeading(state: context.state, attrs: context.attributes)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailing(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(state: context.state)
                }

            } compactLeading: {
                CompactLeading(state: context.state)
            } compactTrailing: {
                CompactTrailing(state: context.state)
            } minimal: {
                MinimalView(state: context.state)
            }
            .widgetURL(URL(string: "flux://stop-activity"))
            .keylineTint(bandColor(for: context.state.band))
        }
    }

    // MARK: - Helpers

    private func bgTint(for band: FluxRiskActivityAttributes.ContentState.Band) -> Color {
        switch band {
        case .safe:     Color(red: 0.04, green: 0.59, blue: 0.41).opacity(0.08)
        case .moderate: Color(red: 0.85, green: 0.47, blue: 0.02).opacity(0.08)
        case .elevated: Color(red: 0.86, green: 0.15, blue: 0.15).opacity(0.1)
        }
    }

    private func bandColor(for band: FluxRiskActivityAttributes.ContentState.Band) -> Color {
        switch band {
        case .safe:     Color(red: 0.04, green: 0.59, blue: 0.41)
        case .moderate: Color(red: 0.85, green: 0.47, blue: 0.02)
        case .elevated: Color(red: 0.86, green: 0.15, blue: 0.15)
        }
    }
}

// MARK: - Lock screen view

private struct LockScreenView: View {
    let state: FluxRiskActivityAttributes.ContentState
    let attrs: FluxRiskActivityAttributes

    var body: some View {
        HStack(spacing: 14) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(bandColor.opacity(0.15), lineWidth: 5)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: CGFloat(state.riskScore) / 100)
                    .stroke(bandColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text("\(state.riskScore)")
                    .font(.custom("Geist-Bold", size: 20))
                    .foregroundStyle(bandColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("FLUX")
                        .font(.custom("GeistMono-Bold", size: 9))
                        .tracking(2.5)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(attrs.childName.uppercased())
                        .font(.custom("GeistMono-Bold", size: 9))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                }

                Text(headline)
                    .font(.custom("Geist-Bold", size: 15))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let signal = state.lastSignalTitle {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(bandColor)
                            .frame(width: 5, height: 5)
                        Text(signal)
                            .font(.custom("Inter-Medium", size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            // Trend
            VStack(alignment: .trailing, spacing: 2) {
                Text(state.trendDirection.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(bandColor)
                Text("7D")
                    .font(.custom("GeistMono-Bold", size: 8))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var bandColor: Color {
        switch state.band {
        case .safe:     Color(red: 0.04, green: 0.59, blue: 0.41)
        case .moderate: Color(red: 0.85, green: 0.47, blue: 0.02)
        case .elevated: Color(red: 0.86, green: 0.15, blue: 0.15)
        }
    }

    private var headline: String {
        switch state.band {
        case .safe:     "todo tranquilo"
        case .moderate: "\(state.activeSignalCount) señales · atención"
        case .elevated: "\(state.activeSignalCount) señales activas"
        }
    }
}

// MARK: - Dynamic Island compact

private struct CompactLeading: View {
    let state: FluxRiskActivityAttributes.ContentState

    var body: some View {
        ZStack {
            Circle()
                .stroke(bandColor.opacity(0.2), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: CGFloat(state.riskScore) / 100)
                .stroke(bandColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(state.riskScore)")
                .font(.custom("Geist-Bold", size: 10))
                .foregroundStyle(bandColor)
        }
        .frame(width: 22, height: 22)
        .padding(.leading, 4)
    }

    private var bandColor: Color {
        switch state.band {
        case .safe:     Color(red: 0.04, green: 0.59, blue: 0.41)
        case .moderate: Color(red: 0.85, green: 0.47, blue: 0.02)
        case .elevated: Color(red: 0.86, green: 0.15, blue: 0.15)
        }
    }
}

private struct CompactTrailing: View {
    let state: FluxRiskActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(bandColor)
                .frame(width: 5, height: 5)
            Text("\(state.activeSignalCount)")
                .font(.custom("Geist-Bold", size: 13))
                .foregroundStyle(.primary)
        }
        .padding(.trailing, 6)
    }

    private var bandColor: Color {
        switch state.band {
        case .safe:     Color(red: 0.04, green: 0.59, blue: 0.41)
        case .moderate: Color(red: 0.85, green: 0.47, blue: 0.02)
        case .elevated: Color(red: 0.86, green: 0.15, blue: 0.15)
        }
    }
}

private struct MinimalView: View {
    let state: FluxRiskActivityAttributes.ContentState

    var body: some View {
        ZStack {
            Circle().fill(bandColor.opacity(0.22))
            Circle().fill(bandColor).frame(width: 8, height: 8)
        }
    }

    private var bandColor: Color {
        switch state.band {
        case .safe:     Color(red: 0.04, green: 0.59, blue: 0.41)
        case .moderate: Color(red: 0.85, green: 0.47, blue: 0.02)
        case .elevated: Color(red: 0.86, green: 0.15, blue: 0.15)
        }
    }
}

// MARK: - Dynamic Island expanded regions

private struct ExpandedLeading: View {
    let state: FluxRiskActivityAttributes.ContentState
    let attrs: FluxRiskActivityAttributes

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(bandColor.opacity(0.2), lineWidth: 4)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: CGFloat(state.riskScore) / 100)
                    .stroke(bandColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Text("\(state.riskScore)")
                    .font(.custom("Geist-Bold", size: 15))
                    .foregroundStyle(bandColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("FLUX")
                    .font(.custom("GeistMono-Bold", size: 9))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Text(attrs.childName)
                    .font(.custom("Geist-SemiBold", size: 13))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var bandColor: Color {
        switch state.band {
        case .safe:     Color(red: 0.04, green: 0.59, blue: 0.41)
        case .moderate: Color(red: 0.85, green: 0.47, blue: 0.02)
        case .elevated: Color(red: 0.86, green: 0.15, blue: 0.15)
        }
    }
}

private struct ExpandedTrailing: View {
    let state: FluxRiskActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 3) {
                Text(state.trendDirection.symbol)
                    .font(.system(size: 16, weight: .bold))
                Text("7D")
                    .font(.custom("GeistMono-Bold", size: 9))
                    .tracking(1.5)
            }
            .foregroundStyle(bandColor)
            Text("\(state.activeSignalCount) señales")
                .font(.custom("Inter-Medium", size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var bandColor: Color {
        switch state.band {
        case .safe:     Color(red: 0.04, green: 0.59, blue: 0.41)
        case .moderate: Color(red: 0.85, green: 0.47, blue: 0.02)
        case .elevated: Color(red: 0.86, green: 0.15, blue: 0.15)
        }
    }
}

private struct ExpandedBottom: View {
    let state: FluxRiskActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let signal = state.lastSignalTitle {
                HStack(spacing: 6) {
                    Circle()
                        .fill(bandColor)
                        .frame(width: 5, height: 5)
                    Text(signal)
                        .font(.custom("Geist-SemiBold", size: 13))
                        .foregroundStyle(.primary)
                    Spacer()
                    if let time = state.lastSignalTime {
                        Text(time, style: .relative)
                            .font(.custom("GeistMono-Regular", size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "cpu")
                    .font(.system(size: 9, weight: .semibold))
                Text(state.weProtectBadge.uppercased())
                    .font(.custom("GeistMono-Bold", size: 9))
                    .tracking(1.5)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var bandColor: Color {
        switch state.band {
        case .safe:     Color(red: 0.04, green: 0.59, blue: 0.41)
        case .moderate: Color(red: 0.85, green: 0.47, blue: 0.02)
        case .elevated: Color(red: 0.86, green: 0.15, blue: 0.15)
        }
    }
}
