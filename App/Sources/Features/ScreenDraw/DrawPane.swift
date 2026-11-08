import SwiftUI

/// Everything this app lets you set, in one pane: it replaces the separate panes of the shortcut,
/// menu bar and login modules, whose job lists and options have no use here.
struct DrawPane: View {
    var settings: Settings = .shared
    #if MODUL_BACKGROUND
    var login: LoginItemModel = .shared
    #endif
    #if MODUL_HOTKEYS
    let center: HotkeyCenter
    @State private var recorder: ShortcutRecorder

    init(center: HotkeyCenter = .shared, settings: Settings = .shared) {
        self.center = center
        self.settings = settings
        _recorder = State(initialValue: ShortcutRecorder(center: center))
    }
    #endif

    var body: some View {
        content
            #if MODUL_HOTKEYS
            .onDisappear { recorder.cancel() }
            #endif
            #if MODUL_BACKGROUND
            .onAppear { login.refresh() }
            #endif
    }

    private var content: some View {
        PaneScaffold(title: DrawText.paneTitle, symbol: "scribble.variable", tint: .accent, subtitle: DrawText.paneIntro) {
            #if MODUL_HOTKEYS
            SettingsSection(DrawText.shortcutSection) {
                ShortcutRecorderRow(DrawFeature.hotkeyID, center: center, recorder: recorder)
            }
            #endif
            #if MODUL_MENUBAR
            menuBarSection
            #endif
            #if MODUL_BACKGROUND
            loginSection
            #endif
        }
    }

    #if MODUL_MENUBAR
    private var menuBarSection: some View {
        let style = Binding(get: { MenuBarIconStyle(setting: settings[.menuBarIconStyle]) },
                            set: { settings[.menuBarIconStyle] = $0.rawValue })
        return SettingsSection(MenuBarText.iconSection, footnote: DrawText.styleNote(style.wrappedValue),
                               footnoteReserve: MenuBarIconStyle.allCases.map(DrawText.styleNote)) {
            TilePicker(MenuBarIconStyle.allCases.map { TileOption($0, title: DrawText.styleName($0)) },
                       selection: style, tone: .settings) { value in
                DrawIconPreview(style: value)
            }
        }
    }
    #endif

    #if MODUL_BACKGROUND
    @ViewBuilder private var loginSection: some View {
        let openAtLogin = Binding(get: { login.isOn }, set: { login.set($0) })
        SettingsSection(BackgroundText.startSection, footnote: login.unavailable.map(BackgroundText.unavailable)) {
            ToggleRow(BackgroundText.openAtLogin, subtitle: BackgroundText.openAtLoginDetail, isOn: openAtLogin)
                .disabled(login.unavailable != nil)
        }
        if login.status == .requiresApproval {
            InlineNotice(BackgroundText.needsApproval, kind: .warning, actionTitle: BackgroundText.openLoginItems) {
                LoginItem.openSystemSettings()
            }
        }
        if let error = login.error {
            InlineNotice(error, kind: .error)
        }
    }
    #endif
}

#if MODUL_MENUBAR
/// The two states this app uses, ready and drawing, in a piece of menu bar.
private struct DrawIconPreview: View {
    let style: MenuBarIconStyle
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme)
        VStack(spacing: 0) {
            HStack(spacing: Space.m) {
                ForEach([MenuBarState.idle, .busy], id: \.self) { state in
                    MenuBarIconImage(state: state, style: style, scale: MenuBarIconMetrics.previewScale)
                }
            }
            .frame(maxWidth: .infinity, minHeight: MenuBarIconMetrics.previewBar)
            .background(t.menuBarTint)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(t.wallpaper)
        .accessibilityLabel(DrawText.styleName(style))
    }
}
#endif
