import SwiftUI

/// SwiftUI rendering of the pet's sprite sheet (7×6 grid).
/// Shared between the main app (minigames, photo mode) and the widget.
struct PetSpriteFrameView: View {
    let row: Int
    let col: Int
    let size: CGFloat
    private let columns: CGFloat = 4
    private let rows: CGFloat = 4

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

/// Animates a 2-frame loop for the given action.
struct AnimatedPet: View {
    let action: PetAction
    let size: CGFloat
    let interval: TimeInterval

    init(action: PetAction = .idle, size: CGFloat = 64, interval: TimeInterval = 0.6) {
        self.action = action
        self.size = size
        self.interval = interval
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: interval)) { ctx in
            let frames = action.spriteFrames
            let idx = Int(ctx.date.timeIntervalSince1970 / interval) % frames.frames.count
            PetSpriteFrameView(row: frames.row, col: frames.frames[idx], size: size)
        }
    }
}
