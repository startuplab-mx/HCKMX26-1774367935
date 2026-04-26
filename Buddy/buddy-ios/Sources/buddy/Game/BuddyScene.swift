import SpriteKit
import SwiftUI
import UIKit

/// 2D top-down-ish scene with depth. The player walks in a 2D floor plane
/// (X horizontal, Y depth — moving up = walking away from viewer).
/// Sprites scale down with depth and the camera follows the player horizontally
/// when the world is wider than the screen.
final class BuddyScene: SKScene {

    // MARK: - World layout

    /// Visible viewport size.
    private let viewSize = CGSize(width: 390, height: 540)
    /// Total room width (world is wider than screen → camera scrolls).
    private let worldWidth: CGFloat = 1170   // 3× viewport
    /// Floor (walkable) area defined in world coordinates.
    /// floorBottomY = closest to viewer (sprites at full scale, big z)
    /// floorTopY    = furthest from viewer (sprites scaled down, smaller z)
    private let floorBottomY: CGFloat = 40
    private let floorTopY: CGFloat = 230
    /// Depth scale at the front (Y=floorBottomY) vs back (Y=floorTopY).
    private let depthScaleFront: CGFloat = 1.0
    private let depthScaleBack: CGFloat = 0.55

    // MARK: - Nodes

    private var background: SKSpriteNode?
    private var pet: SKSpriteNode?
    private var player: SKSpriteNode?
    private let cam = SKCameraNode()

    // MARK: - State

    private var playerVelocity: CGVector = .zero
    private var lastUpdate: TimeInterval = 0
    private var playerFacingRight = true
    private var needBubble: SKNode?
    private var draggingPet = false
    private var dragOffsetWorld: CGPoint = .zero
    private var lastTapAt: TimeInterval = 0
    private var consecutiveTaps = 0
    private var petWanderTask: Task<Void, Never>?
    private var petFacingRight = true
    private var accessoryNode: SKLabelNode?
    private var wasPlayerNearby = false

    // MARK: - Sprite sheets (4×4 grid)

    private let playerSheet = SpriteSheet(imageNamed: "player_sheet", columns: 4, rows: 4)
    private var petSheet = SpriteSheet(imageNamed: "pet_sheet", columns: 4, rows: 4)
    private var backgroundAsset = "background_living_room_wide"

    // Sizes at depthScaleFront (full size). They get scaled down with depth.
    private let petSpriteSize    = CGSize(width: 56, height: 56)
    private let playerSpriteSize = CGSize(width: 48, height: 72)

    // MARK: - Callbacks (UI side)

    var onPetTap: (() -> Void)?
    var onPlayerTap: (() -> Void)?
    var onPetDoubleTap: (() -> Void)?
    var onPetReleased: (() -> Void)?
    var onPlayerNearPet: (() -> Void)?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        scaleMode = .aspectFill
        size = viewSize
        backgroundColor = .black
        anchorPoint = .zero

