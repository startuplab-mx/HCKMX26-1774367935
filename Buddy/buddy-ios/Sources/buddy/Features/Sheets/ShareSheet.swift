import SwiftUI
import CloudKit

/// Sheet to invite caretakers via CloudKit share URL.
struct ShareCaretakerSheet: View {
    let onClose: () -> Void

    @State private var loading = false
    @State private var url: URL?
    @State private var error: String?
    @State private var iCloudOk = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compartir cuidado")
                        .font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                        .foregroundStyle(Theme.darkInk)
                    Text("Invita a un amigo a cuidar a tu mascota juntos")
                        .font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(Theme.darkInk.opacity(0.6))
                }
                Spacer()
                CloseButton(action: onClose)
            }

            if !iCloudOk {
                infoBox(emoji: "☁️", title: "Activa iCloud", body: "Para compartir, inicia sesión en iCloud desde Ajustes y activa Buddy en iCloud Drive.")
            } else if let error {
                infoBox(emoji: "⚠️", title: "Error", body: error)
            } else if let url {
                shareReady(url)
            } else {
                Button(action: createShare) {
                    Text(loading ? "Generando link…" : "Generar link de invitación")
                        .font(.custom(Theme.pixelMono, size: 14).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Theme.actionPink))
                }
                .buttonStyle(.plain)
                .disabled(loading)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Cómo funciona").font(.custom(Theme.pixelMono, size: 12).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
                bullet("1", "Generas un link único de invitación")
                bullet("2", "Lo compartes por iMessage / WhatsApp / cualquier chat")
                bullet("3", "Tu amigo abre el link → pueden cuidar a Buddy juntos")
                bullet("4", "Los cambios se sincronizan en tiempo real (iCloud)")
            }
            .padding(14)
            .background(Theme.lcdInner)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding(20)
        .background(Theme.consoleBG.ignoresSafeArea())
        .task { iCloudOk = await CloudKitService.shared.iCloudAvailable() }
    }

    private func shareReady(_ url: URL) -> some View {
        VStack(spacing: 12) {
            Text("✅ Link listo").font(.custom(Theme.pixelMono, size: 16).weight(.bold))
                .foregroundStyle(.green)
            Text(url.absoluteString)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(2).truncationMode(.middle)
                .padding(10).background(Theme.buttonBG)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            ShareLink(item: url) {
                Text("Compartir invitación")
                    .font(.custom(Theme.pixelMono, size: 14).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Capsule().fill(Theme.actionPink))
            }
        }
    }

    private func infoBox(emoji: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(emoji).font(.system(size: 22)); Text(title).font(.custom(Theme.pixelMono, size: 14).weight(.bold)) }
            Text(body).font(.custom(Theme.pixelMono, size: 11)).foregroundStyle(Theme.darkInk.opacity(0.7))
        }
        .padding(14)
        .background(Theme.buttonBG)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func bullet(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(n).font(.custom(Theme.pixelMono, size: 11).weight(.bold)).foregroundStyle(Theme.actionPink).frame(width: 14)
            Text(text).font(.custom(Theme.pixelMono, size: 11)).foregroundStyle(Theme.darkInk.opacity(0.8))
        }
    }

    private func createShare() {
        loading = true; error = nil
        Task {
            do {
                let url = try await CloudKitService.shared.makeShareURL()
                await MainActor.run { self.url = url; self.loading = false }
            } catch let e {
                await MainActor.run { self.error = e.localizedDescription; self.loading = false }
            }
        }
    }
}
