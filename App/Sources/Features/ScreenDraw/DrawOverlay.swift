import AppKit
import SwiftUI

nonisolated struct DrawScreen: Equatable, Sendable {
    let frame: CGRect
    let visibleFrame: CGRect
    let scale: CGFloat
}

/// Covers one display and takes the mouse and keys without activating the app, so the app in front
/// (the call, the slides) stays in front.
final class DrawPanel: NSPanel {
    let canvas: DrawCanvasView
    var onKey: ((NSEvent) -> Void)?

    init(screen: DrawScreen, board: DrawBoard) {
        canvas = DrawCanvasView(board: board, screenFrame: screen.frame, scale: screen.scale)
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        // after isFloatingPanel, which sets its own lower level
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        container.addSubview(canvas)
        contentView = container
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Handled here, not in a view: a click on the toolbar may move the first responder away from the canvas.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown { onKey?(event) } else { super.sendEvent(event) }
    }

    // Always true: while drawing, ⌘Q and the like must not reach this app's own menu.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        onKey?(event)
        return true
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Drawing mode: one panel per display, the toolbar on the display with the pointer.
final class DrawOverlay {
    static let shared: DrawOverlay = {
        let overlay = DrawOverlay(board: DrawBoard(settings: RenderMode.isHeadless ? .inMemory() : .shared))
        #if MODUL_MENUBAR
        overlay.onActiveChange = { active in
            MenuBarStatus.shared.state = active ? .busy : .idle
            if active { MenuBarStatus.shared.message = DrawText.statusDrawing }
        }
        #endif
        return overlay
    }()

    let board: DrawBoard
    var onActiveChange: ((Bool) -> Void)?
    private let screens: @MainActor () -> [DrawScreen]
    private let mouseLocation: @MainActor () -> CGPoint
    private(set) var panels: [DrawPanel] = []
    private var toolbar: NSView?
    private var toolbarScreen: DrawScreen?
    private var toolbarOffset = CGSize.zero
    private var dragAnchor: CGPoint?
    private var builtScreens: [DrawScreen] = []
    private var isSnapped = false

    var isActive: Bool { !panels.isEmpty }

    init(board: DrawBoard, screens: @escaping @MainActor () -> [DrawScreen] = DrawOverlay.liveScreens,
         mouseLocation: @escaping @MainActor () -> CGPoint = { NSEvent.mouseLocation }) {
        self.board = board
        self.screens = screens
        self.mouseLocation = mouseLocation
        board.onChange = { [weak self] in self?.panels.forEach { $0.canvas.sync() } }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
    }

    static func liveScreens() -> [DrawScreen] {
        NSScreen.screens.map { DrawScreen(frame: $0.frame, visibleFrame: $0.visibleFrame, scale: $0.backingScaleFactor) }
    }

    func toggle() { isActive ? close() : open() }

    func open() {
        guard !isActive else { return }
        buildPanels()
        if isActive { onActiveChange?(true) }
    }

