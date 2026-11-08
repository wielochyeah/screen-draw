import Carbon
import SwiftUI

enum DrawFeature {
    static let hotkeyID = "draw.toggle"

    #if MODUL_HOTKEYS
    /// ⇧⌘1: next to VoiceBud's ⇧⌘2 and the screenshot keys ⇧⌘3 to ⇧⌘6, and taken by neither.
    static let standardHotkey = KeyCombo(keyCode: UInt16(kVK_ANSI_1), modifiers: [.shift, .command])
    #endif

    static func register() {
        #if MODUL_HOTKEYS
        HotkeyCenter.shared.register(id: hotkeyID, title: { DrawText.hotkeyTitle }, subtitle: { DrawText.hotkeySubtitle },
                                     default: standardHotkey, order: 10, showInOnboarding: true) { DrawOverlay.shared.toggle() }
        #endif
        // after the hotkey: its first registration is what adds the module's own pane
        Registry.settingsPanes.removeAll { ["hotkeys", "menubar", "background"].contains($0.id) }
        Registry.settingsPanes.append(SettingsPane(id: "draw", group: .settings, order: 100, title: { DrawText.paneTitle },
                                                   symbol: "scribble.variable", tint: .accent) { AnyView(DrawPane()) })
        Registry.menuItems.append(MenuItemContribution(id: "draw.toggle", order: 10, title: { menuTitle }, symbol: "scribble.variable",
                                                       shortcut: nil) { DrawOverlay.shared.toggle() })
        Registry.terminateHooks.append { DrawOverlay.shared.close() }
        OnboardingFeatures.items.append(OnboardingFeature(id: "draw.pen", order: 10, symbol: "pencil",
                                                          title: { DrawText.featurePenTitle }, detail: { DrawText.featurePenDetail }))
        OnboardingFeatures.items.append(OnboardingFeature(id: "draw.laser", order: 20, symbol: "cursorarrow.rays",
                                                          title: { DrawText.featureLaserTitle }, detail: { DrawText.featureLaserDetail }))
        OnboardingFeatures.items.append(OnboardingFeature(id: "draw.key", order: 30, symbol: "command",
                                                          title: { DrawText.featureKeyTitle }, detail: { DrawText.featureKeyDetail }))
        Registry.selfTests.append(SelfTestCheck(id: "draw.overlay") { DrawSelfTest.overlay() })
        DrawScenes.register()
    }

    private static var menuTitle: String {
        var keys: String?
        #if MODUL_HOTKEYS
        keys = HotkeyCenter.shared.display(hotkeyID)
        #endif
        return DrawText.menuTitle(active: DrawOverlay.shared.isActive, keys: keys)
    }
}

enum DrawSelfTest {
    /// The real panels and canvas, never on screen: a synthetic drag has to leave one layer on the right display.
    static func overlay() -> String? {
        let frame = CGRect(x: 1000, y: 200, width: 800, height: 600)
        let overlay = DrawOverlay(board: DrawBoard(settings: .inMemory()),
                                  screens: { [DrawScreen(frame: frame, visibleFrame: frame, scale: 2)] }, mouseLocation: { CGPoint(x: 1100, y: 300) })
        overlay.open()
        defer { overlay.close() }
        guard let panel = overlay.panels.first else { return "no panel opened" }
        guard panel.frame == frame else { return "panel frame \(panel.frame), expected \(frame)" }
        guard panel.level == .screenSaver else { return "panel is not above other windows" }
        guard panel.styleMask.contains(.nonactivatingPanel), panel.canBecomeKey else { return "panel would activate the app or get no keys" }
        func mouse(_ type: NSEvent.EventType, _ x: CGFloat, _ y: CGFloat) -> NSEvent? {
            NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: y), modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
                               context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
        }
        guard let down = mouse(.leftMouseDown, 10, 10), let drag = mouse(.leftMouseDragged, 60, 40), let up = mouse(.leftMouseUp, 60, 40) else {
            return "cannot build mouse events"
        }
        panel.canvas.mouseDown(with: down)
        panel.canvas.mouseDragged(with: drag)
        panel.canvas.mouseUp(with: up)
        guard panel.canvas.layerCount == 1 else { return "expected 1 ink layer, got \(panel.canvas.layerCount)" }
        guard overlay.board.strokes.first?.points.first == CGPoint(x: 1010, y: 210) else { return "stroke does not start in screen coordinates" }
        return nil
    }
}
