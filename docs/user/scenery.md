# Reale 3D-Umgebungen und Rüdersdorf (experimentell)

Dieses Kapitel beschreibt **die derzeitige Rüdersdorf-Testszene**, nicht eine allgemein verfügbare, vermessene 3D-Stadt. Die üblichen Karten- und Simulationsfunktionen sind im [Benutzerhandbuch](../user_guide.md) beschrieben. Die technische Reproduzierbarkeit steht unter [Entwicklung: Szenen und Höhen](../developer/scenery.md).

## Was dargestellt wird

- Der photogrammetrische **RAWscan „Abandoned Chemical plant Rüdersdorf“** von Andrea Spognetta mit ergänzter, nur näherungsweise rekonstruierter Industriegeometrie. Geometrie, Zustand und Oberflächen stammen nicht durchgehend aus demselben Aufnahmejahr.
- Ein gesondertes Kollisionsnetz (FPC) für den Simulator. Es kann die modellierten Flächen treffen, **garantiert aber keine realen Hindernisabstände**.
- Optional offizielle 3D-Gebäude und Gelände aus der **BKG 3D-Beta**. Dieser Modus wird ausschließlich durch einen speziellen Testbuild freigeschaltet; er ist keine Freigabe für die reale Flugplanung.
- Die Urheber- und Datenquellen stehen im Kartenmenü **Quellen** und unter [Lizenzen/Kartendaten](map_sources_and_attribution.md).

## Anzeige und Einstellungen

1. Öffne die Karte in der Umgebung von Rüdersdorf bei Berlin.
2. Öffne **Karte & Ansicht → Karte → Reale 3D-Umgebungen**. Aktiviere die lokale Szene, sofern die entsprechenden Assets im Build enthalten sind.
3. Unter **Status aktualisieren** lassen sich Modell-, Kollisions-, Höhen- und Maskenzustand getrennt prüfen. Bei fehlenden oder noch nicht geladenen Geländekacheln wird die Ausrichtung nicht als bestätigt angezeigt.
4. Zum Vergleich mit den offiziellen Gebäuden kann **LoD2 im Ersatzbereich ausblenden** verwendet werden. Das betrifft die visualisierten Fremdgebäude, nicht die ursprüngliche Scantextur.

### Höhenreferenz und Bodenabgleich

Die Szenenhöhe im normalen Globe wird nicht unmittelbar aus dem Workbench-Export übernommen. Ein Workbench-Wert auf **flacher Ellipsoid-Oberfläche** ist nicht die spätere absolute Modellhöhe über dem tatsächlich gerenderten Gelände. Die derzeitige Szene nutzt Geländeproben und berücksichtigt zusätzlich den lokalen Bodenversatz des Photogrammetriemodells.

Für die aktuelle Rüdersdorf-Testversion wurde **−16,90 m** als BKG-spezifischer visueller Korrekturwert anhand zweier passender Bodenflächen bestätigt. Er ist **keine amtlich vermessene Höhe**. Andere lokale Einstellungen können Vorrang haben; beim Wechsel zum regulären Cesium-Gelände darf diese Korrektur nicht übertragen werden.

Bei einer neuen Kontrolle:

1. Im BKG-Testmodus **Bodenhöhe vergleichen** wählen.
2. Eine erkennbare, möglichst ebene und freie **Bodenfläche** des Scans antippen. Nicht ein Dach, eine Geschossdecke, Brücke oder Vegetation wählen.
3. Nachdem der Scan ausgeblendet wurde, möglichst dieselbe Stelle auf dem **tatsächlich gerenderten Kartengelände** antippen.
4. Die vorgeschlagene Differenz, den horizontalen Abstand und die Bilddarstellung prüfen. Erst anschließend **Bodenhöhe übernehmen** wählen.

Die Funktion soll kein Geländegefälle mit einem Höhenfehler verwechseln; weit entfernte Vergleichspunkte werden abgelehnt. Ein stark versetztes oder schwebendes Modell ist ein **Kalibrierungsfehler**, kein Hinweis auf sichere Überflughöhen.

## Fliegen und analysieren

Das Scanmodell enthält begeh- beziehungsweise durchfliegbare Öffnungen und experimentelle Kontakte. Eine visuelle Öffnung ist **keine** Erlaubnis oder Garantie, sie mit einem echten FPV-Copter zu durchfliegen. Die Verwendung der FPC-Daten ist auf Simulation begrenzt.

Die **Live-Funk-/Gelände-LoS-Analyse im BKG-Beta-Modus ist derzeit ausdrücklich gesperrt**, weil die zugrundeliegenden Geländedaten nicht für diesen Anwendungsfall validiert sind. Eine fehlende Analyse ist weder eine freie Sichtlinie noch ein belegter Funkverlust. Mit der regulären schweizerischen Geländequelle stehen die dafür vorgesehenen Funktionen separat zur Verfügung. Siehe [Preflight und Funkanalyse](preflight.md) und [Flugsimulator](flight_simulation.md).

## Wenn etwas nicht stimmt

| Beobachtung | Prüfung |
|---|---|
| Modell erscheint nicht | Szene aktiviert, Assets geladen, Höheneinmessung bereit, Kartenposition in Reichweite? **Status aktualisieren**. |
| Modell schwebt oder steckt im Boden | Aktiver Terrainprovider, Status der Geländekacheln und bestätigter BKG-Versatz prüfen. Kein zusätzliches pauschales Geoid-Offset anwenden. |
| Doppeltes Gebäude / Gerüst im Scan | Scan und zusätzlich rekonstruierte Fläche können sich überlagern. Screenshot mit Himmelsrichtung und markiertem Gebäudeteil sichern. |
| Gebäude erscheinen flach/vereinfacht | LoD2 ist eine separate Datenquelle; einzelne Gebäude fehlen oder wurden nach dem Scan verändert. |
| Funkanalyse nicht verfügbar | Im BKG-Beta-Modus derzeit absichtlich deaktiviert. |

**Datenschutz und Nutzungsrechte:** Der Scan und die BKG-Daten haben eigene Bedingungen. Insbesondere unterliegt der Scan **CC BY-NC 4.0** und damit Nichtkommerziell-Beschränkungen. Details unter [Kartendaten und Attribution](map_sources_and_attribution.md) und [Drittanbieterhinweise](../../THIRD_PARTY_NOTICES.md).
