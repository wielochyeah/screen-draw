# Module

Jedes Modul ist ein Ordner unter `App/Sources/Modules/<Name>/` mit `<Name>Module.register()`, eingeschaltet in `starter.json` (`modules`) und als Compiler-Flag `MODUL_<NAME>` gebaut. Ein Modul nutzt nur das Kit und meldet alles über die Registry an: Seiten, Einstellungsbereiche, Einrichtungsschritte, Menüeinträge, Galerie-Einträge, Render-Szenen, Selbsttests. Einstellungsschlüssel tragen das Präfix des Moduls.

| Modul | Form oder Aufgabe | Standard | braucht | Entfernen |
|---|---|---|---|---|
| `menubar` | Menüleisten-App mit Statussymbol und Statusmenü | an | | `bin/starter remove menubar` | <!-- modul:menubar -->
| `background` | geplante Aufgaben, Start beim Anmelden | an | | `bin/starter remove background` | <!-- modul:background -->
| `hotkeys` | globale Tastaturkurzbefehle | an | | `bin/starter remove hotkeys` | <!-- modul:hotkeys -->

Mindestens `window` oder `menubar` bleibt; ohne beide sind die Einstellungen nicht erreichbar, und `bin/starter remove` lehnt das ab. Mit `window` hat die App ein Dock-Symbol (`.regular`), ohne `window` lebt sie nur in der Menüleiste (`.accessory`, `LSUIElement`).

`bin/starter remove <modul>` löscht den Ordner des Moduls und alles, was `starter.manifest.json` ihm zuordnet (Tests, Skills, Werkzeuge), entfernt jeden `#if MODUL_<NAME>` … `#endif`-Block in allen Swift-Dateien (bei `#else` bleibt dieser Teil), Zeilen mit `<!-- modul:<name> -->` und Abschnitte zwischen `<!-- modul:<name>:anfang -->` und `<!-- modul:<name>:ende -->` in Markdown (in YAML, Shell und Python `# modul:<name>`) und das Modul aus `starter.json`; danach baut es (`--ohne-build` lässt das aus, `--probelauf` zeigt nur, was passieren würde). Ein Commit je entferntem Modul.

`make build MODULES=a,b` baut eine andere Auswahl, ohne `starter.json` zu ändern.

## Reihenfolge in der Registry

Jedes Modul hat für seine Einstellungsbereiche und Einrichtungsschritte einen eigenen Bereich von `order`-Werten; zwei Beiträge teilen sich nie einen Wert (`Registry.problems()` meldet es, im Selbsttest `kit.registry` und in `RegistryTests`). Eigene Funktionen des Projekts nehmen die freien Bereiche, in Zehnerschritten.

| `order` | Einstellungsbereich (Gruppe `.settings`, unter den Inhalten) |
|---|---|
| 0 | Allgemein (Kit) |
| 100 bis 199 | Funktionen des Projekts |
| 250 bis 299 | Menüleiste (`menubar`, 250) | <!-- modul:menubar -->
| 350 bis 399 | Hintergrund (`background`, 350) | <!-- modul:background -->
| 400 bis 449 | Tastaturkurzbefehle (`hotkeys`, 400) | <!-- modul:hotkeys -->
| 1000 | Über (Kit) |

Die Gruppe `.content` steht oben; dort beginnen Bereiche der Funktionen bei 100 (Beispiel „Notizen“), die Galerie des Kits (nur in Debug-Builds) hat 900. Die Reihenfolge der Einrichtungsschritte steht im Skill `neuer-onboarding-schritt`: Kit 0 bis 20, Funktionen 30 bis 299, Berechtigungen 300 bis 399, dann `ai` 400, `island` 500, `hotkeys` 600, `background` 900, Fertig 1000.

<!-- modul:menubar:anfang -->
## menubar: Menüleisten-App

- **Zweck:** Statussymbol aus `app.symbol` mit den Zuständen `idle`, `busy` (dezente Bewegung, ruht bei reduzierter Bewegung) und `attention` (Punkt). Klick öffnet das Statusmenü im Stil der Module im Kontrollzentrum (abgerundet, Glas, 340 pt breit) mit Kopf, Abschnitten und Fußzeile; Rechtsklick oder ⌥-Klick öffnet ein Menü aus `Registry.menuItems`.
- **Dateien:** `MenuBarController`, `MenuBarStatus.shared.state`, `MenuBarPanel.sections` (Abschnitte mit Kennung, Reihenfolge und View).
- **Einstellungen:** Bereich „Menüleiste“ mit Statustext und Stil des Symbols (Präfix `menubar.`).
- **Einrichtung:** kein Schritt.
- **Szenen:** `menubar.panel`, `menubar.icon-states` mit Beispieldaten; `menubar.project` zeigt das Statusmenü des Projekts mit seinen eigenen Abschnitten und Menüeinträgen. Eigene Abschnitte rendern Features auf `MenuBarPanelStage` (Menüleiste, Schreibtisch, Statusmenü).
- **Skill:** `menueleisten-app`.
<!-- modul:menubar:ende -->

