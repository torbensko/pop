import AppKit

/// A template silhouette of Artwork/pop-master.jpg, redrawn as paths so it
/// stays crisp and adapts to both light and dark menu bars.
@MainActor
enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: true) { _ in
            NSColor.black.setStroke()
            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: (x - 120) / 30, y: (y - 100) / 30)
            }
            func stroke(_ from: NSPoint, _ to: NSPoint, width: CGFloat) {
                let path = NSBezierPath()
                path.move(to: from)
                path.line(to: to)
                path.lineWidth = width / 30
                path.lineCapStyle = .round
                path.stroke()
            }
            stroke(point(540, 520), point(680, 660), width: 56)
            let lens = NSBezierPath(ovalIn: NSRect(origin: point(260, 240), size: NSSize(width: 320 / 30, height: 320 / 30)))
            lens.lineWidth = 40 / 30
            lens.stroke()
            // Slightly reinforce the fine burst lines for menu-bar-sized rendering.
            for (x1, y1, x2, y2) in [
                (420.0, 120.0, 420.0, 180.0),
                (220.0, 200.0, 264.0, 244.0),
                (580.0, 240.0, 620.0, 200.0),
                (140.0, 400.0, 200.0, 400.0),
                (640.0, 400.0, 700.0, 400.0),
                (220.0, 600.0, 264.0, 556.0),
                (420.0, 620.0, 420.0, 680.0)
            ] {
                stroke(point(x1, y1), point(x2, y2), width: 24)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Pop"
        return image
    }
}
