import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var ai = WeProtectAI.shared
    @Environment(\.dismiss) var dismiss

    // Signal toggles
    @State private var platformTransition = true
    @State private var atypicalHours = true
    @State private var reactiveInstall = true
    @State private var digitalIsolation = false

    // WeProtect toggles
    @State private var autoAnalysisOnScan = true

    // Pairing
    @State private var showPairing = false

    // Otras funciones
    @State private var showPrivacy = false
    @State private var showExportShare = false
    @State private var exportPayload: String = ""
    @State private var showRevokeConfirm = false
    @State private var showClearHistoryConfirm = false

    // Confirmaciones
    @State private var showDeleteConfirm = false

    @EnvironmentObject var profileStore: ProfileStore

    private let biometric = FluxBiometricAuthService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    parentProfileCard
                    profileCard
                    biometricSection
                    signalsSection
                    weProtectSection
                    vozSection
                    dataSection
                    lockSection
                    deleteSection
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(FluxColor.base)
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("listo") { dismiss() }
                        .font(FluxFont.body(14, weight: .semibold))
                        .foregroundStyle(FluxColor.primary)
                }
            }
        }
        .alert("¿Eliminar este perfil?", isPresented: $showDeleteConfirm) {
            Button("Eliminar", role: .destructive) { deleteActiveProfile() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borrarán los datos locales de este perfil. Esta acción no se puede deshacer.")
        }
        .fullScreenCover(isPresented: $showPairing) {
            let invitation = VozInvitation.generate(
                parentDeviceName: UIDevice.current.name,
                parentName: profileStore.activeProfile?.displayName ?? UIDevice.current.name,
                childName: "menor",
                childAge: 13
            )
            ProximityPairingView(role: .parent, invitation: invitation) { _ in
                // sin callback
            } onAcknowledged: { ack in
                guard ack.success, var active = profileStore.activeProfile else { return }
                print("[flux Pair] Parent: ack recibido · childName='\(ack.childName)' childDeviceName='\(ack.childDeviceName)' age=\(ack.childAge)")
                let candidate = ack.childName.isEmpty ? ack.childDeviceName : ack.childName
                let name = extractedChildName(from: candidate)
                if !active.monitoredChildren.contains(where: { $0.name == name }) {
                    active.monitoredChildren.append(
                        ChildProfile(name: name, age: ack.childAge, baselineApps: [])
                    )
                    profileStore.updateProfile(active)
                }
            }
        }
        .sheet(isPresented: $showPrivacy) { privacySheet }
        .sheet(isPresented: $showExportShare) {
            VozShareActivity(text: exportPayload)
        }
        .alert("¿Revocar acceso flux voz?", isPresented: $showRevokeConfirm) {
            Button("Revocar", role: .destructive) { revokeVozAccess() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se desvinculará a los menores monitoreados. Podrás reconectar después.")
        }
        .alert("¿Borrar todo el historial?", isPresented: $showClearHistoryConfirm) {
            Button("Borrar", role: .destructive) { clearLocalHistory() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminarán todas las entradas del buzón, huellas del foro y eventos locales.")
        }
    }

    private func extractedChildName(from deviceName: String) -> String {
        // "iPhone de María" → "María"
        let lower = deviceName.lowercased()
        if let range = lower.range(of: " de ") {
            let name = String(deviceName[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return name }
        }
        return deviceName
    }

    // MARK: - Monitored child card
    @ViewBuilder
    private var profileCard: some View {
        if let child = profileStore.activeProfile?.monitoredChildren.first {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(FluxColor.primary.opacity(0.12))
                    Text(String(child.name.prefix(1)).uppercased())
                        .font(FluxFont.display(20, weight: .bold))
                        .foregroundStyle(FluxColor.primary)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(child.name)
                        .font(FluxFont.display(17, weight: .bold))
                        .foregroundStyle(FluxColor.ink)
                    Text("\(child.age) años · monitoreo activo")
                        .font(FluxFont.body(12))
                        .foregroundStyle(FluxColor.inkMuted)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(FluxColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
            )
        } else {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.3, dash: [4, 4]))
                        .foregroundStyle(FluxColor.inkFaint)
                    Image(systemName: "person.fill.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FluxColor.inkFaint)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sin menores monitoreados")
                        .font(FluxFont.display(14, weight: .semibold))
                        .foregroundStyle(FluxColor.ink)
                    Text("usa «Conectar con un hijo» para vincular")
                        .font(FluxFont.body(12))
                        .foregroundStyle(FluxColor.inkMuted)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.3, dash: [5, 5]))
                    .foregroundStyle(FluxColor.line)
            )
        }
    }

    // MARK: - Parent profile card

    @ViewBuilder
    private var parentProfileCard: some View {
        if let active = profileStore.activeProfile {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(active.avatarColor)
                        .frame(width: 56, height: 56)
                        .shadow(color: active.avatarColor.opacity(0.35), radius: 10, y: 4)
                    Text(active.initial)
                        .font(FluxFont.display(22, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(active.role.modeLabel)
                        .font(FluxFont.mono(9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(active.avatarColor)
                    Text(active.displayName)
                        .font(FluxFont.display(17, weight: .bold))
                        .foregroundStyle(FluxColor.ink)
                    Text("\(active.monitoredChildren.count) menor\(active.monitoredChildren.count == 1 ? "" : "es") monitoreado\(active.monitoredChildren.count == 1 ? "" : "s")")
                        .font(FluxFont.body(12))
                        .foregroundStyle(FluxColor.inkMuted)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(FluxColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(FluxColor.line, lineWidth: 1))
            )
        }
    }

    // MARK: - Biometric

    private var biometricSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SEGURIDAD")
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
                        .font(FluxFont.body(14, weight: .semibold))
                        .foregroundStyle(FluxColor.ink)
                    Text(biometric.isAvailable ? "requerido al abrir tu perfil" : "no disponible en este dispositivo")
                        .font(FluxFont.body(12))
                        .foregroundStyle(FluxColor.inkMuted)
                }
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { profileStore.activeProfile?.biometricEnabled ?? false },
                        set: { newValue in
                            guard let p = profileStore.activeProfile else { return }
                            profileStore.toggleBiometric(for: p, enabled: newValue)
                        }
                    )
                )
                .labelsHidden()
                .tint(FluxColor.primary)
                .disabled(!biometric.isAvailable || profileStore.activeProfile == nil)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(FluxColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
            )
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ZONA PELIGROSA")
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(FluxColor.danger.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FluxColor.danger)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Eliminar perfil")
                            .font(FluxFont.body(14, weight: .semibold))
                            .foregroundStyle(FluxColor.ink)
                        Text("borra los datos locales de este perfil")
                            .font(FluxFont.body(12))
                            .foregroundStyle(FluxColor.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FluxColor.inkFaint)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(FluxColor.surface)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.danger.opacity(0.3), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .disabled(profileStore.activeProfile == nil)
        }
    }

    // MARK: - Privacy sheet

    private var privacySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Aviso de privacidad")
                        .font(FluxFont.display(22, weight: .bold))
                        .foregroundStyle(FluxColor.ink)
                    Text("LFPDPPP · Ley Federal de Protección de Datos Personales en Posesión de los Particulares")
                        .font(FluxFont.mono(10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(FluxColor.inkMuted)

                    privacyBlock(
                        title: "Procesamiento local",
                        body: "Todos los análisis de WeProtect, baselines de uso y entradas del buzón de flux voz se ejecutan y almacenan en tu dispositivo. Nada se envía a servidores externos."
                    )
                    privacyBlock(
                        title: "Pareo por proximidad",
                        body: "La conexión entre el teléfono del padre y del menor usa Bluetooth + Nearby Interaction (UWB). Los identificadores se generan localmente y se cifran con una clave compartida de 32 bytes que nunca sale del pairing."
                    )
                    privacyBlock(
                        title: "Biometría",
                        body: "Face ID / Touch ID se valida con el Secure Enclave de Apple. flux nunca tiene acceso al template biométrico."
                    )
                    privacyBlock(
                        title: "Tus derechos ARCO",
                        body: "Puedes Acceder, Rectificar, Cancelar u Oponerte al tratamiento de tus datos desde esta pantalla: «Exportar datos» y «Eliminar perfil»."
                    )
                }
                .padding(20)
            }
            .background(FluxColor.base)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("listo") { showPrivacy = false }
                        .foregroundStyle(FluxColor.primary)
                }
            }
        }
    }

    private func privacyBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FluxFont.display(15, weight: .bold))
                .foregroundStyle(FluxColor.ink)
            Text(body)
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.inkMuted)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    // MARK: - Helpers de datos

    private var hasMonitoredChildren: Bool {
        (profileStore.activeProfile?.monitoredChildren.count ?? 0) > 0
    }

    private func revokeVozAccess() {
        guard var active = profileStore.activeProfile else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        active.monitoredChildren.removeAll()
        profileStore.updateProfile(active)
    }

    private func clearLocalHistory() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        VozEntryStore.shared.clearAll()
        ForumStore.shared.clearAll()
        AlertCenter.shared.clearAll()
    }

    private func exportProfileData() {
        guard let active = profileStore.activeProfile else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(active),
           let json = String(data: data, encoding: .utf8) {
            exportPayload = json
            showExportShare = true
        }
    }

    private func deleteActiveProfile() {
        guard let p = profileStore.activeProfile else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            profileStore.deleteProfile(p)
            session.endLiveActivity()
        }
    }

    // MARK: - Signals
    private var signalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SEÑALES MONITOREADAS")

            VStack(spacing: 0) {
                toggleRow(
                    title: "Transiciones de plataforma",
                    subtitle: "Saltos sospechosos entre apps",
                    isOn: $platformTransition
                )
                Divider().padding(.leading, 14)
                toggleRow(
                    title: "Horarios atípicos",
                    subtitle: "Actividad nocturna anómala",
                    isOn: $atypicalHours
                )
                Divider().padding(.leading, 14)
                toggleRow(
                    title: "Instalaciones reactivas",
                    subtitle: "Mensajería tras uso intenso de red",
                    isOn: $reactiveInstall
                )
                Divider().padding(.leading, 14)
                toggleRow(
                    title: "Aislamiento digital",
                    subtitle: "Abandono repentino de apps",
                    isOn: $digitalIsolation
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(FluxColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
            )
        }
    }

    // MARK: - WeProtect
    private var weProtectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("WEPROTECT · \(ai.backendKind.label.uppercased())")

            VStack(spacing: 0) {
                toggleRow(
                    title: "Análisis automático al escanear",
                    subtitle: "WeProtect revisa capturas al subirlas",
                    isOn: $autoAnalysisOnScan
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(FluxColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
            )

            HStack(spacing: 6) {
                Image(systemName: ai.backendKind == .foundationModels ? "cpu" : "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                Text("On-device · nada sale de tu teléfono")
                    .font(FluxFont.mono(10, weight: .medium))
                    .tracking(0.5)
            }
            .foregroundStyle(FluxColor.primary)
            .padding(.top, 2)
            .padding(.leading, 4)
        }
    }

    // MARK: - Voz
    private var vozSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("FLUX VOZ")

            VStack(spacing: 0) {
                dashedRow(title: "Conectar con un hijo") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showPairing = true
                }
                Divider().padding(.leading, 14)
                dashedRow(
                    title: "Revocar acceso flux voz",
                    accent: hasMonitoredChildren ? FluxColor.ink : FluxColor.inkFaint
                ) {
                    guard hasMonitoredChildren else { return }
                    showRevokeConfirm = true
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(FluxColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
            )
        }
    }

    // MARK: - Data
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DATOS Y PRIVACIDAD")

            VStack(spacing: 0) {
                dashedRow(title: "Exportar datos") {
                    exportProfileData()
                }
                Divider().padding(.leading, 14)
                dashedRow(title: "Borrar todo el historial", accent: FluxColor.danger) {
                    showClearHistoryConfirm = true
                }
                Divider().padding(.leading, 14)
                dashedRow(title: "Aviso de privacidad · LFPDPPP") {
                    showPrivacy = true
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(FluxColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
            )
        }
    }

    // MARK: - Lock / Logout section

    private var lockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SESIÓN")

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    profileStore.lock()
                    session.endLiveActivity()
                }
            } label: {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Bloquear y cambiar de perfil")
                        .font(FluxFont.body(14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FluxColor.inkFaint)
                }
                .foregroundStyle(FluxColor.ink)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(FluxColor.surface)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(FluxColor.line, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(FluxFont.mono(9, weight: .bold))
            .tracking(2)
            .foregroundStyle(FluxColor.inkFaint)
            .padding(.leading, 4)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FluxFont.body(14, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)
                Text(subtitle)
                    .font(FluxFont.body(12))
                    .foregroundStyle(FluxColor.inkMuted)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(FluxColor.primary)
        }
        .padding(14)
    }

    private func dashedRow(title: String, accent: Color = FluxColor.ink, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(FluxFont.body(14, weight: .medium))
                    .foregroundStyle(accent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FluxColor.inkFaint)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSession())
}