    /// Ends drawing mode. The drawing goes with it, so the next start is a clean screen.
    func close() {
        guard isActive else { return }
        let closing = panels
        panels = []
        toolbar = nil
        toolbarScreen = nil
        dragAnchor = nil
        board.reset()
        onActiveChange?(false)
        // the panels stay on screen for the fade: nothing may reach the board through them any more
        closing.forEach {
            $0.ignoresMouseEvents = true
            $0.onKey = nil
        }
        guard !RenderMode.isHeadless else {
            closing.forEach { $0.orderOut(nil) }
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DrawLook.closeFade
            closing.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: {
            MainActor.assumeIsolated { closing.forEach { $0.orderOut(nil) } }
        }
    }

    private func buildPanels() {
        let all = screens()
        guard !all.isEmpty else { return }
        builtScreens = all
        let mouse = mouseLocation()
        // closed on all sides: the pointer on the top row of a display reports y == maxY
        let home = all.first { mouse.x >= $0.frame.minX && mouse.x <= $0.frame.maxX && mouse.y >= $0.frame.minY && mouse.y <= $0.frame.maxY } ?? all[0]
        panels = all.map { screen in
            let panel = DrawPanel(screen: screen, board: board)
            panel.onKey = { [weak self] event in self?.handle(event) }
            panel.canvas.blockedRect = { [weak self, weak panel] in
                guard let self, let toolbar = self.toolbar, toolbar.window === panel else { return .zero }
                return toolbar.frame
            }
            panel.canvas.sync()
            if screen == home { addToolbar(to: panel, screen: screen) }
            panel.orderFrontRegardless()
            if screen == home {
                panel.makeKey()
                panel.makeFirstResponder(panel.canvas)
            }
            return panel
        }
    }

    private func addToolbar(to panel: DrawPanel, screen: DrawScreen) {
        let bar = DrawToolbar(board: board, onClose: { [weak self] in self?.close() },
                              onDragChanged: { [weak self] in self?.dragToolbar() },
                              onDragEnded: { [weak self] in self?.dragAnchor = nil })
        let host = FirstMouseHostingView(rootView: bar)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        panel.contentView?.addSubview(host)
        toolbar = host
        toolbarScreen = screen
        place(host, offset: toolbarOffset, in: screen)
    }

    private func place(_ view: NSView, offset: CGSize, in screen: DrawScreen) {
        let home = homeOrigin(size: view.frame.size, in: screen)
        view.setFrameOrigin(clamped(NSPoint(x: home.x + offset.width, y: home.y + offset.height), size: view.frame.size, in: screen))
    }

    private func homeOrigin(size: CGSize, in screen: DrawScreen) -> NSPoint {
        NSPoint(x: screen.visibleFrame.midX - screen.frame.minX - size.width / 2,
                y: screen.visibleFrame.minY - screen.frame.minY + DrawLook.toolbarLift)
    }

    private func clamped(_ origin: NSPoint, size: CGSize, in screen: DrawScreen) -> NSPoint {
        NSPoint(x: min(max(origin.x, 0), screen.frame.width - size.width), y: min(max(origin.y, 0), screen.frame.height - size.height))
    }

    func dragToolbar() {
        guard let toolbar, let screen = toolbarScreen else { return }
        let mouse = mouseLocation()
        let local = CGPoint(x: mouse.x - screen.frame.minX, y: mouse.y - screen.frame.minY)
        let home = homeOrigin(size: toolbar.frame.size, in: screen)
        if dragAnchor == nil { isSnapped = toolbar.frame.origin == home }
        let anchor = dragAnchor ?? CGPoint(x: local.x - toolbar.frame.minX, y: local.y - toolbar.frame.minY)
        dragAnchor = anchor
        let wanted = clamped(NSPoint(x: local.x - anchor.x, y: local.y - anchor.y), size: toolbar.frame.size, in: screen)
        guard hypot(wanted.x - home.x, wanted.y - home.y) < DrawLook.snapRadius else {
            isSnapped = false
            toolbar.setFrameOrigin(wanted)
            toolbarOffset = CGSize(width: wanted.x - home.x, height: wanted.y - home.y)
            return
        }
        toolbarOffset = .zero
        guard !isSnapped else { return }
        isSnapped = true
        snap(toolbar, to: home)
    }

    private func snap(_ toolbar: NSView, to home: NSPoint) {
        guard !RenderMode.isHeadless, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            toolbar.setFrameOrigin(home)
            return
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DrawLook.snapDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            toolbar.animator().setFrameOrigin(home)
        }
    }

    /// The notification also fires when only the Dock moved: the panels cover the whole display and stay.
    func screensChanged() {
        guard isActive else { return }
        let current = screens()
        guard current.map(\.frame) != builtScreens.map(\.frame) || current.map(\.scale) != builtScreens.map(\.scale) else { return }
        guard !current.isEmpty else {
            close()
            return
        }
        panels.forEach { $0.orderOut(nil) }
        panels = []
        toolbar = nil
        dragAnchor = nil
        board.interrupt()
        buildPanels()
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let action = DrawKeys.action(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers ?? "",
                                           command: flags.contains(.command), shift: flags.contains(.shift),
                                           otherModifiers: !flags.isDisjoint(with: [.control, .option])) else { return }
        perform(action)
    }

    func perform(_ action: DrawKeyAction) {
        switch action {
        case .close: close()
        case .undo: board.undo()
        case .redo: board.redo()
        case .clear: board.clear()
        case .thinner: board.stepWidth(by: -1)
        case .thicker: board.stepWidth(by: 1)
        case .tool(let tool): board.tool = tool
        case .color(let color): board.color = color
        }
    }
}
