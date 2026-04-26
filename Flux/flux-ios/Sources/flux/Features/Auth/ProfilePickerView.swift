import SwiftUI

struct ProfilePickerView: View {
    @EnvironmentObject var store: ProfileStore
    @State private var selectedProfileID: UUID?
    @State private var authError: String?
    @State private var isAuthenticating = false
    @State private var showingCreate = false
    @State private var profileToDelete: FluxProfile?

    private let biometric = FluxBiometricAuthService.shared

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Spacer()
                profilesGrid
                Spacer()
                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showingCreate) {
            CreateProfileSheet()
                .environmentObject(store)
        }
        .alert(
            "¿Eliminar perfil?",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            ),
            presenting: profileToDelete
        ) { profile in
            Button("Eliminar", role: .destructive) {
                withAnimation(.smooth(duration: 0.25)) {
                    store.deleteProfile(profile)
                }
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.warning)
                profileToDelete = nil
            }
            Button("Cancelar", role: .cancel) { profileToDelete = nil }
        } message: { profile in
            Text("Se borrarán los datos locales de \(profile.displayName). Esta acción no se puede deshacer.")
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            FluxColor.base.ignoresSafeArea()

            Circle()
                .fill(FluxColor.primary.opacity(0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: -120, y: -250)

            Circle()
                .fill(FluxColor.accent.opacity(0.1))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 140, y: 280)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("FLUX")
                    .font(FluxFont.mono(11, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(FluxColor.inkMuted)
            }

            Text("¿quién eres? \u{00A0}")
                .font(FluxFont.caveat(44, weight: .semibold))
                .foregroundStyle(FluxColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            Text("Elige un perfil para continuar")
                .font(FluxFont.body(14))
                .foregroundStyle(FluxColor.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Profiles grid

    private var profilesGrid: some View {
        VStack(spacing: 16) {
            ForEach(store.profiles) { profile in
                profileCard(profile: profile)
            }

            if store.profiles.count < 4 {
                addProfileButton
            }
        }
    }

    private func profileCard(profile: FluxProfile) -> some View {
        Button {
            Task { await selectProfile(profile) }
        } label: {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(profile.avatarColor)
                        .frame(width: 60, height: 60)
                        .shadow(color: profile.avatarColor.opacity(0.35), radius: 10, y: 4)
                    Text(profile.initial)
                        .font(FluxFont.display(24, weight: .bold))
                        .foregroundStyle(.white)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(profile.role.modeLabel)
                            .font(FluxFont.mono(9, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(profile.avatarColor)
                        if profile.role == .parent {
                            Text("· \(profile.monitoredChildren.count) menor\(profile.monitoredChildren.count == 1 ? "" : "es")")
                                .font(FluxFont.mono(9, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(FluxColor.inkFaint)
                        }
                    }
                    Text(profile.displayName)
                        .font(FluxFont.display(18, weight: .bold))
                        .kerning(-0.3)
                        .foregroundStyle(FluxColor.ink)

                    if profile.role == .parent, let child = profile.monitoredChildren.first {
                        Text("monitoreando a \(child.name)")
                            .font(FluxFont.body(12))
                            .foregroundStyle(FluxColor.inkMuted)
                    } else if profile.role == .child, let parent = profile.pairedWithParentName {
                        Text("vinculada con \(parent)")
                            .font(FluxFont.body(12))
                            .foregroundStyle(FluxColor.inkMuted)
                    }
                }

                Spacer()

                // Lock icon
                ZStack {
                    Circle()
                        .fill(FluxColor.surfaceAlt)
                        .frame(width: 38, height: 38)
                    Image(systemName: profile.biometricEnabled ? biometric.biometricIcon : "lock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FluxColor.ink)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(FluxColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                selectedProfileID == profile.id
                                    ? profile.avatarColor
                                    : FluxColor.line,
                                lineWidth: selectedProfileID == profile.id ? 2 : 1
                            )
                    )
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
            )
        }
        .buttonStyle(ProfileCardButtonStyle())
        .scaleEffect(isAuthenticating && selectedProfileID == profile.id ? 0.97 : 1)
        .animation(.smooth(duration: 0.2), value: isAuthenticating)
        .contextMenu {
            Button(role: .destructive) {
                profileToDelete = profile
            } label: {
                Label("Eliminar perfil", systemImage: "trash")
            }
        }
    }

    private var addProfileButton: some View {
        Button { showingCreate = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                        .foregroundStyle(FluxColor.inkFaint)
                        .frame(width: 60, height: 60)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(FluxColor.inkFaint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Agregar perfil")
                        .font(FluxFont.display(16, weight: .semibold))
                        .foregroundStyle(FluxColor.inkMuted)
                    Text("padre o menor")
                        .font(FluxFont.body(12))
                        .foregroundStyle(FluxColor.inkFaint)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                    .foregroundStyle(FluxColor.line)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            if let err = authError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(err)
                        .font(FluxFont.body(12, weight: .medium))
                }
                .foregroundStyle(FluxColor.danger)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Capsule().fill(FluxColor.danger.opacity(0.1)))
            }

            HStack(spacing: 5) {
                Image(systemName: biometric.biometricIcon)
                    .font(.system(size: 11, weight: .medium))
                Text("\(biometric.biometricName) requerido · on-device")
                    .font(FluxFont.mono(10, weight: .medium))
                    .tracking(1)
            }
            .foregroundStyle(FluxColor.inkFaint)
        }
    }

    // MARK: - Auth

    @MainActor
    private func selectProfile(_ profile: FluxProfile) async {
        selectedProfileID = profile.id
        authError = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        // Si el perfil tiene biometría habilitada y el dispositivo la soporta, autenticar
        if profile.biometricEnabled && biometric.isAvailable {
            let reason = "Desbloquear perfil de \(profile.displayName)"
            let success = await biometric.authenticate(reason: reason)
            guard success else {
                authError = "Autenticación cancelada"
                selectedProfileID = nil
                return
            }
        }

        // Haptic de éxito
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        withAnimation(.smooth(duration: 0.3)) {
            store.selectProfile(profile)
        }
    }
}

// MARK: - Button style con scale on press

struct ProfileCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ProfilePickerView()
        .environmentObject(ProfileStore.shared)
}