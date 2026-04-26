import SwiftUI

struct LCDCard: View {
    let pet: Pet

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.lcdOuter)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.lcdStroke.opacity(0.4), lineWidth: 2)
                )

            HStack(spacing: 12) {
                avatar
                Rectangle()
                    .fill(Theme.lcdStroke)
                    .frame(width: 2)
                stats
            }
            .padding(16)
        }
        .frame(height: 170)
        .padding(.horizontal, 20)
    }

    private var avatar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.lcdStroke, lineWidth: 2)
                    )
                Text("🐱")
                    .font(.system(size: 36))
            }
            .frame(width: 80, height: 70)
            HStack(spacing: 4) {
                Text(pet.name)
                    .font(.custom(Theme.pixelMono, size: 18).weight(.bold))
                    .foregroundStyle(Theme.lcdInk)
                Text("✏")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.lcdInk)
            }
        }
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 12) {
            row(label: "Age", value: "\(pet.ageInDays) Days")
            row(label: "Mood", value: hearts(filled: pet.moodLevel, total: 3))
            row(label: "Satiety", value: dots(filled: pet.satietyLevel, total: 2))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom(Theme.pixelMono, size: 16))
                .foregroundStyle(Theme.lcdInk)
            Spacer()
            Text(value)
                .font(.custom(Theme.pixelMono, size: 16))
                .foregroundStyle(label == "Mood" ? Color(red: 0.878, green: 0.282, blue: 0.471) : Theme.lcdInk)
        }
    }

    private func hearts(filled: Int, total: Int) -> String {
        (0..<total).map { $0 < filled ? "♥" : "♡" }.joined(separator: " ")
    }

    private func dots(filled: Int, total: Int) -> String {
        (0..<total).map { $0 < filled ? "●" : "○" }.joined(separator: " ")
    }
}
