import SwiftUI

struct ShopSheet: View {
    let coins: Int
    let onBuy: (ShopItem) -> Bool
    let onConsume: (ShopItem) -> Void
    let onEquip: (ShopItem?) -> Void   // nil = unequip
    let onClose: () -> Void

    @State private var category: ShopCategory = .food
    @State private var owned: Set<String> = InventoryStore.owned()
    @State private var equippedID: String? = InventoryStore.equippedAccessoryID
    @State private var lastAction: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tienda")
                        .font(.custom(Theme.pixelMono, size: 22).weight(.bold))
                        .foregroundStyle(Theme.darkInk)
                    HStack(spacing: 4) {
                        Text("\(coins) 🪙").font(.custom(Theme.pixelMono, size: 13))
                            .foregroundStyle(Theme.actionPink)
                        if !lastAction.isEmpty {
                            Text("· \(lastAction)").font(.custom(Theme.pixelMono, size: 11))
                                .foregroundStyle(Theme.darkInk.opacity(0.6))
                        }
                    }
                }
                Spacer()
                CloseButton(action: onClose)
            }
            categoryTabs
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(ShopCatalog.items(in: category)) { item in
                        itemRow(item)
                    }
                }
            }
        }
        .padding(20)
        .background(Theme.consoleBG.ignoresSafeArea())
    }

    private var categoryTabs: some View {
        HStack(spacing: 6) {
            ForEach(ShopCategory.allCases) { c in
                Button { category = c } label: {
                    Text(c.label)
                        .font(.custom(Theme.pixelMono, size: 12))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(c == category ? Theme.actionPink : Theme.buttonBG)
                        .foregroundStyle(c == category ? .white : Theme.darkInk)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func itemRow(_ item: ShopItem) -> some View {
        let isOwned = owned.contains(item.id)
        let isCosmetic = item.category == .accessories || item.category == .cosmetics
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.lcdInner)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.lcdStroke, lineWidth: 2))
                Text(item.emoji).font(.system(size: 32))
            }
            .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.custom(Theme.pixelMono, size: 14).weight(.bold)).foregroundStyle(Theme.darkInk)
                if !item.effects.isEmpty {
                    Text(effectsLabel(item.effects))
                        .font(.custom(Theme.pixelMono, size: 10))
                        .foregroundStyle(Theme.darkInk.opacity(0.6))
                } else {
                    Text(isCosmetic ? "Cosmético" : "")
                        .font(.custom(Theme.pixelMono, size: 10))
                        .foregroundStyle(Theme.darkInk.opacity(0.5))
                }
            }
            Spacer()
            if isCosmetic && isOwned {
                let isEquipped = equippedID == item.id
                Button {
                    if isEquipped {
                        equippedID = nil
                        InventoryStore.equippedAccessoryID = nil
                        onEquip(nil)
                        lastAction = "Quitaste \(item.name)"
                    } else {
                        equippedID = item.id
                        InventoryStore.equippedAccessoryID = item.id
                        onEquip(item)
                        lastAction = "Pusiste \(item.name)"
                    }
                } label: {
                    Text(isEquipped ? "Quitar" : "Poner")
                        .font(.custom(Theme.pixelMono, size: 11).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(isEquipped ? Color.gray : Theme.actionPink))
                }
                .buttonStyle(.plain)
            } else if !isCosmetic {
                // Consumibles: comprar = consumir directo
                Button {
                    if onBuy(item) {
                        onConsume(item)
                        lastAction = "✓ \(item.name) consumido"
                    } else {
                        lastAction = "✗ Sin monedas"
                    }
                } label: {
                    Text("\(item.price)🪙")
                        .font(.custom(Theme.pixelMono, size: 12).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(coins >= item.price ? Theme.actionPink : .gray))
                }
                .buttonStyle(.plain)
                .disabled(coins < item.price)
            } else {
                Button {
                    if onBuy(item) {
                        owned.insert(item.id)
                        InventoryStore.add(item.id)
                        lastAction = "✓ \(item.name) comprado"
                    } else {
                        lastAction = "✗ Sin monedas"
                    }
                } label: {
                    Text("\(item.price)🪙")
                        .font(.custom(Theme.pixelMono, size: 12).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(coins >= item.price ? Theme.actionPink : .gray))
                }
                .buttonStyle(.plain)
                .disabled(coins < item.price)
            }
        }
        .padding(10)
        .background(Theme.buttonBG)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func effectsLabel(_ effects: [String: Int]) -> String {
        let map: [String: String] = ["hunger": "🍖", "thirst": "💧", "energy": "⚡", "hygiene": "🧼", "happiness": "❤️"]
        return effects.map { "\(map[$0.key] ?? $0.key)+\($0.value)" }.joined(separator: " ")
    }
}
