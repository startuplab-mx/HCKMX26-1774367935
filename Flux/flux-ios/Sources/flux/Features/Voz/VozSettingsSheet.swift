import SwiftUI

struct VozSettingsSheet: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var showLogoutConfirm = false
    @State private var showPairing = false
    @State private var pairingToast: String?

    private let biometric = FluxBiometricAuthService.shared

    private var profile: FluxProfile? { profileStore.activeProfile }

    var body: some View {
        ZStack {
            FluxColor.voz.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        profileCard
                        pairingSection
                        biometricCard
                        dangerZone
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showPairing) {
            ProximityPairingView(role: .child) { invitation in
                handlePairingComplete(invitation)
            }
        }
        .overlay(alignment: .top) {
            if let msg = pairingToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(FluxColor.safe)
                    Text(msg).font(FluxFont.body(13, weight: .semibold))
                }
                .foregroundStyle(FluxColor.vozInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(FluxColor.vozSurface).shadow(color: .black.opacity(0.1), radius: 10, y: 4))
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert("¿Eliminar este perfil?", isPresented: $showDeleteConfirm) {
            Button("Eliminar", role: .destructive) { deleteProfile() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borrarán tus datos locales. Esta acción no se puede deshacer.")
        }
        .alert("¿Cerrar sesión?", isPresented: $showLogoutConfirm) {
            Button("Cerrar sesión", role: .destructive) { logout() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Volverás al selector de perfil.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CONFIGURACIÓN")
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(FluxColor.vozMuted)
                Text("tu perfil")
                    .font(FluxFont.caveat(34, weight: .semibold))
                    .foregroundStyle(FluxColor.vozInk)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FluxColor.vozInk)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(FluxColor.vozCard))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Profile card

    private var profileCard: some View {
        HStack(spacing: 14) {
            if let profile {
                ZStack {
                    Circle()
                        .fill(profile.avatarColor)
                        .frame(width: 58, height: 58)
                        .shadow(color: profile.avatarColor.opacity(0.35), radius: 10, y: 4)
                    Text(profile.initial)
                        .font(FluxFont.display(22, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.role.modeLabel)
                        .font(FluxFont.mono(9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(FluxColor.vozAccent)
                    Text(profile.displayName)
                        .font(FluxFont.display(17, weight: .bold))
                        .foregroundStyle(FluxColor.vozInk)
                    if let parent = profile.pairedWithParentName {
                        Text("vinculada con \(parent)")
                            .font(FluxFont.body(12))
                            .foregroundStyle(FluxColor.vozMuted)
                    }
                }
                Spacer()
            } else {
                Text("sin perfil activo")
                    .font(FluxFont.body(14))
                    .foregroundStyle(FluxColor.vozMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(FluxColor.vozSurface)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(FluxColor.vozLine, lineWidth: 1))
        )
    }

    // MARK: - Pairing

    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VÍNCULO")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.vozMuted)
                .padding(.leading, 4)

            if let paired = profile?.pairedWithParentName {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(FluxColor.safe.opacity(0.14)).frame(width: 40, height: 40)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FluxColor.safe)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vinculada con \(paired)")
                            .font(FluxFont.display(14, weight: .semibold))
                            .foregroundStyle(FluxColor.vozInk)
                        Text("solo tú ves tu buzón · on-device")
                            .font(FluxFont.body(11))
                            .foregroundStyle(FluxColor.vozMuted)
                    }
                    Spacer()
                    Button {
                        unlinkParent()
                    } label: {
                        Text("desvincular")
                            .font(FluxFont.mono(10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(FluxColor.danger)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(FluxColor.danger.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(FluxColor.vozSurface)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.vozLine, lineWidth: 1))
                )
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showPairing = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(FluxColor.vozAccent.opacity(0.12)).frame(width: 40, height: 40)
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(FluxColor.vozAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Conectar con un padre")
                                .font(FluxFont.display(14, weight: .semibold))
                                .foregroundStyle(FluxColor.vozInk)
                            Text("acerca tu teléfono al de un adulto de confianza")
                                .font(FluxFont.body(11))
                                .foregroundStyle(FluxColor.vozMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FluxColor.vozMuted)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(FluxColor.vozSurface)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.vozLine, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Biometric

    private var biometricCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(FluxColor.vozAccent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: biometric.biometricIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FluxColor.vozAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Bloquear con \(biometric.biometricName)")
                    .font(FluxFont.display(14, weight: .semibold))
                    .foregroundStyle(FluxColor.vozInk)
                Text(biometric.isAvailable ? "on-device · solo tú lo abres" : "no disponible en este dispositivo")
                    .font(FluxFont.body(11))
                    .foregroundStyle(FluxColor.vozMuted)
            }
            Spacer()
            Toggle(
                "",
                isOn: Binding(
                    get: { profile?.biometricEnabled ?? false },
                    set: { newValue in
                        guard let p = profile else { return }
                        profileStore.toggleBiometric(for: p, enabled: newValue)
                    }
                )
            )
            .labelsHidden()
            .tint(FluxColor.vozAccent)
            .disabled(!biometric.isAvailable || profile == nil)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(FluxColor.vozSurface)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(FluxColor.vozLine, lineWidth: 1))
        )
    }

    // MARK: - Danger zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SESIÓN")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.vozMuted)
                .padding(.leading, 4)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showLogoutConfirm = true
            } label: {
                settingsRow(icon: "lock.fill", title: "Cerrar sesión",
                            subtitle: "volver al selector de perfil",
                            tint: FluxColor.vozInk)
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showDeleteConfirm = true
            } label: {
                settingsRow(icon: "trash.fill", title: "Eliminar perfil",
                            subtitle: "borra los datos locales",
                            tint: FluxColor.danger)
            }
            .buttonStyle(.plain)
            .disabled(profile == nil)
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FluxFont.display(14, weight: .semibold))
                    .foregroundStyle(FluxColor.vozInk)
                Text(subtitle)
                    .font(FluxFont.body(11))
                    .foregroundStyle(FluxColor.vozMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FluxColor.vozMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(FluxColor.vozSurface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.vozLine, lineWidth: 1))
        )
    }

    // MARK: - Actions

    private func logout() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        profileStore.lock()
        dismiss()
    }

    private func handlePairingComplete(_ invitation: VozInvitation) {
        guard var p = profile else { return }
        let displayName = invitation.parentName.isEmpty ? invitation.parentDeviceName : invitation.parentName
        p.pairedWithParentName = displayName
        p.caseID = invitation.caseID
        profileStore.updateProfile(p)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.smooth(duration: 0.3)) {
            pairingToast = "vinculad@ con \(displayName)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.smooth(duration: 0.3)) { pairingToast = nil }
        }
    }

    private func unlinkParent() {
        guard var p = profile else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        p.pairedWithParentName = nil
        p.caseID = nil
        profileStore.updateProfile(p)
    }

    private func deleteProfile() {
        guard let p = profile else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        profileStore.deleteProfile(p)
        dismiss()
    }
}

#Preview {
    VozSettingsSheet()
        .environmentObject(ProfileStore.shared)
}
