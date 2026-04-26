import SwiftUI

/// Analog-ish joystick. Outputs a normalized CGVector (-1...1).
struct JoystickView: View {
    let onChange: (CGVector) -> Void

    @State private var knobOffset: CGSize = .zero
    private let baseSize: CGFloat = 96
    private let knobSize: CGFloat = 44
    private var maxRadius: CGFloat { (baseSize - knobSize) / 2 }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.25))
                .overlay(Circle().stroke(Theme.darkInk.opacity(0.25), lineWidth: 2))
                .frame(width: baseSize, height: baseSize)
            Circle()
                .fill(Theme.actionPink)
                .overlay(Circle().stroke(Theme.actionPinkDark, lineWidth: 2))
                .frame(width: knobSize, height: knobSize)
                .offset(knobOffset)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    let dist = sqrt(dx * dx + dy * dy)
                    if dist <= maxRadius {
                        knobOffset = CGSize(width: dx, height: dy)
                    } else {
                        let scale = maxRadius / dist
                        knobOffset = CGSize(width: dx * scale, height: dy * scale)
                    }
                    onChange(CGVector(
                        dx: knobOffset.width / maxRadius,
                        dy: knobOffset.height / maxRadius
                    ))
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        knobOffset = .zero
                    }
                    onChange(.zero)
                }
        )
    }
}
