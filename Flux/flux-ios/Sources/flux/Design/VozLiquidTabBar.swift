import SwiftUI
import UIKit

// MARK: - Liquid Glass Tab Bar · modo menor (flux voz)

struct VozLiquidTabBar: View {
    @Binding var selectedTab: VozTab
    let onScanTap: () -> Void

    @State private var showLabel: Bool = false
    @State private var selectedTabForLabel: VozTab? = nil

    enum VozTab: Int, CaseIterable {
        case buzon, forum, myCase, help

        var icon: String {
            switch self {
            case .buzon: "envelope.fill"
            case .forum: "circle.grid.hex.fill"
            case .myCase: "bubble.left.and.bubble.right.fill"
            case .help: "heart.fill"
            }
        }

        var label: String {
            switch self {
            case .buzon: "buzón"
            case .forum: "foro"
            case .myCase: "mi caso"
            case .help: "ayuda"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VozTabBarItem(
                    icon: VozTab.buzon.icon, label: VozTab.buzon.label,
                    isSelected: selectedTab == .buzon,
                    showLabel: showLabel && selectedTabForLabel == .buzon,
                    action: { handleTabTap(.buzon) }
                )
                VozTabBarItem(
                    icon: VozTab.forum.icon, label: VozTab.forum.label,
                    isSelected: selectedTab == .forum,
                    showLabel: showLabel && selectedTabForLabel == .forum,
                    action: { handleTabTap(.forum) }
                )
                Color.clear.frame(width: 56, height: 1)
                VozTabBarItem(
                    icon: VozTab.myCase.icon, label: VozTab.myCase.label,
                    isSelected: selectedTab == .myCase,
                    showLabel: showLabel && selectedTabForLabel == .myCase,
                    action: { handleTabTap(.myCase) }
                )
                VozTabBarItem(
                    icon: VozTab.help.icon, label: VozTab.help.label,
                    isSelected: selectedTab == .help,
                    showLabel: showLabel && selectedTabForLabel == .help,
                    action: { handleTabTap(.help) }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(vozLiquidBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedTab)
        .animation(.easeInOut(duration: 0.3), value: showLabel)
        // FAB fuera del flujo de layout
        .overlay(alignment: .top) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onScanTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [FluxColor.vozAccent.opacity(0.3), .clear],
                                center: .center, startRadius: 20, endRadius: 44
                            )
                        )
                        .frame(width: 92, height: 92)
                        .modifier(PulseHalo())

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [FluxColor.vozInk, Color(hex: 0x1C1915)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: FluxColor.vozInk.opacity(0.35), radius: 12, x: 0, y: 4)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )

                    Image(systemName: "viewfinder")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(FluxColor.voz)
                }
            }
            .offset(y: -18)
        }
    }

    private func handleTabTap(_ tab: VozTab) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        selectedTab = tab
        selectedTabForLabel = tab
        showLabel = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                self.showLabel = false
            }
        }
    }

    private var vozLiquidBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [FluxColor.voz.opacity(0.5), FluxColor.voz.opacity(0.2)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [FluxColor.vozAccent.opacity(0.3), FluxColor.vozAccent.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: FluxColor.vozInk.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Voz tab item

struct VozTabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let showLabel: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? activeGradient : inactiveGradient)
                    .opacity(showLabel ? 0 : 1)

                if showLabel {
                    Text(label)
                        .font(.custom("Inter-SemiBold", size: 11))
                        .foregroundStyle(FluxColor.vozInk)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 40)
            .frame(maxWidth: showLabel ? 100 : 40)
            .background(
                Capsule()
                    .fill(isSelected ? FluxColor.vozAccent.opacity(0.12) : Color.clear)
            )
            .scaleEffect(CGSize(width: isPressed ? 0.9 : 1.0, height: isPressed ? 0.9 : 1.0))
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.05, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }

    private var activeGradient: LinearGradient {
        LinearGradient(
            colors: [FluxColor.vozAccent, Color(hex: 0xB8884F)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var inactiveGradient: LinearGradient {
        LinearGradient(
            colors: [FluxColor.vozMuted, FluxColor.vozMuted],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}
