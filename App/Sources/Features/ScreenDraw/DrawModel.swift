import CoreGraphics
import Foundation
import Observation

nonisolated enum DrawTool: String, CaseIterable, Codable, Sendable {
    case pen, marker, arrow, rectangle, oval, laser

    var symbol: String {
        switch self {
        case .pen: "pencil"
        case .marker: "highlighter"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .oval: "circle"
        case .laser: "cursorarrow.rays"
        }
    }

    var key: String {
        switch self {
        case .pen: "p"
        case .marker: "m"
        case .arrow: "a"
        case .rectangle: "r"
        case .oval: "o"
        case .laser: "l"
        }
    }

    var isFreehand: Bool { self == .pen || self == .marker || self == .laser }
}

nonisolated enum InkColor: String, CaseIterable, Codable, Sendable {
    case red, yellow, green, blue, white, black

    var hex: UInt32 {
        switch self {
        case .red: 0xFF3B30
        case .yellow: 0xFFCC00
        case .green: 0x34C759
        case .blue: 0x0A84FF
        case .white: 0xFFFFFF
        case .black: 0x111113
        }
    }

    var key: String { String((InkColor.allCases.firstIndex(of: self) ?? 0) + 1) }
}

nonisolated enum InkWidth: String, CaseIterable, Codable, Sendable {
    case thin, medium, thick

    var points: CGFloat {
        switch self {
        case .thin: 3
        case .medium: 5
        case .thick: 9
        }
    }
}

/// One finished or running mark. Points are global screen coordinates (AppKit, y up), so a stroke
/// that crosses from one display to the next appears on both.
nonisolated struct DrawStroke: Identifiable, Equatable, Sendable {
    let id: Int
    let tool: DrawTool
    let color: InkColor
    let width: InkWidth
    var points: [CGPoint]
}

extension SettingKey {
    static var drawTool: SettingKey<DrawTool> { .init("draw.tool", default: .pen) }
    static var drawColor: SettingKey<InkColor> { .init("draw.color", default: .red) }
    static var drawWidth: SettingKey<InkWidth> { .init("draw.width", default: .medium) }
}

/// The drawing itself: what is on the screen, what undo brings back, and the current pen.
@Observable final class DrawBoard {
    /// How long a laser line stays at full strength after the mouse lets go, then how long it fades.
    nonisolated static let laserHold: TimeInterval = 1.4
    nonisolated static let laserFade: TimeInterval = 0.6
    /// How far each new mouse sample pulls the line: below 1 takes the shake out of a hand-drawn circle.
    nonisolated static let smoothing: CGFloat = 0.55
    /// Samples closer than this to the last point add nothing visible.
    nonisolated static let minStep: CGFloat = 0.75
    /// A shape smaller than this diagonal is a stray click.
    nonisolated static let minShape: CGFloat = 4

    typealias Scheduler = (TimeInterval, @escaping @MainActor () -> Void) -> Void

    var tool: DrawTool { didSet { settings[.drawTool] = tool; onChange?() } }
    var color: InkColor { didSet { settings[.drawColor] = color; onChange?() } }
    var width: InkWidth { didSet { settings[.drawWidth] = width; onChange?() } }

    private(set) var strokes: [DrawStroke] = []
    private(set) var flashes: [DrawStroke] = []
    private(set) var live: DrawStroke?
    private var history: [[DrawStroke]] = []
    private var future: [[DrawStroke]] = []
    private var nextID = 1
    private var rawEnd: CGPoint?
    private var liveConstrained = false

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private let schedule: Scheduler

