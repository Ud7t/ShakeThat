import AppKit

/// The menu bar glyph: the cursor and shake lines from the app icon, drawn as a template
/// image so macOS tints it for light and dark menu bars.
enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            // Paths are in the app icon's SVG coordinates (Resources/Icon/ShakeThatIcon.svg).
            // Their combined bounds, including the arcs' stroke width, are about
            // x 187...441 and y 116...393; scale that to fit 14pt and centre it.
            let content = NSRect(x: 187, y: 116, width: 254, height: 277)
            let scale = 14 / content.height
            let transform = NSAffineTransform()
            transform.translateX(
                by: rect.midX - content.midX * scale,
                yBy: rect.midY - content.midY * scale
            )
            transform.scale(by: scale)
            transform.concat()

            NSColor.black.setFill()
            cursorPath().fill()

            NSColor.black.setStroke()
            let innerArc = arc(from: (346, 158), (370, 178), (383, 200), to: (387, 223))
            innerArc.stroke()
            NSColor.black.withAlphaComponent(0.55).setStroke()
            let outerArc = arc(from: (368, 129), (402, 155), (421, 185), to: (428, 220))
            outerArc.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ShakeThat"
        return image
    }

    private static func cursorPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 187, y: 135))
        path.line(to: NSPoint(x: 187, y: 345))
        path.curve(to: NSPoint(x: 192, y: 347), controlPoint1: NSPoint(x: 187, y: 349), controlPoint2: NSPoint(x: 188.667, y: 349.667))
        path.line(to: NSPoint(x: 242, y: 299))
        path.line(to: NSPoint(x: 288, y: 390))
        path.curve(to: NSPoint(x: 294, y: 392), controlPoint1: NSPoint(x: 289.333, y: 392.667), controlPoint2: NSPoint(x: 291.333, y: 393.333))
        path.line(to: NSPoint(x: 332, y: 372))
        path.curve(to: NSPoint(x: 334, y: 366), controlPoint1: NSPoint(x: 334.667, y: 370.667), controlPoint2: NSPoint(x: 335.333, y: 368.667))
        path.line(to: NSPoint(x: 287, y: 278))
        path.line(to: NSPoint(x: 359, y: 278))
        path.curve(to: NSPoint(x: 360, y: 273), controlPoint1: NSPoint(x: 363, y: 278), controlPoint2: NSPoint(x: 363.333, y: 276.333))
        path.line(to: NSPoint(x: 193, y: 132))
        path.curve(to: NSPoint(x: 187, y: 135), controlPoint1: NSPoint(x: 189, y: 128.667), controlPoint2: NSPoint(x: 187, y: 129.667))
        path.close()
        return path
    }

    private static func arc(
        from start: (CGFloat, CGFloat),
        _ control1: (CGFloat, CGFloat),
        _ control2: (CGFloat, CGFloat),
        to end: (CGFloat, CGFloat)
    ) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: start.0, y: start.1))
        path.curve(
            to: NSPoint(x: end.0, y: end.1),
            controlPoint1: NSPoint(x: control1.0, y: control1.1),
            controlPoint2: NSPoint(x: control2.0, y: control2.1)
        )
        // Thicker than in the app icon so the lines survive being shrunk to menu bar size.
        path.lineWidth = 22
        path.lineCapStyle = .round
        return path
    }
}
