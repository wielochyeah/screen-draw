#if TESTING
import AppKit

final class DrawTests: TestSuite {
    private static func board(_ queue: Queue? = nil) -> DrawBoard {
        DrawBoard(settings: .inMemory(), schedule: { delay, work in queue?.items.append((delay, work)) })
    }

    private final class Queue {
        var items: [(TimeInterval, @MainActor () -> Void)] = []
    }

    private final class Pointer {
        var location = CGPoint.zero
    }

    private final class Displays {
        var current: [DrawScreen]
        init(_ current: [DrawScreen]) { self.current = current }
    }

    private static func stroke(_ board: DrawBoard, _ a: CGPoint, _ b: CGPoint, constrained: Bool = false) {
        board.begin(at: a)
        board.extend(to: b, constrained: constrained)
        board.end()
    }

    override class func register() {
        #if MODUL_HOTKEYS
        test("the standard key passes the shortcut rules on US and German keyboards") {
            for layout in [TableKeyboardLayout.us, TableKeyboardLayout.german] as [KeyboardLayout] {
                let verdict = ShortcutRules.judge(DrawFeature.standardHotkey,
                                                  in: ShortcutRules.Context(layout: layout, system: [], others: [], appName: "Screen Draw"))
                if case .refuse(let why) = verdict { fail("refused: \(why)") }
            }
        }
        test("the standard key is free of VoiceBud and the screenshot keys") {
            // ⇧⌘2 VoiceBud text recognition; ⇧⌘3, ⇧⌘4, ⇧⌘5, ⇧⌘6 macOS screenshots (virtual codes 19, 20, 21, 23, 22)
            expectEqual(DrawFeature.standardHotkey.keyCode, 18)
            expect(![19, 20, 21, 22, 23].contains(DrawFeature.standardHotkey.keyCode))
            expectEqual(DrawFeature.standardHotkey.modifiers, [.shift, .command])
        }
        test("pressing the hotkey starts drawing and pressing it again stops it") {
            let backend = FakeHotkeyBackend()
            let center = HotkeyCenter(backend: backend, store: MemoryHotkeyStore())
            let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
            let overlay = DrawOverlay(board: board(), screens: { [DrawScreen(frame: frame, visibleFrame: frame, scale: 2)] }, mouseLocation: { .zero })
            center.register(id: DrawFeature.hotkeyID, title: { "" }, default: DrawFeature.standardHotkey) { overlay.toggle() }
            center.startForTesting()
            defer { center.stop(); overlay.close() }
            backend.press(DrawFeature.standardHotkey)
            backend.press(DrawFeature.standardHotkey, down: false)
            expect(overlay.isActive)
            backend.press(DrawFeature.standardHotkey)
            backend.press(DrawFeature.standardHotkey, down: false)
            expect(!overlay.isActive)
        }
        #endif

        test("one panel per display, toolbar display follows the pointer") {
            let left = CGRect(x: -1440, y: 0, width: 1440, height: 900), right = CGRect(x: 0, y: 0, width: 1728, height: 1117)
            let overlay = DrawOverlay(board: board(), screens: { [DrawScreen(frame: left, visibleFrame: left, scale: 2), DrawScreen(frame: right, visibleFrame: right, scale: 2)] },
                                      mouseLocation: { CGPoint(x: -200, y: 100) })
            overlay.open()
            defer { overlay.close() }
            expectEqual(overlay.panels.count, 2)
            expectEqual(overlay.panels[0].frame, left)
            expectEqual(overlay.panels[1].frame, right)
            expectEqual(overlay.panels[0].contentView?.subviews.count, 2, "canvas and toolbar on the display with the pointer")
            expectEqual(overlay.panels[1].contentView?.subviews.count, 1, "canvas only")
        }

        test("stopping clears the drawing, also for undo") {
            let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
            let overlay = DrawOverlay(board: board(), screens: { [DrawScreen(frame: frame, visibleFrame: frame, scale: 2)] }, mouseLocation: { .zero })
            overlay.open()
            stroke(overlay.board, CGPoint(x: 10, y: 10), CGPoint(x: 90, y: 90))
            expectEqual(overlay.board.strokes.count, 1)
            overlay.close()
            expect(overlay.board.strokes.isEmpty)
            expect(!overlay.board.canUndo)
        }

        test("the ink layer reaches the point where the mouse let go") {
            let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
            let overlay = DrawOverlay(board: board(), screens: { [DrawScreen(frame: frame, visibleFrame: frame, scale: 2)] }, mouseLocation: { .zero })
            overlay.open()
            defer { overlay.close() }
            stroke(overlay.board, CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0))
            let id = overlay.board.strokes[0].id
            expectEqual(overlay.panels[0].canvas.inkBounds(of: id)?.maxX, 100)
        }

