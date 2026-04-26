import SwiftUI
import UIKit

// MARK: - Liquid Glass Bubble Tab Bar (adaptado de Atenea para flux)

struct FluxLiquidTabBar: View {
    @Binding var selectedTab: FluxTab
    let onScanTap: () -> Void

    @State private var showLabel: Bool = false
    @State private var selectedTabForLabel: FluxTab? = nil

    enum FluxTab: Int, CaseIterable {
        case home, weProtect, community, forum

        var icon: String {
            switch self {
            case .home: "house.fill"
            case .weProtect: "sparkles"
            case .community: "person.3.fill"
            case .forum: "circle.grid.hex.fill"
            }
        }

        var label: String {
            switch self {
            case .home: "inicio"
            case .weProtect: "WeProtect"
            case .community: "comunidad"
            case .forum: "foro"
            }
        }
    }

    var body: some View {
        // Compact bubble tab bar — la altura del ZStack la define solo el pill
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                FluxTabBarItem(
                    icon: FluxTab.home.icon,
                    label: FluxTab.home.label,
                    isSelected: selectedTab == .home,
                    showLabel: showLabel && selectedTabForLabel == .home,
                    action: { handleTabTap(.home) }
                )

                FluxTabBarItem(
                    icon: FluxTab.weProtect.icon,
                    label: FluxTab.weProtect.label,
                    isSelected: selectedTab == .weProtect,
                    showLabel: showLabel && selectedTabForLabel == .weProtect,
                    action: { handleTabTap(.weProtect) }
                )

                // Espacio central para el FAB escáner
                Color.clear.frame(width: 56, height: 1)

                FluxTabBarItem(
                    icon: FluxTab.community.icon,
                    label: FluxTab.community.label,
                    isSelected: selectedTab == .community,
                    showLabel: showLabel && selectedTabForLabel == .community,
                    action: { handleTabTap(.community) }
                )

                FluxTabBarItem(
                    icon: FluxTab.forum.icon,
                    label: FluxTab.forum.label,
                    isSelected: selectedTab == .forum,
                    showLabel: showLabel && selectedTabForLabel == .forum,
                    action: { handleTabTap(.forum) }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(liquidGlassBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedTab)
        .animation(.easeInOut(duration: 0.3), value: showLabel)
        // FAB fuera del flujo de layout — centrado horizontalmente, flotando sobre el pill
        .overlay(alignment: .top) {
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onScanTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [FluxColor.primary.opacity(0.35), .clear],
                                center: .center, startRadius: 20, endRadius: 44
                            )
                        )
                        .frame(width: 92, height: 92)
                        .modifier(PulseHalo())

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [FluxColor.ink, Color(hex: 0x0B0D10)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: FluxColor.ink.opacity(0.35), radius: 12, x: 0, y: 4)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )

                    Image(systemName: "viewfinder")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(FluxColor.base)
                }
            }
            .offset(y: -18)
        }
    }

    // MARK: - Logic

    private func handleTabTap(_ tab: FluxTab) {
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

    // MARK: - Liquid Glass Background

    private var liquidGlassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Collapsible Tab Item

struct FluxTabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let showLabel: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? activeGradient : inactiveGradient)
                    .opacity(showLabel ? 0 : 1)

                // Label (aparece al tap)
                if showLabel {
                    Text(label)
                        .font(.custom("Inter-SemiBold", size: 11))
                        .foregroundStyle(FluxColor.ink)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 40)
            .frame(maxWidth: showLabel ? 100 : 40)
            .background(
                Capsule()
                    .fill(isSelected ? FluxColor.primary.opacity(0.12) : Color.clear)
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
            colors: [FluxColor.primary, Color(hex: 0x2DD4BF)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var inactiveGradient: LinearGradient {
        LinearGradient(
            colors: [FluxColor.inkFaint, FluxColor.inkFaint],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - Pulse halo modifier (para el FAB)

struct PulseHalo: ViewModifier {
    @State private var pulse: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulse)
            .opacity(2 - pulse)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulse = 1.15
                }
            }
    }
}
