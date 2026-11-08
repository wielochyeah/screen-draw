import SwiftUI

enum DrawLook {
    static let toolButton: CGFloat = 38
    static let dotButton: CGFloat = 28
    static let colorDot: CGFloat = 18
    static let selectionRing: CGFloat = 2
    static let toolGlyph: CGFloat = 17
    static let gripGlyph: CGFloat = 12
    /// Distance of the toolbar from the bottom of the usable screen.
    static let toolbarLift: CGFloat = 16
    static let closeFade: TimeInterval = 0.12
    /// Closer than this to its usual place, the toolbar locks onto it.
    static let snapRadius: CGFloat = 36
    static let snapDuration: TimeInterval = 0.14
    static let stage = CGSize(width: 1280, height: 800)
    static let sampleCard = CGSize(width: 620, height: 360)
    /// Renders cannot draw real glass: the stand-in stays this opaque, so the backdrop shows through as on screen.
    static let glassPreview: Double = 0.62

    static func widthDot(_ width: InkWidth) -> CGFloat {
        switch width {
        case .thin: 5
        case .medium: 9
        case .thick: 14
        }
    }
}

private struct DrawButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Motion.pressScaleSmall : 1)
            .animation(Motion.adaptive(Motion.press, reduce: reduceMotion), value: configuration.isPressed)
    }
}

/// A floating capsule of Liquid Glass. The grip and every empty spot move the bar; the buttons sit directly on the glass.
struct DrawToolbar: View {
    @Bindable var board: DrawBoard
    let onClose: () -> Void
    let onDragChanged: () -> Void
    let onDragEnded: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.renderStatic) private var renderStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    @State private var appeared = false

    private var isStatic: Bool { renderStatic || RenderMode.isStatic }
    private var slide: Animation { Motion.adaptive(Motion.selection, reduce: reduceMotion) }

    var body: some View {
        let t = Theme(scheme)
        let shown = appeared || isStatic
        bar(t)
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { _ in onDragChanged() }
                .onEnded { _ in onDragEnded() })
            .padding(Space.m)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : Motion.pageOffset)
            .onAppear { withAnimation(Motion.adaptive(Motion.page, reduce: reduceMotion)) { appeared = true } }
    }

    @ViewBuilder private func bar(_ t: Theme) -> some View {
        let content = HStack(spacing: Space.m) {
            HStack(spacing: Space.xs) {
                Image(systemName: "line.3.horizontal")
                    .symbolFont(DrawLook.gripGlyph, weight: .semibold)
                    .foregroundStyle(glyph(t))
                    .opacity(Metrics.disabledOpacity)
                    .padding(.leading, Space.xs)
                    .help(DrawText.move)
                    .accessibilityLabel(DrawText.move)
                tools(t)
            }
            colors(t)
            widths(t)
            actions(t)
        }
        .padding(Space.xs)
        if isStatic {
            content
                .background(Capsule().fill(t.glassStandIn).opacity(DrawLook.glassPreview))
                .shadow(color: t.panelShadow, radius: Space.xs, y: Space.hair)
        } else {
            content.glassEffect(.regular, in: Capsule())
        }
    }

    private func glyph(_ t: Theme) -> AnyShapeStyle {
        if isStatic { return AnyShapeStyle(t.fg) }
        // design-ausnahme: glass turns light or dark with what is behind it, .primary follows that and a fixed token does not
        return AnyShapeStyle(HierarchicalShapeStyle.primary)
    }

    private func tools(_ t: Theme) -> some View {
        HStack(spacing: 0) {
            ForEach(DrawTool.allCases, id: \.self) { tool in
                let selected = board.tool == tool
                Button { board.tool = tool } label: {
                    Image(systemName: tool.symbol)
                        .symbolFont(DrawLook.toolGlyph, weight: .medium)
                        .foregroundStyle(selected ? AnyShapeStyle(t.accentText) : glyph(t))
                        .frame(width: DrawLook.toolButton, height: DrawLook.toolButton)
                        .background {
                            if selected { Circle().fill(t.chipActive).matchedGeometryEffect(id: "tool", in: selection) }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(DrawButtonStyle())
                .help(DrawText.withKey(DrawText.name(tool), tool.key))
                .accessibilityLabel(DrawText.name(tool))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .animation(slide, value: board.tool)
    }

    private func colors(_ t: Theme) -> some View {
        HStack(spacing: 0) {
            ForEach(InkColor.allCases, id: \.self) { color in
                let selected = board.color == color
                Button { board.color = color } label: {
                    Circle().fill(ink(color))
                        .frame(width: DrawLook.colorDot, height: DrawLook.colorDot)
                        .overlay(Circle().strokeBorder(t.windowStroke, lineWidth: Metrics.hairline))
                        .frame(width: DrawLook.dotButton, height: DrawLook.dotButton)
                        .overlay {
                            if selected {
                                Circle().strokeBorder(glyph(t), lineWidth: DrawLook.selectionRing)
                                    .matchedGeometryEffect(id: "color", in: selection)
                            }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(DrawButtonStyle())
                .help(DrawText.withKey(DrawText.name(color), color.key))
                .accessibilityLabel(DrawText.name(color))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .animation(slide, value: board.color)
    }

    private func ink(_ color: InkColor) -> Color {
        // design-ausnahme: the swatch shows the exact ink, it is not interface chrome
        Color(cgColor: color.cgColor)
    }

    private func widths(_ t: Theme) -> some View {
        HStack(spacing: 0) {
            ForEach(InkWidth.allCases, id: \.self) { width in
                let selected = board.width == width
                Button { board.width = width } label: {
                    Circle().fill(glyph(t))
                        .frame(width: DrawLook.widthDot(width), height: DrawLook.widthDot(width))
                        .frame(width: DrawLook.dotButton, height: DrawLook.dotButton)
                        .background {
                            if selected { Circle().fill(t.chipActive).matchedGeometryEffect(id: "width", in: selection) }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(DrawButtonStyle())
                .help(DrawText.name(width))
                .accessibilityLabel(DrawText.name(width))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .animation(slide, value: board.width)
    }

    private func actions(_ t: Theme) -> some View {
        HStack(spacing: 0) {
            action("arrow.uturn.backward", DrawText.undo, enabled: board.canUndo, t) { board.undo() }
            action("arrow.uturn.forward", DrawText.redo, enabled: board.canRedo, t) { board.redo() }
            action("trash", DrawText.clear, enabled: !board.strokes.isEmpty, t) { board.clear() }
            action("xmark", DrawText.close, enabled: true, filled: true, t, onClose)
                .padding(.leading, Space.xxs)
        }
    }

    private func action(_ symbol: String, _ label: String, enabled: Bool, filled: Bool = false, _ t: Theme, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: symbol)
                .symbolFont(DrawLook.toolGlyph, weight: .medium)
                .foregroundStyle(glyph(t))
                .frame(width: DrawLook.toolButton, height: DrawLook.toolButton)
                .background(Circle().fill(filled ? t.chip : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(DrawButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : Metrics.disabledOpacity)
        .help(label)
        .accessibilityLabel(label)
    }
}
