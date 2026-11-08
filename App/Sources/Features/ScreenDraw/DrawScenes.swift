import SwiftUI

enum DrawSamples {
    /// Marks on the sample slide of `DrawStage`, in its coordinates (origin bottom left).
    static func board() -> DrawBoard {
        let board = DrawBoard(settings: .inMemory(), schedule: { _, _ in })
        func draw(_ tool: DrawTool, _ color: InkColor, _ width: InkWidth, _ points: [CGPoint]) {
            guard let first = points.first else { return }
            board.tool = tool
            board.color = color
            board.width = width
            board.begin(at: first)
            points.dropFirst().forEach { board.extend(to: $0, constrained: false) }
            board.end()
        }
        draw(.marker, .yellow, .medium, [CGPoint(x: 362, y: 435), CGPoint(x: 438, y: 435)])
        draw(.pen, .red, .medium, circle(center: CGPoint(x: 896, y: 385), radiusX: 50, radiusY: 26))
        draw(.arrow, .blue, .medium, [CGPoint(x: 1090, y: 215), CGPoint(x: 960, y: 362)])
        board.tool = .pen
        board.color = .red
        board.width = .medium
        return board
    }

    /// A hand-drawn ring: overshoots its start and wobbles a little, like a mouse does.
    private static func circle(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) -> [CGPoint] {
        stride(from: 0.0, through: 2.15 * Double.pi, by: 0.06).map { angle in
            let wobble = 1 + 0.03 * sin(angle * 5) + 0.018 * angle
            return CGPoint(x: center.x + radiusX * wobble * cos(angle + 2), y: center.y + radiusY * wobble * sin(angle + 2))
        }
    }
}

/// The drawing mode on a sample screen: the real canvas layers and the real toolbar.
struct DrawStage: View {
    @Environment(\.colorScheme) private var scheme
    @State private var board = DrawSamples.board()

    var body: some View {
        let t = Theme(scheme)
        ZStack(alignment: .bottom) {
            Rectangle().fill(t.wallpaper)
            slide(t).frame(maxWidth: .infinity, maxHeight: .infinity)
            if let ink = DrawCanvasView(board: board, screenFrame: CGRect(origin: .zero, size: DrawLook.stage), scale: 2).snapshot(scale: 2) {
                Image(decorative: ink, scale: 2).allowsHitTesting(false)
            }
            DrawToolbar(board: board, onClose: {}, onDragChanged: {}, onDragEnded: {})
        }
        .frame(width: DrawLook.stage.width, height: DrawLook.stage.height)
    }

    private func slide(_ t: Theme) -> some View {
        GlassSurface(cornerRadius: Radius.panel) {
            VStack(alignment: .leading, spacing: Space.l) {
                Text(DrawText.sampleHeading).font(TypeScale.title).foregroundStyle(t.fg)
                ForEach(DrawText.sampleRows, id: \.0) { row in
                    HStack {
                        Text(row.0).font(TypeScale.headline).foregroundStyle(t.fg2)
                        Spacer()
                        Text(row.1).font(TypeScale.title).monospacedDigit().foregroundStyle(t.fg)
                    }
                }
            }
            .padding(Space.xl)
            .frame(width: DrawLook.sampleCard.width, height: DrawLook.sampleCard.height, alignment: .top)
        }
    }
}

enum DrawScenes {
    static func register() {
        Registry.renderScenes.append(RenderScene(id: "draw.toolbar", size: .zero) {
            AnyView(DrawToolbar(board: DrawSamples.board(), onClose: {}, onDragChanged: {}, onDragEnded: {}))
        })
        Registry.renderScenes.append(RenderScene(id: "draw.overlay", size: DrawLook.stage) { AnyView(DrawStage()) })
        #if MODUL_HOTKEYS
        Registry.renderScenes.append(RenderScene(id: "draw.pane", size: SettingsScenes.paneSize) {
            let center = HotkeyCenter(backend: FakeHotkeyBackend(), store: MemoryHotkeyStore())
            center.layout = TableKeyboardLayout.us
            center.register(id: DrawFeature.hotkeyID, title: { DrawText.hotkeyTitle }, subtitle: { DrawText.hotkeySubtitle },
                            default: DrawFeature.standardHotkey) {}
            return AnyView(DrawPane(center: center, settings: .inMemory()))
        })
        #endif
        Registry.renderScenes.append(RenderScene(id: "draw.settings", size: .zero) { AnyView(SettingsScenes.window(pane: "draw")) })
        #if MODUL_MENUBAR
        Registry.renderScenes.append(RenderScene(id: "draw.menubar", size: .zero) {
            let toggle = MenuItemContribution(id: "draw.toggle", order: 10, title: { DrawText.menuTitle(active: false, keys: "⇧⌘1") },
                                              symbol: "scribble.variable", shortcut: nil) {}
            return AnyView(MenuBarPanelStage(status: MenuBarStatus(), sections: [], actions: [toggle], showsWindowAction: false))
        })
        #endif
    }
}
