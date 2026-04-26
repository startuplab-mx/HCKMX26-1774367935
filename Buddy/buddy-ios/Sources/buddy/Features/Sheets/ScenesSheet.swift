import SwiftUI

enum SceneTheme: String, CaseIterable, Identifiable, Codable {
    case livingRoom, bedroom, garden, kitchen, beach

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .livingRoom: "Sala"
        case .bedroom:    "Recámara"
        case .garden:     "Jardín"
        case .kitchen:    "Cocina"
        case .beach:      "Playa"
        }
    }

    var emoji: String {
        switch self {
        case .livingRoom: "🛋️"
        case .bedroom:    "🛏️"
        case .garden:     "🌳"
        case .kitchen:    "🍳"
        case .beach:      "🏖️"
        }
    }

    /// Wide version used for the in-scene scrolling room.
    var assetName: String {
        switch self {
        case .livingRoom: "background_living_room_wide"
        case .bedroom:    "background_bedroom_wide"
        case .garden:     "background_garden_wide"
        case .kitchen:    "background_kitchen_wide"
        case .beach:      "background_beach_wide"
        }
    }

    /// Square version used for thumbnails / preview cards.
    var thumbnailAssetName: String {
        switch self {
        case .livingRoom: "background_living_room"
        case .bedroom:    "background_bedroom"
        case .garden:     "background_garden"
        case .kitchen:    "background_kitchen"
        case .beach:      "background_beach"
        }
    }

    /// No tint — each scene has a unique asset now.
    var tintColor: (r: Double, g: Double, b: Double, a: Double) { (1, 1, 1, 0) }

    /// Free for default; others cost coins.
    var unlockPrice: Int {
        switch self {
        case .livingRoom: 0
        case .bedroom:    50
        case .garden:     80
        case .kitchen:    120
        case .beach:      200
        }
    }
}

/// Persistencia de escenas desbloqueadas.
struct SceneStore {
    private static let unlockedKey = "buddy.scenes.unlocked.v1"
    private static let activeKey = "buddy.scene.active.v1"

    static func unlocked() -> Set<SceneTheme> {
        let arr = UserDefaults.standard.stringArray(forKey: unlockedKey) ?? [SceneTheme.livingRoom.rawValue]
        return Set(arr.compactMap { SceneTheme(rawValue: $0) })
    }
    static func unlock(_ s: SceneTheme) {
        var set = unlocked(); set.insert(s)
        UserDefaults.standard.set(set.map(\.rawValue), forKey: unlockedKey)
    }
    static func isUnlocked(_ s: SceneTheme) -> Bool { unlocked().contains(s) }
    static var active: SceneTheme {
        get { SceneTheme(rawValue: UserDefaults.standard.string(forKey: activeKey) ?? "livingRoom") ?? .livingRoom }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: activeKey) }
    }
}

struct ScenesSheet: View {
    let current: SceneTheme
    let coins: Int
    let onPick: (SceneTheme) -> Void
    let onUnlock: (SceneTheme) -> Bool   // returns true if had enough coins
    let onClose: () -> Void

    @State private var unlocked: Set<SceneTheme> = SceneStore.unlocked()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Escenarios")
                        .font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                        .foregroundStyle(Theme.darkInk)
                    Text("Cambia el ambiente donde vive Buddy")
                        .font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(Theme.darkInk.opacity(0.6))
                }
                Spacer()
                CloseButton(action: onClose)
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(SceneTheme.allCases) { s in
                        sceneCard(s)
                    }
                }
            }
        }
        .padding(20)
        .background(Theme.consoleBG.ignoresSafeArea())
    }

    private func sceneCard(_ s: SceneTheme) -> some View {
        let isUnlocked = unlocked.contains(s)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.lcdInner)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.lcdStroke, lineWidth: 2))
                Image(s.thumbnailAssetName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: 80, height: 64)
                    .overlay(
                        Color(red: s.tintColor.r, green: s.tintColor.g, blue: s.tintColor.b)
                            .opacity(s.tintColor.a)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                if !isUnlocked {
                    Color.black.opacity(0.5).clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack { Text("🔒"); Text(s.emoji) }.font(.system(size: 18))
                }
            }
            .frame(width: 96, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(s.emoji)
                    Text(s.displayName)
                        .font(.custom(Theme.pixelMono, size: 15).weight(.bold))
                        .foregroundStyle(Theme.darkInk)
                }
                if isUnlocked {
                    Text(s == current ? "Activo" : "Toca para usar")
                        .font(.custom(Theme.pixelMono, size: 11))
                        .foregroundStyle(s == current ? Theme.actionPink : Theme.darkInk.opacity(0.5))
                } else {
                    Button {
                        if onUnlock(s) {
                            unlocked.insert(s)
                            SceneStore.unlock(s)
                        }
                    } label: {
                        Text("Desbloquear · \(s.unlockPrice)🪙")
                            .font(.custom(Theme.pixelMono, size: 11).weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(coins >= s.unlockPrice ? Theme.actionPink : .gray))
                    }
                    .buttonStyle(.plain)
                    .disabled(coins < s.unlockPrice)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.lcdOuter)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.lcdStroke.opacity(0.4), lineWidth: 1))
        .onTapGesture {
            if isUnlocked { onPick(s) }
        }
    }
}
