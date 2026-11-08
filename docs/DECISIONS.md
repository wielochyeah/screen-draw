# Entscheidungen

Entscheidungen dieses Projekts, jede mit Datum, Wortlaut, Grund und Folgen. Neue Einträge kommen ans Ende; eine überholte Entscheidung bleibt stehen und bekommt einen Verweis auf die neue.

Die Entscheidungen des Starters stehen in `docs/STARTER_DECISIONS.md`. Die Datei gehört zum Kit: `bin/starter sync` zieht sie nach, das Projekt ändert sie nicht. Eine Kennung wie E-05 in Code, Regeln und Dokumenten des Kits verweist dorthin. Eigene Einträge zählen als PE-01, PE-02 und so weiter, damit sie weder mit einer späteren Entscheidung des Starters (E-NN) noch mit einer Regel des Projekts (P-NN in `rules/projekt/`) zusammenfallen; weicht das Projekt von einer Entscheidung des Starters ab, nennt der Eintrag deren Kennung.

Aufbau eines Eintrags:

```md
### PE-01 (Datum): Titel

- **Entscheidung:** was gilt
- **Grund:** warum
- **Folgen:** was sich dadurch ändert
```

## 2026-11-08: Standard-Kurzbefehl ⇧⌘1

VoiceBud belegt ⌃⇧, ⌃⌥, ⌃⌘ und ⇧⌘2, macOS ⇧⌘3 bis ⇧⌘6. ⇧⌘1 ist frei, liegt daneben und besteht `ShortcutRules` auf US- und deutscher Tastatur. Er lässt sich unter Einstellungen > Zeichnen ändern.

## 2026-11-08: Zeichnung endet mit dem Zeichenmodus

Beim Beenden verschwindet die Zeichnung, auch für „Widerrufen“. Sie ist Teil eines Gesprächs und wird nicht gespeichert.

## 2026-11-08: Panels aktivieren die App nicht

Das Zeichnen läuft in `NSPanel` mit `.nonactivatingPanel`, damit die App im Vordergrund (Videokonferenz, Folien) vorn bleibt und über Vollbild-Apps gezeichnet werden kann.

## 2026-11-08: Werkzeugleiste aus Standardglas

Die Leiste nutzt `.regular`. Der Auftraggeber hat `.regular` und `.clear` auf dem echten Bildschirm direkt über dem Dock verglichen und `.regular` gewählt.
