import SwiftUI

struct ToastBanner: View {
    let emoji: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom(Theme.pixelMono, size: 13).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
                Text(detail)
                    .font(.custom(Theme.pixelMono, size: 11))
                    .foregroundStyle(Theme.darkInk.opacity(0.7))
            }
            Spacer()
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.actionPink, lineWidth: 2))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 16)
    }
}

@Observable
final class ToastQueue {
    static let shared = ToastQueue()
    private init() {}

    private(set) var current: ToastData?

    struct ToastData: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let detail: String
    }

    func show(emoji: String, title: String, detail: String, duration: TimeInterval = 2.5) {
        let toast = ToastData(emoji: emoji, title: title, detail: detail)
        current = toast
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if current?.id == toast.id { current = nil }
        }
    }
}
