import SwiftUI

struct PixelButton: View {
    let action: () -> Void
    let content: AnyView

    init<C: View>(action: @escaping () -> Void, @ViewBuilder content: () -> C) {
        self.action = action
        self.content = AnyView(content())
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(width: 36, height: 36)
                .background(Theme.buttonBG)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.buttonStroke, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
