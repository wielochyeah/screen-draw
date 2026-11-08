# Projekt

## 1. Projekt

| Feld | Angabe |
|---|---|
| Name | `Screen Draw` |
| Bundle-ID | `local.screendraw` |
| Zweck | Mit einem Tastaturkurzbefehl direkt auf dem Bildschirm zeichnen, um anderen in einem Gespräch etwas zu zeigen. Noch einmal drücken beendet das Zeichnen. |
| Zielgruppe | Der Auftraggeber, kein Vorwissen nötig |
| UI-Sprachen | Englisch und Deutsch, Anrede im Deutschen du |
| Mindestversion | macOS 26.0 |
| Akzent und Symbol | `rot`, SF Symbol `scribble.variable` |
| Auftraggeber | Nils Wieloch |

## 2. App-Formen

| Form | Modul | genutzt | Wofür |
|---|---|---|---|
| Fenster-App | `window` | nein | entfällt, das Zeichnen läuft in Panels über dem Bildschirm |
| Menüleisten-App | `menubar` | ja | Statusmenü mit „Zeichnen starten“ und dem aktuellen Kurzbefehl |
| Insel an der Notch | `island` | nein | entfällt, kein Zustand zu melden |
| Hintergrund | `background` | ja | nur Start beim Anmelden, damit der Kurzbefehl immer greift; keine Aufgaben |

## 3. Ansichten

| Ansicht | Ort | Frage der Nutzerin | Hauptaktion | Render-Szene |
|---|---|---|---|---|
| Zeichnen | Panel je Bildschirm | Wie zeige ich etwas? | Mit der Maus zeichnen | `draw.overlay` |
| Werkzeugleiste | unten auf dem Bildschirm mit dem Zeiger | Womit zeichne ich? | Werkzeug wählen | `draw.toolbar` |
| Zeichnen | Einstellungen, ersetzt die Bereiche der Module `hotkeys`, `menubar` und `background` | Welche Taste startet das Zeichnen? | Ändern | `draw.pane`, `draw.settings` |
| Statusmenü | Menüleiste | Wie starte ich ohne Tastatur? | Zeichnen starten | `draw.menubar` |

## 4. Datenobjekte und Speicher

| Objekt | Speicherort | Tabelle oder Schlüssel | Feature-Ordner |
|---|---|---|---|
| Zeichnung | nur im Speicher, weg beim Beenden | entfällt | `App/Sources/Features/ScreenDraw/` |
| Zuletzt gewähltes Werkzeug, Farbe, Linie | `Settings` (`settings.json`) | `draw.tool`, `draw.color`, `draw.width` | `App/Sources/Features/ScreenDraw/` |
| Kurzbefehl | `Settings` (`settings.json`) | `hotkeys.draw.toggle` | `App/Sources/Modules/Hotkeys/` |

Daten liegen unter `~/Library/Application Support/local.screendraw/`.

## 5. Berechtigungen

Keine. Der Kurzbefehl läuft über Carbon `RegisterEventHotKey`, das Zeichnen liest den Bildschirm nicht.

## 6. Lokale KI

Entfällt, die App nutzt keine KI.

## 7. Fachsprache

- **Begriffe mit Erklärung**: Laser: Linie, die etwa 2 Sekunden nach dem Loslassen verschwindet.
- **Verbotene Begriffe** dieses Projekts: keine.
- **Pflichtformulierungen**: keine.

## 8. Verteilung

| Feld | Angabe |
|---|---|
| Signatur | ad hoc |
| Notarisierung | nein |
| Weitergabe | nur eigener Mac |
| Updates | neu bauen |

## 9. Festlegungen

Entscheidungen des Projekts stehen in `docs/DECISIONS.md` mit Datum, Grund und Folgen, die des Starters in `docs/STARTER_DECISIONS.md`.

## 10. Offene Fragen an den Auftraggeber

| Nr. | Frage | Kontext | Stand |
|---|---|---|---|
| 1 | Soll die App ein eigenes Symbol bekommen? | Das App-Symbol nutzt zurzeit ein SF Symbol; das ist für die Weitergabe an andere nicht erlaubt (`docs/VERTEILUNG.md`, Abschnitt 8). | offen, nur nötig bei Weitergabe |
