import SwiftUI

/// El pet bobea al beat. Tap al pet justo cuando el aro se cierra.
/// Mejoras: feedback PERFECT/GOOD/MISS visible, accuracy %, combos visibles, bpm aumenta.
struct RhythmTapGame: View {
    let petName: String
    let onClose: (Int) -> Void

    @State private var beatTime: Date = Date()
    @State private var nextBeatIn: TimeInterval = 0.6
    @State private var score = 0
    @State private var combo = 0
    @State private var maxCombo = 0
    @State private var perfects = 0
    @State private var goods = 0
    @State private var misses = 0
    @State private var rounds = 0
    @State private var gameOver = false
    @State private var lastFeedback: String = ""
    @State private var lastFeedbackColor: Color = .white
    @State private var bpm: Double = 100

    private let totalRounds = 25

    private var accuracy: Int {
        let total = perfects + goods + misses
        guard total > 0 else { return 0 }
        return (perfects * 100 + goods * 50) / total
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            ZStack {
                TimelineView(.animation) { ctx in
                    let elapsed = ctx.date.timeIntervalSince(beatTime)
                    let progress = min(1.0, elapsed / nextBeatIn)
                    let isPerfect = progress > 0.85 && progress < 1.0
                    Circle()
                        .stroke(isPerfect ? Color.yellow : Theme.actionPink.opacity(0.6), lineWidth: isPerfect ? 6 : 4)
                        .frame(width: 220 - progress * 120, height: 220 - progress * 120)
                }
                Circle().stroke(Theme.lcdStroke, lineWidth: 3).frame(width: 100, height: 100)
                TimelineView(.animation) { ctx in
                    let elapsed = ctx.date.timeIntervalSince(beatTime)
                    let bob = sin(elapsed / nextBeatIn * .pi * 2) * 6
                    AnimatedPet(action: combo >= 5 ? .play : .idle, size: 80, interval: 0.3)
                        .offset(y: bob)
                        .scaleEffect(combo >= 10 ? 1.15 : 1.0)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { tap() }
            HStack(spacing: 16) {
                if !lastFeedback.isEmpty {
                    Text(lastFeedback)
                        .font(.custom(Theme.pixelMono, size: 18).weight(.bold))
                        .foregroundStyle(lastFeedbackColor)
                        .transition(.scale.combined(with: .opacity))
                }
                if combo >= 3 {
                    Text("🔥 \(combo)")
                        .font(.custom(Theme.pixelMono, size: 16).weight(.bold))
                        .foregroundStyle(.orange)
                }
            }
            .frame(height: 30)
            Spacer()
            // Hit accuracy bar
            VStack(spacing: 4) {
                HStack {
                    Text("Accuracy").font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(Theme.darkInk.opacity(0.6))
                    Spacer()
                    Text("\(accuracy)%").font(.custom(Theme.pixelMono, size: 12).weight(.bold))
                        .foregroundStyle(accuracy >= 80 ? .green : (accuracy >= 50 ? .orange : .red))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.darkInk.opacity(0.1))
                        Capsule().fill(LinearGradient(colors: [.red, .orange, .green], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(4, geo.size.width * CGFloat(accuracy) / 100))
                    }
                }.frame(height: 6)
            }.padding(.horizontal, 28)
            Text("Tap al pet cuando el aro toque al pet")
                .font(.custom(Theme.pixelMono, size: 11)).foregroundStyle(Theme.darkInk.opacity(0.6))
            Spacer().frame(height: 30)
            if gameOver { gameOverView }
        }
        .background(Theme.consoleBG)
        .onAppear { startRound() }
    }

    private var header: some View {
        HStack {
            Button { onClose(0) } label: {
                Image(systemName: "xmark").foregroundStyle(Theme.darkInk)
                    .frame(width: 32, height: 32).background(Theme.buttonBG).clipShape(Circle())
            }.buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text("\(petName) baila").font(.custom(Theme.pixelMono, size: 14).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
                HStack(spacing: 12) {
                    Label("\(score)", systemImage: "music.note")
                    Label("\(Int(bpm)) BPM", systemImage: "metronome")
                    Label("\(rounds)/\(totalRounds)", systemImage: "circle.grid.cross")
                }.font(.custom(Theme.pixelMono, size: 11)).foregroundStyle(Theme.darkInk.opacity(0.7))
            }
            Spacer()
            Spacer().frame(width: 32)
        }.padding()
    }

    private var gameOverView: some View {
        VStack(spacing: 6) {
            Text("¡Final!").font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                .foregroundStyle(Theme.darkInk)
            HStack(spacing: 12) {
                Text("⭐ \(perfects)").foregroundStyle(.yellow)
                Text("👍 \(goods)").foregroundStyle(.blue)
                Text("✗ \(misses)").foregroundStyle(.red)
            }.font(.custom(Theme.pixelMono, size: 12))
            Text("Accuracy: \(accuracy)%").font(.custom(Theme.pixelMono, size: 14).weight(.bold))
                .foregroundStyle(Theme.darkInk)
            let reward = score + maxCombo * 2 + (accuracy >= 80 ? 30 : 0)
            Text("\(reward)🪙").font(.custom(Theme.pixelMono, size: 18).weight(.bold))
                .foregroundStyle(Theme.actionPink)
            Button { onClose(reward) } label: {
                Text("Cobrar").font(.custom(Theme.pixelMono, size: 14).weight(.bold))
                    .foregroundStyle(.white).padding(.horizontal, 32).padding(.vertical, 12)
                    .background(Capsule().fill(Theme.actionPink))
            }.buttonStyle(.plain)
        }
        .padding(20).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 24)
    }

    private func startRound() {
        guard rounds < totalRounds else { gameOver = true; SoundService.shared.playReward(); return }
        beatTime = Date()
        // BPM ramps up over the rounds
        bpm = 100 + Double(rounds) * 3
        nextBeatIn = 60.0 / bpm
        DispatchQueue.main.asyncAfter(deadline: .now() + nextBeatIn * 1.5) {
            if rounds < totalRounds, !gameOver {
                combo = 0; misses += 1
                showFeedback("MISS", color: .red)
                rounds += 1; startRound()
            }
        }
    }

    private func tap() {
        guard !gameOver else { return }
        let elapsed = Date().timeIntervalSince(beatTime)
        let diff = abs(elapsed - nextBeatIn)
        if diff < 0.1 {
            score += 5; combo += 1; perfects += 1
            showFeedback("⭐ PERFECT", color: .yellow)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else if diff < 0.25 {
            score += 3; combo += 1; goods += 1
            showFeedback("👍 GOOD", color: .blue)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            combo = 0; misses += 1
            showFeedback("OFF", color: .gray)
        }
        maxCombo = max(maxCombo, combo)
        SoundService.shared.play(for: combo > 0 ? .play : .sad)
        rounds += 1
        if rounds < totalRounds { startRound() } else { gameOver = true; SoundService.shared.playReward() }
    }

    private func showFeedback(_ text: String, color: Color) {
        withAnimation(.spring(response: 0.3)) {
            lastFeedback = text
            lastFeedbackColor = color
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { if lastFeedback == text { lastFeedback = "" } }
        }
    }
}
