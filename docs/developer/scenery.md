# Reale 3D-Szenen: Rüdersdorf, Höhen und Kollisionen

**Status:** experimentelle lokale Referenzszene, aktueller Geometriestand **R35**. Diese Datei ist die technische **aktuelle** Referenz; für chronologische Änderungen gilt ausschließlich das [Changelog](../../CHANGELOG.md). Bedienung und Sicherheitsgrenzen sind unter [Nutzer: Reale 3D-Umgebungen](../user/scenery.md) beschrieben.

## Systemgrenzen und Datenfluss

| Aufgabe | Implementierung |
|---|---|
| Persistente Definitionen, Manifest v1 und Asset-Provider | `lib/features/scenery/`, Drift-Tabelle `sceneries` (Schema 13) |
| Flutter/Cesium-Kommunikation und Kartenmenü | `lib/features/globe/`, `web/globe.js`, `web/core/globe_bridge.js` |
| Szenenkatalog, Aktivierung, Höhenzustand, Kollision und Quellen | `web/features/scenery/scenery_manager.js`, `web/assets/scenery/catalog.json` |
| Referenz/Transformation | `web/features/scenery/scenery_alignment.js`, `web/assets/scenery/reference_alignment.json` |
| GLB-Darstellung | `web/assets/scenery/local_reference.glb` |
| FPC-Kollisionen | `web/assets/scenery/local_reference.fpc`, `web/features/scenery/scenery_collision.js` |
| Testweise BKG-Gebäude und örtliche 3D-Auswahl | `web/features/terrain/regional_3d.js`, `web/features/scenery/scenery_bridge_calibration.js` |
| Workbench-Ansicht / lokaler Datenrelay | `tool/scenery/cesium_georeference_workbench.html`, `tool/scenery/serve_workbench.py` |
| Reproduzierbare Rekonstruktionen, Messberichte und Regressionen | `tool/scenery/`, `test/js/scenery_*.test.cjs`, `tool/scenery/test_ruedersdorf_*.py` |

Die **Haupt-GLB und FPC werden zusammen erstellt**: Die physische Kollision muss exakt zu den gerenderten Dreiecken passen. In `catalog.json` und allen Terrain-Zertifikaten muss die SHA-256 der jeweils aktuellen FPC stehen. Beim Ändern der Scan-/Ersatzgeometrie dürfen solche Zertifikate nicht unverändert auf eine andere FPC zeigen. Ein aktuelles Geometriemodell ersetzt keine physische Kalibrierung.

### Provenienz und nichtkommerzielle Bedingungen

