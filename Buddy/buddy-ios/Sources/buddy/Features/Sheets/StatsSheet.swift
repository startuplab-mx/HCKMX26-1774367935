import SwiftUI

struct StatsSheet: View {
    let pet: Pet
    let needs: [PetNeed]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider().background(Theme.lcdStroke)
            statsList
            if !needs.isEmpty {
                Divider().background(Theme.lcdStroke)
                needsSection
            }
            Spacer()
        }
        .padding(20)
        .background(Theme.consoleBG.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
                Text("\(pet.character.displayName) · \(pet.ageInDays) días")
                    .font(.custom(Theme.pixelMono, size: 12))
                    .foregroundStyle(Theme.darkInk.opacity(0.6))
            }
            Spacer()
            Button(action: onClose) {
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

    private var statsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            statRow(label: "Hambre",    value: pet.stats.hunger,    color: Color(red: 0.91, green: 0.45, blue: 0.28), icon: "🍖")
            statRow(label: "Sed",       value: pet.stats.thirst,    color: Color(red: 0.36, green: 0.71, blue: 0.91), icon: "💧")
            statRow(label: "Energía",   value: pet.stats.energy,    color: Color(red: 0.96, green: 0.78, blue: 0.30), icon: "⚡")
            statRow(label: "Higiene",   value: pet.stats.hygiene,   color: Color(red: 0.55, green: 0.80, blue: 0.65), icon: "🧼")
            statRow(label: "Felicidad", value: pet.stats.happiness, color: Color(red: 0.88, green: 0.32, blue: 0.55), icon: "❤")
        }
    }

    private func statRow(label: String, value: Int, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(icon)  \(label)")
                    .font(.custom(Theme.pixelMono, size: 13))
                    .foregroundStyle(Theme.darkInk)
                Spacer()
                Text("\(value)/100")
                    .font(.custom(Theme.pixelMono, size: 13).weight(.bold))
                    .foregroundStyle(value < 30 ? .red : Theme.darkInk)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.darkInk.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * CGFloat(value) / 100))
                }
            }
            .frame(height: 10)
        }
    }

    private var needsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Necesidades urgentes")
                .font(.custom(Theme.pixelMono, size: 12).weight(.bold))
                .foregroundStyle(Theme.darkInk.opacity(0.6))
            ForEach(needs) { need in
                HStack {
                    Text(need.emoji)
                    Text(need.label)
                        .font(.custom(Theme.pixelMono, size: 13))
                        .foregroundStyle(Theme.darkInk)
                    Spacer()
                    Text("→ \(need.actionLabel)")
                        .font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(Theme.actionPink)
                }
            }
        }
    }
}
