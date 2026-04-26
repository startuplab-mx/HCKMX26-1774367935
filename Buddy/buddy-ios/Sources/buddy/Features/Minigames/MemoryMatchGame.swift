import SwiftUI

/// Memorama con 3 niveles de dificultad. Cards muestran expresiones reales del pet.
struct MemoryMatchGame: View {
    let petName: String
    let onClose: (Int) -> Void

    enum Difficulty: Int, CaseIterable {
        case easy = 4, medium = 6, hard = 8
        var label: String {
            switch self {
            case .easy: "Fácil (8 cartas)"
            case .medium: "Medio (12 cartas)"
            case .hard: "Difícil (16 cartas)"
            }
        }
        var pairs: Int { self.rawValue }
        var cols: Int { self == .easy ? 4 : (self == .medium ? 4 : 4) }
        var rewardMultiplier: Int { self == .easy ? 1 : (self == .medium ? 2 : 3) }
    }

    @State private var difficulty: Difficulty? = nil
    @State private var cards: [Card] = []
    @State private var flipped: [Int] = []
    @State private var matchedIDs: Set<UUID> = []
    @State private var moves = 0
    @State private var startTime: Date = Date()
    @State private var elapsedTime: TimeInterval = 0
    @State private var won = false
    @State private var timer: Timer?

    private let allSlots: [(row: Int, col: Int, label: String)] = [
        (0, 0, "idle1"), (0, 2, "idle2"), (1, 0, "walk1"), (1, 2, "walk2"),
        (2, 0, "eat1"), (2, 2, "eat2"), (3, 0, "sleep1"), (3, 2, "sleep2")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let _ = difficulty {
                gameBody
            } else {
                difficultyPicker
            }
        }
        .background(Theme.consoleBG)
    }

    private var header: some View {
        HStack {
            Button { onClose(0) } label: {
                Image(systemName: "xmark").foregroundStyle(Theme.darkInk)
                    .frame(width: 32, height: 32).background(Theme.buttonBG).clipShape(Circle())
            }.buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text("Caras de \(petName)").font(.custom(Theme.pixelMono, size: 14).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
                if difficulty != nil {
                    HStack(spacing: 16) {
                        Label("\(moves)", systemImage: "hand.tap")
                        Label("\(Int(elapsedTime))s", systemImage: "timer")
                        Label("\(matchedIDs.count/2)/\(difficulty?.pairs ?? 0)", systemImage: "checkmark.seal")
                    }
                    .font(.custom(Theme.pixelMono, size: 11))
                    .foregroundStyle(Theme.darkInk.opacity(0.7))
                }
            }
            Spacer()
            Spacer().frame(width: 32)
        }.padding()
    }

    private var difficultyPicker: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Elige dificultad")
                .font(.custom(Theme.pixelMono, size: 18).weight(.bold))
                .foregroundStyle(Theme.darkInk)
            ForEach(Difficulty.allCases, id: \.rawValue) { d in
                Button { startGame(d) } label: {
                    HStack {
                        Text(d.label)
                        Spacer()
                        Text("×\(d.rewardMultiplier) 🪙")
                    }
                    .font(.custom(Theme.pixelMono, size: 14).weight(.bold))
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(Theme.actionPink))
                }.buttonStyle(.plain).padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    private var gameBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: difficulty?.cols ?? 4), spacing: 8) {
                    ForEach(cards.indices, id: \.self) { i in cardView(i) }
                }
                .padding()
            }
            if won { winView }
        }
    }

    private var winView: some View {
        VStack(spacing: 8) {
            Text("¡Perfecto!").font(.custom(Theme.pixelMono, size: 18).weight(.bold))
            let baseReward = max(10, 100 - moves * 2 - Int(elapsedTime))
            let reward = baseReward * (difficulty?.rewardMultiplier ?? 1)
            Text("\(reward)🪙").font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                .foregroundStyle(Theme.actionPink)
            Button { onClose(reward) } label: {
                Text("Cobrar")
                    .font(.custom(Theme.pixelMono, size: 14).weight(.bold))
                    .foregroundStyle(.white).padding(.horizontal, 32).padding(.vertical, 12)
                    .background(Capsule().fill(Theme.actionPink))
            }.buttonStyle(.plain)
        }.padding(20)
    }

    private func cardView(_ i: Int) -> some View {
        let card = cards[i]
        let show = flipped.contains(i) || matchedIDs.contains(card.id)
        return Button { tap(i) } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(show ? Theme.lcdInner : Theme.actionPink)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.lcdStroke, lineWidth: 2))
                if show {
                    PetSpriteFrameView(row: card.row, col: card.col, size: 48)
                } else {
                    Text("?").font(.custom(Theme.pixelMono, size: 22).weight(.bold)).foregroundStyle(.white)
                }
            }
            .frame(height: 70)
            .opacity(matchedIDs.contains(card.id) ? 0.4 : 1)
            .rotation3DEffect(.degrees(show ? 0 : 180), axis: (0, 1, 0))
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: show)
        }
        .buttonStyle(.plain).disabled(show || flipped.count >= 2)
    }

    private func startGame(_ d: Difficulty) {
        difficulty = d
        let count = d.pairs
        // Pick `count` slots, repeat each twice, shuffle
        let chosen = Array(allSlots.shuffled().prefix(count))
        let pairs = (chosen + chosen).shuffled()
        cards = pairs.map { Card(row: $0.row, col: $0.col, label: $0.label) }
        flipped = []; matchedIDs = []; moves = 0; won = false
        startTime = Date(); elapsedTime = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if !won { elapsedTime = Date().timeIntervalSince(startTime) }
        }
    }

    private func tap(_ i: Int) {
        SoundService.shared.playClick()
        flipped.append(i)
        if flipped.count == 2 {
            moves += 1
            let a = cards[flipped[0]]; let b = cards[flipped[1]]
            if a.label == b.label {
                matchedIDs.insert(a.id); matchedIDs.insert(b.id)
                flipped = []
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if matchedIDs.count == cards.count {
                    won = true
                    timer?.invalidate()
                    SoundService.shared.playReward()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { flipped = [] }
            }
        }
    }

    struct Card: Identifiable {
        let id = UUID()
        let row: Int
        let col: Int
        let label: String
    }
}
