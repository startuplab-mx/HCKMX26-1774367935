import SwiftUI

struct ReincarnationSheet: View {
    let onConfirm: (String, PetCharacter) -> Void

    @State private var name: String = "Buddy"
    @State private var character: PetCharacter = .garfield

    var body: some View {
        VStack(spacing: 24) {
            Text("🪦")
                .font(.system(size: 60))
                .padding(.top, 40)
            Text("Tu mascota descansa en paz")
                .font(.custom(Theme.pixelMono, size: 18).weight(.bold))
                .foregroundStyle(Theme.darkInk)
                .multilineTextAlignment(.center)
            Text("Pero el ciclo continúa.\nDale vida a un nuevo amigo.")
                .font(.custom(Theme.pixelMono, size: 13))
                .foregroundStyle(Theme.darkInk.opacity(0.7))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Nombre")
                    .font(.custom(Theme.pixelMono, size: 11).weight(.bold))
                    .foregroundStyle(Theme.darkInk.opacity(0.5))
                TextField("Buddy", text: $name)
                    .font(.custom(Theme.pixelMono, size: 16))
                    .padding(12)
                    .background(Theme.buttonBG)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)

            Button {
                onConfirm(name.isEmpty ? "Buddy" : name, character)
            } label: {
                Text("Renacer ✨")
                    .font(.custom(Theme.pixelMono, size: 16).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Theme.actionPink))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            Spacer()
        }
        .padding(20)
        .background(Theme.consoleBG.ignoresSafeArea())
        .interactiveDismissDisabled()
    }
}
