# Simulator-Einstellungen und Hängebrücken – 25.11.2026

## Ergebnis

Die vollständige Simulator-Konfiguration wird über das vorhandene lokale
Einstellungsrepository gespeichert. Sie steht nach einem Neustart und nach einer
Backup-Wiederherstellung wieder zur Verfügung. Eindeutig gekennzeichnete oder
benannte Hängebrücken bekommen keine automatisch geschätzten Brückenpfeiler.

Bearbeitet wurde ausschließlich eine isolierte Kopie des Quellstands
`0.19.28+55`. Der ursprüngliche Projektordner wurde nur gelesen. Versionsnummer,
Abhängigkeiten sowie RF- und Flugphysik-Berechnungen wurden nicht geändert.

## Bestätigte Ursachen und Änderungen

### Simulator

`HomeScreen._simulationSettings` war ein Sitzungswert mit Standardinitialisierung.
Nur Signal-HUD und Failsafe wurden separat im Einstellungsrepository gespeichert.
Die Backup-Funktion erlaubte von diesen Einstellungen lediglich die Sichtbarkeit
der Touch-Steuerung. Deshalb reichte das bisherige Speichern weder für einen
vollständigen Neustart noch für einen vollständigen Backup-Roundtrip aus.

* Der zusätzliche Schlüssel `simulation.settings.v1` speichert Flugmodus,
  Advanced/Legacy, Physikfrequenz und Physikparameter, Start-/Geschwindigkeitswerte,
  Kamera, Grafik, HUD-Darstellung, Controllerbelegung, Akku-/Antriebsprofile und
  Beleuchtungszeit. Die ausgewählte Drohnen- und Akkuidentität bleibt enthalten.
* Signal-HUD und Failsafe behalten ihre bestehenden maßgeblichen Schlüssel.
  Beide werden nun ebenfalls in Backups aufgenommen. Die vollständige wirksame
  Konfiguration liefert `GlobeController.simulationSettings`.
* Einstellungsdialog und Routenwiedergabe verwenden diesen gespeicherten Stand.
  Der Dialog wartet auf das Laden der Einstellungen. Speichern erfolgt auch,
  wenn anschließend kein Flug gestartet wird.
* Aktive Schnellregler im Flug speichern ihre gültigen Änderungen. Unveränderte
  Ereignisse erzeugen keinen zusätzlichen Schreibauftrag. Ein inaktiver oder neu
  geladener Renderer darf seine Standardwerte nicht als Nutzerwahl speichern.
* Die vorhandene serialisierte Schreibwarteschlange wird weiterverwendet.
  Fehlende Felder älterer Konfigurationen erhalten Standardwerte; ungültige Werte
  werden ausdrücklich abgelehnt. Das bestehende transaktionale Restore prüft die
  neuen Werte vor dem Ersetzen persönlicher Daten.

Backup-Version, Dateiformat, Größenlimits und Verschlüsselung bleiben unverändert.
Alte Backups bleiben einlesbar. Einstellungen, die in einem alten Backup noch
nicht enthalten waren, können daraus nicht rekonstruiert werden.

### Brücken

Der direkte OSM-Parser erkannte bestimmte Konstruktionstypen bereits. Der
Import von Luftfahrthindernis-Profilen setzte dagegen `mappedOnly: false`.
Zusätzlich konnten unklassifizierte native Brückengeometrien trotz einer
überlagernden, korrekt klassifizierten Hängebrücke geschätzte Stützen erzeugen.

* Eine gemeinsame Erkennung berücksichtigt strukturelle Kennzeichnungen und
  eindeutige Typnamen, etwa „Hängebrücke“, „Suspension Bridge“, „Passerelle
  suspendue“ und „Ponte sospeso“. Ein allgemeiner Fußbrücken- oder Straßenname
  reicht dafür nicht aus. Bestehende Ausschlüsse für Bogen- und
  Schrägseilbrücken bleiben erhalten.
* Die Kennzeichnung wird beim Import von Hindernisprofilen übernommen und bei
  der Stützengenerierung erneut berücksichtigt.
* Ein überlagerndes natives Profil erhält auf einem ausgeschlossenen Abschnitt
  ebenfalls keine geschätzten Stützen. Der Abgleich verlangt räumliche Nähe und
  passende Ausrichtung; querende normale Brücken bleiben unabhängig.
* Tatsächlich kartierte Pfeiler/Pylone werden weiterhin übernommen. Unterdrückt
  werden ausschließlich die automatisch geschätzten Zwischenstützen.

## Regressionen und Prüfung

Neue Dart-Tests prüfen vollständige JSON-Roundtrips mit nicht standardmäßigen
Werten für beide Physikmodelle, fehlende/ungültige Felder, Schließen und erneutes
Öffnen einer echten SQLite-Datei, Einstellungs-Reset, Renderer-Neustart,
Schnellregler, Beleuchtungszeit, Wiederherstellung im laufenden Controller sowie
unverschlüsselte und verschlüsselte Backups einschließlich Gerätezuordnungen.
Ein ungültiges Restore darf den bestehenden Zustand nicht ersetzen.

Neue JS-Tests prüfen alle Importpfade, mehrsprachige eindeutige Namen,
mehrdeutige Namen, überlagerte Quellen in beiden Reihenfolgen, querende Brücken,
kartierte Pylone sowie den Verzicht auf unnötige Terrainabfragen ohne Stützen.

Die bestehenden Repository-Tests berücksichtigen den zusätzlichen
Einstellungsschlüssel. Der erste gezielte Prüflauf fand ausschließlich die
dadurch veraltete feste Zeilenanzahl; diese wurde angepasst.

* `dart format --output=none --set-exit-if-changed` für alle neun geänderten
  Dart-Dateien: **0 Formatierungsänderungen**.
* `flutter analyze`: **keine Befunde**.
* `flutter test`: **1082 Tests bestanden**.
* `node --test test/js/*.test.cjs`: **996 Tests bestanden**, keine Fehler
  oder übersprungenen Tests. Enthält den bestehenden lokalen Chromium-Test.
* Abschließende gezielte Persistenz-/Repository-Prüfung: **17 Tests bestanden**.
* Gezielte Brückenprüfung: **35 Tests bestanden**
  (`node --test test/js/bridge_supports.test.cjs test/js/bridge_supports_osint.test.cjs`).
* Alle 1564 Dateien des ursprünglichen Snapshot-Manifests stimmen weiterhin
  bytegenau mit dem nur gelesenen Original überein.

## Grenzen

Es wurden automatisierte Tests unter Windows ausgeführt. Ein neuer Android-Build
und ein manueller Flugtest auf dem Mobilgerät gehören nicht zu dieser Prüfung.
Brücken ohne eindeutige Metadaten oder Typnamen können weiterhin geschätzte
Stützen erhalten. Die Änderung behauptet keine Erkennung aus Luftbildern oder
3D-Geometrie. Es wurden keine Leistungsverbesserungen gemessen oder behauptet.

Der ZIP-Inhalt besteht ausschließlich aus den neuen/geänderten Projektdateien
dieser beiden Anpassungen. Zum Übernehmen die Verzeichnisstruktur im Projekt
beibehalten. Das begleitende Manifest enthält Dateiliste und SHA-256-Prüfsummen.
