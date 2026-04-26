import SwiftUI

struct OnboardingFlow: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) var dismiss
    @State private var step: Step = .welcome

    enum Step: Int, CaseIterable {
        case welcome, transparency, profile
    }

    var body: some View {
        ZStack {
            FluxColor.base.ignoresSafeArea()

            switch step {
            case .welcome:
                OnboardingWelcome(onContinue: advance)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .transparency:
                OnboardingTransparency(onContinue: advance)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .profile:
                OnboardingProfile(onContinue: finish)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.smooth(duration: 0.35), value: step)
    }

    private func advance() {
        let next = (step.rawValue + 1)
        if let s = Step(rawValue: next) { step = s }
    }

    private func finish(_ child: ChildProfile) {
        let parent = FluxProfile(
            role: .parent,
            displayName: "Tú",
            avatarColorHex: 0x0F766E,
            biometricEnabled: FluxBiometricAuthService.shared.isAvailable,
            monitoredChildren: [child]
        )
        profileStore.addProfile(parent)
        profileStore.selectProfile(parent)
        dismiss()
    }
}

// MARK: - 01 Welcome
struct OnboardingWelcome: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("FLUX")
                .font(FluxFont.mono(11, weight: .bold))
                .tracking(6)
                .foregroundStyle(FluxColor.inkMuted)

            Text("flux")
                .font(FluxFont.display(96, weight: .black))
                .kerning(-5)
                .foregroundStyle(FluxColor.ink)
                .padding(.top, 16)

            Text("Detecta lo que tú no ves.")
                .font(FluxFont.body(20, weight: .medium))
                .foregroundStyle(FluxColor.ink)
                .padding(.top, 20)

            Text("Escanea una conversación, una captura o un archivo. WeProtect te dice si hay patrón de riesgo. Todo corre en tu teléfono.")
                .font(FluxFont.body(15))
                .foregroundStyle(FluxColor.inkMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 40)
                .padding(.top, 16)

            Spacer()

            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text("Empezar")
                        .font(FluxFont.body(16, weight: .semibold))
                        .foregroundStyle(FluxColor.base)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(FluxColor.ink))
                }

                Button { } label: {
                    Text("leer cómo funciona")
                        .font(FluxFont.body(13, weight: .medium))
                        .foregroundStyle(FluxColor.inkMuted)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - 02 Transparencia
struct OnboardingTransparency: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i == 0 ? FluxColor.ink : FluxColor.line)
                        .frame(height: 3)
                }
            }
            .padding(.top, 28)

            Text("PASO 1 DE 3")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(FluxColor.inkFaint)
                .padding(.top, 12)

            Text("Qué leemos y qué no.")
                .font(FluxFont.title1)
                .kerning(-0.6)
                .foregroundStyle(FluxColor.ink)
                .padding(.top, 4)

            Text("Transparencia primero. Esto no se modifica después.")
                .font(FluxFont.body(15))
                .foregroundStyle(FluxColor.inkMuted)

            readBlock
                .padding(.top, 12)

            neverBlock

            Spacer()

            Button(action: onContinue) {
                Text("Entiendo, continuar")
                    .font(FluxFont.body(16, weight: .semibold))
                    .foregroundStyle(FluxColor.base)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Capsule().fill(FluxColor.ink))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private var readBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("SÍ LEEMOS", systemImage: "")
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(FluxColor.safe)
            ForEach(["Tiempo de uso por app", "Horarios de actividad", "Apps instaladas nuevas", "Lo que TÚ decidas escanear"], id: \.self) { item in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(FluxColor.safe))
                    Text(item)
                        .font(FluxFont.body(14))
                        .foregroundStyle(FluxColor.ink)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.safe.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.safe.opacity(0.2), lineWidth: 1))
        )
    }

    private var neverBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("NUNCA LEEMOS", systemImage: "")
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(FluxColor.danger)
            ForEach(["Contenido de mensajes automáticamente", "Fotos o videos sin tu permiso", "Contactos o llamadas", "Ubicación precisa"], id: \.self) { item in
                HStack(spacing: 10) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(FluxColor.danger))
                    Text(item)
                        .font(FluxFont.body(14))
                        .foregroundStyle(FluxColor.ink)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.danger.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.danger.opacity(0.2), lineWidth: 1))
        )
    }
}

// MARK: - 03 Perfil del menor
struct OnboardingProfile: View {
    let onContinue: (ChildProfile) -> Void

    @State private var name: String = "Lucía"
    @State private var age: Int = 13
    @State private var selectedApps: Set<String> = ["TikTok", "Instagram", "WhatsApp"]

    let allApps = ["TikTok", "Instagram", "WhatsApp", "Discord", "Roblox", "YouTube", "Snapchat", "Telegram"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(FluxColor.ink)
                            .frame(height: 3)
                    }
                }
                .padding(.top, 28)

                Text("PASO 3 DE 3")
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(2.5)
                    .foregroundStyle(FluxColor.inkFaint)
                    .padding(.top, 12)

                Text("¿A quién vamos a cuidar?")
                    .font(FluxFont.title1)
                    .kerning(-0.6)
                    .foregroundStyle(FluxColor.ink)

                fieldBlock("Nombre") {
                    TextField("Nombre del menor", text: $name)
                        .font(FluxFont.body(15))
                        .foregroundStyle(FluxColor.ink)
                }

                fieldBlock("Edad") {
                    HStack {
                        Text("\(age) años")
                            .font(FluxFont.body(15))
                            .foregroundStyle(FluxColor.ink)
                        Spacer()
                        Stepper("", value: $age, in: 8...17).labelsHidden()
                    }
                }

                baselineAppsBlock

                consentBlock

                Button {
                    onContinue(ChildProfile(name: name, age: age, baselineApps: Array(selectedApps)))
                } label: {
                    Text("Activar detección")
                        .font(FluxFont.body(16, weight: .semibold))
                        .foregroundStyle(FluxColor.base)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(FluxColor.ink))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func fieldBlock(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private var baselineAppsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APPS QUE USA HABITUALMENTE")
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)
            Text("Calibrar \"normal\" para esta persona")
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.inkMuted)

            FlowLayout(spacing: 8) {
                ForEach(allApps, id: \.self) { app in
                    appChip(app)
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FluxColor.surfaceAlt)
        )
    }

    private func appChip(_ app: String) -> some View {
        let isSelected = selectedApps.contains(app)
        return Button {
            withAnimation(.smooth(duration: 0.2)) {
                if isSelected { selectedApps.remove(app) } else { selectedApps.insert(app) }
            }
        } label: {
            HStack(spacing: 5) {
                Text(app)
                    .font(FluxFont.body(13, weight: .medium))
                if isSelected {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                } else {
                    Image(systemName: "plus").font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundStyle(isSelected ? FluxColor.base : FluxColor.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? FluxColor.ink : FluxColor.surface)
                    .overlay(Capsule().stroke(FluxColor.line, lineWidth: isSelected ? 0 : 1))
            )
        }
    }

    private var consentBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CONSENTIMIENTO")
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.warn)
            Text("Recomendamos hablar con \(name). Puedes invitarla a flux voz desde Ajustes.")
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FluxColor.warn.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(FluxColor.warn.opacity(0.2), lineWidth: 1))
        )
    }
}

// MARK: - FlowLayout helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}

#Preview {
    OnboardingFlow().environmentObject(AppSession())
}
