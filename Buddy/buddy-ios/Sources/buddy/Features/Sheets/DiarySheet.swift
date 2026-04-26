import SwiftUI

struct DiarySheet: View {
    let onClose: () -> Void
    @State private var entries: [DiaryEntry] = DiaryStore.entries()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diario").font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                        .foregroundStyle(Theme.darkInk)
                    Text("Lo que ha pasado con Buddy")
                        .font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(Theme.darkInk.opacity(0.6))
                }
                Spacer()
                CloseButton(action: onClose)
            }
            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(entries) { e in entryRow(e) }
                    }
                }
            }
        }
        .padding(20)
        .background(Theme.consoleBG.ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("📖").font(.system(size: 60))
            Text("Tu diario está vacío")
                .font(.custom(Theme.pixelMono, size: 14)).foregroundStyle(Theme.darkInk.opacity(0.6))
            Text("Cuida a tu mascota para empezar a llenarlo")
                .font(.custom(Theme.pixelMono, size: 11)).foregroundStyle(Theme.darkInk.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func entryRow(_ e: DiaryEntry) -> some View {
        HStack(spacing: 10) {
            Text(e.emoji).font(.system(size: 22)).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.detail).font(.custom(Theme.pixelMono, size: 13))
                    .foregroundStyle(Theme.darkInk)
                Text(e.timestamp.formatted(.relative(presentation: .named)))
                    .font(.custom(Theme.pixelMono, size: 10))
                    .foregroundStyle(Theme.darkInk.opacity(0.5))
            }
            Spacer()
        }
        .padding(10)
        .background(Theme.buttonBG)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
