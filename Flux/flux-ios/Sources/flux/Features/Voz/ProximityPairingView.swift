import SwiftUI

struct ProximityPairingView: View {
    let role: PairingRole
    let invitation: VozInvitation?
    let onComplete: (VozInvitation) -> Void
    let onAcknowledged: (VozAcknowledgement) -> Void

    @Environment(\.dismiss) var dismiss
    @StateObject private var service: ProximityPairingService
    @State private var pulse: CGFloat = 1

    init(
        role: PairingRole,
        invitation: VozInvitation? = nil,
        onComplete: @escaping (VozInvitation) -> Void = { _ in },
        onAcknowledged: @escaping (VozAcknowledgement) -> Void = { _ in }
    ) {
        self.role = role
        self.invitation = invitation
        self.onComplete = onComplete
        self.onAcknowledged = onAcknowledged
        _service = StateObject(wrappedValue: ProximityPairingService(role: role, invitation: invitation))
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 32) {
                header
                Spacer()
                proximityVisualizer
                Spacer()
                statusText
                cancelButton
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 40)
        }
        .onAppear {
            service.onPairingCompleted = { inv in
                onComplete(inv)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            }
            service.onInvitationSent = { ack in
                onAcknowledged(ack)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            }
            service.start()
        }
        .onDisappear { service.stop() }
    }

    // MARK: - Background
    @ViewBuilder
    private var background: some View {
        if role == .parent {
            LinearGradient(
                colors: [FluxColor.base, FluxColor.surfaceAlt],
                startPoint: .top, endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [FluxColor.voz, Color(hex: 0xF0E8D4)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 8) {
            Text(role == .parent ? "INVITAR A FLUX VOZ" : "CONECTAR CON TU ADULTO")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(3)
                .foregroundStyle(role == .parent ? FluxColor.primary : FluxColor.vozAccent)

            Text(role == .parent ? "Acerca tu teléfono al de \(invitation?.childName ?? "el menor")" : "Acerca tu teléfono al de un adulto de confianza")
                .font(FluxFont.display(24, weight: .bold))
                .kerning(-0.4)
                .foregroundStyle(role == .parent ? FluxColor.ink : FluxColor.vozInk)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Proximity visualizer
    private var proximityVisualizer: some View {
        ZStack {
            // Halo exterior
            Circle()
                .fill(ringColor.opacity(0.08))
                .frame(width: 280, height: 280)
                .scaleEffect(pulse)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

            Circle()
                .fill(ringColor.opacity(0.15))
                .frame(width: 200, height: 200)
                .scaleEffect(pulse * 0.92)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.3), value: pulse)

            // Centro
            Circle()
                .fill(
                    LinearGradient(
                        colors: [ringColor, ringColor.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
                .shadow(color: ringColor.opacity(0.4), radius: 20)
                .overlay(
                    VStack(spacing: 2) {
                        Image(systemName: iconName)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white)
                        if let d = service.peerDistance {
                            Text(distanceString(d))
                                .font(FluxFont.mono(11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                                .tracking(1)
                        }
                    }
                )
        }
        .onAppear { pulse = 1.15 }
    }

    // MARK: - Status
    private var statusText: some View {
        VStack(spacing: 8) {
            Text(statusTitle)
                .font(FluxFont.display(20, weight: .semibold))
                .kerning(-0.3)
                .foregroundStyle(role == .parent ? FluxColor.ink : FluxColor.vozInk)

            Text(statusSubtitle)
                .font(FluxFont.body(14))
                .foregroundStyle(role == .parent ? FluxColor.inkMuted : FluxColor.vozMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Cancel
    private var cancelButton: some View {
        Button { dismiss() } label: {
            Text("cancelar")
                .font(FluxFont.body(14, weight: .medium))
                .foregroundStyle(role == .parent ? FluxColor.inkMuted : FluxColor.vozMuted)
        }
    }

    // MARK: - Derived state
    private var ringColor: Color {
        switch service.phase {
        case .preparing, .waitingForPeer: role == .parent ? FluxColor.primary : FluxColor.vozAccent
        case .reading, .processing:       FluxColor.warn
        case .approved:                   FluxColor.safe
        case .declined:                   FluxColor.danger
        }
    }

    private var iconName: String {
        switch service.phase {
        case .preparing:      "antenna.radiowaves.left.and.right"
        case .waitingForPeer: "dot.radiowaves.left.and.right"
        case .reading:        "arrow.triangle.2.circlepath"
        case .processing:     "sparkles"
        case .approved:       "checkmark"
        case .declined:       "xmark"
        }
    }

    private var statusTitle: String {
        switch service.phase {
        case .preparing:      "preparando..."
        case .waitingForPeer: role == .parent ? "buscando al menor" : "buscando a un adulto"
        case .reading:        "casi listo..."
        case .processing:     "enviando"
        case .approved:       role == .parent ? "listo ✓" : "tu espacio está listo"
        case .declined:       "no se pudo conectar"
        }
    }

    private var statusSubtitle: String {
        switch service.phase {
        case .preparing:      "activando Bluetooth y UWB"
        case .waitingForPeer: "asegúrate que ambos tengan la app abierta"
        case .reading:        "acerca más los teléfonos, menos de 30 cm"
        case .processing:     "transfiriendo de forma segura"
        case .approved:       role == .parent ? "la invitación se entregó a \(service.receivedAck?.childDeviceName ?? "el menor")" : "flux voz ya está activa en tu teléfono"
        case .declined(let msg): msg
        }
    }

    private func distanceString(_ d: Float) -> String {
        let cm = d * 100
        if cm < 100 { return "\(Int(cm)) cm" }
        return String(format: "%.1f m", d)
    }
}

#Preview("Parent") {
    ProximityPairingView(
        role: .parent,
        invitation: VozInvitation.generate(parentDeviceName: "iPhone de Camila", parentName: "Camila Vega", childName: "Lucía", childAge: 13)
    )
}

#Preview("Child") {
    ProximityPairingView(role: .child)
}
