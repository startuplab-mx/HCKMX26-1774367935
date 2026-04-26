import SwiftUI

/// Pill-style action button used in the controls strip and bottom sheets.
struct ActionPill: View {
    let title: String
    let icon: String
    let cost: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.custom(Theme.pixelMono, size: 13))
                    .foregroundStyle(.white)
                if let cost {
                    Text("· \(cost)🪙")
                        .font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Theme.actionPink)
                    .overlay(Capsule().stroke(Theme.actionPinkDark, lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
    }
}
