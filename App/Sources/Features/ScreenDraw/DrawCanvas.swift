import AppKit
import QuartzCore

extension InkColor {
    var cgColor: CGColor {
        // design-ausnahme: ink is content the person picks on top of any screen, not interface chrome
        CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// The ink of one display. Every stroke is its own shape layer, so a new mouse sample only redraws
/// the running stroke, also on a 5K display with a full screen of marks.
final class DrawCanvasView: NSView {
    private let board: DrawBoard
    private let backingScale: CGFloat
    private var layers: [Int: CAShapeLayer] = [:]
    private var fading: Set<Int> = []
    private var lastLiveID: Int?
    private var cursorKey = ""
    private var cursor = NSCursor.crosshair
    var blockedRect: () -> NSRect = { .zero }

    init(board: DrawBoard, screenFrame: CGRect, scale: CGFloat) {
        self.board = board
        backingScale = scale
        super.init(frame: NSRect(origin: .zero, size: screenFrame.size))
        let root = CALayer()
        root.frame = bounds
        // design-ausnahme: one step above fully clear, or macOS lets clicks through to the app below
        root.backgroundColor = CGColor(gray: 0, alpha: 1.0 / 255)
        root.sublayerTransform = CATransform3DMakeTranslation(-screenFrame.minX, -screenFrame.minY, 0)
        layer = root
        wantsLayer = true
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseMoved, .cursorUpdate], owner: self))
    }

    // MARK: Mouse

    private func globalPoint(_ event: NSEvent) -> CGPoint {
        window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
    }

    override func mouseDown(with event: NSEvent) { board.begin(at: globalPoint(event)) }
    override func mouseDragged(with event: NSEvent) { board.extend(to: globalPoint(event), constrained: event.modifierFlags.contains(.shift)) }
    override func mouseUp(with event: NSEvent) { board.end() }
    override func cursorUpdate(with event: NSEvent) { applyCursor(event) }
    override func mouseMoved(with event: NSEvent) { applyCursor(event) }

    private func applyCursor(_ event: NSEvent) {
        let overToolbar = blockedRect().contains(convert(event.locationInWindow, from: nil))
        (overToolbar ? NSCursor.arrow : cursor).set()
    }

    // MARK: Ink

    /// Brings the layers in line with the board.
    func sync() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let visible = board.visible
        let ids = Set(visible.map(\.id))
        for (id, shape) in layers where !ids.contains(id) {
            shape.removeFromSuperlayer()
            layers[id] = nil
            fading.remove(id)
        }
        for stroke in visible {
            if let shape = layers[stroke.id] {
                // also once after the mouse let go: the end of a stroke adds its last point
                if stroke.id == board.live?.id || stroke.id == lastLiveID { shape.path = DrawGeometry.path(of: stroke) }
            } else {
                let shape = makeLayer(for: stroke)
                layer?.addSublayer(shape)
                layers[stroke.id] = shape
            }
        }
        lastLiveID = board.live?.id
        for flash in board.flashes where !fading.contains(flash.id) {
            fading.insert(flash.id)
            layers[flash.id].map(fadeOut)
        }
        refreshCursor()
    }

    var layerCount: Int { layers.count }

    func inkBounds(of id: Int) -> CGRect? { layers[id]?.path?.boundingBoxOfPath }

    private func makeLayer(for stroke: DrawStroke) -> CAShapeLayer {
        let shape = CAShapeLayer()
        shape.contentsScale = backingScale
        shape.path = DrawGeometry.path(of: stroke)
        shape.fillColor = nil
        shape.strokeColor = stroke.color.cgColor
        shape.lineWidth = DrawGeometry.lineWidth(of: stroke)
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.opacity = DrawGeometry.opacity(of: stroke)
        if stroke.tool == .laser {
            shape.shadowColor = stroke.color.cgColor
            shape.shadowOpacity = 0.9
            shape.shadowRadius = 7
            shape.shadowOffset = .zero
        }
        return shape
    }

    private func fadeOut(_ shape: CAShapeLayer) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.beginTime = CACurrentMediaTime() + DrawBoard.laserHold
        fade.duration = DrawBoard.laserFade
        fade.fillMode = .both
        fade.isRemovedOnCompletion = false
        shape.add(fade, forKey: "fade")
    }

    private func refreshCursor() {
        let key = "\(board.tool.rawValue)-\(board.color.rawValue)-\(board.width.rawValue)"
        guard key != cursorKey else { return }
        cursorKey = key
        cursor = Self.makeCursor(tool: board.tool, color: board.color, width: board.width)
        if window?.isKeyWindow == true { cursor.set() }
    }

    /// A dot of the current ink, as wide as the line it draws, with a thin edge that shows on any background.
    private static func makeCursor(tool: DrawTool, color: InkColor, width: InkWidth) -> NSCursor {
        guard tool.isFreehand else { return .crosshair }
        let line = tool == .marker ? width.points * 4 : width.points
        let side = max(line, 7) + 3
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: rect.insetBy(dx: 1.5, dy: 1.5))
            context.setStrokeColor((color == .white ? InkColor.black : .white).cgColor)
            context.setLineWidth(1)
            context.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
    }

    /// The ink as a picture, drawn by the same layers the overlay shows.
    func snapshot(scale: CGFloat) -> CGImage? {
        sync()
        guard let root = layer, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: Int(bounds.width * scale), height: Int(bounds.height * scale), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        root.render(in: context)
        return context.makeImage()
    }
}
