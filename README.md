# Screen Draw

Screen Draw ist eine native Mac-App, entstanden aus dem mac-app-starter. Zweck, Zielgruppe und offene Fragen stehen in `docs/PROJECT.md`, Einrichtung und Weiterbau in `docs/UEBERGABE.md`.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `CLAUDE.md` | Teil A: allgemeine Regeln, erzeugt aus `rules/`; Teil B: Verweis auf das Projekt |
| `rules/` | einzige Regelquelle: Regelgruppen, Wortlisten; `rules/projekt/` für die Regeln des Projekts |
| `starter.json` | die eine Konfiguration: Name, Bundle-ID, Akzent, Symbol, Module, Berechtigungen, Sprachen, Commit-Identität, Signatur |
| `starter.manifest.json` | Kit-, gemeinsame und Projekt-Pfade, Module mit ihren Pfaden und Abhängigkeiten |
| `starter.lock.json` | Starter-Fassung und Prüfsummen der Kit-Dateien eines Projekts |
| `App/Sources/Kit/` | immer dabei: Sprache, Einstellungen, Datenbank, Registry, Design, Einrichtung, Einstellungsfenster, Berechtigungen, Galerie, Render, Start |
| `App/Sources/Modules/` | entfernbare Module, je Ordner eines |
| `App/Sources/Features/` | Funktionen des Projekts |
| `App/Resources/` | Nutzungsbeschreibungen der Berechtigungen (`InfoPlist.json`), App-Symbol, Hinweise zu Fremdcode für „Über“ (`Notices/`) |
| `App/Tests/` | Swift-Tests mit eigenem Harness |
| `tools/` | App-Symbol und DMG-Hintergrund in Swift, Einstellungen für dmgbuild |
| `scripts/` | Build, Tests, Renders, Prüfungen, Hooks, Starter-Werkzeuge |
| `bin/starter` | init, remove, strip-examples, sync, check-kit, modules, doctor |
| `docs/` | `UEBERGABE.md`, `DESIGN.md`, `ARCHITEKTUR.md`, `MODULE.md`, `VERTEILUNG.md`, `PROJECT.md`, `DECISIONS.md`, `STARTER_FEEDBACK.md`, `agents/`, `vorlagen/` |
| `.claude/` | Rechte, Hooks, Skills, Subagenten, Workflow `red-team` |

## Regeln

Die Regeln stehen einmal in `rules/` und werden mit `make rules` verteilt: nach `CLAUDE.md` Teil A und in die Wortlisten der Prüfskripte. `make check` prüft Regeln, Texte in beiden Sprachen, Design-Tokens und Kit-Pfade; der Hook `commit-msg` prüft Autor und Format jedes Commits. Neue Wünsche kommen in `docs/agents/VORGABEN.md` und werden innerhalb eines Arbeitstags in `rules/projekt/` eingearbeitet. Bei Widerspruch gilt: `docs/agents/VORGABEN.md` vor `CLAUDE.md` vor `docs/PROJECT.md` vor `docs/DESIGN.md`.

## Module

| Modul | Inhalt | Standard | Entfernen |
|---|---|---|---|
| `window` | Hauptfenster mit Seitenleiste, Suche und Bausteinen im Stil von Musik | an | `bin/starter remove window` |
| `menubar` | Statussymbol mit Zuständen, Statusmenü, Kontextmenü; ohne `window` ohne Dock-Symbol | an | `bin/starter remove menubar` |
| `island` | Insel an der Notch, Kapsel ohne Notch, alle Zustände bis zur Ergebniskarte | an | `bin/starter remove island` |
| `background` | geplante Aufgaben, Start beim Anmelden | an | `bin/starter remove background` |
| `hotkeys` | globale Tastaturkurzbefehle mit Aufnahme und Regeln | an | `bin/starter remove hotkeys` |
| `ai` | lokale KI mit Apple Foundation Models | an | `bin/starter remove ai` |
| `mlx` | eigene Modelle über MLX, Downloads mit Fortschritt (braucht `ai`) | aus | `bin/starter remove mlx` |
| `examples` | Beispiel-Feature, das alle Module nutzt | an | `bin/starter strip-examples` |

Mindestens `window` oder `menubar` bleibt. Einzelheiten je Modul in `docs/MODULE.md`.

## Befehle

