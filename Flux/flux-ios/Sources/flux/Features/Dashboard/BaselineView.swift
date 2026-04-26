import SwiftUI

// MARK: - Baseline view · "¿cómo se ve un día normal?"
// Contexto educativo: muestra la línea base del menor para que el padre
// entienda qué es desvío y qué no. Evita el alarmismo constante.

struct BaselineView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) var dismiss

    private var profile: ChildProfile {
        profileStore.activeProfile?.monitoredChildren.first
            ?? session.activeChildProfile
            ?? ChildProfile(name: "tu hij@", age: 13, baselineApps: [])
    }

    // Mock de uso por hora del día (0–23) en minutos
    private let hourlyUsage: [Double] = [
        0, 0, 0, 0, 0, 0,           // 00-05
        5, 12, 28, 15, 10, 18,       // 06-11
        22, 35, 30, 24, 20, 25,      // 12-17
        40, 55, 42, 30, 18, 8        // 18-23
    ]

    private let appUsage: [(name: String, icon: String, minutes: Int, color: Color)] = [
        ("TikTok", "play.rectangle.fill", 134, .pink),
        ("Instagram", "camera.fill", 62, .purple),
        ("WhatsApp", "message.fill", 48, .green),
        ("YouTube", "play.tv.fill", 32, .red),
        ("Spotify", "music.note", 24, .mint)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                hourlyChart
                appsSection
                observationCard
                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(FluxColor.base)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("volver")
                            .font(FluxFont.body(14, weight: .medium))
                    }
                    .foregroundStyle(FluxColor.ink)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LÍNEA BASE · ÚLTIMOS 30 DÍAS")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(FluxColor.primary)
            Text("Día normal de \(profile.name)")
                .font(FluxFont.display(26, weight: .bold))
                .kerning(-0.7)
                .foregroundStyle(FluxColor.ink)
            Text("Así se ve su actividad habitual. Cualquier desvío es lo que flux detecta.")
                .font(FluxFont.body(13))
                .foregroundStyle(FluxColor.inkMuted)
                .lineSpacing(2)
                .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    // MARK: - Hourly chart

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HORARIOS DE USO")
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)

            let maxValue = hourlyUsage.max() ?? 1

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(hourlyUsage.enumerated()), id: \.offset) { idx, value in
                    let normalized = value / maxValue
                    let opacity = 0.25 + min(normalized, 1.0) * 0.65
                    let height = max(4, CGFloat(normalized) * 100)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(FluxColor.primary.opacity(opacity))
                        .frame(height: height)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)

            HStack {
                chartLabel("6am", at: .leading)
                Spacer()
                chartLabel("12pm", at: .leading)
                Spacer()
                chartLabel("6pm", at: .leading)
                Spacer()
                chartLabel("12am", at: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(FluxColor.surfaceAlt)
        )
    }

    private func chartLabel(_ text: String, at alignment: HorizontalAlignment) -> some View {
        Text(text)
            .font(FluxFont.mono(9, weight: .medium))
            .foregroundStyle(FluxColor.inkFaint)
    }

    // MARK: - Apps section

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APPS MÁS USADAS · PROMEDIO DIARIO")
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2)
                .foregroundStyle(FluxColor.inkFaint)

            VStack(spacing: 10) {
                ForEach(appUsage, id: \.name) { app in
                    appRow(app)
                }
            }
        }
    }

    private func appRow(_ app: (name: String, icon: String, minutes: Int, color: Color)) -> some View {
        let maxMinutes = appUsage.map(\.minutes).max() ?? 1
        let ratio = Double(app.minutes) / Double(maxMinutes)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(app.color.opacity(0.15))
                    Image(systemName: app.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(app.color)
                }
                .frame(width: 34, height: 34)

                Text(app.name)
                    .font(FluxFont.body(14, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)

                Spacer()

                Text(formatMinutes(app.minutes))
                    .font(FluxFont.mono(11, weight: .bold))
                    .foregroundStyle(FluxColor.inkMuted)
            }

            // Barra relativa
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(FluxColor.surfaceAlt)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(app.color.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(ratio))
                }
            }
            .frame(height: 5)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FluxColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(FluxColor.line, lineWidth: 1))
        )
    }

    private func formatMinutes(_ mins: Int) -> String {
        if mins < 60 { return "\(mins)m / día" }
        let h = mins / 60
        let m = mins % 60
        if m == 0 { return "\(h)h / día" }
        return "\(h)h \(m)m / día"
    }

    // MARK: - Observation card

    private var observationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(FluxColor.safe.opacity(0.15))
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FluxColor.safe)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text("OBSERVACIÓN")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.safe)
                Text("Los últimos 30 días su patrón ha sido estable.")
                    .font(FluxFont.body(14, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)
                Text("El cambio reciente (transición TikTok → Discord entre 2 y 4 AM) es lo que genera alerta.")
                    .font(FluxFont.body(13))
                    .foregroundStyle(FluxColor.inkMuted)
                    .lineSpacing(2)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(FluxColor.safe.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(FluxColor.safe.opacity(0.2), lineWidth: 1))
        )
    }
}

#Preview {
    NavigationStack {
        BaselineView()
            .environmentObject(AppSession())
    }
}
