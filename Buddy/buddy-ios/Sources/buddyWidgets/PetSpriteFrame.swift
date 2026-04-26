import SwiftUI

/// Renders a single frame of the pet sprite sheet (7×6 grid) at a given display size.
struct PetSpriteFrame: View {
    let row: Int
    let col: Int
    let size: CGFloat

    private let columns: CGFloat = 7
    private let rows: CGFloat = 6

    var body: some View {
        Image("pet_sheet")
            .resizable()
            .interpolation(.none)
            .frame(width: size * columns, height: size * rows)
            .offset(x: -CGFloat(col) * size, y: -CGFloat(row) * size)
            .frame(width: size, height: size, alignment: .topLeading)
            .clipped()
    }
}

/// Animated 2-frame loop for a given PetAction, swapping frames every `interval` seconds
/// using TimelineView (the only viable animation primitive in widgets / Live Activities).
struct AnimatedPetSprite: View {
    let action: PetAction
    let size: CGFloat
    let interval: TimeInterval

    init(action: PetAction, size: CGFloat, interval: TimeInterval = 0.6) {
        self.action = action
        self.size = size
        self.interval = interval
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: interval)) { context in
            let (row, frames) = action.spriteFrames
            let idx = Int(context.date.timeIntervalSince1970 / interval) % frames.count
            PetSpriteFrame(row: row, col: frames[idx], size: size)
        }
    }
}