| Befehl | Zweck |
|---|---|
| `make doctor` | Werkzeuge prüfen (Command Line Tools, Compiler, SDK, Python), installiert nichts |
| `make build` | Debug-Build nach `build/<Name>.app`; `MODULES=a,b` wählt andere Module, `CONFIG=release` optimiert |
| `make run` | bauen und die App starten, nur für die Person am Mac (Agenten prüfen mit `--selftest` und `make shots`) |
| `make test` | Swift-Tests (`build/tests/run-tests`) und Python-Tests; `ONLY=<präfix>` führt nur passende Swift-Tests aus |
| `make check` | Regeln, Texte, Design, Kit, Build und Tests, Warnungen als Fehler; vor jedem Push |
| `make check-light` | alles aus `make check`, was ohne Mac läuft (Regeln, Texte, Design, Kit, Python-Tests); der Hook `pre-push` nutzt es außerhalb von macOS |
| `make typecheck` | jede Modul-Kombination der CI prüfen, ohne zu bauen; `MODULES=a,b` für eine |
| `make shots` | jede Szene in en und de, hell und dunkel nach `build/shots/` mit `index.html`; `ONLY=<präfix>` |
| `make readme-shots` | Bilder aus `docs/screenshots/list.txt` nach `docs/screenshots/`, höchstens 1200 Pixel breit, dazu App-Symbol und DMG-Fenster |
| `make icon` | App-Symbol aus Akzent und SF Symbol nach `App/Resources/AppIcon.icns`, nur für die Entwicklung (vor der Weitergabe ein eigenes Motiv, `docs/VERTEILUNG.md`) |
| `make dmg` | Release-Build und DMG nach `build/dmg/` |
| `make notarize` | ein DMG aus `make dmg` mit Developer ID erneut einreichen; der Weg zur Notarisierung ist `signing.notarize: true` und `make dmg` (`docs/VERTEILUNG.md`) |
| `make rules` | `CLAUDE.md` Teil A und Wortlisten aus `rules/` schreiben |
| `make hooks` | `scripts/hooks` als Git-Hooks einrichten; die Commit-Identität aus `starter.json` setzen, wenn Git keine kennt |
| `bin/starter init` | eine Kopie des Starters zum Projekt machen |
| `bin/starter remove <modul> [--probelauf] [--ohne-build]` | ein Modul mit seinen Dateien und Markierungen entfernen |
| `bin/starter strip-examples` | die Beispiele entfernen |
| `bin/starter sync --ziel <tag> [--probelauf]` | Kit-Pfade auf eine neuere Fassung des Starters ziehen |
| `bin/starter modules` | Module mit Stand und Pfaden zeigen |

## Betrieb

Die App läuft auf Apple Silicon ab macOS 26. Standard ist die Ad-hoc-Signatur: Empfänger öffnen die App beim ersten Mal über „Dennoch öffnen“ in den Systemeinstellungen unter „Datenschutz & Sicherheit“, und jeder neue Build verliert die erlaubten Berechtigungen. Mit `signing.identity` in `starter.json` signiert `make dmg` mit Developer ID und Hardened Runtime; mit `signing.notarize: true` notarisiert es App und DMG mit einem Profil aus dem Schlüsselbund. Das Anmeldeobjekt funktioniert nur aus einem installierten Ort wie `/Applications` (Finder: „Programme“). Einzelheiten in `docs/VERTEILUNG.md`.

## Pflege

Der Starter trägt Tags (`v1.0.0`) und `CHANGELOG.md` mit Inhalt, Migrationen und Hinweisen je Fassung; jedes Projekt speichert seinen Stand in `starter.lock.json`. `bin/starter sync --ziel <tag>` zieht Kit-Pfade per Drei-Wege-Zusammenführung nach, `make check-kit` meldet geänderte Kit-Pfade. Verbesserungen, die auch anderen Projekten nützen, hält ein Projekt in `docs/STARTER_FEEDBACK.md` fest; der Skill `starter-rueckfluss` macht daraus einen Pull Request im Starter.

## Lizenz

Der Starter steht unter der MIT-Lizenz, der Text liegt in `LICENSE`. Gestaltung und Teile des Codes stammen aus VoiceBud von Anas Riad, ebenfalls unter MIT.

Ein Projekt aus dem Starter legt in `LICENSE` seine eigene Lizenz und Copyright-Zeile fest. Die MIT-Hinweise des Starters und von VoiceBud bleiben in `THIRD_PARTY_NOTICES.md` und in `App/Resources/Notices/`, die App zeigt sie unter „Über“.
