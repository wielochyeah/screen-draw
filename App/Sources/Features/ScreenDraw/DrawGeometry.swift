import CoreGraphics
import Foundation

/// Turns strokes into paths. No state and no drawing, so overlay, renders and tests share it.
nonisolated enum DrawGeometry {
    /// The end point with ⇧ held: a square or circle for shapes, a 45° step for lines and arrows.
    static func constrainedEnd(start: CGPoint, end: CGPoint, tool: DrawTool) -> CGPoint {
        let dx = end.x - start.x, dy = end.y - start.y
        switch tool {
        case .rectangle, .oval:
            let side = max(abs(dx), abs(dy))
            return CGPoint(x: start.x + (dx < 0 ? -side : side), y: start.y + (dy < 0 ? -side : side))
        case .pen, .marker, .laser, .arrow:
            let step = CGFloat.pi / 4
            let angle = (atan2(dy, dx) / step).rounded() * step
            let length = hypot(dx, dy)
            return CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
        }
    }

    static func lineWidth(of stroke: DrawStroke) -> CGFloat {
        stroke.tool == .marker ? stroke.width.points * 4 : stroke.width.points
    }

    static func opacity(of stroke: DrawStroke) -> Float { stroke.tool == .marker ? 0.4 : 1 }

    static func path(of stroke: DrawStroke) -> CGPath {
        let path = CGMutablePath()
        guard let first = stroke.points.first, let last = stroke.points.last else { return path }
        switch stroke.tool {
        case .pen, .marker, .laser:
            addSmoothLine(through: stroke.points, to: path)
        case .arrow:
            addArrow(from: first, to: last, lineWidth: lineWidth(of: stroke), to: path)
        case .rectangle:
            let rect = box(first, last)
            let radius = min(lineWidth(of: stroke) * 1.5, min(rect.width, rect.height) / 2)
            path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
        case .oval:
            path.addEllipse(in: box(first, last))
        }
        return path
    }

    static func box(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// Quadratic curves between the midpoints of the samples: passes near every sample without corners.
    private static func addSmoothLine(through points: [CGPoint], to path: CGMutablePath) {
        guard let first = points.first, let last = points.last else { return }
        path.move(to: first)
        guard points.count > 2 else {
            // a single click still leaves a dot: a line needs some length for its round caps
            path.addLine(to: points.count == 2 ? last : CGPoint(x: first.x + 0.01, y: first.y))
            return
        }
        for index in 1..<(points.count - 1) {
            let control = points[index], next = points[index + 1]
            path.addQuadCurve(to: CGPoint(x: (control.x + next.x) / 2, y: (control.y + next.y) / 2), control: control)
        }
        path.addLine(to: last)
    }

    private static func addArrow(from start: CGPoint, to tip: CGPoint, lineWidth: CGFloat, to path: CGMutablePath) {
        let angle = atan2(tip.y - start.y, tip.x - start.x)
        let head = headLength(lineWidth: lineWidth)
        let spread = CGFloat.pi * 0.16
        path.move(to: start)
        path.addLine(to: tip)
        path.move(to: CGPoint(x: tip.x - cos(angle - spread) * head, y: tip.y - sin(angle - spread) * head))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x - cos(angle + spread) * head, y: tip.y - sin(angle + spread) * head))
    }

    static func headLength(lineWidth: CGFloat) -> CGFloat { max(16, lineWidth * 4.5) }
}
