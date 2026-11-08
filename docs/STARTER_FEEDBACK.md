# Rückmeldungen an den Starter

Allgemeine Verbesserungen, die ein Projekt an Kit-Pfaden braucht. Kit-Pfade (`starter.manifest.json`, Gruppe `kit`) werden im Projekt nicht geändert; der Bedarf steht hier mit Datei, Grund und Test. Der Skill `starter-rueckfluss` macht daraus einen Pull Request im Starter, mit Test, Render-Szene und Galerie-Eintrag, wo etwas sichtbar ist. Namen, Fachbegriffe und Daten des Projekts gehören nicht hierher.

| Nr. | Datei im Starter | Bedarf | Grund | Test, der ihn belegt | Stand |
|---|---|---|---|---|---|
| 1 | `App/Sources/Modules/MenuBar/MenuBarController.swift` | Das Symbol nur bei einem echten Wechsel zwischen hell und dunkel neu zeichnen | Jedes Neuzeichnen löste die nächste Meldung aus, die App hielt ab dem Start einen CPU-Kern ausgelastet | `MenuBarTests`: „appearance reports redraw only on a real change“ | übernommen in v1.0.2 |
