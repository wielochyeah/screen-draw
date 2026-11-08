enum DrawText {
    static var hotkeyTitle: String { tr(en: "Draw on the screen", de: "Auf dem Bildschirm zeichnen") }
    static var hotkeySubtitle: String { tr(en: "Press once to start, press again to stop.", de: "Einmal drücken startet, erneut drücken beendet.") }

    static func menuTitle(active: Bool, keys: String?) -> String {
        let action = active ? tr(en: "Stop Drawing", de: "Zeichnen beenden") : tr(en: "Start Drawing", de: "Zeichnen starten")
        guard let keys else { return action }
        return "\(action) (\(keys))"
    }

    static func name(_ tool: DrawTool) -> String {
        switch tool {
        case .pen: tr(en: "Pen", de: "Stift")
        case .marker: tr(en: "Highlighter", de: "Textmarker")
        case .arrow: tr(en: "Arrow", de: "Pfeil")
        case .rectangle: tr(en: "Rectangle", de: "Rechteck")
        case .oval: tr(en: "Circle", de: "Kreis")
        case .laser: tr(en: "Laser, fades by itself", de: "Laser, verblasst von selbst")
        }
    }

    static func name(_ color: InkColor) -> String {
        switch color {
        case .red: tr(en: "Red", de: "Rot")
        case .yellow: tr(en: "Yellow", de: "Gelb")
        case .green: tr(en: "Green", de: "Grün")
        case .blue: tr(en: "Blue", de: "Blau")
        case .white: tr(en: "White", de: "Weiß")
        case .black: tr(en: "Black", de: "Schwarz")
        }
    }

    static func name(_ width: InkWidth) -> String {
        switch width {
        case .thin: tr(en: "Thin line", de: "Dünne Linie")
        case .medium: tr(en: "Medium line", de: "Mittlere Linie")
        case .thick: tr(en: "Thick line", de: "Dicke Linie")
        }
    }

    static func withKey(_ name: String, _ key: String) -> String { "\(name) (\(key.uppercased()))" }

    static var undo: String { tr(en: "Undo", de: "Widerrufen") }
    static var redo: String { tr(en: "Redo", de: "Wiederholen") }
    static var clear: String { tr(en: "Clear All", de: "Alles löschen") }
    static var close: String { tr(en: "Stop Drawing", de: "Zeichnen beenden") }
    static var statusDrawing: String { tr(en: "Drawing", de: "Zeichnet") }

    static var paneTitle: String { tr(en: "Drawing", de: "Zeichnen") }
    static var paneIntro: String { tr(en: "Shortcut, menu bar icon and start at login.", de: "Kurzbefehl, Symbol in der Menüleiste und Start beim Anmelden.") }
    static var shortcutSection: String { tr(en: "Shortcut", de: "Kurzbefehl") }

    #if MODUL_MENUBAR
    static func styleName(_ style: MenuBarIconStyle) -> String {
        style == .marks ? tr(en: "Ring", de: "Ring") : MenuBarText.styleName(style)
    }

    static func styleNote(_ style: MenuBarIconStyle) -> String {
        switch style {
        case .plain: tr(en: "The icon stays the same while you draw.", de: "Das Symbol bleibt gleich, während du zeichnest.")
        case .marks: tr(en: "A small ring turns while you draw.", de: "Ein kleiner Ring dreht sich, während du zeichnest.")
        case .color: tr(en: "The icon takes the accent color while you draw.", de: "Das Symbol nimmt die Akzentfarbe an, während du zeichnest.")
        }
    }
    #endif

    static var move: String { tr(en: "Move Toolbar", de: "Werkzeugleiste bewegen") }

    static var featurePenTitle: String { tr(en: "Draw over every app", de: "Über jeder App zeichnen") }
    static var featurePenDetail: String {
        tr(en: "Circle, underline or point with an arrow while others watch your screen.",
           de: "Kreise ein, unterstreiche oder zeige mit einem Pfeil, während andere deinen Bildschirm sehen.")
    }
    static var featureLaserTitle: String { tr(en: "Laser that fades", de: "Laser, der verblasst") }
    static var featureLaserDetail: String {
        tr(en: "Laser lines disappear about 2 seconds after you let go.",
           de: "Linien des Lasers verschwinden etwa 2 Sekunden nach dem Loslassen.")
    }
    static var featureKeyTitle: String { tr(en: "One shortcut, on and off", de: "Ein Kurzbefehl, an und aus") }
    static var featureKeyDetail: String {
        tr(en: "The same keys start and stop drawing. When you stop, the drawing is gone.",
           de: "Dieselben Tasten starten und beenden das Zeichnen. Beim Beenden verschwindet die Zeichnung.")
    }

    static var sampleHeading: String { tr(en: "Revenue by quarter", de: "Umsatz je Quartal") }
    static var sampleRows: [(String, String)] {
        [(tr(en: "Quarter 1", de: "Quartal 1"), Format.number(412)),
         (tr(en: "Quarter 2", de: "Quartal 2"), Format.number(438)),
         (tr(en: "Quarter 3", de: "Quartal 3"), Format.number(517))]
    }
}
