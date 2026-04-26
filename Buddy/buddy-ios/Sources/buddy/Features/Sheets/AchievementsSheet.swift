import SwiftUI

struct AchievementsSheet: View {
    let onClose: () -> Void
    @State private var unlocked: Set<Achievement> = AchievementStore.unlocked()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Logros").font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                        .foregroundStyle(Theme.darkInk)
                    Text("\(unlocked.count) / \(Achievement.allCases.count) desbloqueados")
                        .font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(Theme.darkInk.opacity(0.6))
                }
                Spacer()
                CloseButton(action: onClose)
            }
            ProgressView(value: Double(unlocked.count), total: Double(Achievement.allCases.count))
                .tint(Theme.actionPink)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(Achievement.allCases) { a in
                        cell(a)
                    }
                }
            }
        }
        .padding(20)
        .background(Theme.consoleBG.ignoresSafeArea())
    }

    private func cell(_ a: Achievement) -> some View {
        let isOn = unlocked.contains(a)
        return VStack(spacing: 6) {
            Text(a.emoji).font(.system(size: 28)).opacity(isOn ? 1 : 0.3)
            Text(a.title)
                .font(.custom(Theme.pixelMono, size: 11).weight(.bold))
                .foregroundStyle(isOn ? Theme.darkInk : Theme.darkInk.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
            Text("\(a.reward)🪙")
                .font(.custom(Theme.pixelMono, size: 9))
                .foregroundStyle(isOn ? Theme.actionPink : Theme.darkInk.opacity(0.4))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Theme.buttonBG)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isOn ? Theme.actionPink : .clear, lineWidth: 2)
        )
    }
}