    init(settings: Settings, schedule: @escaping Scheduler = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { MainActor.assumeIsolated(work) }
    }) {
        self.settings = settings
        self.schedule = schedule
        tool = settings[.drawTool]
        color = settings[.drawColor]
        width = settings[.drawWidth]
    }

    var canUndo: Bool { !history.isEmpty }
    var canRedo: Bool { !future.isEmpty }
    var visible: [DrawStroke] { strokes + flashes + (live.map { [$0] } ?? []) }

    func begin(at point: CGPoint) {
        live = DrawStroke(id: nextID, tool: tool, color: color, width: width, points: [point])
        nextID += 1
        rawEnd = point
        liveConstrained = false
        onChange?()
    }

    func extend(to point: CGPoint, constrained: Bool) {
        guard var stroke = live, let first = stroke.points.first, let last = stroke.points.last else { return }
        rawEnd = point
        liveConstrained = constrained
        if constrained {
            stroke.points = [first, DrawGeometry.constrainedEnd(start: first, end: point, tool: stroke.tool)]
        } else if stroke.tool.isFreehand {
            let smoothed = CGPoint(x: last.x + (point.x - last.x) * Self.smoothing, y: last.y + (point.y - last.y) * Self.smoothing)
            guard hypot(smoothed.x - last.x, smoothed.y - last.y) >= Self.minStep else { return }
            stroke.points.append(smoothed)
        } else {
            stroke.points = [first, point]
        }
        live = stroke
        onChange?()
    }

    func end() {
        guard var stroke = live else { return }
        live = nil
        defer { onChange?() }
        if stroke.tool.isFreehand {
            if !liveConstrained, let raw = rawEnd, let last = stroke.points.last, hypot(raw.x - last.x, raw.y - last.y) >= Self.minStep {
                stroke.points.append(raw)
            }
        } else {
            guard let first = stroke.points.first, let last = stroke.points.last,
                  hypot(last.x - first.x, last.y - first.y) >= Self.minShape else { return }
        }
        if stroke.tool == .laser {
            flashes.append(stroke)
            let id = stroke.id
            schedule(Self.laserHold + Self.laserFade) { [weak self] in self?.removeFlash(id) }
        } else {
            remember()
            strokes.append(stroke)
        }
    }

    func undo() {
        guard let previous = history.popLast() else { return }
        future.append(strokes)
        strokes = previous
        onChange?()
    }

    func redo() {
        guard let next = future.popLast() else { return }
        history.append(strokes)
        strokes = next
        onChange?()
    }

    func clear() {
        flashes = []
        if !strokes.isEmpty {
            remember()
            strokes = []
        }
        onChange?()
    }

    /// Back to an empty screen with nothing to undo (drawing mode ended).
    func reset() {
        strokes = []
        flashes = []
        live = nil
        history = []
        future = []
        onChange?()
    }

    func stepWidth(by delta: Int) {
        let all = InkWidth.allCases
        guard let index = all.firstIndex(of: width) else { return }
        width = all[min(max(index + delta, 0), all.count - 1)]
    }

    /// Drops what cannot survive new canvases: a stroke whose mouse-up will never come and laser lines mid-fade.
    func interrupt() {
        live = nil
        flashes = []
        onChange?()
    }

    private func remember() {
        history.append(strokes)
        future = []
    }

    private func removeFlash(_ id: Int) {
        flashes.removeAll { $0.id == id }
        onChange?()
    }
}

/// What a key does while drawing.
nonisolated enum DrawKeyAction: Equatable, Sendable {
    case close, undo, redo, clear, thinner, thicker
    case tool(DrawTool)
    case color(InkColor)
}

nonisolated enum DrawKeys {
    private static let escape: UInt16 = 53
    private static let delete: UInt16 = 51
    private static let forwardDelete: UInt16 = 117

    /// `characters` is the event's text ignoring modifiers; only ⌘ and ⇧ matter here, a chord with ⌃ or ⌥ does nothing.
    static func action(keyCode: UInt16, characters: String, command: Bool, shift: Bool, otherModifiers: Bool) -> DrawKeyAction? {
        guard !otherModifiers else { return nil }
        let text = characters.lowercased()
        if command { return text == "z" ? (shift ? .redo : .undo) : nil }
        if keyCode == escape { return .close }
        if keyCode == delete || keyCode == forwardDelete { return .clear }
        if text == "+" || text == "=" { return .thicker }
        if text == "-" { return .thinner }
        if shift { return nil }
        if let tool = DrawTool.allCases.first(where: { $0.key == text }) { return .tool(tool) }
        if let color = InkColor.allCases.first(where: { $0.key == text }) { return .color(color) }
        return nil
    }
}
