import SwiftUI
import UIKit

struct PhotoModeSheet: View {
    let pet: Pet
    let onClose: () -> Void

    @State private var caption: String = ""
    @State private var savedToLibrary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Foto").font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                        .foregroundStyle(Theme.darkInk)
                    Text("Comparte un momento de \(pet.name)")
                        .font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(Theme.darkInk.opacity(0.6))
                }
                Spacer()
                CloseButton(action: onClose)
            }
            poster
            TextField("Escribe algo…", text: $caption)
                .font(.custom(Theme.pixelMono, size: 14))
                .padding(12).background(Theme.buttonBG)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            HStack(spacing: 10) {
                ShareLink(
                    item: Image(uiImage: poster.snapshot()),
                    preview: SharePreview("\(pet.name)", image: Image(uiImage: poster.snapshot()))
                ) {
                    Label("Compartir", systemImage: "square.and.arrow.up")
                        .font(.custom(Theme.pixelMono, size: 13).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.actionPink))
                }
                Button {
                    let img = poster.snapshot()
                    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                    savedToLibrary = true
                } label: {
                    Label("Guardar", systemImage: "square.and.arrow.down")
                        .font(.custom(Theme.pixelMono, size: 13).weight(.bold))
                        .foregroundStyle(Theme.darkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.buttonBG))
                }
                .buttonStyle(.plain)
            }
            if savedToLibrary {
                Text("✓ Guardado en Fotos").font(.custom(Theme.pixelMono, size: 11))
                    .foregroundStyle(.green)
            }
            Spacer()
        }
        .padding(20)
        .background(Theme.consoleBG.ignoresSafeArea())
    }

    @ViewBuilder
    private var poster: some View {
        VStack(spacing: 8) {
            Image("background_living_room")
                .resizable()
                .interpolation(.none)
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .overlay(
                    Image("pet_sheet")
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 7 * 60, height: 6 * 60)
                        .offset(x: 0, y: 0)
                        .frame(width: 60, height: 60, alignment: .topLeading)
                        .clipped()
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(caption.isEmpty ? "\(pet.name) · día \(pet.ageInDays)" : caption)
                .font(.custom(Theme.pixelMono, size: 14).weight(.bold))
                .foregroundStyle(Theme.darkInk)
            Text("📍 Habitación · Buddy app")
                .font(.custom(Theme.pixelMono, size: 9))
                .foregroundStyle(Theme.darkInk.opacity(0.5))
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

extension View {
    @MainActor
    func snapshot() -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }
}