<!-- modul:background:anfang -->
## background: Hintergrund

- **Zweck:** geplante Aufgaben über `NSBackgroundActivityScheduler` mit Intervall, Toleranz und Dienstgüte; letzter Lauf, Ergebnis und Dauer werden gespeichert; Schalter und „Jetzt ausführen“ je Aufgabe. Start beim Anmelden über `SMAppService.mainApp`, nur aus einem installierten Ort.
- **Dateien:** `BackgroundJobs` (`register(id:title:interval:tolerance:qos:exact:run:)`, `runNow(_:)`), `LoginItem` (`isAvailable` mit Begründung).
- **Einstellungen:** Bereich „Hintergrund“ mit Anmeldeobjekt und Liste der Aufgaben (Präfix `background.`).
- **Einrichtung:** „Mit dem Mac starten“ (order 900), nur wenn `LoginItem.isAvailable`; die Wahl gilt erst nach „Fertig“ (`Registry.onboardingFinishedHooks`).
- **Szenen:** `background.pane`, `background.onboarding`.
- **Skill:** `hintergrund-job`.
<!-- modul:background:ende -->

<!-- modul:hotkeys:anfang -->
## hotkeys: Tastaturkurzbefehle

- **Zweck:** globale Tastaturkurzbefehle über Carbon `RegisterEventHotKey` (ohne Berechtigung für Eingabeüberwachung), änderbar durch die Nutzerin, ohne Neustart neu angemeldet. Regeln lehnen Kurzbefehle des Systems, Standardbefehle von Apps, Kombinationen, die auf der aktuellen Belegung ein Zeichen tippen, und Doppelungen ab; jede Ablehnung nennt den Grund in beiden Sprachen und schlägt eine freie Variante vor.
- **Dateien:** `KeyCombo` (Anzeige mit ⌃⌥⇧⌘ und Tastennamen der Belegung), `HotkeyCenter` (`register(id:title:default:action:)`), `ShortcutRules`, `ShortcutRecorder`.
- **Einstellungen:** Bereich „Tastaturkurzbefehle“; Änderungen der Nutzerin mit Präfix `hotkeys.`.
- **Einrichtung:** „Dein Tastaturkurzbefehl“ (order 600), nur wenn ein Kurzbefehl mit `showInOnboarding: true` angemeldet ist.
- **Szenen:** `hotkeys.pane`, `hotkeys.recorder-states`, `hotkeys.onboarding`.
- **Skill:** `kurzbefehl`.
<!-- modul:hotkeys:ende -->

## Kit (nicht entfernbar)

| Bereich | Ordner | Inhalt |
|---|---|---|
| Core | `Kit/Core/` | Sprache, Einstellungen, Datenbank, Registry, Render-Modus, Pfade, Protokoll |
| Design | `Kit/Design/` | Tokens, Komponenten, Muster (`docs/DESIGN.md`) |
| Texte | `Kit/Texts/` | gemeinsame Wörter (`CommonText`, `KitText`) |
| Einrichtung | `Kit/Onboarding/` | Fenster 720 x 560, Ablauf, Schritte Begrüßung (0, Bild über `Registry.welcomeArt` ersetzbar), Sprache (10), Funktionen (20), Berechtigungen (300 und folgende), Fertig (1000); Szenen `onboarding.*` mit Beispieldaten, `onboarding.project` mit jedem Schritt des Projekts |
| Berechtigungen | `Kit/Permissions/` | Arten, Status, Anfrage, Links in die Systemeinstellungen, Abfrage während jemand hinsieht, Neustart |
| Einstellungen | `Kit/Settings/` | Fenster 900 x 620 mit Seitenleiste (Gruppen Inhalt und Einstellungen), Bereiche „Allgemein“ (Sprache, Erscheinungsbild, Einrichtung erneut zeigen, zurücksetzen) und „Über“ |
| Galerie | `Kit/Gallery/` | jeder Baustein aus `Registry.gallery`, in Debug-Builds oder mit `kit.showGallery` |
| Render | `Kit/Render/` | `--render` für `make shots` |
| Main | `Kit/Main/` | Start, Flags, Aktivierungsrichtlinie, Fenster, Hauptmenü, Modulliste, Selbsttest |
