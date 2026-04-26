import SwiftUI

enum MinigameID: String, CaseIterable, Identifiable {
    case catchFood, memoryMatch, tapReaction, rhythmTap
    var id: String { rawValue }

    var title: String {
        switch self {
        case .catchFood:   "Atrapa la comida"
        case .memoryMatch: "Memorama"
        case .tapReaction: "Reacción"
        case .rhythmTap:   "Rhythm Tap"
        }
    }

    var emoji: String {
        switch self {
        case .catchFood:   "🍖"
        case .memoryMatch: "🃏"
        case .tapReaction: "🎯"
        case .rhythmTap:   "🎵"
        }
    }

    var subtitle: String {
        switch self {
        case .catchFood:   "30s · gana monedas atrapando comida"
        case .memoryMatch: "Encuentra parejas en pocos movs."
        case .tapReaction: "20s · toca al pet más rápido posible"
        case .rhythmTap:   "20 rondas · tap al ritmo del beat"
        }
    }
}

struct MinigamesHubSheet: View {
    let onPick: (MinigameID) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mini-juegos")
                        .font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                        .foregroundStyle(Theme.darkInk)
                    Text("Juega para ganar monedas")
                        .font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(Theme.darkInk.opacity(0.6))
                }
                Spacer()
                CloseButton(action: onClose)
            }
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(MinigameID.allCases) { game in
                        gameCard(game)
                    }
                }
            }
        }
        .padding(20)
        .background(Theme.consoleBG.ignoresSafeArea())
    }

    private func gameCard(_ g: MinigameID) -> some View {
        Button { onPick(g) } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.lcdInner)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.lcdStroke, lineWidth: 2))
                    Text(g.emoji).font(.system(size: 36))
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    Text(g.title)
                        .font(.custom(Theme.pixelMono, size: 16).weight(.bold))
                        .foregroundStyle(Theme.darkInk)
                    Text(g.subtitle)
                        .font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(Theme.darkInk.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.darkInk.opacity(0.4))
            }
            .padding(12)
            .background(Theme.buttonBG)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.buttonStroke.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
