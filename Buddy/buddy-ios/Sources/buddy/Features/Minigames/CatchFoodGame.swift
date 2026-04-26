import SwiftUI

/// El pet real está abajo. Drag horizontal lo mueve. La comida cae desde arriba.
/// Mejoras: dificultad progresiva, power-ups dorados (5x score), combo multiplier,
/// rachas que aumentan la velocidad, evitar trampas para mantener combo.
struct CatchFoodGame: View {
    let petName: String
    let onClose: (Int) -> Void

    @State private var items: [FallingItem] = []
    @State private var petX: CGFloat = 0.5
    @State private var score = 0
    @State private var combo = 0
    @State private var maxCombo = 0
    @State private var timeLeft = 30
    @State private var gameOver = false
    @State private var spawnTimer: Timer?
    @State private var countdownTimer: Timer?
    @State private var animTimer: Timer?
    @State private var lastEatTick: Date = .distantPast
    @State private var feedback: String = ""
    @State private var difficultyLevel: Int = 1

    private let foodEmojis = ["🍖", "🍗", "🍪", "🥩", "🐟", "🥛", "🥕", "🍣"]
    private let trapEmojis = ["💣", "☠️", "🌶️"]
    private let petWidth: CGFloat = 0.18

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            GeometryReader { geo in
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 1, green: 0.95, blue: 0.85), Color(red: 1, green: 0.88, blue: 0.74)],
                        startPoint: .top, endPoint: .bottom
                    ).ignoresSafeArea()
                    Rectangle()
                        .fill(Color(red: 0.73, green: 0.54, blue: 0.37))
                        .frame(height: 60)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    ForEach(items) { item in
                        Text(item.emoji)
                            .font(.system(size: item.golden ? 48 : 36))
                            .shadow(color: item.golden ? .yellow : .clear, radius: item.golden ? 8 : 0)
                            .position(x: item.x * geo.size.width, y: item.y * geo.size.height)
                    }
                    AnimatedPet(action: petAction, size: 64, interval: 0.25)
                        .scaleEffect(combo >= 5 ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3), value: combo >= 5)
                        .position(x: petX * geo.size.width, y: geo.size.height - 60)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    let newX = v.location.x / geo.size.width
                                    petX = min(0.95, max(0.05, newX))
                                }
                        )
                    if !feedback.isEmpty {
                        Text(feedback)
                            .font(.custom(Theme.pixelMono, size: 28).weight(.bold))
                            .foregroundStyle(combo > 0 ? Theme.actionPink : .red)
                            .shadow(color: .white, radius: 2)
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.4)
                            .transition(.scale.combined(with: .opacity))
                    }
                    if gameOver { gameOverView }
                }
                .onAppear { start(in: geo.size) }
                .onDisappear { stop() }
            }
        }
        .background(Theme.consoleBG)
    }

    private var petAction: PetAction {
        Date().timeIntervalSince(lastEatTick) < 0.4 ? .eat : .idle
    }

    private var header: some View {
        HStack {
            Button { onClose(0) } label: {
                Image(systemName: "xmark").foregroundStyle(Theme.darkInk)
                    .frame(width: 32, height: 32).background(Theme.buttonBG).clipShape(Circle())
            }.buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text("\(petName) tiene hambre")
                    .font(.custom(Theme.pixelMono, size: 13).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
                HStack(spacing: 12) {
                    Label("\(score)", systemImage: "fork.knife")
                    Label("Lv\(difficultyLevel)", systemImage: "bolt.fill")
                    Label("\(timeLeft)s", systemImage: "timer")
                }.font(.custom(Theme.pixelMono, size: 11)).foregroundStyle(Theme.darkInk.opacity(0.7))
                if combo >= 3 {
                    Text("🔥 COMBO x\(combo)")
                        .font(.custom(Theme.pixelMono, size: 12).weight(.bold))
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Spacer().frame(width: 32)
        }
        .padding()
        .background(Theme.consoleBG)
    }

    private var gameOverView: some View {
        VStack(spacing: 12) {
            Text("¡Terminó!").font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                .foregroundStyle(Theme.darkInk)
            Text("\(score) puntos").font(.custom(Theme.pixelMono, size: 16))
                .foregroundStyle(Theme.darkInk.opacity(0.7))
            Text("Combo máx: \(maxCombo)").font(.custom(Theme.pixelMono, size: 12))
                .foregroundStyle(.orange)
            let reward = score * 2 + maxCombo * 3
            Text("→ \(reward)🪙").font(.custom(Theme.pixelMono, size: 18).weight(.bold))
                .foregroundStyle(Theme.actionPink)
            Button { onClose(reward) } label: {
                Text("Cobrar").font(.custom(Theme.pixelMono, size: 14).weight(.bold))
                    .foregroundStyle(.white).padding(.horizontal, 32).padding(.vertical, 12)
                    .background(Capsule().fill(Theme.actionPink))
            }.buttonStyle(.plain)
        }
        .padding(28).background(.white).clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
    }

    // MARK: - Game

    private func start(in size: CGSize) {
        score = 0; combo = 0; maxCombo = 0; timeLeft = 30; gameOver = false; items = []; petX = 0.5
        difficultyLevel = 1
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in spawn() }
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeLeft -= 1
            // Increase difficulty every 10 seconds
            if timeLeft == 20 || timeLeft == 10 {
                difficultyLevel += 1
                spawnTimer?.invalidate()
                let interval = max(0.25, 0.7 - Double(difficultyLevel) * 0.15)
                spawnTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in spawn() }
                showFeedback("¡Nivel \(difficultyLevel)!")
            }
            if timeLeft <= 0 { endGame() }
        }
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in tick(in: size) }
    }

    private func stop() { spawnTimer?.invalidate(); countdownTimer?.invalidate(); animTimer?.invalidate() }

    private func spawn() {
        let isTrap = Int.random(in: 0..<10) < (1 + difficultyLevel / 2)
        let isGolden = !isTrap && Int.random(in: 0..<20) == 0
        let pool = isTrap ? trapEmojis : foodEmojis
        items.append(FallingItem(
            emoji: isGolden ? "⭐" : pool.randomElement()!,
            x: CGFloat.random(in: 0.1...0.9),
            y: -0.05,
            isTrap: isTrap,
            golden: isGolden
        ))
    }

    private func tick(in size: CGSize) {
        guard !gameOver else { return }
        let speed: CGFloat = 0.012 + CGFloat(difficultyLevel) * 0.003
        var caught: [UUID] = []
        var landed: [UUID] = []
        for i in items.indices {
            items[i].y += speed
            let petY: CGFloat = (size.height - 60) / size.height
            if items[i].y >= petY - 0.05 && items[i].y < petY + 0.05 &&
                abs(items[i].x - petX) < petWidth {
                caught.append(items[i].id)
                if items[i].isTrap {
                    score = max(0, score - 2)
                    combo = 0
                    showFeedback("💥 -2")
                    SoundService.shared.play(for: .sad)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                } else if items[i].golden {
                    score += 10
                    combo += 1
                    maxCombo = max(maxCombo, combo)
                    lastEatTick = Date()
                    showFeedback("⭐ +10!")
                    SoundService.shared.playReward()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    let bonus = max(1, combo / 3)
                    score += 1 + bonus
                    combo += 1
                    maxCombo = max(maxCombo, combo)
                    lastEatTick = Date()
                    if combo >= 5 { showFeedback("¡\(combo) combo!") }
                    SoundService.shared.play(for: .eat)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else if items[i].y > 1.05 {
                landed.append(items[i].id)
                if !items[i].isTrap {
                    combo = 0  // missed food breaks combo
                }
            }
        }
        items.removeAll { caught.contains($0.id) || landed.contains($0.id) }
    }

    private func showFeedback(_ text: String) {
        withAnimation(.spring(response: 0.3)) { feedback = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { if feedback == text { feedback = "" } }
        }
    }

    private func endGame() { stop(); gameOver = true; SoundService.shared.playReward() }

    struct FallingItem: Identifiable {
        let id = UUID()
        let emoji: String
        var x: CGFloat
        var y: CGFloat
        let isTrap: Bool
        let golden: Bool
    }
}