Basis ist der Original-RAWscan von **Andrea Spognetta (spogna)**, „Abandoned Chemical plant Rüdersdorf – RAWscan“, [Originalmodell](https://sketchfab.com/3d-models/abandoned-chemical-plant-rudersdorf-rawscan-d2464ec36fb644f28e904e5517f1da64), **CC BY-NC 4.0**. Die ursprünglichen Positionen, Normalen und UV-Koordinaten der wiederhergestellten Rohscanflächen bleiben erhalten; zusätzliche Gebäude und Kollisionsflächen sind **fotogestützte Simulation**, keine vermessene Aufnahme. Original-RAWscan-Quellen und hochauflösende Texturen dürfen nicht ungeprüft weiterverteilt oder unter Apache-2.0 umgelabelt werden. Die mobilen Assets können eine verkleinerte Texturatlas-Version verwenden. Hinweise zur Herkunft von DGM1, GCG2016 und BKG finden sich unter [Third-party notices](../../THIRD_PARTY_NOTICES.md) und in den Asset-Credits `web/assets/scenery/ATTRIBUTION.md`.

## Persistente Scenery-Architektur

Der Renderer liefert seinen bereits geladenen gebündelten Katalog über
`scenery-catalog` einmalig als anfängliche Definitionen. `SceneryRepository`
übernimmt diese einmalig in die Drift-Tabelle `sceneries`; eine gespeicherte
Initialisierungsmarke verhindert, dass absichtlich entfernte Vorlagen nach einem
Neustart oder Backup-Restore wieder erscheinen. Alte Aktivierungen und
Ausrichtungen werden transaktional übernommen. Ungültige Bestandsdaten werden
als Fehler gemeldet und bleiben erhalten. Datenbankschema 13 ergänzt ausschließlich
diese Tabelle; bestehende Tabellen werden dafür nicht umgebaut.

`SceneryManifest` definiert das JSON-Format **schemaVersion 1**:

| Feld | Vertrag |
|---|---|
| `id`, `name`, `description` | Stabile Kennung und Beschreibung |
| `source` | `author`, HTTPS-`url`, `license`, `attribution` |
| `anchor` | `longitude`, `latitude`, `heightM`, `reference`: `WGS84_ELLIPSOID` oder `TERRAIN_RELATIVE` |
| `bounds` | Geographische Region `west`, `south`, `east`, `north`; West > Ost kennzeichnet den Datumswechsel |
| `rotation`, `scale` | `headingDeg`, `pitchDeg`, `rollDeg`, einheitlicher Maßstab im lokalen ENU-System |
| `assets` | Eigene Kennung, Rolle `visual`/`collision`, `provider`, `format`, `uri` pro Asset |
| `collision` | `enabled`, Referenzen über `assetIds`, `sidedness` |
| `visibility` | `enabled`, `loadRadiusM`, `unloadRadiusM` mit Hysterese |
| `minimumAppVersion` | Semantische Mindestversion `major.minor.patch` |
| `extensions` | Provideroptionen; die Cesium-Kompatibilität enthält bestehende Höhen-/Terrainzertifikate |

Definitionen sind unveränderliche Snapshots. Es gelten höchstens 64 Szenen,
128 KiB pro Definition, 1 MiB pro Katalog sowie höchstens je 16 visuelle und
Kollisionsassets. Katalog-Bounds aus Vorlagen/Platzierungsformularen sind
konservative Abdeckungsregionen, keine vermessenen Mesh-Grenzen. Tatsächliche
Mesh-Bounds, Dateiauswahl und Ressourcenimport gehören zum Asset-Importworkflow.

`SceneryAssetProvider` löst logische Referenzen auf. Der vorhandene Provider
`bundled` unterstützt selbstenthaltende GLB und FPC innerhalb des Szenen-Assetroots.
Weitere Provider/Formate können definiert und gespeichert werden; ohne passenden
Ladepfad bleibt die Szene **unavailable**, ebenso bei einer zu hohen Mindestversion.
Front-/Back-only-Kollision und neu geneigte, bereits terrainkalibrierte Szenen
bleiben bis zu einer passenden Implementierung/Neukalibrierung nicht verfügbar.
Es wird kein nicht unterstütztes Format als GLB oder gültige Kollision ausgegeben.

Die Bridge-Nachricht `replace-scenery-catalog` überträgt einen vollständigen
aufgelösten Katalog. Unveränderte Einträge behalten Modelle und Kollisionsdaten;
entfernte/geänderte Einträge entwerten laufende Ladevorgänge. Fehlerhafte optionale
Szenen erhalten einen eigenen Fehlerzustand. Alle Kollisionsassets einer Szene
müssen geladen sein, bevor ihre physische Kollision aktiv wird. Darstellungs- und
Kollisionsgeometrie verwenden dieselbe ENU-Rotation einschließlich Pitch und Roll.
Eine veränderte Platzierung entwertet alte Gebäude-/Terrain-Ersatzmasken;
Grundkarte und optionale Szenen werden unabhängig wiederhergestellt. Veraltete
Wiederherstellungsgenerationen übertragen keinen Katalog.
Änderungen während Navigation werden abgewiesen. Nach Renderer-Neuverbindung
wird der aktuelle Datenbankstand erneut übertragen.

Szenendefinitionen und Initialisierungszustand werden im bestehenden Backupformat
mitgeführt; Modellbytes und Provider-Caches werden damit nicht als austauschbares
Scenery-Paket exportiert. Alte Backups bleiben einlesbar. Ein allgemeiner
GLB/glTF-Dateiimport, frei wählbare 3D-Tiles-Dienste und `.fpvscenery`-Pakete sind
separate Ausbauschritte. Die Referenzszene und die BKG-Grenzen unten bleiben gültig.

## Geometrie und Orientierung

- Der Modellmaßstab ist `16.023268178233355`; Rotation um die lokale Vertikale `99.7993823133657°`; geographischer Anker bei **13.789853720999993° E / 52.48411904363446° N**.
- In der verwendeten lokalen Baustellenkoordinate zeigt **−X nach Norden** und **+Y nach Osten**. Die Cesium-/GLB-Transformationsmatrizen und die Transformationsachse für FPC dürfen nicht unabhängig geändert werden.
- Die nördliche Originalscan-Gebäudegruppe und die südlichen rekonstruierten Produktionsgebäude **sind unterschiedliche Orte**. Rekonstruktionsänderungen müssen auf eindeutig kontrollierten lokalen Bounding Boxes erfolgen; die gewünschte Himmelsrichtung allein ist keine hinreichende Maskendefinition.
- **R29** fügte fehlende Rohscan-Dreiecke aus dem Originalarchiv zurück. **R34** restaurierte versehentlich entfernte südliche Rekonstruktionsflächen. **R35** entfernte ausschließlich das künstliche, teils in den nördlichen Scan hineinragende R24-Gerüst. Details der einzelnen Bearbeitungsschritte stehen in maschinenlesbaren `refinement_*_report.json` und im Changelog; alte inkrementelle Release-READMEs sind keine aktuelle Spezifikation.
- Die äußere Leiterplattform der langen Halle liegt **außerhalb** der Halle, nicht in einer künstlich geöffneten Dachfläche. Beim Modellieren dürfen echte Dachöffnungen (z. B. der zentralen Silos) nicht mit anderen Silo-Gebäuden verwechselt werden.

## Höhenbezüge – keine doppelte Korrektur

Unterscheide **(a)** Workbench-Flat-Preview, **(b)** lokal gesampelte Scan-Bodenhöhe, **(c)** vertikalen Referenzrahmen einer Datenquelle und **(d)** den tatsächlich gerenderten Terrainprovider.

| Referenz | Wert / Bedeutung |
|---|---|
| Workbench-Export (flacher Ellipsoid) | **34,25 m** Ankerhöhe; visuelle Vorschau, keine übertragbare Geländeankerhöhe |
| DGM1 am geographischen Anker | **40,949489589 m NHN** (DHHN2016), aus amtlichem Raster interpoliert |
| GCG2016-Anomalie | **+38,871142785 m**; Umrechnung normal/ellipsoid |
| Daraus ermittelte ellipsoidale Bodenhöhe | **79,820632374 m** |
| Lokale Bodenreferenz | `groundReferenceLocalUp = -2.02575` |
| Modellanker für diese DGM1-Kontrolle | **112,279767886 m** vor zusätzlichem Vergleich mit tatsächlich gerendertem Gelände |
| Nutzerbestätigter BKG-spezifischer visueller Versatz | **−16,90 m**; nur für die experimentelle BKG-Variante, nicht als Geoidkonstante |

Die Beziehung für eine **bekannte** ellipsoidale Bodenhöhe lautet:

`rootEllipsoidHeightM = groundEllipsoidHeightM - groundReferenceLocalUp * scale`

Der aktuelle Katalog verwendet `heightAlignmentMode: "terrain"`, `requireGroundCalibration: true` und ein eigenes `bkgHeightOffsetM`. Während der automatischen Kalibrierung werden gerenderte Geländehöhen in mehreren Kontrollpositionen gelesen und robust zu einer Modellankerhöhe zusammengeführt. Fehlende Kacheln sind **kein** Wert null, und der dynamische BKG-Korrekturwert darf nicht zusätzlich als allgemeiner Geoidversatz verstanden werden. Nutzerseitige gespeicherte Einstellungen können den Katalogstandard übersteuern. Laufzeitstatus (`heightState`, `groundHeightM`, `effectiveAlignment`, `bkgHeightOffsetM`) ist bei Problemen vor der Änderung von Konstanten zu protokollieren.

### Bediengestützter Bodenabgleich

`web/features/scenery/scenery_bridge_calibration.js` verwendet ein Scan-Oberflächen-Pick und nach Ausblenden des Scans einen Pick auf das **gleiche offene Gelände**. Das Programm prüft den horizontalen Abstand und berechnet die signed Höhendifferenz. Das Ergebnis wird erst nach expliziter Bestätigung als **BKG-only** Einstellung gespeichert. Es dürfen keine LoD2-Dächer/Vegetation mit Scan-Bodenpunkten verglichen werden. Der visuell bestätigte Versatz ist nur eine reproduzierbare Betriebseinstellung, keine Vermessung.

## BKG-LoD2-Workbench

Der Workbench braucht einen HTTP-Server statt `file://`. Die lokale Relay-Route wird nur von `serve_workbench.py` bedient; `python -m http.server` stellt sie **nicht** bereit.

```powershell
python tool/scenery/serve_workbench.py --port 8765
```

Danach [Workbench öffnen](http://localhost:8765/tool/scenery/cesium_georeference_workbench.html?lod2=relay). Ein Relay-`404` kann einen falschen Server oder einen Upstream-404 bedeuten; ein `502` weist auf fehlgeschlagene Kommunikation zwischen lokalem Relay und BKG hin. Zuerst die lokale Konsole lesen und den offiziellen Dienst gegebenenfalls getrennt mit `curl.exe` und Python `urllib.request` prüfen. Das Relay begrenzt erlaubte Upstream-Pfade, nutzt keine Zugangsdaten und speichert keine heruntergeladenen BKG-Assets im Projekt.

**Der BKG-Beta-Modus verwendet seinen eigenen Höhen-/Modellstatus und ist nicht gleichzusetzen mit der normalen Schweiz-Karte.** Die URL `lod2_4326_null.json` ist die LoD2-Variante ohne DGM5-Höhenversatz; sie allein bestätigt nicht die tatsächliche Terrainhöhe.

## Android-Testbuild und Validierung

```powershell
powershell -ExecutionPolicy Bypass -File tool/build/build_android_ruedersdorf_test.ps1
```

Der Build aktiviert `--dart-define=FPV_REGIONAL_3D_TEST=true`, prüft die notwendigen GLB-/FPC-Dateien und erstellt eine **experimentelle** Test-APK. Die öffentliche Release-Konfiguration aktiviert den BKG-Modus nicht standardmäßig. Für die normale App sind die Vorgaben unter [Contributing](../../CONTRIBUTING.md) maßgeblich.

```sh
node --test test/js/*.test.cjs
python -m unittest discover -s test/tool -p 'test_*.py'
python tool/quality/check_docs.py
```

Aktuell gepflegte JavaScript-Regressionen: `scenery_site_integrity.test.cjs`
(Originalscan, Südgebäude, Öffnungen und FPC), `scenery_underlay.test.cjs`
(optionale Geländeersetzung), `scenery_rendered_ground.test.cjs`
(Render-/Höhenproben) sowie `scenery_ground_calibration.test.cjs` (BKG-only
Bodenabgleich und Android-Asset). Dateinamen mit einer Revisionsnummer können weiterhin aktive
Geometrieregressionen sein und werden nicht pauschal entfernt. Für alte Pfade nach
einem ZIP-Update den geprüften [Struktur-Cleanup](../README.md#applying-a-changed-files-zip)
verwenden.

Zusätzlich die passende `test_ruedersdorf_*.py`-Geometrieprüfung ausführen und das Modell real auf einem Gerät mit verschiedenen Kamerawinkeln vergleichen. Tests von Rohdreiecken, BVH-Hashes und Codepfaden beweisen **keine** richtige Höhenlage im BKG-Globus. Bei einer Geometrieänderung sowohl Ausschnitt als auch kollidierbare Öffnungen prüfen; bei Höhenänderung Oberkante/Boden in mehreren Bildbereichen und nach Providerwechsel.

## Sicherheit, Datenlücken und Grenzen

- Rüdersdorfer FPC-Kollisionen sind experimentelle Simulationsflächen, nicht reale Hindernismessungen.
- Das optionale separate **DGM1-Unterlay** (`ruedersdorf_r11_ground.glb/.fpc`) ist nicht mit dem Hauptmodell gleichzusetzen. Das Einblenden und Clipping erfordert gültige Assets, passende Zertifikate, echte Terrainproben und aktivierte, dem Renderer gehörende Clipping-Masken. Standardmäßig ist `clipTerrain` deaktiviert.
- Regionale BKG-Gebäude können sich visuell mit Scanflächen überlagern. Die Gebäudemaskierung ist getrennt von der optionalen, geprüften Terrainmaske.
- **Die Echtzeit-Funk-/LoS-Analyse für BKG-Beta ist gesperrt**, solange die Terrainabfrage und 3D-Hindernisbehandlung dafür nicht validiert sind. Fehlende Höhen dürfen weder als freie Sicht noch als Funkverlust ausgegeben werden. Technische Details: [Radio/Rescue](radio_and_rescue.md).
- Quellenangaben im UI und externe Nutzungsrechte müssen bei jeder Modelländerung erhalten bleiben. Vor jeder Veröffentlichung der abgeleiteten RAWscan-Geometrie die **CC BY-NC 4.0**-Beschränkung prüfen.

## Regional 3D service boundary

BKG 3D Beta is an independently gated online test source. Its transport omits
credentials, uses no-store semantics for root/descendant requests, and fails closed
when that transport cannot be installed. FPVManager does not persist these tiles;
embedding/browser/proxy caches require separate host review. Keep official on-screen
credits and test-license change notices. Raster/hillshade have distinct CC BY 4.0 /
DL-DE BY 2.0 terms: see [map sources](../user/map_sources_and_attribution.md) and
[third-party notices](../../THIRD_PARTY_NOTICES.md).

Rendered BKG geometry does not validate the height datum or certify RF/route
clearance. Unknown tiles remain unknown. Copernicus GLO-30 is not an active fallback
or a ready-made Quantized Mesh endpoint; hosting, conversion, datum and rights would
need independent verification. The existing local DGM/geoid alignment is separate.
