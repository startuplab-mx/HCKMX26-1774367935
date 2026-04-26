import SwiftUI

struct TopBar: View {
    let coins: Int
    let lives: Int    // displayed as caretaker level
    let onInfo: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            PixelButton(action: {}) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.910, green: 0.722, blue: 0.282))
                        .frame(width: 22, height: 22)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 0.957, green: 0.831, blue: 0.439))
                        .frame(width: 8, height: 14)
                }
            }
            Text("\(coins)")
                .font(.custom(Theme.pixelMono, size: 18).weight(.bold))
                .foregroundStyle(Theme.darkInk)

            Spacer()

            HStack(spacing: 4) {
                Text("Lv")
                    .font(.custom(Theme.pixelMono, size: 12))
                    .foregroundStyle(Theme.darkInk.opacity(0.7))
                Text("\(lives)")
                    .font(.custom(Theme.pixelMono, size: 16).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.buttonBG)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.buttonStroke, lineWidth: 1.5))

            PixelButton(action: onInfo) {
                Text("i")
                    .font(.custom(Theme.pixelMono, size: 20).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
            }
            PixelButton(action: onSettings) {
                Text("⚙")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.darkInk)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
