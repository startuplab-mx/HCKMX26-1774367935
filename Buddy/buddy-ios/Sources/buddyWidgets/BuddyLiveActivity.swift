import ActivityKit
import SwiftUI
import WidgetKit

struct BuddyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BuddyActivityAttributes.self) { context in
            // MARK: - Lock Screen / Notification banner
            LockScreenView(state: context.state)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .activityBackgroundTint(Color(red: 0.937, green: 0.902, blue: 0.839))
                .activitySystemActionForegroundColor(.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // EXPANDED
                DynamicIslandExpandedRegion(.leading) {
                    AnimatedPetSprite(action: context.state.action, size: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(context.state.petName)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: i < context.state.moodLevel ? "heart.fill" : "heart")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.pink)
                                    .symbolEffect(.bounce, options: .repeating, value: context.state.moodLevel)
                            }
                        }
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: actionIcon(context.state.action))
                            .symbolEffect(.pulse, options: .repeating)
                            .foregroundStyle(.orange)
                        Text("\(context.state.petName) está \(context.state.action.label)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                AnimatedPetSprite(action: context.state.action, size: 22)
            } compactTrailing: {
                HStack(spacing: 1) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.pink)
                    Text("\(context.state.moodLevel)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            } minimal: {
                AnimatedPetSprite(action: context.state.action, size: 18)
            }
            .keylineTint(.orange)
        }
    }

    private func actionIcon(_ action: PetAction) -> String {
        switch action {
        case .idle:  "sparkles"
        case .eat:   "fork.knife"
        case .sleep: "moon.zzz.fill"
        case .play:  "gamecontroller.fill"
        case .sad:   "cloud.rain.fill"
        }
    }
}

private struct LockScreenView: View {
    let state: BuddyActivityAttributes.State

    var body: some View {
        HStack(spacing: 12) {
            AnimatedPetSprite(action: state.action, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(state.petName)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                Text("está \(state.action.label)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < state.moodLevel ? "heart.fill" : "heart")
                            .font(.system(size: 11))
                            .foregroundStyle(.pink)
                    }
                }
            }
            Spacer()
        }
    }
}
