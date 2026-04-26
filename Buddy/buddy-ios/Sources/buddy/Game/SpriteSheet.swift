import SpriteKit

/// Slices a grid sprite sheet (cols × rows) into individual SKTextures.
struct SpriteSheet {
    let texture: SKTexture
    let columns: Int
    let rows: Int

    init(imageNamed name: String, columns: Int, rows: Int) {
        let tex = SKTexture(imageNamed: name)
        tex.filteringMode = .nearest
        self.texture = tex
        self.columns = columns
        self.rows = rows
    }

    /// Returns the texture at (col, row), 0-indexed from top-left.
    func frame(col: Int, row: Int) -> SKTexture {
        let w = 1.0 / CGFloat(columns)
        let h = 1.0 / CGFloat(rows)
        let x = CGFloat(col) * w
        // SKTexture rect is bottom-left origin in normalized coords
        let y = 1.0 - CGFloat(row + 1) * h
        let frame = SKTexture(rect: CGRect(x: x, y: y, width: w, height: h), in: texture)
        frame.filteringMode = .nearest
        return frame
    }

    /// Returns a strip of frames from a single row.
    func frames(row: Int, cols: Range<Int>) -> [SKTexture] {
        cols.map { frame(col: $0, row: row) }
    }
}
