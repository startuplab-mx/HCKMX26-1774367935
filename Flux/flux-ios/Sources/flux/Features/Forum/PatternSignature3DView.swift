import SwiftUI
import RealityKit

// MARK: - 3D Signature visualization
// Constelación 3D de la huella: esferas glow por emoji, líneas conectando,
// texto 3D flotante con frases. Rota automático + drag interactivo.

struct PatternSignature3DView: View {
    let footprint: PatternFootprint

    @State private var rotationY: Float = 0
    @State private var rotationX: Float = 0
    @State private var dragStartY: Float = 0
    @State private var dragStartX: Float = 0
    @State private var isDragging = false
    @State private var autoRotate: Bool = true
    @State private var rootEntity: Entity = Entity()

    var body: some View {
        ZStack {
            backgroundView

            RealityView { content in
                let root = buildScene()
                self.rootEntity = root
                content.add(root)
            } update: { content in
                guard let root = content.entities.first else { return }
                let qX = simd_quatf(angle: rotationX, axis: [1, 0, 0])
                let qY = simd_quatf(angle: rotationY, axis: [0, 1, 0])
                root.transform.rotation = qY * qX
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            autoRotate = false
                            dragStartY = rotationY
                            dragStartX = rotationX
                        }
                        rotationY = dragStartY + Float(value.translation.width) * 0.008
                        rotationX = dragStartX - Float(value.translation.height) * 0.008
                    }
                    .onEnded { _ in
                        isDragging = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if !isDragging { autoRotate = true }
                        }
                    }
            )
            .onAppear {
                startAutoRotation()
            }

            VStack {
                Spacer()
                captionBar
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1A1D23), Color(hex: 0x0F1114)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Stars
            GeometryReader { geo in
                ForEach(0..<35, id: \.self) { _ in
                    Circle()
                        .fill(.white.opacity(Double.random(in: 0.2...0.6)))
                        .frame(width: CGFloat.random(in: 1...2.5), height: CGFloat.random(in: 1...2.5))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                }
            }

            // Glows
            Circle()
                .fill(FluxColor.primary.opacity(0.25))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -80, y: -60)

            Circle()
                .fill(FluxColor.accent.opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 90, y: 70)
        }
    }

    // MARK: - Scene builder

    private func buildScene() -> Entity {
        let root = Entity()

        let nodes = buildNodeData()

        // 3 esferas emoji
        for (idx, node) in nodes.enumerated() {
            let entity = makeEmojiNode(node: node, index: idx)
            root.addChild(entity)
        }

        // Texto 3D con frases
        let textNodes = buildTextNodes()
        for textNode in textNodes {
            if let entity = makeTextNode(textNode: textNode) {
                root.addChild(entity)
            }
        }

        // Líneas entre todos los pares
        let allPositions = nodes.map { $0.position } + textNodes.map { $0.position }
        for i in 0..<allPositions.count {
            for j in (i+1)..<allPositions.count {
                // solo conectar emojis ↔ emojis y emojis ↔ texto (no todos con todos)
                if i < nodes.count || j < nodes.count {
                    if let line = makeConnection(from: allPositions[i], to: allPositions[j]) {
                        root.addChild(line)
                    }
                }
            }
        }

        // Partículas de polvo
        for _ in 0..<18 {
            root.addChild(makeDustParticle())
        }

        return root
    }

    // MARK: - Emoji node

    private func makeEmojiNode(node: EmojiNode, index: Int) -> Entity {
        let container = Entity()

        // Glow core
        var glowMat = UnlitMaterial()
        glowMat.color = .init(tint: node.color.withAlphaComponent(0.75))
        let core = ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [glowMat])
        container.addChild(core)

        // Halo exterior semitransparente
        var haloMat = UnlitMaterial()
        haloMat.color = .init(tint: node.color.withAlphaComponent(0.2))
        let halo = ModelEntity(mesh: .generateSphere(radius: 0.085), materials: [haloMat])
        halo.components.set(OpacityComponent(opacity: 0.3))
        container.addChild(halo)

        // Emoji text como mesh 3D
        let mesh = MeshResource.generateText(
            node.emoji,
            extrusionDepth: 0.005,
            font: .systemFont(ofSize: 0.09),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        var textMat = UnlitMaterial()
        textMat.color = .init(tint: .white)
        let textEntity = ModelEntity(mesh: mesh, materials: [textMat])
        // Centrar el texto sobre el punto
        let bounds = textEntity.visualBounds(relativeTo: nil)
        textEntity.position = SIMD3<Float>(
            -bounds.extents.x / 2,
            -bounds.extents.y / 2,
            0.055
        )
        container.addChild(textEntity)

        container.position = node.position
        return container
    }

    // MARK: - Text node (phrases, platform, time)

    private func makeTextNode(textNode: TextNode) -> Entity? {
        let mesh = MeshResource.generateText(
            textNode.text,
            extrusionDepth: 0.002,
            font: .systemFont(ofSize: 0.035, weight: .semibold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor.white.withAlphaComponent(0.92))
        let entity = ModelEntity(mesh: mesh, materials: [mat])

        // Centrar
        let bounds = entity.visualBounds(relativeTo: nil)
        entity.position = SIMD3<Float>(
            textNode.position.x - bounds.extents.x / 2,
            textNode.position.y - bounds.extents.y / 2,
            textNode.position.z
        )

        // Billboard effect approximado — orientar siempre hacia frente
        // (RealityKit billboard real requiere BillboardComponent iOS 18+)
        if #available(iOS 18.0, *) {
            entity.components.set(BillboardComponent())
        }

        return entity
    }

    // MARK: - Connection line

    private func makeConnection(from a: SIMD3<Float>, to b: SIMD3<Float>) -> Entity? {
        let midpoint = (a + b) / 2
        let delta = b - a
        let length = simd_length(delta)
        guard length > 0.001 else { return nil }
        let direction = simd_normalize(delta)

        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor.white.withAlphaComponent(0.18))
        let cylinder = ModelEntity(
            mesh: .generateCylinder(height: length, radius: 0.0018),
            materials: [mat]
        )

        let up: SIMD3<Float> = [0, 1, 0]
        let dot = simd_dot(up, direction)
        if abs(dot) < 0.999 {
            let axis = simd_normalize(simd_cross(up, direction))
            let angle = acos(dot)
            cylinder.transform.rotation = simd_quatf(angle: angle, axis: axis)
        } else if dot < 0 {
            cylinder.transform.rotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        }

        cylinder.position = midpoint
        return cylinder
    }

    // MARK: - Dust particles

    private func makeDustParticle() -> Entity {
        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor.white.withAlphaComponent(0.5))
        let particle = ModelEntity(mesh: .generateSphere(radius: 0.007), materials: [mat])
        particle.position = SIMD3<Float>(
            Float.random(in: -0.6...0.6),
            Float.random(in: -0.45...0.45),
            Float.random(in: -0.35...0.35)
        )
        return particle
    }

    // MARK: - Caption overlay

    private var captionBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: 0x4ADE80))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color(hex: 0x4ADE80), radius: 3)
                Text("HUELLA · CASO \(footprint.id)")
                    .font(FluxFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Text("MATCH × \(footprint.matchCount)")
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - Auto rotation

    private func startAutoRotation() {
        Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            guard autoRotate else { return }
            rotationY += 0.003
        }
    }

    // MARK: - Data

    private struct EmojiNode {
        let emoji: String
        let position: SIMD3<Float>
        let color: UIColor
    }

    private struct TextNode {
        let text: String
        let position: SIMD3<Float>
    }

    private func buildNodeData() -> [EmojiNode] {
        let emojis = footprint.emojis.isEmpty ? ["●"] : footprint.emojis
        let positions: [SIMD3<Float>] = [
            [-0.22, 0.14, 0.08],
            [0.2, 0.03, -0.08],
            [-0.02, -0.2, 0.10]
        ]
        let colors: [UIColor] = [
            UIColor(red: 0.98, green: 0.44, blue: 0.52, alpha: 1),
            UIColor(red: 0.85, green: 0.47, blue: 0.02, alpha: 1),
            UIColor(red: 0.18, green: 0.83, blue: 0.75, alpha: 1)
        ]

        var result: [EmojiNode] = []
        for (i, emoji) in emojis.prefix(3).enumerated() {
            result.append(EmojiNode(
                emoji: emoji,
                position: positions[i % positions.count],
                color: colors[i % colors.count]
            ))
        }
        return result
    }

    private func buildTextNodes() -> [TextNode] {
        var result: [TextNode] = []

        if let phrase = footprint.phrases.first {
            let truncated = phrase.count > 28 ? String(phrase.prefix(26)) + "…" : phrase
            result.append(TextNode(
                text: "\"\(truncated)\"",
                position: [-0.3, -0.1, -0.02]
            ))
        }

        if let platform = footprint.platforms.first {
            let route = footprint.platforms.count >= 2
                ? "\(footprint.platforms[0].rawValue) → \(footprint.platforms[1].rawValue)"
                : platform.rawValue
            result.append(TextNode(
                text: route,
                position: [0.22, 0.23, 0.02]
            ))
        }

        result.append(TextNode(
            text: footprint.timeWindow.rawValue,
            position: [0.25, -0.2, 0.08]
        ))

        return result
    }
}

#Preview {
    PatternSignature3DView(footprint: PatternFootprint.mock[0])
        .frame(height: 320)
        .padding(20)
        .background(FluxColor.base)
}
