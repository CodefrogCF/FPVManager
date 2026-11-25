# Live-Funkanalyse direkt über dem Startpunkt

Stand: 25.11.2026, Ausgangsversion `0.19.29+56`.
Änderungen wurden ausschließlich in einer Arbeitskopie erstellt. Der
Originalordner wurde nur gelesen.

## Ursache und Korrektur

Der Live-Controller verwarf einen horizontalen Abstand unter einem Meter
ausdrücklich mit `Unknown: vertical path / less than 1 m`. Auch Sampling-Policy,
gemeinsamer LoS-Kern und Routen-Batch schlossen diese Strecken aus. Deshalb wurde
eine Drohne direkt über der Bodenstation unabhängig von ihrem Höhenabstand
dauerhaft als unbekannt behandelt. Ein vorhandener Test verlangte dieses alte
Verhalten sogar ausdrücklich.

Die Korrektur lässt einen horizontalen Abstand von null zu und wertet die Strecke
mit den regulären Geländedaten aus. Der bisherige Mindestabstand des RF-Modells
von einem Meter bezieht sich auf die tatsächliche räumliche Antennentrennung.
Zusammenfallende oder räumlich weniger als einen Meter getrennte Antennen bleiben
ausdrücklich unbekannt.

Für eine exakt senkrechte Strecke werden die Profilanteile über das Höhenintervall
bestimmt, ohne durch den horizontalen Abstand zu teilen. Für alle anderen Strecken
bleibt die räumlich korrekte Zuordnung nicht gleichmäßig verteilter Geländepunkte
über ihren Bodenabstand erhalten.

Der Abstand zur Geländeoberfläche wird zur **endlichen Verbindungsstrecke**
berechnet. Eine Projektion auf eine unendlich verlängerte senkrechte Gerade würde
auch Gelände unter beiden Antennen fälschlich mit Abstand null bewerten. Der neue
Abstand bleibt vorzeichenbehaftet: Durchdringungen von Gelände bzw. ausdrücklich
erfassten Oberflächen bleiben blockiert. Die veröffentlichte Funkdistanz
berücksichtigt ebenfalls den Höhenunterschied zur Antenne.

Die Terrainabfrage verwendet weiterhin den bestehenden Scheduler, Provider- und
Generationsschutz sowie die bisherigen Datenfrische- und Samplingregeln. Für die
vertikale Säule genügen die zwei regulären Profilendpunkte an derselben
Geländekoordinate; es gibt keinen pauschalen „über Home immer frei“-Sonderwert.
Fehlende Daten, Timeouts und nicht unterstützte Höhenbezüge bleiben unbekannt.
RF-Linkbudget und Failsafe-Logik wurden nicht verändert.

## Regressionen

Der neue gezielte Test wurde zunächst gegen den ursprünglichen Code ausgeführt:
**8 von 9 Fällen schlugen fehl**, insbesondere vertikale freie und blockierte
Strecken, der Überflug von Home und die Erholung nach einem Terrainfehler. Der
Fall zusammenfallender Antennen war bereits korrekt unbekannt.

Die endgültigen Tests prüfen zusätzlich:

* Vertikale und nahezu vertikale Strecken sowie Bewegungen über die alte
  horizontale 1-m-Grenze in beiden Richtungen.
* Freie Verbindungen oberhalb des Bodens, auch bei einem Empfänger unterhalb der
  Senderantenne; Gelände- und ausdrücklich erfasste Gebäudedurchdringungen.
* Endliche, korrekte Freiräume am Äquator und in hohen Breiten.
* Reguläres, begrenztes Sampling, Routen-Batches und gültige Live-Beobachtungen.
* Fehlende Terrainwerte, Timeout, nicht verfügbarer Provider und anschließende
  Erholung mit einer frischen gültigen Beobachtung.
* Übernahme der gültigen vertikalen Beobachtung durch den JS-Bridge-Empfänger und
  das bestehende RC-/Video-Linkbudget mit 48 m Antennenabstand. Ein danach
  unbekanntes Ergebnis darf keine RF-Qualität erfinden.

## Prüfergebnisse

* `dart format --output=none --set-exit-if-changed` für alle fünf geänderten
  Dart-Dateien: keine Formatierungsänderungen.
* `flutter analyze`: keine Befunde.
* `flutter test`: **1092 Tests bestanden**, einschließlich der zehn
  neuen vertikalen Regressionstests und der vorhandenen RF-/Physiktests.
* `node --test test/js/*.test.cjs`: **997 Tests bestanden**, keine Fehler
  oder übersprungenen Tests, einschließlich des lokalen Chromium-Tests.
* Erster gezielter Lauf nach der Korrektur: 66 LoS-/Sampling-/Scheduler-Tests
  bestanden. Der abschließende Gesamtlauf enthält zusätzlich den ergänzten Test
  für Äquator und hohe Breiten.
* Originalvergleich: alle 1567 Dateien des Snapshot-Manifests sind
  unverändert. Der ZIP-Inhalt wurde per CRC und SHA-256 gegen die Arbeitskopie
  geprüft.

## Grenzen und Übernahme

Geprüft wurden automatisierte Tests unter Windows einschließlich des bestehenden
lokalen Chromium-Tests. Ein manueller Android-Flugtest steht noch aus. Die
berechnete RF-Qualität bleibt das bestehende Simulationsmodell, keine Messung.
Es wurden keine Leistungsverbesserungen gemessen oder behauptet.

Das ZIP enthält ausschließlich die neuen bzw. geänderten Dateien dieses Fixes
mit Projekt-Verzeichnisstruktur. Versionsnummer, Abhängigkeiten und die zuletzt
ergänzte Simulator-Persistenz bzw. Hängebrückenerkennung bleiben erhalten. Die
begleitende Dateiliste enthält SHA-256-Prüfsummen.
