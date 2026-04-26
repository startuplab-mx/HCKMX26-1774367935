import SwiftUI

struct OnboardingView: View {
    let onFinish: (String, PetCharacter) -> Void

    @State private var step = 0
    @State private var name = ""
    @State private var character: PetCharacter = .garfield

    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.95, green: 0.86, blue: 0.72),
                Color(red: 1, green: 0.94, blue: 0.84)
            ], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                switch step {
                case 0: welcomeStep
                case 1: nameStep
                default: characterStep
                }
                Spacer()
                Button(action: next) {
                    Text(step == 2 ? "¡Empezar! 🚀" : "Siguiente")
                        .font(.custom(Theme.pixelMono, size: 16).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Theme.actionPink))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .disabled(step == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Text("🐾").font(.system(size: 80))
            Text("Bienvenido a Buddy")
                .font(.custom(Theme.pixelMono, size: 26).weight(.bold))
                .foregroundStyle(Theme.darkInk)
            Text("Adopta tu mascota digital.\nAliméntala, cuídala, juega con ella.\nY no la dejes sola por mucho tiempo.")
                .font(.custom(Theme.pixelMono, size: 13))
                .foregroundStyle(Theme.darkInk.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var nameStep: some View {
        VStack(spacing: 16) {
            Text("✏️").font(.system(size: 60))
            Text("¿Cómo se llama?")
                .font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                .foregroundStyle(Theme.darkInk)
            TextField("Buddy", text: $name)
                .font(.custom(Theme.pixelMono, size: 18))
                .multilineTextAlignment(.center)
                .padding(16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 40)
                .submitLabel(.done)
        }
    }

    private var characterStep: some View {
        VStack(spacing: 16) {
            Text("🎨").font(.system(size: 60))
            Text("Elige tu personaje")
                .font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                .foregroundStyle(Theme.darkInk)
            HStack(spacing: 12) {
                ForEach(PetCharacter.allCases) { c in
                    Button { character = c } label: {
                        VStack(spacing: 4) {
                            Text(c == .garfield ? "🐱" : "🔒").font(.system(size: 36))
                            Text(c.displayName).font(.custom(Theme.pixelMono, size: 11))
                                .foregroundStyle(Theme.darkInk)
                        }
                        .frame(width: 70, height: 70)
                        .background(c == character ? Theme.lcdInner : Theme.buttonBG)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(c == character ? Theme.actionPink : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .disabled(c != .garfield)
                    .opacity(c == .garfield ? 1 : 0.4)
                }
            }
            Text("Más personajes pronto")
                .font(.custom(Theme.pixelMono, size: 10))
                .foregroundStyle(Theme.darkInk.opacity(0.5))
        }
    }

    private func next() {
        if step < 2 { step += 1 } else { onFinish(name.trimmingCharacters(in: .whitespaces), character) }
    }
}
