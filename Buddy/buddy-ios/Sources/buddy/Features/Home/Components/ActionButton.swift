import SwiftUI

struct ActionButton: View {
    let label: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Theme.actionPink)
                .overlay(Circle().stroke(Theme.actionPinkDark, lineWidth: 3))
                .overlay(
                    Text(label)
                        .font(.custom(Theme.pixelMono, size: size * 0.42).weight(.bold))
                        .foregroundStyle(.white)
                )
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}