        addChild(cam)
        camera = cam
        cam.position = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)

        addBackground()
        addPet()
        addPlayer()
        startPetWandering()
    }

    // MARK: - Background

    private func addBackground() {
        let tex = SKTexture(imageNamed: backgroundAsset)
        tex.filteringMode = .nearest
        let bg = SKSpriteNode(texture: tex)
        bg.anchorPoint = .zero
        bg.position = .zero
        // Scale uniformly so the background height matches the viewport.
        // The wide background is composed for ~3:1 ratio, so scaling by Y
        // already makes it cover the world width almost exactly.
        let scale = viewSize.height / tex.size().height
        bg.setScale(scale)
        let scaledWidth = tex.size().width * scale
        // If the scaled bg is narrower than the world, stretch X just enough to fill.
        // If wider, leave it (extra is hidden off-camera).
        if scaledWidth < worldWidth {
            bg.xScale = (worldWidth / tex.size().width)
        }
        bg.zPosition = 0
        addChild(bg)
        background = bg
    }

    func setBackground(asset: String) {
        guard backgroundAsset != asset else { return }
        backgroundAsset = asset
        background?.removeFromParent()
        addBackground()
    }

    // MARK: - Pet

    private func addPet() {
        let idle = petSheet.frames(row: 0, cols: 0..<4)
        let node = SKSpriteNode(texture: idle.first)
        node.size = petSpriteSize
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = CGPoint(x: worldWidth * 0.55, y: floorBottomY + 40)
        node.texture?.filteringMode = .nearest
        addChild(node)
        node.run(.repeatForever(.animate(with: idle, timePerFrame: 0.4, resize: false, restore: true)), withKey: "petAnim")
        pet = node
        applyDepth(to: node)
    }

    func setPetCharacter(asset: String) {
        petSheet = SpriteSheet(imageNamed: asset, columns: 4, rows: 4)
        guard let pet else { return }
        pet.removeAction(forKey: "petAnim")
        let idle = petSheet.frames(row: 0, cols: 0..<4)
        pet.texture = idle.first
        pet.run(.repeatForever(.animate(with: idle, timePerFrame: 0.4, resize: false, restore: true)), withKey: "petAnim")
        startPetWandering()
    }

    // MARK: - Player

    private func addPlayer() {
        let idle = playerSheet.frames(row: 0, cols: 0..<4)
        let node = SKSpriteNode(texture: idle.first)
        node.texture?.filteringMode = .nearest
        node.size = playerSpriteSize
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = CGPoint(x: worldWidth * 0.30, y: floorBottomY + 40)
        addChild(node)
        node.run(.repeatForever(.animate(with: idle, timePerFrame: 0.5, resize: false, restore: true)), withKey: "playerAnim")
        player = node
        applyDepth(to: node)
    }

    // MARK: - Touches (drag pet, tap pet/player)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)  // already in world coords (camera handles transform)
        if let pet, pet.frame.contains(p) {
            let now = CACurrentMediaTime()
            if now - lastTapAt < 0.4 {
                consecutiveTaps += 1
                if consecutiveTaps >= 2 {
                    onPetDoubleTap?()
                    consecutiveTaps = 0
                }
            } else {
                consecutiveTaps = 1
            }
            lastTapAt = now

            draggingPet = true
            dragOffsetWorld = CGPoint(x: p.x - pet.position.x, y: p.y - pet.position.y)
            stopPetWandering()
            UISelectionFeedbackGenerator().selectionChanged()
            onPetTap?()
            return
        }
        if let player, player.frame.contains(p) {
            onPlayerTap?()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard draggingPet, let t = touches.first, let pet else { return }
        let p = t.location(in: self)
        let newX = (p.x - dragOffsetWorld.x).clamped(to: 30...(worldWidth - 30))
        let newY = (p.y - dragOffsetWorld.y).clamped(to: floorBottomY...floorTopY)
        pet.position = CGPoint(x: newX, y: newY)
        applyDepth(to: pet)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if draggingPet {
            draggingPet = false
            startPetWandering()
            onPetReleased?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        draggingPet = false
        startPetWandering()
    }

    // MARK: - Pet AI (2D wandering)

    private func startPetWandering() {
        petWanderTask?.cancel()
        petWanderTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(.random(in: 4...10)))
                self?.wanderTick()
            }
        }
    }

    private func wanderTick() {
        guard let pet, let player else { return }
        // 25% of the time, walk toward the player (curiosity).
        let target: CGPoint
        if Int.random(in: 0..<4) == 0 {
            target = CGPoint(
                x: player.position.x + CGFloat.random(in: -40...40),
                y: player.position.y + CGFloat.random(in: -20...20)
            )
        } else {
            target = CGPoint(
                x: CGFloat.random(in: 60...(worldWidth - 60)),
                y: CGFloat.random(in: floorBottomY...floorTopY)
            )
        }
        let dx = target.x - pet.position.x
        if dx > 5 { petFacingRight = true; pet.xScale = abs(pet.xScale) }
        else if dx < -5 { petFacingRight = false; pet.xScale = -abs(pet.xScale) }
        let distance = hypot(dx, target.y - pet.position.y)
        let duration = TimeInterval(min(2.5, distance / 50))
        pet.run(.move(to: clampToFloor(target), duration: duration)) { [weak self] in
            if let self, let pet = self.pet { self.applyDepth(to: pet) }
        }
        // Update depth gradually during the move via update loop (next ticks)
    }

    func stopPetWandering() {
        petWanderTask?.cancel()
        petWanderTask = nil
    }

    private func clampToFloor(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x.clamped(to: 30...(worldWidth - 30)),
                y: p.y.clamped(to: floorBottomY...floorTopY))
    }

    // MARK: - Public input

    /// Velocity in normalized units (-1...1 each axis).
    /// dx > 0 = walk right ; dy < 0 = walk up (deeper into room) ; dy > 0 = walk down (toward viewer).
    func setPlayerVelocity(_ v: CGVector) {
        playerVelocity = v
        updatePlayerAnimation()
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 0.05)
        lastUpdate = currentTime

        guard let player else { return }
        let speedX: CGFloat = 110
        let speedY: CGFloat = 60   // depth axis is slower (perspective)
        let dx = playerVelocity.dx * speedX * CGFloat(dt)
        let dy = -playerVelocity.dy * speedY * CGFloat(dt)  // joystick dy positive = down on screen
        let newX = (player.position.x + dx).clamped(to: 30...(worldWidth - 30))
        let newY = (player.position.y + dy).clamped(to: floorBottomY...floorTopY)
        player.position = CGPoint(x: newX, y: newY)
        applyDepth(to: player)

        // Facing
        if playerVelocity.dx > 0.05 && !playerFacingRight {
            playerFacingRight = true
            player.xScale = abs(player.xScale)
        } else if playerVelocity.dx < -0.05 && playerFacingRight {
            playerFacingRight = false
            player.xScale = -abs(player.xScale)
        }

        // Camera follow X (clamped so we don't show beyond the world edges)
        let camMinX = viewSize.width / 2
        let camMaxX = worldWidth - viewSize.width / 2
        cam.position.x = newX.clamped(to: camMinX...camMaxX)
        cam.position.y = viewSize.height / 2

        // Continuous pet depth update (in case it's mid-action)
        if let pet { applyDepth(to: pet) }

        // Pet faces player when nearby
        if let pet, !draggingPet {
            let distance = hypot(pet.position.x - player.position.x, pet.position.y - player.position.y)
            if distance < 80 {
                let shouldFaceRight = player.position.x > pet.position.x
                if shouldFaceRight != petFacingRight {
                    petFacingRight = shouldFaceRight
                    pet.xScale = shouldFaceRight ? abs(pet.xScale) : -abs(pet.xScale)
                }
                if !wasPlayerNearby { wasPlayerNearby = true; onPlayerNearPet?() }
            } else if wasPlayerNearby {
                wasPlayerNearby = false
            }
        }
    }

    /// Apply perspective: scale + zPosition based on Y position in floor area.
    private func applyDepth(to node: SKSpriteNode) {
        let ratio = ((node.position.y - floorBottomY) / (floorTopY - floorBottomY)).clamped(to: 0...1)
        let scale = depthScaleFront - (depthScaleFront - depthScaleBack) * ratio
        node.yScale = scale
        // Preserve current x flip direction (sign), but apply scale magnitude
        node.xScale = node.xScale >= 0 ? scale : -scale
        // zPosition: front (low Y) = high z, back (high Y) = low z
        node.zPosition = 100 - node.position.y
    }

    private func updatePlayerAnimation() {
        guard let player else { return }
        let absX = abs(playerVelocity.dx)
        let absY = abs(playerVelocity.dy)
        let movingHorizontal = absX > 0.05 && absX >= absY
        let movingVertical   = absY > 0.05 && absY > absX
        player.removeAction(forKey: "playerAnim")
        if movingHorizontal {
            let walk = playerSheet.frames(row: 1, cols: 0..<4)
            player.run(.repeatForever(.animate(with: walk, timePerFrame: 0.12, resize: false, restore: true)), withKey: "playerAnim")
        } else if movingVertical {
            let walk = playerSheet.frames(row: 2, cols: 0..<4)
            player.run(.repeatForever(.animate(with: walk, timePerFrame: 0.14, resize: false, restore: true)), withKey: "playerAnim")
        } else {
            let idle = playerSheet.frames(row: 0, cols: 0..<4)
            player.run(.repeatForever(.animate(with: idle, timePerFrame: 0.5, resize: false, restore: true)), withKey: "playerAnim")
        }
    }

    // MARK: - Cosmetics, animations & legacy actions

    func setAccessory(emoji: String?) {
        accessoryNode?.removeFromParent()
        accessoryNode = nil
        guard let emoji, let pet else { return }
        let label = SKLabelNode(text: emoji)
        label.fontSize = 18
        label.zPosition = 25
        label.position = CGPoint(x: 0, y: petSpriteSize.height + 4)
        pet.addChild(label)
        accessoryNode = label
    }

    func feedItem(emoji: String) {
        guard let pet else { return }
        let food = SKLabelNode(text: emoji)
        food.fontSize = 28
        food.zPosition = pet.zPosition + 1
        food.position = CGPoint(x: pet.position.x + CGFloat.random(in: -20...20), y: pet.position.y + viewSize.height)
        addChild(food)
        let drop = SKAction.move(to: CGPoint(x: pet.position.x, y: pet.position.y + petSpriteSize.height * 0.3), duration: 0.6)
        drop.timingMode = .easeIn
        let eatFrames = petSheet.frames(row: 2, cols: 0..<4)
        let petEatAction = SKAction.animate(with: eatFrames, timePerFrame: 0.18, resize: false, restore: true)
        food.run(.sequence([drop, .group([.scale(to: 0.1, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        pet.run(petEatAction)
    }

    func giveWaterAnimation() { feedItem(emoji: "💧") }

    func bathAnimation() {
        guard let pet else { return }
        for _ in 0..<6 {
            let bubble = SKLabelNode(text: ["🫧", "💦", "🧼"].randomElement()!)
            bubble.fontSize = 22
            bubble.zPosition = pet.zPosition + 1
            bubble.position = CGPoint(x: pet.position.x + CGFloat.random(in: -25...25), y: pet.position.y + petSpriteSize.height * 0.5)
            addChild(bubble)
            bubble.run(.sequence([.group([.moveBy(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: 30...50), duration: 0.8), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
        }
    }

    func sleepAnimation() {
        guard let pet else { return }
        let z = SKLabelNode(text: "Z")
        z.fontSize = 24
        z.fontColor = .white
        z.zPosition = pet.zPosition + 1
        z.position = CGPoint(x: pet.position.x + 12, y: pet.position.y + petSpriteSize.height + 6)
        addChild(z)
        z.run(.sequence([.group([.moveBy(x: 16, y: 40, duration: 1.2), .fadeOut(withDuration: 1.2)]), .removeFromParent()]))
    }

    func performTrick() {
        guard let pet else { return }
        let jump = SKAction.sequence([
            .group([.moveBy(x: 0, y: 30, duration: 0.18), .rotate(byAngle: .pi * 2, duration: 0.36)]),
            .moveBy(x: 0, y: -30, duration: 0.18)
        ])
        pet.run(jump)
        emitSparkles(at: pet.position, count: 8)
    }

    // MARK: - Juice (particles + squash/stretch)

    /// Squash & stretch tap feedback on the pet.
    func bouncePet() {
        guard let pet else { return }
        let baseY = pet.yScale
        let baseX = pet.xScale
        let signX: CGFloat = baseX >= 0 ? 1 : -1
        let mag = abs(baseY)
        let squash = SKAction.scaleX(to: signX * mag * 1.15, y: mag * 0.85, duration: 0.08)
        let stretch = SKAction.scaleX(to: signX * mag, y: mag, duration: 0.12)
        stretch.timingMode = .easeOut
        pet.run(.sequence([squash, stretch]), withKey: "bounce")
    }

    /// Floating hearts above the pet (caress/love feedback).
    func emitHearts(count: Int = 4) {
        guard let pet else { return }
        for i in 0..<count {
            let h = SKLabelNode(text: ["💖", "💗", "💕"].randomElement()!)
            h.fontSize = CGFloat.random(in: 14...22)
            h.zPosition = pet.zPosition + 5
            h.position = CGPoint(
                x: pet.position.x + CGFloat.random(in: -16...16),
                y: pet.position.y + petSpriteSize.height * pet.yScale - 4
            )
            addChild(h)
            let dx = CGFloat.random(in: -25...25)
            let drift = SKAction.group([
                .moveBy(x: dx, y: CGFloat.random(in: 50...80), duration: 1.0),
                .fadeOut(withDuration: 1.0),
                .scale(by: 1.3, duration: 1.0)
            ])
            h.run(.sequence([
                .wait(forDuration: Double(i) * 0.08),
                drift,
                .removeFromParent()
            ]))
        }
    }

    /// Sparkles around a position (level-up, trick).
    func emitSparkles(at point: CGPoint, count: Int = 10) {
        for _ in 0..<count {
            let s = SKLabelNode(text: ["✨", "⭐", "💫"].randomElement()!)
            s.fontSize = CGFloat.random(in: 12...20)
            s.zPosition = 200
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 20...60)
            let target = CGPoint(x: point.x + cos(angle) * dist, y: point.y + sin(angle) * dist)
            s.position = point
            addChild(s)
            s.run(.sequence([
                .group([
                    .move(to: target, duration: 0.6),
                    .fadeOut(withDuration: 0.6),
                    .rotate(byAngle: .pi, duration: 0.6)
                ]),
                .removeFromParent()
            ]))
        }
    }

    /// Big confetti burst — for achievements / level up celebrations.
    func emitConfetti() {
        guard let player else { return }
        let center = CGPoint(x: player.position.x, y: player.position.y + 100)
        let emojis = ["🎉", "🎊", "✨", "⭐", "💫", "🎈", "💖", "⚡"]
        for _ in 0..<24 {
            let c = SKLabelNode(text: emojis.randomElement()!)
            c.fontSize = CGFloat.random(in: 18...28)
            c.zPosition = 300
            c.position = center
            addChild(c)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 80...180)
            let target = CGPoint(x: center.x + cos(angle) * dist, y: center.y + sin(angle) * dist - 60)
            c.run(.sequence([
                .group([
                    .move(to: target, duration: 1.4),
                    .rotate(byAngle: CGFloat.random(in: -3...3), duration: 1.4),
                    .sequence([
                        .wait(forDuration: 0.8),
                        .fadeOut(withDuration: 0.6)
                    ])
                ]),
                .removeFromParent()
            ]))
        }
    }

    private var speechBubble: SKNode?

    /// Cartoon speech bubble floating above the pet for ~2.5s.
    func sayPet(_ text: String, duration: TimeInterval = 2.5) {
        guard let pet else { return }
        speechBubble?.removeFromParent()

        let label = SKLabelNode(text: text)
        label.fontName = "Menlo-Bold"
        label.fontSize = 11
        label.fontColor = UIColor(red: 0.235, green: 0.173, blue: 0.110, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        let textW = label.frame.width + 16
        let textH = label.frame.height + 10
        let bubble = SKShapeNode(rectOf: CGSize(width: textW, height: textH), cornerRadius: 8)
        bubble.fillColor = .white
        bubble.strokeColor = UIColor(red: 0.659, green: 0.580, blue: 0.424, alpha: 1)
        bubble.lineWidth = 1.5
        bubble.zPosition = 250
        bubble.addChild(label)

        // Tail (small triangle pointing down)
        let tail = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -4, y: -textH/2))
            p.addLine(to: CGPoint(x: 0, y: -textH/2 - 5))
            p.addLine(to: CGPoint(x: 4, y: -textH/2))
            p.closeSubpath()
            return p
        }())
        tail.fillColor = .white
        tail.strokeColor = UIColor(red: 0.659, green: 0.580, blue: 0.424, alpha: 1)
        tail.lineWidth = 1.5
        bubble.addChild(tail)

        bubble.position = CGPoint(
            x: pet.position.x,
            y: pet.position.y + petSpriteSize.height * pet.yScale + textH/2 + 12
        )
        bubble.alpha = 0
        bubble.setScale(0.6)
        addChild(bubble)
        speechBubble = bubble

        bubble.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.18),
                .scale(to: 1.0, duration: 0.22)
            ]),
            .wait(forDuration: duration),
            .group([
                .fadeOut(withDuration: 0.25),
                .scale(to: 0.7, duration: 0.25)
            ]),
            .removeFromParent()
        ]))
    }

    /// Brief screen shake for impact.
    func screenShake(intensity: CGFloat = 8) {
        let original = cam.position
        let shake = SKAction.sequence([
            .moveBy(x: intensity, y: 0, duration: 0.04),
            .moveBy(x: -intensity * 2, y: 0, duration: 0.06),
            .moveBy(x: intensity * 1.5, y: 0, duration: 0.04),
            .move(to: original, duration: 0.04)
        ])
        cam.run(shake)
    }

    func triggerEat() { performTrick() }
    func triggerPet() { performTrick() }

    func showNeedBubble(emoji: String?) {
        needBubble?.removeFromParent()
        needBubble = nil
        guard let emoji, let pet else { return }
        let bg = SKShapeNode(circleOfRadius: 14)
        bg.fillColor = .white
        bg.strokeColor = UIColor(red: 0.878, green: 0.282, blue: 0.282, alpha: 1)
        bg.lineWidth = 2
        let label = SKLabelNode(text: emoji)
        label.fontSize = 18
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        bg.addChild(label)
        bg.position = CGPoint(x: pet.position.x + 18, y: pet.position.y + petSpriteSize.height + 4)
        bg.zPosition = pet.zPosition + 5
        addChild(bg)
        needBubble = bg
        let bob = SKAction.sequence([.moveBy(x: 0, y: 4, duration: 0.6), .moveBy(x: 0, y: -4, duration: 0.6)])
        bg.run(.repeatForever(bob))
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
