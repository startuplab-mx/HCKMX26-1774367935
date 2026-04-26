import SwiftUI

/// El pet aparece en posiciones random. Tócalo rápido. 30 segundos.
/// Mejoras: combos x2/x3/x5, velocidad aumenta con cada hit, modo speed final 5s.
struct TapReactionGame: View {
    let petName: String
    let onClose: (Int) -> Void

    @State private var target: Target?
    @State private var score = 0
    @State private var combo = 0
    @State private var maxCombo = 0
    @State private var timeLeft = 30
    @State private var gameOver = false
    @State private var spawnTimer: Timer?
    @State private var countdownTimer: Timer?
    @State private var feedback: String = ""
    @State private var bossMode = false

    private var multiplier: Int {
        switch combo {
        case 0..<3: 1
        case 3..<6: 2
        case 6..<10: 3
        default: 5
        }
    }

    private var spawnInterval: Double {
        let base = bossMode ? 0.4 : 1.5
        return max(0.3, base - Double(combo) * 0.05)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            GeometryReader { geo in
                ZStack {
                    (bossMode ? Color(red: 1, green: 0.85, blue: 0.85) : Theme.lcdInner).ignoresSafeArea()
                    if let t = target {
                        Button { hit() } label: {
                            AnimatedPet(action: .play, size: 64, interval: 0.15)
                                .scaleEffect(t.scale)
                                .shadow(color: combo >= 6 ? .orange : .clear, radius: combo >= 6 ? 12 : 0)
                        }
                        .position(x: t.x * geo.size.width, y: t.y * geo.size.height)
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                    if !feedback.isEmpty {
                        Text(feedback)
                            .font(.custom(Theme.pixelMono, size: 32).weight(.bold))
                            .foregroundStyle(Theme.actionPink)
                            .shadow(color: .white, radius: 3)
                            .position(x: geo.size.width / 2, y: 80)
                            .transition(.scale.combined(with: .opacity))
                    }
                    if gameOver { gameOverView }
                }
                .onAppear { start() }
                .onDisappear { stop() }
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
                Text(bossMode ? "⚡ BOSS MODE" : "Atrapa a \(petName)")
                    .font(.custom(Theme.pixelMono, size: 14).weight(.bold))
                    .foregroundStyle(bossMode ? .red : Theme.darkInk)
                HStack(spacing: 12) {
                    Label("\(score)", systemImage: "target")
                    if multiplier > 1 {
                        Text("x\(multiplier)").font(.custom(Theme.pixelMono, size: 12).weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    Label("\(timeLeft)s", systemImage: "timer")
                }.font(.custom(Theme.pixelMono, size: 11)).foregroundStyle(Theme.darkInk.opacity(0.7))
                if combo >= 3 {
                    Text("🔥 \(combo) combo")
                        .font(.custom(Theme.pixelMono, size: 11).weight(.bold))
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Spacer().frame(width: 32)
        }.padding()
    }

    private var gameOverView: some View {
        VStack(spacing: 12) {
            Text("¡Tiempo!").font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                .foregroundStyle(Theme.darkInk)
            Text("\(score) puntos · combo máx \(maxCombo)")
                .font(.custom(Theme.pixelMono, size: 12))
                .foregroundStyle(Theme.darkInk.opacity(0.7))
            let reward = score + maxCombo * 5
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

    private func start() {
        score = 0; combo = 0; maxCombo = 0; timeLeft = 30; gameOver = false; bossMode = false
        spawn()
        scheduleSpawnTimer()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeLeft -= 1
            // Boss mode in last 5 seconds
            if timeLeft == 5 && !bossMode {
                bossMode = true
                showFeedback("⚡ BOSS!")
                scheduleSpawnTimer()
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
            if timeLeft <= 0 { endGame() }
        }
    }

    private func scheduleSpawnTimer() {
        spawnTimer?.invalidate()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { _ in
            if target != nil {
                combo = 0  // missed
            }
            spawn()
        }
    }

    private func stop() { spawnTimer?.invalidate(); countdownTimer?.invalidate() }

    private func spawn() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            target = Target(
                x: CGFloat.random(in: 0.15...0.85),
                y: CGFloat.random(in: 0.2...0.8),
                scale: bossMode ? 0.7 : CGFloat.random(in: 0.85...1.2)
            )
        }
    }

    private func hit() {
        let points = 1 * multiplier
        score += points
        combo += 1
        maxCombo = max(maxCombo, combo)
        UIImpactFeedbackGenerator(style: combo >= 5 ? .heavy : .medium).impactOccurred()
        SoundService.shared.play(for: .play)
        if combo % 5 == 0 && combo > 0 {
            showFeedback("🔥 \(combo) COMBO!")
            scheduleSpawnTimer()  // re-schedule with new (faster) interval
        } else if multiplier > 1 {
            showFeedback("+\(points)")
        }
        spawn()
    }

    private func showFeedback(_ text: String) {
        withAnimation(.spring(response: 0.3)) { feedback = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { if feedback == text { feedback = "" } }
        }
    }

    private func endGame() { stop(); gameOver = true; SoundService.shared.playReward() }

    struct Target { let x: CGFloat; let y: CGFloat; let scale: CGFloat }
}