        test("Esc reaches the panel and stops drawing") {
            let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
            let overlay = DrawOverlay(board: board(), screens: { [DrawScreen(frame: frame, visibleFrame: frame, scale: 2)] }, mouseLocation: { .zero })
            overlay.open()
            defer { overlay.close() }
            guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
                                               characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53) else {
                fail("no key event")
                return
            }
            overlay.panels[0].sendEvent(event)
            expect(!overlay.isActive)
        }

        test("closing panels take no more input") {
            let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
            let overlay = DrawOverlay(board: board(), screens: { [DrawScreen(frame: frame, visibleFrame: frame, scale: 2)] }, mouseLocation: { .zero })
            overlay.open()
            let panel = overlay.panels[0]
            overlay.close()
            expect(panel.ignoresMouseEvents)
            expect(panel.onKey == nil)
        }

        test("the pointer on the top row of a display picks that display") {
            let lower = CGRect(x: 0, y: 0, width: 800, height: 600), upper = CGRect(x: 0, y: 700, width: 800, height: 600)
            let overlay = DrawOverlay(board: board(), screens: { [DrawScreen(frame: lower, visibleFrame: lower, scale: 2), DrawScreen(frame: upper, visibleFrame: upper, scale: 2)] },
                                      mouseLocation: { CGPoint(x: 100, y: 1300) })
            overlay.open()
            defer { overlay.close() }
            expectEqual(overlay.panels[1].contentView?.subviews.count, 2)
        }

        test("a Dock change keeps the panels, a new display rebuilds them without a stuck stroke") {
            let frame = CGRect(x: 0, y: 0, width: 800, height: 600), extra = CGRect(x: 800, y: 0, width: 800, height: 600)
            let displays = Displays([DrawScreen(frame: frame, visibleFrame: frame, scale: 2)])
            let overlay = DrawOverlay(board: board(), screens: { displays.current }, mouseLocation: { .zero })
            overlay.open()
            defer { overlay.close() }
            let first = overlay.panels[0]
            displays.current = [DrawScreen(frame: frame, visibleFrame: frame.insetBy(dx: 0, dy: 40), scale: 2)]
            overlay.screensChanged()
            expect(overlay.panels[0] === first, "same panel after a Dock change")
            overlay.board.begin(at: CGPoint(x: 5, y: 5))
            displays.current.append(DrawScreen(frame: extra, visibleFrame: extra, scale: 2))
            overlay.screensChanged()
            expectEqual(overlay.panels.count, 2)
            expect(overlay.board.live == nil)
        }

        test("all displays gone ends drawing and clears it") {
            let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
            let displays = Displays([DrawScreen(frame: frame, visibleFrame: frame, scale: 2)])
            let overlay = DrawOverlay(board: board(), screens: { displays.current }, mouseLocation: { .zero })
            overlay.open()
            stroke(overlay.board, CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0))
            displays.current = []
            overlay.screensChanged()
            expect(!overlay.isActive)
            expect(overlay.board.strokes.isEmpty)
        }

        test("the toolbar locks onto its usual place within 36 pt and lets go beyond") {
            let frame = CGRect(x: 0, y: 0, width: 1600, height: 1000)
            let pointer = Pointer()
            let overlay = DrawOverlay(board: board(), screens: { [DrawScreen(frame: frame, visibleFrame: frame, scale: 2)] }, mouseLocation: { pointer.location })
            overlay.open()
            defer { overlay.close() }
            guard let bar = overlay.panels[0].contentView?.subviews.last else {
                fail("no toolbar")
                return
            }
            let home = bar.frame.origin
            pointer.location = CGPoint(x: home.x + 20, y: home.y + 20)
            overlay.dragToolbar()
            pointer.location = CGPoint(x: home.x + 40, y: home.y + 30)
            overlay.dragToolbar()
            expectEqual(bar.frame.origin, home, "22.4 pt away stays locked")
            pointer.location = CGPoint(x: home.x + 220, y: home.y + 120)
            overlay.dragToolbar()
            expectEqual(bar.frame.origin, CGPoint(x: home.x + 200, y: home.y + 100), "far away follows the pointer")
            pointer.location = CGPoint(x: home.x + 30, y: home.y + 25)
            overlay.dragToolbar()
            expectEqual(bar.frame.origin, home, "coming back within 11.2 pt locks again")
        }

        test("the app reports when drawing starts and stops") {
            let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
            let overlay = DrawOverlay(board: board(), screens: { [DrawScreen(frame: frame, visibleFrame: frame, scale: 2)] }, mouseLocation: { .zero })
            var reported: [Bool] = []
            overlay.onActiveChange = { reported.append($0) }
            overlay.open()
            overlay.open()
            overlay.close()
            overlay.close()
            expectEqual(reported, [true, false])
        }

        test("settings show one drawing pane instead of the module panes") {
            let ids = Registry.settingsPanes.map(\.id)
            expect(ids.contains("draw"), "\(ids)")
            for gone in ["hotkeys", "menubar", "background"] { expect(!ids.contains(gone), gone) }
        }

        test("self-test of the real panel passes") { expect(DrawSelfTest.overlay() == nil, DrawSelfTest.overlay() ?? "") }

        test("undo and redo walk the strokes, clear is undoable") {
            let b = board()
            stroke(b, CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0))
            stroke(b, CGPoint(x: 0, y: 10), CGPoint(x: 50, y: 10))
            b.undo()
            expectEqual(b.strokes.count, 1)
            b.redo()
            expectEqual(b.strokes.count, 2)
            b.clear()
            expectEqual(b.strokes.count, 0)
            b.undo()
            expectEqual(b.strokes.count, 2)
        }

        test("a new stroke drops the redo steps") {
            let b = board()
            stroke(b, CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0))
            b.undo()
            stroke(b, CGPoint(x: 0, y: 10), CGPoint(x: 50, y: 10))
            expect(!b.canRedo)
        }

        test("a click with the pen leaves a dot, a click with a shape leaves nothing") {
            let b = board()
            b.begin(at: CGPoint(x: 5, y: 5))
            b.end()
            expectEqual(b.strokes.count, 1)
            b.tool = .rectangle
            stroke(b, CGPoint(x: 5, y: 5), CGPoint(x: 7, y: 6))
            expectEqual(b.strokes.count, 1, "2.2 pt diagonal is below the 4 pt minimum")
        }

        test("shapes keep two points") {
            let b = board()
            b.tool = .oval
            b.begin(at: CGPoint(x: 0, y: 0))
            b.extend(to: CGPoint(x: 10, y: 10), constrained: false)
            b.extend(to: CGPoint(x: 30, y: 20), constrained: false)
            b.end()
            expectEqual(b.strokes[0].points, [CGPoint(x: 0, y: 0), CGPoint(x: 30, y: 20)])
        }

        test("freehand ends exactly where the mouse let go") {
            let b = board()
            b.begin(at: CGPoint(x: 0, y: 0))
            b.extend(to: CGPoint(x: 100, y: 0), constrained: false)
            expect(abs((b.live?.points.last?.x ?? 0) - 55) < 0.001, "smoothing 0.55 of the way")
            b.end()
            expectEqual(b.strokes[0].points.last, CGPoint(x: 100, y: 0))
        }

        test("laser lines are no undo steps and go away by themselves") {
            let queue = Queue()
            let b = board(queue)
            b.tool = .laser
            stroke(b, CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0))
            expectEqual(b.flashes.count, 1)
            expect(b.strokes.isEmpty)
            expect(!b.canUndo)
            expectEqual(queue.items.count, 1)
            expectEqual(queue.items[0].0, 2.0, "1.4 s hold plus 0.6 s fade")
            queue.items[0].1()
            expect(b.flashes.isEmpty)
        }

        test("the pen is remembered") {
            let settings = Settings.inMemory()
            let first = DrawBoard(settings: settings, schedule: { _, _ in })
            first.tool = .arrow
            first.color = .blue
            first.width = .thick
            let second = DrawBoard(settings: settings, schedule: { _, _ in })
            expectEqual(second.tool, .arrow)
            expectEqual(second.color, .blue)
            expectEqual(second.width, .thick)
        }

        test("⇧ makes a square from a drag of 30 by 10") {
            expectEqual(DrawGeometry.constrainedEnd(start: .zero, end: CGPoint(x: 30, y: -10), tool: .rectangle), CGPoint(x: 30, y: -30))
        }

        test("⇧ snaps a line to the nearest 45 degrees") {
            let end = DrawGeometry.constrainedEnd(start: .zero, end: CGPoint(x: 100, y: 5), tool: .arrow)
            expect(abs(end.y) < 0.001, "almost flat becomes flat")
            expect(abs(end.x - hypot(100, 5)) < 0.001, "keeps the length")
        }

        test("the arrow head ends at the tip") {
            let arrow = DrawStroke(id: 1, tool: .arrow, color: .red, width: .medium, points: [.zero, CGPoint(x: 100, y: 0)])
            let box = DrawGeometry.path(of: arrow).boundingBoxOfPath
            expect(abs(box.maxX - 100) < 0.001)
            // head 22.5 pt at 28.8 degrees: wings 22.5 * sin(0.16 pi) = 10.8 pt either side
            expect(abs(box.maxY - 10.83) < 0.05, "wing \(box.maxY)")
        }

        test("the highlighter is four times as wide and see-through") {
            let marker = DrawStroke(id: 1, tool: .marker, color: .yellow, width: .thin, points: [.zero])
            expectEqual(DrawGeometry.lineWidth(of: marker), 12)
            expectEqual(DrawGeometry.opacity(of: marker), 0.4)
        }

        test("keys") {
            func key(_ code: UInt16, _ text: String, command: Bool = false, shift: Bool = false, other: Bool = false) -> DrawKeyAction? {
                DrawKeys.action(keyCode: code, characters: text, command: command, shift: shift, otherModifiers: other)
            }
            expectEqual(key(53, "\u{1b}"), .close)
            expectEqual(key(6, "z", command: true), .undo, "keycode differs on German keyboards, the letter counts")
            expectEqual(key(16, "z", command: true, shift: true), .redo)
            expectEqual(key(51, "\u{7f}"), .clear)
            expectEqual(key(35, "p"), .tool(.pen))
            expectEqual(key(18, "1"), .color(.red))
            expectEqual(key(23, "5"), .color(.white))
            expectEqual(key(30, "+"), .thicker)
            expectEqual(key(44, "-"), .thinner)
            expect(key(35, "p", command: true) == nil, "⌘P does nothing while drawing")
            expect(key(35, "p", other: true) == nil)
        }

        test("width steps stop at both ends") {
            let b = board()
            b.width = .thick
            b.stepWidth(by: 1)
            expectEqual(b.width, .thick)
            b.width = .thin
            b.stepWidth(by: -1)
            expectEqual(b.width, .thin)
            b.stepWidth(by: 1)
            expectEqual(b.width, .medium)
        }
    }
}
#endif
