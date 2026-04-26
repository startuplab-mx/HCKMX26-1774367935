import SwiftUI

struct PetsSheet: View {
    let current: PetCharacter
    let coins: Int
    let onPick: (PetCharacter) -> Void
    let onUnlock: (PetCharacter) -> Bool
    let onClose: () -> Void

    @State private var unlocked: Set<PetCharacter> = CharacterStore.unlocked()

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personajes")
                        .font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                        .foregroundStyle(Theme.darkInk)
                    Text("Toca uno para cambiar tu mascota")
                        .font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(Theme.darkInk.opacity(0.6))
                }
                Spacer()
                CloseButton(action: onClose)
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PetCharacter.allCases) { c in
                        characterCard(c)
                    }
                }
            }
        }
        .padding(20)
        .background(Theme.consoleBG.ignoresSafeArea())
    }

    private func characterCard(_ c: PetCharacter) -> some View {
        let isUnlocked = unlocked.contains(c)
        return VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.lcdInner)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(c == current ? Theme.actionPink : Theme.lcdStroke, lineWidth: 2))
                Image(c.spriteSheetAsset)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 4 * 60, height: 4 * 60)
                    .offset(x: 0, y: 0)
                    .frame(width: 60, height: 60, alignment: .topLeading)
                    .clipped()
                if !isUnlocked {
                    Color.black.opacity(0.4).clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("🔒").font(.system(size: 36))
                }
            }
            .frame(height: 120)
            HStack(spacing: 4) {
                Text(c.emoji)
                Text(c.displayName)
                    .font(.custom(Theme.pixelMono, size: 13).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
            }
            if isUnlocked {
                Text(c == current ? "Activo" : "Toca para usar")
                    .font(.custom(Theme.pixelMono, size: 10))
                    .foregroundStyle(c == current ? Theme.actionPink : Theme.darkInk.opacity(0.5))
            } else {
                Button {
                    if onUnlock(c) {
                        unlocked.insert(c)
                        CharacterStore.unlock(c)
                    }
                } label: {
                    Text("\(c.unlockPrice)🪙")
                        .font(.custom(Theme.pixelMono, size: 11).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(coins >= c.unlockPrice ? Theme.actionPink : .gray))
                }
                .buttonStyle(.plain)
                .disabled(coins < c.unlockPrice)
            }
        }
        .onTapGesture { if isUnlocked { onPick(c) } }
    }
}

struct CloseButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("✕")
                .font(.custom(Theme.pixelMono, size: 18).weight(.bold))
                .foregroundStyle(Theme.darkInk)
                .frame(width: 36, height: 36)
                .background(Theme.buttonBG)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.buttonStroke, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
