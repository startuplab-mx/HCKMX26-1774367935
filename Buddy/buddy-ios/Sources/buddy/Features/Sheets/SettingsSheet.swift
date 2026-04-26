import SwiftUI

struct SettingsSheet: View {
    @Binding var dynamicIslandOn: Bool
    @Binding var soundsOn: Bool
    let onResetPet: () -> Void
    let onClose: () -> Void

    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Ajustes")
                    .font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
                Spacer()
                CloseButton(action: onClose)
            }

            section("Notificaciones") {
                toggleRow("Dynamic Island", systemImage: "rectangle.roundedtop", binding: $dynamicIslandOn)
                toggleRow("Sonidos del pet", systemImage: "speaker.wave.2.fill", binding: $soundsOn)
            }

            section("Mascota") {
                Button {
                    confirmReset = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reiniciar mascota")
                            .font(.custom(Theme.pixelMono, size: 14))
                        Spacer()
                    }
                    .foregroundStyle(.red)
                    .padding(12)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            section("Acerca de") {
                infoRow("Versión", "0.1.0")
                infoRow("Hecho con", "♥ + pixel art")
            }

            Spacer()
        }
        .padding(20)
        .background(Theme.consoleBG.ignoresSafeArea())
        .alert("¿Reiniciar mascota?", isPresented: $confirmReset) {
            Button("Cancelar", role: .cancel) {}
            Button("Reiniciar", role: .destructive) { onResetPet() }
        } message: {
            Text("Perderás todo el progreso del pet actual. Las monedas se conservan.")
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.custom(Theme.pixelMono, size: 11).weight(.bold))
                .foregroundStyle(Theme.darkInk.opacity(0.5))
            VStack(spacing: 8) { content() }
        }
    }

    private func toggleRow(_ title: String, systemImage: String, binding: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.darkInk)
                .frame(width: 24)
            Text(title)
                .font(.custom(Theme.pixelMono, size: 14))
                .foregroundStyle(Theme.darkInk)
            Spacer()
            Toggle("", isOn: binding).labelsHidden().tint(Theme.actionPink)
        }
        .padding(12)
        .background(Theme.buttonBG)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom(Theme.pixelMono, size: 13))
                .foregroundStyle(Theme.darkInk.opacity(0.7))
            Spacer()
            Text(value)
                .font(.custom(Theme.pixelMono, size: 13).weight(.bold))
                .foregroundStyle(Theme.darkInk)
        }
        .padding(12)
        .background(Theme.buttonBG)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
