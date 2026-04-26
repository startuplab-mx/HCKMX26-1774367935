import SwiftUI

struct CreateProfileSheet: View {
    @EnvironmentObject var store: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var role: FluxProfile.Role = .parent
    @State private var name: String = ""
    @State private var colorHex: UInt32 = FluxProfile.sampleAvatarColors.first ?? 0x0F766E
    @State private var biometricEnabled: Bool = FluxBiometricAuthService.shared.isAvailable
    @State private var childAge: Int = 13
    @State private var pairedParentName: String = ""
    @FocusState private var nameFocused: Bool

    private let biometric = FluxBiometricAuthService.shared

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty }

    var body: some View {
        ZStack {
            FluxColor.base.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        avatarPreview
                        roleSection
                        nameSection
                        colorSection
                        if role == .child {
                            childExtras
                        }
                        biometricSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                footer
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NUEVO PERFIL")
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(FluxColor.inkMuted)
                Text("crear cuenta")
                    .font(FluxFont.caveat(34, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(FluxColor.surfaceAlt))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Avatar preview

    private var avatarPreview: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 92, height: 92)
                    .shadow(color: Color(hex: colorHex).opacity(0.35), radius: 14, y: 6)
                Text(trimmedName.isEmpty ? "?" : String(trimmedName.prefix(1)).uppercased())
                    .font(FluxFont.display(38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .animation(.smooth(duration: 0.25), value: colorHex)
            .animation(.smooth(duration: 0.15), value: trimmedName)
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Role

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("TIPO DE PERFIL")

            HStack(spacing: 10) {
                roleChip(.parent, icon: "shield.lefthalf.filled", title: "Padre / Madre", subtitle: "monitorea a un menor")
                roleChip(.child, icon: "sparkles", title: "Menor", subtitle: "flux voz")
            }
        }
    }

    private func roleChip(_ value: FluxProfile.Role, icon: String, title: String, subtitle: String) -> some View {
        let selected = role == value
        let tint: Color = value == .parent ? FluxColor.primary : FluxColor.vozAccent
        return Button {
            withAnimation(.smooth(duration: 0.2)) { role = value }
            if value == .parent, colorHex == 0x8B5E3C { colorHex = 0x0F766E }
            if value == .child, colorHex == 0x0F766E { colorHex = 0x8B5E3C }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? tint : FluxColor.inkMuted)
                Text(title)
                    .font(FluxFont.display(14, weight: .bold))
                    .foregroundStyle(FluxColor.ink)
                Text(subtitle)
                    .font(FluxFont.body(11))
                    .foregroundStyle(FluxColor.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(selected ? tint.opacity(0.08) : FluxColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(selected ? tint : FluxColor.line, lineWidth: selected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("NOMBRE")
            TextField("", text: $name, prompt: Text("ej. Camila Vega").foregroundStyle(FluxColor.inkFaint))
                .font(FluxFont.display(17, weight: .semibold))
                .foregroundStyle(FluxColor.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($nameFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(FluxColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(nameFocused ? FluxColor.primary : FluxColor.line,
                                        lineWidth: nameFocused ? 1.5 : 1)
                        )
                )
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("COLOR DE AVATAR")
            HStack(spacing: 12) {
                ForEach(FluxProfile.sampleAvatarColors, id: \.self) { hex in
                    Button {
                        withAnimation(.smooth(duration: 0.2)) { colorHex = hex }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                            if colorHex == hex {
                                Circle()
                                    .stroke(FluxColor.ink, lineWidth: 2)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    // MARK: - Child extras

    private var childExtras: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("EDAD")
                HStack(spacing: 10) {
                    Button {
                        if childAge > 6 { childAge -= 1 }
                    } label: {
                        stepperButton(icon: "minus")
                    }
                    Text("\(childAge) años")
                        .font(FluxFont.display(17, weight: .bold))
                        .foregroundStyle(FluxColor.ink)
                        .frame(maxWidth: .infinity)
                    Button {
                        if childAge < 17 { childAge += 1 }
                    } label: {
                        stepperButton(icon: "plus")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(FluxColor.surface)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FluxColor.line, lineWidth: 1))
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("VINCULADO CON (OPCIONAL)")
                TextField("", text: $pairedParentName, prompt: Text("nombre del padre/madre").foregroundStyle(FluxColor.inkFaint))
                    .font(FluxFont.body(15))
                    .foregroundStyle(FluxColor.ink)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(FluxColor.surface)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FluxColor.line, lineWidth: 1))
                    )
            }
        }
    }

    private func stepperButton(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(FluxColor.ink)
            .frame(width: 40, height: 40)
            .background(Circle().fill(FluxColor.surfaceAlt))
    }

    // MARK: - Biometric

    private var biometricSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(FluxColor.primarySoft)
                    .frame(width: 40, height: 40)
                Image(systemName: biometric.biometricIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FluxColor.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Bloquear con \(biometric.biometricName)")
                    .font(FluxFont.display(14, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)
                Text(biometric.isAvailable ? "requerido al abrir este perfil" : "no disponible en este dispositivo")
                    .font(FluxFont.body(11))
                    .foregroundStyle(FluxColor.inkMuted)
            }
            Spacer()
            Toggle("", isOn: $biometricEnabled)
                .labelsHidden()
                .tint(FluxColor.primary)
                .disabled(!biometric.isAvailable)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().background(FluxColor.line)
            Button {
                save()
            } label: {
                Text("Crear perfil")
                    .font(FluxFont.display(16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(canSave ? FluxColor.ink : FluxColor.inkFaint)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(FluxColor.base)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(FluxFont.mono(10, weight: .bold))
            .tracking(2)
            .foregroundStyle(FluxColor.inkMuted)
    }

    // MARK: - Save

    private func save() {
        guard canSave else { return }

        let useBiometric = biometricEnabled && biometric.isAvailable

        let profile: FluxProfile
        switch role {
        case .parent:
            profile = FluxProfile(
                role: .parent,
                displayName: trimmedName,
                avatarColorHex: colorHex,
                biometricEnabled: useBiometric,
                monitoredChildren: []
            )
        case .child:
            let paired = pairedParentName.trimmingCharacters(in: .whitespacesAndNewlines)
            profile = FluxProfile(
                role: .child,
                displayName: trimmedName,
                avatarColorHex: colorHex,
                biometricEnabled: useBiometric,
                caseID: UUID(),
                pairedWithParentName: paired.isEmpty ? nil : paired,
                childAge: childAge
            )
        }

        store.addProfile(profile)

        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        dismiss()
    }
}

#Preview {
    CreateProfileSheet()
        .environmentObject(ProfileStore.shared)
}
