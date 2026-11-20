// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'fpv_strings.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class FpvStringsDe extends FpvStrings {
  FpvStringsDe([String locale = 'de']) : super(locale);

  @override
  String get airspaceAbsenceOfAMatch3e743a0d =>
      'Das Fehlen eines Matches stellt keinen unbeschränkten Luftraum dar. Quellenabdeckung wird nicht unabhängig voneinander überprüft.';

  @override
  String get airspaceAirspaceFlightSafetyfe71cada =>
      'Airspace & Flugsicherheit';

  @override
  String get airspaceAirspaceIntersectionsb23b9966 => 'Luftraum-Kreuzungen';

  @override
  String airspaceAllSourceAttributes5a87df81(String arg0) {
    return 'Alle Quellattribute ($arg0)';
  }

  @override
  String get airspaceApiAccessFreeServicesa6e68dbd =>
      'API-Zugang (nur kostenlose Dienste)';

  @override
  String get airspaceApiKeycf678cab => 'API-Schlüssel';

  @override
  String get airspaceAutomaticDabsNotamAvailability2968fe7b =>
      'Automatische DABS/NOTAM-Verfügbarkeit: nicht verbunden. Es wird keine Behauptung gemacht, dass temporäre Einschränkungen abgerufen oder überprüft wurden.';

  @override
  String get airspaceBazlUasGeographicalZones729ad95f => 'BAZL UAS-Gebiete';

  @override
  String get airspaceCheckTheLatestDabsf5c81052 =>
      'Überprüfen Sie die neuesten DABS und Original NOTAM direkt vor dem Fliegen. DABS ist ein periodischer Schnappschuss.';

  @override
  String get airspaceCloseAirspaceCheckeac0670c => 'Enge Luftraumkontrolle';

  @override
  String get airspaceCloseDetails433da6d1 => 'Details schließen';

  @override
  String get airspaceCloseSafetyPanelc70c84b5 => 'Sicherheitspanel schließen';

  @override
  String get airspaceCloseZoneInspection127a12af =>
      'Inspektion in geschlossenen Zonen';

  @override
  String get airspaceColorsDescribeSourceRestrictionsc0980bc9 =>
      'Die Farben zeigen Einschränkungen aus den Quelldaten. Blau bedeutet keine Flugfreigabe. Prüfe alle überlappenden Zonen und deren Bedingungen.';

  @override
  String get airspaceCopyOfficialLink14342de0 => 'Offiziellen Link kopieren';

  @override
  String get airspaceCouldNotOpenBrowserfceaf72a =>
      'Der Browser kann nicht geöffnet werden. Kopieren Sie stattdessen die URL.';

  @override
  String airspaceDataLimitation1a823833(String arg0) {
    return 'Datenbeschränkung: $arg0';
  }

  @override
  String get airspaceDatasetCacheIsStale23d0712d =>
      'Datensatz-Cache ist veraltet oder seine Uhr ist inkonsistent.';

  @override
  String get airspaceEachLimitRetainsIts3b9913eb =>
      'Jede Grenze behält ihre eigene Quelleinheit und vertikale Referenz.';

  @override
  String airspaceFeatures98bdf3c0(String arg0, String arg1) {
    return '$arg0: $arg1 Eigenschaften';
  }

  @override
  String get airspaceFlightSafetyCurrentOfficiala1a04e11 =>
      'Flugsicherheit & aktuelle amtliche Publikationen';

  @override
  String get airspaceGetFreeApiKeyb5c8a05f =>
      'Erhalten Sie kostenlosen API-Schlüssel';

  @override
  String get airspaceInspectRestrictionsdfa16e61 =>
      'Inspizieren von Beschränkungen';

  @override
  String airspaceIntersectingZones8134036b(String arg0) {
    return 'Intersektionszonen: $arg0';
  }

  @override
  String get airspaceKeyConfigured61737de7 => 'Schlüssel konfiguriert';

  @override
  String get airspaceKeysAreKeptFor409824c9 =>
      'Schlüssel werden nur für diese Browser-Sitzung gehalten und verschwinden nach dem Neustart.';

  @override
  String airspaceLastRefreshFailed7971e026(String arg0) {
    return 'Letzte Aktualisierung fehlgeschlagen: $arg0';
  }

  @override
  String get airspaceLeaveExistingKeyUnchanged814b9fe9 =>
      'Lassen Sie den vorhandenen Schlüssel unverändert, indem Sie diesen leer halten';

  @override
  String get airspaceLoadingUasDataAndddfb5ec6 =>
      'UAS-Daten werden geladen und Geometrie überprüft..';

  @override
  String airspaceLower082a2966(String arg0) {
    return 'Niedriger: $arg0';
  }

  @override
  String get airspaceManualPreflightChecklistb4d4bf28 =>
      'Manuelle Vorflug-Checkliste';

  @override
  String get airspaceNextZone6c44893a => 'Nächste Zone';

  @override
  String get airspaceNoHorizontalIntersectionsFound318ee27f =>
      'In den geprüften Daten wurden keine horizontalen Schnitte gefunden.';

  @override
  String get airspaceNoKeyConfigured697416d1 => 'Kein Schlüssel konfiguriert';

  @override
  String get airspaceNoSupportedAirspaceProviderdcf17faa =>
      'Kein unterstützter Luftraumanbieter benötigt derzeit einen frei erhältlichen API-Schlüssel. BAZL arbeitet ohne einen; Skyguide-NOTAM-Zugang ist nicht als kostenlos verifiziert.';

  @override
  String get airspaceOpenOfficialSource47aa309c => 'Offizielle Quelle öffnen';

  @override
  String airspacePolygonFeaturesChecked0b14a2bb(String arg0) {
    return '$arg0 Polygon-Funktionen geprüft';
  }

  @override
  String get airspacePreflightInformationOnlyFpvmanager3ddafa1c =>
      'Nur Vorfluginformationen. FPVManager kann keine Fluggenehmigung erteilen oder garantieren, dass ein Flug legal oder sicher ist.';

  @override
  String get airspacePreviousZoneb179c069 => 'Vorherige Zone';

  @override
  String get airspaceReadTheLatestDabs49e90175 =>
      '2. Lesen Sie die neuesten DABS und das Original NOTAM für die gesamte Flugdauer und Route.';

  @override
  String get airspaceRecheckImmediatelyBeforeTake68acccbc =>
      '4. Überprüfen Sie sofort vor dem Start erneut; ein neuer Download oder ein leeres Schnittergebnis ist kein Beweis für die Berechtigung.';

  @override
  String get airspaceRefreshSourceDatae31028f4 => 'Quelldaten aktualisieren';

  @override
  String get airspaceRestrictionLegendCesiumMap50513b33 =>
      'Restriktionslegende (Cesium map)';

  @override
  String get airspaceRestrictionNotProvided55e0f3ad =>
      'Beschränkung nicht vorgesehen';

  @override
  String get airspaceRestrictionNotProvidedBy569286af =>
      'Nicht quellengebundene Beschränkung';

  @override
  String get airspaceRetryWithFreshData71969c16 => 'Retry mit frischen Daten';

  @override
  String airspaceRouteSnapshotWaypointsAll292bb6c5(String arg0) {
    return 'Route Snapshot · $arg0 Wegpunkte · alle Verbindungssegmente';
  }

  @override
  String get airspaceTemporaryTimeDependentInformation90a7f86a =>
      'Vorübergehende/zeitabhängige Informationen';

  @override
  String get airspaceTimesAndOffsetsAred587335b =>
      'Zeiten und Offsets werden als geliefert dargestellt; die Anwendbarkeit wird nicht berechnet.';

  @override
  String get airspaceUasDataQuality1458ab06 => 'UAS-Datenqualität';

  @override
  String airspaceWaypointsSegments6fa17a75(String arg0, String arg1) {
    return 'Wegpunkte: $arg0 · Segmente: $arg1';
  }

  @override
  String airspaceZoneOfAtThiscce172f2(String arg0, String arg1) {
    return 'Zone $arg0 von $arg1 an dieser Position';
  }

  @override
  String avalancheAbrufPruefung87671789(String arg0) {
    return 'Abruf / Prüfung: $arg0';
  }

  @override
  String get avalancheDarstellungDerPubliziertenTagesabschnitte07920ee4 =>
      'Darstellung der publizierten Tagesabschnitte';

  @override
  String avalancheErneutAktualisierenInSed2b6e00(String arg0) {
    return 'Erneut aktualisieren in $arg0 s';
  }

  @override
  String get avalancheFruehererTagesabschnittbbaf5db6 =>
      'Früherer Tagesabschnitt';

  @override
  String get avalancheGefahrenstufenRegionaleUbersicht44dc4622 =>
      'Gefahrenstufen · regionale Übersicht';

  @override
  String get avalancheGrauUnbekanntOderVeralteter1feb3e46 =>
      'Grau: unbekannt oder veralteter / nicht bestätigter Stand. Abgelaufene Flächen werden ausgeblendet. Ein fehlendes Bulletin ist keine Entwarnung.';

  @override
  String avalancheGueltigkeita66abbe1(String arg0, String arg1) {
    return 'Gültigkeit: $arg0 – $arg1';
  }

  @override
  String get avalancheLawinenbulletinSlfe00b361e => 'Lawinenbulletin · SLF';

  @override
  String avalanchePublikation0e56fdd8(String arg0) {
    return 'Publikation: $arg0';
  }

  @override
  String get avalancheSlfBulletinAktualisieren6cedce41 =>
      'SLF-Bulletin aktualisieren';

  @override
  String get avalancheSpaetererTagesabschnitte6b59639 =>
      'Späterer Tagesabschnitt';

  @override
  String get avalancheTagesuebersicht6ec1173c => 'Tagesübersicht';

  @override
  String get avalancheUnbekanntAlterStandaba56b7e => 'Unbekannt / alter Stand';

  @override
  String get batteriesAddBattery418deef8 => 'Akku hinzufügen';

  @override
  String get batteriesAddPackFromTypea7df2842 => 'Pack vom Typ hinzufügen';

  @override
  String get batteriesAddType937e2dfc => 'Typ hinzufügen';

  @override
  String get batteriesAssociatedFlightPlans1c957aa1 => 'Zugehörige Flugpläne';

  @override
  String get batteriesAvailability681b5b5a => 'Verfügbarkeit';

  @override
  String get batteriesBatteryDetails139e0037 => 'Akkudetails';

  @override
  String get batteriesBatteryInventory01b473c6 => 'Batteriebestand';

  @override
  String get batteriesBatteryTypeReusableTemplate7a43b0a1 =>
      'Batterietyp · wiederverwendbare Vorlage';

  @override
  String batteriesBatterycc97f71f(String arg0, String arg1) {
    return '$arg0 Akku$arg1';
  }

  @override
  String batteriesCalculatedNominalEnergyWh30e6efe0(String arg0) {
    return 'Berechnete Nennenergie: $arg0 Wh (Kapazität × Nennspannung)';
  }

  @override
  String get batteriesConditionAvailability033503de =>
      'Zustand & Verfügbarkeit';

  @override
  String get batteriesCopyTypeSpecifications02a95788 => 'Typdaten übernehmen';

  @override
  String batteriesDeleteBattery7407e336(String arg0) {
    return 'Batterie löschen$arg0?';
  }

  @override
  String get batteriesEditBattery29162bfe => 'Akku bearbeiten';

  @override
  String get batteriesIndividualBattery211df7bd => 'Einzelner Akku';

  @override
  String get batteriesNoBatteryTypesYetc908d855 =>
      'Noch keine Batterietypen. Fügen Sie eine wiederverwendbare Spezifikationsvorlage hinzu.';

  @override
  String get batteriesNoDroneProfilesYet036373ca =>
      'Noch keine Drohnenprofile.';

  @override
  String get batteriesNoIndividualBatteriesYet2f6f284a =>
      'Noch keine einzelnen Akkus erfasst. Füge einen Akku zum Bestand hinzu.';

  @override
  String get batteriesNoSavedFlightPlans0eb9aef8 =>
      'Noch keine gespeicherten Flugpläne.';

  @override
  String get batteriesNoTypeTemplate58240414 => 'Keine Mustervorlage';

  @override
  String get batteriesOptional0c6c4102 => 'Optional';

  @override
  String get batteriesPacksKeepIndependentSpecificationa8fd26d6 =>
      'Akkus behalten ihre eigenen technischen Daten. Spätere Änderungen an der Typvorlage wirken sich nicht rückwirkend aus.';

  @override
  String get batteriesRemovedType24f2204a => 'Entfernter Typ';

  @override
  String get batteriesRetryLoadingOptions99cf637e => 'Ladeversuch wiederholen';

  @override
  String get batteriesTheAssignedTypeWas57b002ba =>
      'Der zugewiesene Typ wurde entfernt. Wählen Sie einen Typ oder keine Vorlage.';

  @override
  String get batteriesThisBatteryNoLongere1b6ecdf =>
      'Diese Batterie existiert nicht mehr.';

  @override
  String get batteriesTypeTemplateOptionalbafc4970 => 'Typvorlage (optional)';

  @override
  String get batteriesUnableToLoadBattery8a3276bc =>
      'Batteriebestand kann nicht geladen werden.';

  @override
  String get batteriesUnableToLoadThis46eed388 =>
      'Diese Batterie kann nicht geladen werden.';

  @override
  String get batteriesUnableToLoadTypesc7010120 =>
      'Typvorlagen und Zuordnungen konnten nicht geladen werden.';

  @override
  String get commonAPlanningRadiusIse6a1033a =>
      'Ein Planungsradius ist keine VLOS-Grenze. Sichtbarkeit, Flugzeugausrichtung, Beobachter, Personen, Pilotenqualifikationen, lokale Einschränkungen und Zulassungen erfordern eine manuelle Überprüfung.';

  @override
  String get commonAbbrechen07af7cb3 => 'Abbrechen';

  @override
  String get commonAbrufzeitIstNichtVeroeffentlichungszeit8d993e52 =>
      'Abrufzeit ist nicht Veröffentlichungszeit. Gültig von/bis beschreibt den angegebenen Zeitraum; ein frischer Download beweist nicht, dass der gesamte Inhalt aktuell ist. Fehlende Zeitangaben werden nicht ergänzt.';

  @override
  String get commonAbsoluteSourceHeightsLn1571b147 =>
      'Absolute Quellhöhe: LN02. Erhöhte Anzeige: CHGeo2004 + HTRANS zum ETRS89-Ellipsoid, die als WGS84-Annäherung verwendet werden. Unbekannte Linien-/Fläche-Höhen werden nur als Bodenmarkierung am ersten Quellwirbel angezeigt. Isolierte Punktbarrieren mit offizieller AGL-Höhe werden auf genau dieser Höhe über dem aktuell gerenderten Gelände angezeigt; ihre visualisierte absolute Spitze kann von der untersuchten LN02-Oberseite abweichen. Extra KML-Markierungspunkte auf Linien/Polygonen werden nicht als Hindernisse gezeichnet. Kabelvertices passend veröffentlichten Masten folgen den gleichen geländegerechten Masten, mit interpolierten Anzeigekorrekturen zwischen den Stützen. Andere Geometrie behält Quellen absolute Höhen. Kabelsag wird nicht rekonstruiert; Routenprüfungen verwenden originale Quellgeometrie.';

  @override
  String get commonAdd61cc55aa => 'Hinzufügen';

  @override
  String get commonAglIsADistance519675fb =>
      'AGL ist eine Entfernung über diesem Bodenpunkt, nicht eine Meereshöhe.';

  @override
  String get commonAirframe2149a671 => 'Flugplan';

  @override
  String get commonAirspaceStatusNotCheckedfcc694aa =>
      'Status des Luftraums: Durch diese Wetterbeurteilung NICHT abgefragt. Aktuelle UAS-Zonen, DABS und NOTAM separat einsehen.';

  @override
  String get commonAirspaceb3cb9fb5 => 'Luftraum';

  @override
  String get commonAktivitaetsprofileUndArbeitsbereiched4c2fe93 =>
      'Aktivitätsprofile und Arbeitsbereiche';

  @override
  String get commonAktivitaetsprofilee88c0015 => 'Aktivitätsprofile';

  @override
  String get commonAktualisierungFehlgeschlagenGespeicherteDatene03c0f00 =>
      'Aktualisierung fehlgeschlagen: gespeicherte Daten, aktueller Status unbekannt.';

  @override
  String get commonAktuelleBazlKarteDabs491537fb =>
      'Aktuelle BAZL-Karte, DABS und Original-NOTAM für Flugzeit und Route sowie örtliche Regeln prüfen. DABS ist ein periodisches Bulletin; NOTAM können sich zwischen Ausgaben ändern. Der automatische DABS/NOTAM-Abruf ist derzeit nicht angeschlossen. Auch Wetter, Hindernisse und Höhenbezüge prüfen und unmittelbar vor Abflug erneut verifizieren.';

  @override
  String get commonAlle4c7a986f => 'Alle';

  @override
  String get commonAlleSekundenSolangeDie8b77bd0f =>
      'Alle 60 Sekunden, solange die Navigation aktiv ist. Im Hintergrund pausiert der Abruf.';

  @override
  String get commonAlleZonenPruefen026c7d8e => 'Alle Zonen prüfen';

  @override
  String get commonAnbieterbedingungenUndBerechtigungenGeltenff0efbff =>
      'Anbieterbedingungen und Berechtigungen gelten pro Quelle. Für ASTRA das Token des passenden Produkts verwenden, nicht Token-Hash oder OJP-Token. Android nutzt die bestehende sichere Schlüsselablage; Schlüssel gehören weder in einfache Einstellungen noch in Backups. Web-Zugänge bleiben in den bisher unterstützten Grenzen. Keine öffentlichen Proxys geben private Schlüssel weiter.';

  @override
  String get commonAngleAcroEQ41fdac85 =>
      'Angle/Acro: E/Q Gas, A/D Yaw, W/S Pitch, Pfeile links/rechts Roll; IJKL steuert ebenfalls die Lage. GPS/Ego: WASD/Pfeile bewegen, Ziehen oder IJKL umsehen; GPS nutzt E/Q für die Höhe. Escape beendet die Ansicht. Für Controller nach Fokusverlust oder echter Trennung die passende Ruheposition einnehmen. Gas-Nullpunkt und Kanalzuordnung bleiben eigene Controller-Einstellungen.';

  @override
  String get commonAngleAcroLinksGas98d5063f =>
      'Angle/Acro: links Gas und Yaw, rechts Pitch und Roll. GPS: links Bewegung, rechts Blickrichtung, separate Knöpfe für Steigen/Sinken. Beide Touch-Sticks sitzen fest. Die Schnelleinstellungen können sie ausblenden; Tastatur und externe Controller bleiben nutzbar.';

  @override
  String get commonAngleAcroNullUntena9ccc141 =>
      'Angle/Acro: Null unten nutzt den ganzen Gasweg; Null in der Mitte nur die obere Hälfte. Zum Verbinden oder Fortsetzen Gas auf null, übrige Sticks zentrieren.';

  @override
  String get commonAngleStabilisiertDieLage6d00e2df =>
      'Angle stabilisiert die Lage, Acro gibt Drehraten vor, GPS bremst und hält die Höhe. „Flugeinstellungen“ bündelt Kamera/Anzeige, Grafik/Licht, Controller, Wind und Funkvorschau. Lange Bildpausen werden nicht als großer Flugschritt nachgeholt. Die Physik, Gelände- und Modellkontakte bleiben Näherungen; Gebäude, Bäume und Kabel bilden keine vollständige Kollisionswelt. Einstellungen außerhalb eines Fluges bereiten die nächste Simulation vor.';

  @override
  String get commonAnwendenb18093c4 => 'Anwenden';

  @override
  String get commonApproximateGreatCircleDistances7eb1a34f =>
      'Ungefähre Großkreisabstände und konstante Fluggeschwindigkeit pro Segment. Ohne Beschleunigung, Schweben, Manövrieren oder Böen. Das Flugzeug muss in der Lage sein, die geplante Geschwindigkeit und Steiggeschwindigkeit zu erreichen.';

  @override
  String get commonApproximateMetricDistancesUse2ad8d0c4 =>
      'Ungefähre metrische Entfernungen verwenden die Schweizer LV95 Projektion. 3D-Werte verwenden originale Quellhöhen, die in die Gelände-Ellipsoid-Referenz umgewandelt werden, nicht angepasste Anzeigegeometrie. Die 30 m AGL-Vorschau ist nie eine geprüfte Höhe.';

  @override
  String get commonAssessModeledBridgesSupports6afd1bbd =>
      'Assess modellierte Brücken, Stützen und Tunnelwände';

  @override
  String get commonAssociatedDrones0b96fd82 => 'Assoziierte Drohnen';

  @override
  String get commonAstraVdpBestEffort6d0423b7 =>
      'ASTRA / VDP · Best-Effort-Messdaten, keine bestätigte Verkehrsprognose.';

  @override
  String commonAtMGroundAltitude06f0de9e(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return 'Auf $arg0 m: Boden $arg1, Höhe $arg2, AGL $arg3.';
  }

  @override
  String get commonAus6997e3eb => 'Aus';

  @override
  String get commonAusgewaehlteAufnahmenSindHistorische73e77349 =>
      'Ausgewählte Aufnahmen sind historische bzw. verzögert veröffentlichte Bilddaten. Keine Live-Beobachtung. Es werden nur kleine STAC-Metadaten gespeichert, keine Rohbilddateien. Wolken, Schatten und fehlende Bilddeckung sind keine leeren Flächen.';

  @override
  String get commonAvailable7c62a142 => 'Verfügbar';

  @override
  String commonAverageAirspeedMS071139b2(String arg0, String arg1) {
    return 'Mittlere Fluggeschwindigkeit: $arg0 m/s · maximal $arg1 m/s';
  }

  @override
  String commonAverageGroundSpeedM20c0470a(String arg0, String arg1) {
    return 'Mittlere Geschwindigkeit über Grund: $arg0 m/s · maximal $arg1 m/s';
  }

  @override
  String commonAverageSpeedMSabf80b70(String arg0, String arg1, String arg2) {
    return 'Durchschnittliche $arg0 Geschwindigkeit: $arg1 m/s · maximal $arg2 m/s';
  }

  @override
  String get commonBackupsSchuetzenSpotsBilder26ad5793 =>
      'Backups schützen Spots, Bilder, Ausrüstung und Planung unabhängig vom Kartencache. Optionales Passwort schützt den Export; ungeschützte Backups sind lesbar. API-Schlüssel und öffentliche Karten-/OSINT-Caches gehören nicht zum persönlichen Backup. Browser können lokalen Speicher löschen; wichtige Daten zusätzlich sichern.';

  @override
  String get commonBafuLiveWerteSind2d1baf8b =>
      'BAFU-Live-Werte sind unkorrigiert. 10-Minuten-Mittel enthalten die bereitgestellte Einheit und den verfügbaren Freigabestatus; unbekannte Referenzen bleiben unbekannt. Frische des lokalen Snapshots und Alter einer einzelnen Messung sind getrennte Angaben. Beobachtungen bewerten weder eine Aktivität als sicher noch ersetzen sie amtliche Warnungen. Abrufe erfolgen bewusst, in begrenzten Abständen; lokale Messwert-Snapshots lassen sich auch ohne Netz öffnen.';

  @override
  String get commonBaustellee9cf26e7 => 'Baustelle';

  @override
  String get commonBazlAuthorisationSubtypesSame4c054fce =>
      'Unterarten der BAZL-Zulassung (gleiche Kategorie, unterschiedliche anwendbare Bedingungen):';

  @override
  String get commonBazlWmsZeigtKombiniertee1af0170 =>
      'BAZL-WMS zeigt kombinierte Rasterbilder; Kategorien und Höhen sind daraus nicht einzeln auswählbar. Vektordaten bieten Details, soweit die Quelle sie enthält. Unbekannte Höhen bleiben unbekannt. Gerade Kabelverbindungen und einfache Mast-/Kranmodelle sind Näherungen, keine exakte Bauwerksaufnahme.';

  @override
  String get commonBeimAbrufWerdenDiecd3b9e12 =>
      'Beim Abruf werden die gewählten Kartenkoordinaten an Open-Meteo gesendet. „Aktuell“ sind Modellwerte, keine Live-Messung vor Ort. Daten und Auswahl gelten für diese Sitzung.';

  @override
  String get commonBeobachtungen9156ea0e => 'Beobachtungen';

  @override
  String get commonBereichBisKmRadiusfecda995 =>
      'Bereich bis 25 km Radius direkt auf diesem Gerät vorbereiten: Topografie, SWISSIMAGE-Satellitenbilder, neutrales Relief und 3D-Gelände aus offiziellen Downloadquellen. In der Webversion ist auch die gesamte Schweiz wählbar.';

  @override
  String get commonBereicheVorbereiten1c921757 => 'Bereiche vorbereiten';

  @override
  String get commonBeschleunigungMS1457d0c3 => 'Beschleunigung (m/s²)';

  @override
  String get commonBevorzugteEbenenSindSchnellzugriffe2eb52776 =>
      'Bevorzugte Ebenen sind Schnellzugriffe zu den bestehenden Ebenenreglern. Ein Profil aktiviert keine Datenquelle, Standortfreigabe, API-Verbindung oder automatische Aktualisierung. Quelleneinstellungen und Berechtigungen bleiben eigenständig. Profile speichern keine Zugangsdaten oder persönlichen Orte.';

  @override
  String get commonBewoelkung3dac517c => 'Bewölkung';

  @override
  String get commonBewoelkungModellbedeckungKeineGemessenencfb37c6a =>
      'Bewölkung: 0–100 % Modellbedeckung, keine gemessenen 3D-Wolken. Temperatur: °C in 2 m Höhe. Alle sichtbaren Raster verwenden dieselbe Prognosezeit.';

  @override
  String get commonBewoelkungNiederschlagRegenNeuschnee33c03591 =>
      'Bewölkung, Niederschlag, Regen, Neuschnee, Schneehöhe und Temperatur sind getrennte Modellprognosen mit gemeinsamer Zeit. Summen gelten für eine Stunde; Schneehöhe ist davon unabhängig. Dieses Stichprobenraster ist kein Wetterradar und keine gemessene 3D-Wolke. Der Wetterbereich bietet separat veröffentlichte MeteoSwiss-Radarbilder: Zeitpunkt wählen, laden oder abspielen. Radar ist eine Beobachtung; fehlende Bilder oder Pixel bedeuten nicht trockenes Wetter.';

  @override
  String commonBezugb64247b0(String arg0, String arg1, String arg2) {
    return 'Bezug: $arg0 · $arg1, $arg2';
  }

  @override
  String get commonBodenansicht66b19097 => 'Bodenansicht';

  @override
  String get commonBodenroutenfc34e044 => 'Bodenrouten';

  @override
  String get commonBremswirkungMSaca7620a => 'Bremswirkung (m/s²)';

  @override
  String get commonCalibrationOutsideIsNot45f5bb20 =>
      'Kalibrierung außerhalb 0.25–4× wird nicht angewendet. Prüfeinheiten, Sensoren und Flugbedingungen.';

  @override
  String get commonCampsites7c38c052 => 'Campingplätze';

  @override
  String get commonCancel77dfd213 => 'Abbrechen';

  @override
  String get commonChSwisstopoSpezialbefliegungen7d9cb953 =>
      'ch.swisstopo.spezialbefliegungen';

  @override
  String get commonChSwisstopoSwisseoS9f4a6c16 =>
      'swisstopo.swisseo_s2-sr_v200';

  @override
  String get commonChannelBandwidth0c1b6ee1 => 'Kanalbandbreite';

  @override
  String get commonChargeCyclesAndCondition2b6f03c0 =>
      'Ladung, Zyklen und Zustand werden manuell aufgezeichnet.';

  @override
  String get commonCheckAltitudeReferencesLocal541cb086 =>
      '3. Überprüfen Sie Höhenangaben, lokale / cantonale Regeln, Flugplatz-Verfahren, Wetter und Hindernisse.';

  @override
  String get commonCheckCurrentOfficialZonesb6eb2aee =>
      'Prüfen Sie aktuelle offizielle Zonen, DABS/NOTAM, Zonengültigkeits- und Höhenreferenzen, Flugzeugklasse und -masse, Pilotenqualifikationen, Personen und Eigentum, Berechtigungen und lokale Regeln. Diese Überprüfungen können nicht allein von der Route aus durchgeführt werden.';

  @override
  String get commonClearOverlay89f8488e => 'Überlagerung entfernen';

  @override
  String get commonCloseNavigationMenu53cad4d7 => 'Navigationsmenü schließen';

  @override
  String get commonClosebbfa773e => 'Schließen';

  @override
  String get commonCodefrogRibbitCodefrogCh4326d9c5 =>
      'Codefrog · ribbit@codefrog.ch. Die vollständige Datenschutzerklärung ist unter Offline & Daten verlinkt.';

  @override
  String get commonCombinedRasterSymbolsNo01f2553a =>
      'Kombinierte Rastersymbole: keine Kategoriefilter, Objektauswahl oder präzise 3D-Höhen.';

  @override
  String get commonCommaSeparatedUpTo0410e8b5 =>
      'Komma getrennt · bis zu 10 Tags, jeweils 32 Zeichen';

  @override
  String get commonCommunicationProfileUnavailableSelect22f9df96 =>
      'Funkprofil nicht verfügbar. Wähle die Funkstrecke erneut aus.';

  @override
  String get commonConnectingToDTerrain33c3d51a =>
      'Verbindung zum 3D-Gelände wird aufgebaut. Die Karte ist vorübergehend flach.';

  @override
  String get commonContinue2e026239 => 'Fortsetzen';

  @override
  String get commonCruisePowere01cb967 => 'Kreuzfahrtleistung';

  @override
  String get commonCruiseSpeed806d91ba => 'Reisegeschwindigkeit';

  @override
  String get commonDBauwerkeff58c166 => '3D-Bauwerke';

  @override
  String get commonDGebaeudee0eaa628 => '3D-Gebäude';

  @override
  String get commonDLichtEnthaeltGebaeude1ba3ed81 =>
      '„3D & Licht“ enthält Gebäude, Vegetation, Bauwerke, automatische 3D-Tunnel und Beleuchtung. Tunnel und ergänzte Brückenpfeiler sind schematisch. Tunnelwände, Boden und Decke haben geometrische Kontaktprüfungen; die optionale Prüfung fremder 3D-Modelle ist nur eine Näherung geladener Oberflächen. Fehlende Objekte werden nicht ergänzt. Streaming-3D und Beschriftungen sind keine vollständigen Offlineebenen. „Quellen“ öffnet die vollständigen aktiven Angaben.';

  @override
  String get commonDTerrainUnavailableFlatc09ad4e3 =>
      '3D-Gelände nicht verfügbar. Die Karte zeigt keine Geländehöhen.';

  @override
  String get commonDUndQuellen2d9ae897 => '3D und Quellen';

  @override
  String get commonDVegetation7f361b72 => '3D-Vegetation';

  @override
  String get commonDatenquelleBundesamtFuerEnergieb3a50654 =>
      'Datenquelle: Bundesamt für Energie (BFE), Ladepunkte Elektromobilität, geo.admin.ch · O-By-Ask. Nutzung mit Quellenangabe; kommerzielle Nutzung nur mit vorheriger Erlaubnis des Dateninhabers.';

  @override
  String get commonDatenquellen3253fdfe => 'Datenquellen';

  @override
  String commonDatensaetzeNichtSicherZugeordnet393f5548(String arg0) {
    return '$arg0 Datensätze nicht sicher zugeordnet / nicht gewichtet. Fehlende Straßenkennung, Richtung, Ortsauflösung oder Gültigkeit bleiben unbekannt.';
  }

  @override
  String get commonDatenschutzUndApiZugaenge303f9be7 =>
      'Datenschutz und API-Zugänge';

  @override
  String get commonDatenschutzkontakteec0b69d => 'Datenschutzkontakt';

  @override
  String get commonDatenstandUndVerfuegbarkeit0ff67f1d =>
      'Datenstand und Verfügbarkeit';

  @override
  String get commonDefaultsMAntennaMhz63828140 =>
      'Voreinstellung: 2 m Antenne, 5800 MHz und 60% First-Zone Radius. Stellen Sie die tatsächliche Steuer- oder Videofrequenz für jede Analyse.';

  @override
  String get commonDeletef6fdbe48 => 'Löschen';

  @override
  String get commonDerGewaehlteAusschnittWird46b1cc5d =>
      'Der gewählte Ausschnitt wird an geo.admin.ch gesendet. Räumlicher Auszug, keine vollständige Zugänglichkeitsprüfung.';

  @override
  String get commonDerKompassRichtetDie15ee98a3 =>
      'Der Kompass richtet die Karte nach Norden aus. „Mein Standort“ ortet erst nach Antippen. Langes Drücken öffnet Genauigkeit und Verfolgung; Kartenbewegungen beenden die Verfolgung. Die Suche akzeptiert Koordinaten, Orte und Straßen.';

  @override
  String get commonDieKantoneErlassenDiea929ec2f =>
      'Die Kantone erlassen die verbindlichen Regeln. Eine Gefahrenstufe allein begründet kein Feuerverbot. Fehlende, veraltete oder unvollständige Daten bedeuten keine Entwarnung.';

  @override
  String get commonDieTagesuebersichtZeigtDie3e26c236 =>
      'Die Tagesübersicht zeigt die höchste publizierte regionale Stufe. Höhenlagen, Expositionen und Lawinenprobleme stehen in der Beschreibung beim Antippen. Die Farbe gilt nicht pauschal für jeden Hang.';

  @override
  String get commonDisabledf4f4473d => 'Deaktiviert';

  @override
  String get commonDocumentation9e9cf322 => 'Dokumentation';

  @override
  String get commonDonee9b450d1 => 'Fertig';

  @override
  String get commonDrinkingWaterc9176049 => 'Trinkwasser';

  @override
  String get commonDrivingRouteToAn298a4f2a =>
      'Fahrweg zu einer Adresse, Koordinaten oder gespeicherten Stelle. Zeiten sind OSRM Basisschätzungen. Verfügbare Verkehr kann helfen, Alternativen zu vergleichen. Überprüfen Sie Parkplätze, private Straßen und die endgültige Annäherung vor Ort.';

  @override
  String get commonDrohnenprofileNichtVerfuegbarManuelle5ff33edb =>
      'Drohnenprofile nicht verfügbar. Manuelle Werte bleiben nutzbar.';

  @override
  String get commonDurchflugNichtVerfuegbarAngaben4931f578 =>
      'Durchflug nicht verfügbar: Angaben zu Einstieg, Höhenprofil oder Terrain-Ausschnitten.';

  @override
  String get commonEbenenUndDatenschutze913d2a4 => 'Ebenen und Datenschutz';

  @override
  String get commonEbenenc8f2bacd => 'Ebenen';

  @override
  String get commonEigeneSpotsFotosAusruestunga83357cb =>
      'Eigene Spots, Fotos, Ausrüstung, Routen und Checklisten sind bereits lokal. Heruntergeladene UAS-Zonen, Vektorhindernisse und SLF-Bulletins bleiben als datierte Momentaufnahmen verfügbar. Diese Ebenen bei Bedarf vorher in den Kartenebenen aktualisieren. WMS-Bilder, gestreamte Gebäude/Bäume, Verkehr, Flugbewegungen und laufende Wetterdaten werden nicht als vollständige Offline-Datensätze zugesagt.';

  @override
  String get commonEin3b564e70 => 'Ein';

  @override
  String get commonEinLaptopIstFuer32903d0e =>
      'Ein Laptop ist für die Aufbereitung nicht erforderlich. Bereits erstellte .fpvregion-Pakete bis 64 MiB können weiterhin importiert werden. Quellenlücken, Landesgrenzen und der gewählte Detailgrad begrenzen die Abdeckung.';

  @override
  String get commonEineModellprognoseIstKeineae457c8d =>
      'Eine Modellprognose ist keine lokale Windmessung am Flugpunkt. Die 3D-Pfeile folgen der Luftströmung, nicht der meteorologischen Herkunftsrichtung. Farben: grün <3, gelb 3–7, orange 7–12, rot ab 12 m/s. Fehlende oder abgelaufene Werte bleiben nicht verfügbar.';

  @override
  String get commonEineUasZoneIst43501474 =>
      'Eine UAS-Zone ist nicht automatisch ein vollständiges Flugverbot. Prüfe jede überlappende Einschränkung, zuständige Stelle, Zeit, Höhe und Freigabeanforderung. Farben beschreiben unterstützte Quellattribute; Blau ist keine Flugfreigabe. Räumliche Checks prüfen Geometrie und ersetzen keine rechtliche Beurteilung.';

  @override
  String get commonEingabeInDerZeitzone41488cc9 =>
      'Eingabe in der Zeitzone des Geräts; gespeichert in UTC. Nur Lichtvorschau, keine Wetter- oder Freigabeprüfung.';

  @override
  String get commonEingabed3a77fb1 => 'Eingabe';

  @override
  String get commonEn094b0fe0 => 'en';

  @override
  String get commonEnableddf174a3f => 'Aktiviert';

  @override
  String get commonEndgeschwindigkeitImFreienFall86d01f28 =>
      'Endgeschwindigkeit im freien Fall (m/s)';

  @override
  String get commonErneutVersuchen3234b7ec => 'Erneut versuchen';

  @override
  String get commonEstimatedae64c7cf => 'Geschätzt';

  @override
  String get commonEstimatesAreNotGuarantees31122c9b =>
      'Schätzungen sind keine Garantien. Szenarien skalieren den Verbrauch; es sind keine statistischen Konfidenzintervalle. Validieren Sie das Modell gegen gemessene Flüge. Batteriezustand, Temperatur und Spannungssog können nutzbare Energie reduzieren.';

  @override
  String get commonExperimentellGeladeneModelloberflaechenKeine5d6ce860 =>
      'Experimentell · geladene Modelloberflächen, keine exakte Wandprüfung.';

  @override
  String get commonExpoLinearWeich280777be => 'Expo (0 linear, 1 weich)';

  @override
  String get commonFahrplanIstNichtGarantiertc1ec8079 =>
      'Fahrplan ist nicht garantiert. Prognosen nur, wenn vom Datenlieferanten verfügbar. Gespeicherte Daten sind niemals live.';

  @override
  String get commonFehlenImAkkuDie64009d59 =>
      'Fehlen im Akku die Startladungsdaten, wird 100 % als editierbare Annahme verwendet. Für eine Spannungsschätzung benötigt das Drohnenprofil Hover- und Cruise-Leistung sowie Cruise-Geschwindigkeit.';

  @override
  String commonFirstCoordinateWgsbca0344d(String arg0, String arg1) {
    return 'Erste Koordinaten: $arg0, $arg1 · WGS84';
  }

  @override
  String get commonFlugBedienung59a0edfe => 'Flug & Bedienung';

  @override
  String get commonFlugaufzeichnung0cfe3bb1 => 'Flugaufzeichnung';

  @override
  String get commonFlugeigenschaften5e125e21 => 'Flugeigenschaften';

  @override
  String get commonFlugeinstellungen51e6bd4a => 'Flugeinstellungen';

  @override
  String get commonFlugrouten39801473 => 'Flugrouten';

  @override
  String get commonFpvPlannedVerifyObservera86fbfbe =>
      'FPV geplant: Überprüfung der Beobachteranforderungen, direkter visueller Kontakt und Kommunikation.';

  @override
  String get commonFpvmanagerCsvVTime07c740c7 =>
      'FPVManager CSV v1: time_s,airspeed_m_s,curnction_v,current_a (groundspeed_m_s wird ebenfalls akzeptiert). EdgeTX: Date, Time, GSpd(kmh/km/h/m/s/kts), Curr(A), VFAS(V) oder Bat(V). Verwenden Sie eine einzelne Spannungs- und Geschwindigkeitsspalte. UTF-8, Dezimalpunkt, 2–20000 Zeilen, bis zu 4 MiB, Lücken ≤30 s. Fehlende Messungen werden abgelehnt. Siehe Beispiel docs/preflight.md.';

  @override
  String get commonFpvmanagerSpeichertPersoenlicheEintraegea3c540bd =>
      'FPVManager speichert persönliche Einträge auf dem Gerät. iOS kann sie in seine Gerätesicherung aufnehmen. Beim Zentrieren und Folgen können Online-Kacheln den Standortbereich erkennen lassen. FOSSGIS protokolliert Routenanfragen. Open-Meteo löscht seine Protokolle laut Anbieter nach 90 Tagen.';

  @override
  String get commonFrequency89836a87 => 'Häufigkeit';

  @override
  String get commonFreshInnerhalbDerAbrufrichtlinie329c6fa9 =>
      'Fresh: innerhalb der Abrufrichtlinie. Stale/expired: veraltet oder abgelaufen. Unavailable: kein nutzbarer Datenstand. Refresh failed: die Aktualisierung schlug fehl; ein vorheriger Stand kann noch angezeigt werden. Quellenstatus und Warnungen stehen weiterhin beim jeweiligen Werkzeug. Keine Anzeige garantiert einen sicheren oder erlaubten Flug.';

  @override
  String get commonFuerDiesesEinsatzproduktIst01b0accb =>
      'Für dieses Einsatzprodukt ist kein georeferenzierter, begrenzt lesbarer RGB-GeoTIFF mit bestätigter Projektion hinterlegt. Kein Kartenbild erfunden.';

  @override
  String commonGebietKmMaximalDetektoren3b49fe28(String arg0, String arg1) {
    return 'Gebiet: $arg0, $arg1 · 30 km · maximal 100 Detektoren';
  }

  @override
  String get commonGefahr7a20fb89 => 'Gefahr';

  @override
  String get commonGelaendehoehe77ccc7f0 => 'Geländehöhe';

  @override
  String get commonGelaendehoeheAbfragencba121dc => 'Geländehöhe abfragen';

  @override
  String get commonGemesseneWerte1e2beb80 => 'Gemessene Werte';

  @override
  String get commonGeometricVisibilityAndFresnelcc5d61f4 =>
      'Sichtlinie und freie Fresnelzone werden geometrisch angenähert. Signalqualität und Funkreichweite werden dabei weder gemessen noch garantiert.';

  @override
  String get commonGewaesserUndAktualitaet3be29a45 => 'Gewässer und Aktualität';

  @override
  String get commonGrafikLichtfef9954a => 'Grafik & Licht';

  @override
  String get commonGrafikTageszeitac9c3755 => 'Grafik & Tageszeit';

  @override
  String get commonGrenzend6f52947 => 'Grenzen';

  @override
  String commonGroesstePublizierteVerzoegerungMinc0ec7c7c(String arg0) {
    return 'Größte publizierte Verzögerung: $arg0 min · Vergleichswert, nicht zur Ankunftszeit addiert';
  }

  @override
  String get commonHeightConversionChgeoHtranscc1a7473 =>
      'Höhenkonvertierung: CHGeo2004 + HTRANS → ETRS89 Ellipsoid (WGS84 Approximation). Bei Single Point Hindernissen mit gültiger AGL, verwenden die gerenderten Marker und Höhenstiel lokales Cesium Terrain + Quelle AGL; die Quelloberseite AMSL bleibt oben aufgeführt und kann abweichen. Kabelvertices, die einem einzigartigen veröffentlichten Mast entsprechen (innerhalb von 2 m horizontal und 5 m in Quell-Top-Elevation) folgen seiner angezeigten Oberseite; Offsets zwischen aufeinander abgestimmten Stützen werden interpoliert. Dies ist eine ungefähre Anzeigekorrektur, nicht vermessene Kabelgeometrie. Unübertroffene Abschnitte behalten Quellhöhen. Routenkontrollen verwenden originale Quellhöhen.';

  @override
  String get commonHilfeHinweise1f11bc49 => 'Hilfe & Hinweise';

  @override
  String get commonHilfeZurKarte2a98c570 => 'Hilfe zur Karte';

  @override
  String get commonHindernisseUndFunkabschattunga9ce1773 =>
      'Hindernisse und Funkabschattung';

  @override
  String get commonHinzufuegenf0d37b9d => 'Hinzufügen';

  @override
  String get commonHoechstgeschwindigkeitMS7904c398 =>
      'Höchstgeschwindigkeit (m/s)';

  @override
  String get commonHoehenbezug920e5815 => 'Höhenbezug';

  @override
  String commonHorizontalDAirspeedM069070e6(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
  ) {
    return '$arg0 horizontal · $arg1 3D Luftgeschwindigkeit $arg2 m/s · $arg3 · Freiraum $arg4';
  }

  @override
  String get commonHorizontalWgsGeometryOnly45382b9e =>
      'Die Prüfung betrachtet horizontale Geometrie in WGS84 und erfasst auch Berührungen an Grenzen. Die Route verläuft geradlinig zwischen Wegpunkten. Höhenlimits, Gültigkeitszeiten und rechtliche Anwendbarkeit sind ungeprüft. Die Prüfung erteilt keine Flugfreigabe.';

  @override
  String get commonHorizontalesSichtfeldae3aaf25 =>
      'Horizontales Sichtfeld (°)';

  @override
  String get commonHoverPowerbaf23552 => 'Energieübertrager';

  @override
  String get commonImBereichBodenroutenWaehlstf1272516 =>
      'Im Bereich Bodenrouten wählst du ausdrücklich „Zu Fuß“ oder „Velo“. Nach deiner Zustimmung werden Start und Ziel an die dazu passenden FOSSGIS-/OSRM-Profile gesendet. Berechnete und importierte Routen bleiben als eigene lokale Datensätze auch ohne Netz verfügbar und werden mit dem persönlichen Backup gesichert. GPX erhält den Aktivitätsmodus und vorhandene Quellenhöhen, ohne daraus AGL-Höhen zu erzeugen. Unbekannte GPX-Typen benötigen den gewählten Importmodus; zusätzliche oder nicht unterstützte Angaben werden gemeldet. Ein gespeicherter Linienverlauf bestätigt keine aktuelle Öffnung. Der Bereich bietet Planung und Austausch; die bisherige Autonavigation ist eigenständig.';

  @override
  String get commonImportLocallycfc01f3f => 'Lokal importieren';

  @override
  String get commonImportieren7d4a3f2a => 'Importieren';

  @override
  String get commonIncompleteCheckGeometryCandidate8ab13e83 =>
      'Unvollständige Prüfung: Geometrie, Kandidaten- oder Berechnungsgrenzen wurden erreicht. Einige Hindernisse wurden nicht bewertet.';

  @override
  String get commonJpegPngOrWebpe13c3bbf =>
      'JPEG, PNG oder WebP · bis zu 12 MiB und 16 MP. Fotos werden lokal verkleinert und gespeichert.';

  @override
  String get commonJsonMitEpsgQuellef95a2fe5 =>
      'JSON mit EPSG:4979, Quelle und separatem Kollisionsmesh. GLB/IFC werden nicht direkt unterstützt.';

  @override
  String get commonKacory5617237a => 'Kakorie';

  @override
  String get commonKameraAnzeige6c89d080 => 'Kamera & Anzeige';

  @override
  String get commonKameraHudd79e87be => 'Kamera & HUD';

  @override
  String get commonKameraneigung4c3e596e => 'Kameraneigung';

  @override
  String get commonKameraneigungNachOben943b5e57 =>
      'Kameraneigung nach oben (°)';

  @override
  String get commonKarteAnsichtBuendeltKarte719d6808 =>
      '„Karte & Ansicht“ bündelt Karte, Luftraum, Hindernisse und OSINT. Satellit, Topo und Relief sind Hintergrundkarten; Straßen, Beschriftungen und gespeicherte Spots sind unabhängig schaltbar. Beschriftungen zeigen eine begrenzte Auswahl Schweizer Orts- und Straßennamen. Seltene Werkzeuge und Metadaten lassen sich bei Bedarf öffnen; laufende Fehler und Datenlücken bleiben sichtbar.';

  @override
  String get commonKarteAnsichtb4cd1571 => 'Karte & Ansicht';

  @override
  String get commonKarteUndBeschriftungen20474dfe => 'Karte und Beschriftungen';

  @override
  String get commonKarteUndLaufendeAktivitaeten4df7dcc2 =>
      'Karte und laufende Aktivitäten';

  @override
  String get commonKarteZuruecksetzend562ce9b => 'Karte zurücksetzen';

  @override
  String get commonKartenbewegungBeendetDieVerfolgung79535231 =>
      'Kartenbewegung beendet die Verfolgung.';

  @override
  String get commonKartenebenen83ea2698 => 'Kartenebenen';

  @override
  String get commonKartenpunktOrtOderRoute53c79c56 =>
      'Kartenpunkt, Ort oder Route wählen';

  @override
  String get commonKartenstartwerteGeltenBeimApp3fbf4f32 =>
      'Kartenstartwerte gelten beim App-Start, Aktivieren oder Speichern des aktiven Profils. Spätere Änderungen auf der Karte bleiben bis zur nächsten Aktivierung oder zum Neustart erhalten. Während Bodenansicht, Simulation, Navigation oder pausiertem Renderer werden Startwerte zurückgestellt und erst danach angewendet. Kamera, Auswahl, laufende Steuerung, Formulare und persönliche Datensätze werden beim Wechsel nicht zurückgesetzt. Ohne Profil bleibt die aktuelle Karte erhalten.';

  @override
  String get commonKeinOnlineNachladenFuer3b0d241a =>
      'Kein Online-Nachladen für Grundkarte und Gelände, auch nach Neustart. Live-Daten können weiterhin online sein.';

  @override
  String get commonKeine3ce60e74 => 'Keine';

  @override
  String get commonKeineTrefferBedeutenNicht4cb792ac =>
      'Keine Treffer bedeuten nicht, dass es keine Ladestationen gibt.';

  @override
  String get commonKeineTrefferBedeutenNichtdf8f1b9e =>
      'Keine Treffer bedeuten nicht, dass keine Anlage vorhanden ist.';

  @override
  String get commonKeysAreStoredLocally5e3f356a =>
      'Schlüssel werden lokal mit verschlüsseltem OS-Backed-Speicher gespeichert, nicht App-Einstellungen.';

  @override
  String get commonKoordinatenOrtOderStrasseed101593 =>
      'Koordinaten, Ort oder Straße';

  @override
  String get commonKoordinatenUndHoehene15ceca0 => 'Koordinaten und Höhen';

  @override
  String get commonKritischeZellspannungVc0450582 =>
      'Kritische Zellspannung (V)';

  @override
  String get commonLatitudeLongitudeHeightM29549b09 =>
      'Breite,Länge,Höhe_m_agl,Radius_m,Art,Quelle Arten: Bauen, Vegetation, andere. Bis zu 100 Beobachtungen. Höhen 0–1000 m AGL, Radius 1–1000 m.';

  @override
  String get commonLawineninformationen505b7525 => 'Gesetzliche Informationen';

  @override
  String get commonLeaveUnknownValuesEmptyc1fa72a7 =>
      'Lassen Sie unbekannte Werte leer. Identifizieren Sie jeden eingegebenen Wert als gemessen, geschätzt oder Quelle nicht angegeben. Bearbeiten einer Zahl setzt seine vorherige Quelle zurück.';

  @override
  String get commonLinksBewegungRechtsBlickf668a7b3 =>
      'Links: Bewegung · Rechts: Blick · E/Q: Höhe';

  @override
  String get commonLinksGasYawRechtsd7f829e1 =>
      'Links: Gas / Yaw · Rechts: Pitch / Roll';

  @override
  String get commonLoading33ce4174 => 'Wird geladen …';

  @override
  String get commonLoeschenffa5a8a7 => 'Löschen';

  @override
  String get commonLokalUndOnline5fe8b49a => 'Lokal und online';

  @override
  String get commonLuftfahrthindernissef4bb6756 => 'Luftfahrthindernisse';

  @override
  String get commonLuftraumUndFlugvorbereitung28d1eda6 =>
      'Luftraum und Flugvorbereitung';

  @override
  String get commonManualAssumptionNotAn31019e80 =>
      'Manuelle Annahme, keine automatisch überprüfte Prognose.';

  @override
  String get commonMapLayerse2967959 => 'Kartenebenen';

  @override
  String get commonMapLayersfdee4317 => 'Kartenebenen';

  @override
  String get commonMapOrangePotentialObstructionbe96635a =>
      'Karte: orange = potenzielle Obstruktion, lila = Fresnel-Intrusion, cyan = keine beprobte Obstruktion, grau = unbekannt. Der ausgewählte Pfad zeigt die konfigurierte Fresnel-Hüllkurve.';

  @override
  String get commonMarkiertePufferUmVeroeffentlichte170a2673 =>
      'Markierte Puffer um veröffentlichte Punkte/Linien sind Planungshilfen. Sie definieren weder rechtlichen Abstand noch vertikale Freigängigkeit. Funk-LOS/Fresnel prüft unterstützte Geländedaten und Annahmen; Gebäude, Vegetation und nicht erfasste Objekte können weiterhin abschatten. Fehlende Hindernisse oder freie Geometrie sind kein Sicherheitsnachweis.';

  @override
  String get commonMaximalerSchubGewichtbf903e1b => 'Maximaler Schub / Gewicht';

  @override
  String get commonMaximumClimbRate97079473 => 'Maximale Steigung';

  @override
  String get commonMaximumPower96af2765 => 'Maximale Leistung';

  @override
  String get commonMaximumSpeedb02bf3de => 'Höchstgeschwindigkeit';

  @override
  String get commonMaximumTransmitterPower654a8d01 => 'Maximale Sendeleistung';

  @override
  String get commonMeasured9550373e => 'Gemessen';

  @override
  String get commonMeasuredHourlyStationAverages6b75bd38 =>
      'Gemessene Stundendurchschnittswerte (No/m3, Pollenkörner pro Kubikmeter); keine Prognose oder Expositionsschätzung an der ausgewählten Stelle.';

  @override
  String get commonMeinStandort98425c52 => 'Mein Standort';

  @override
  String get commonMessstationenf5f4587a => 'Messstationen';

  @override
  String get commonMeteoswissStationswerteSindMessungen2c9d236f =>
      'MeteoSwiss-Stationswerte sind Messungen an einem einzelnen Standort; Wind und Böen stehen im Quellenformat km/h, Niederschlag als Summe über zehn Minuten. Die Messzeiten sind UTC und werden zusätzlich lokal angezeigt. Sie beschreiben kein vollständiges Windfeld und ändern den Simulatorwind nicht. Fehlende Qualitätsflags bleiben unbekannt.';

  @override
  String get commonMethodSourcesLimits2cadbcdb => 'Methode, Quellen & Grenzen';

  @override
  String get commonMissingTilesRemainUnavailable2b39e068 =>
      'Fehlende Kacheln bleiben nicht verfügbar. Live-Datenlagen und API-Aktionen sind getrennt und können immer noch das Netzwerk nutzen.';

  @override
  String get commonMittelpunktAufDemGlobec923e1bf =>
      'Mittelpunkt auf dem Globe wählen oder Koordinaten eingeben, Radius bis 25 km und gewünschte Details/Assets wählen. Web bietet zusätzlich die gesamte Schweiz. Download und Aufbereitung benötigen Zeit, freien Speicher und eine geöffnete App. Quelllücken und gewählte Details begrenzen die Abdeckung.';

  @override
  String get commonMobilitaetOsint610c90a7 => 'Mobilität & OSINT';

  @override
  String get commonModelWindAtM9f419984 =>
      'Modellwind auf 10 m und 80 m ist keine Vorhersage der lokalen Rotorturbulenzen. Täler, Grate, Hindernisse und thermischen können größere Abweichungen verursachen.';

  @override
  String get commonModellUndMessung5e4ffe89 => 'Modell und Messung';

  @override
  String get commonMotorAnsprechzeitS5a0796fd => 'Motor-Ansprechzeit (s)';

  @override
  String get commonMotorCount7eb9729b => 'Anzahl der Motoren';

  @override
  String get commonMoveTheMapTob0c48a5b =>
      'Bewegen Sie die Karte an einen Ort und tippen Sie dann auf die Karte, um Ihren ersten Wegpunkt festzulegen.';

  @override
  String get commonNameDescriptionCategoryOr5d2460f9 =>
      'Name, Beschreibung, Kategorie oder Tags';

  @override
  String get commonNaturUndSperrungen058761a3 => 'Natur und Sperrungen';

  @override
  String get commonNavigationUndMobilitaet625d3f0a =>
      'Navigation und Mobilität';

  @override
  String get commonNavigationUndVerkehredf4cfaf => 'Navigation und Verkehr';

  @override
  String get commonNeuschneesummeH10eeb220 => 'Neuschneesumme (1 h)';

  @override
  String get commonNextbc981983 => 'Weiter';

  @override
  String get commonNiederschlagUndGrossraeumigerRegen09d9c44f =>
      'Niederschlag und großräumiger Regen sind Summen der vorangegangenen Stunde (mm), Neuschnee in cm, Schneehöhe in m. Eine Regenrate oder Niederschlagsart wird daraus nicht abgeleitet.';

  @override
  String get commonNiederschlagssummeHb61d9c9a => 'Niederschlagssumme (1 h)';

  @override
  String get commonNo816c52fd => 'Nein';

  @override
  String get commonNoBuildingOrCanopy5fb91054 =>
      'Kein Gebäude- oder Baldachinservice ist angeschlossen. Importieren Sie bekannte lokale Fußabdrücke als kreisförmige AGL-Höhenbeobachtungen. Dies sind ungefähre Standortbeobachtungen, nicht ein komplettes Oberflächenmodell.';

  @override
  String get commonNoEquipmentProfilesYet41f7bf08 =>
      'Noch keine Geräteprofile. Fügen Sie separate Konfigurationen für Funksteuerung, Video oder Telemetrie hinzu.';

  @override
  String get commonNone6eef6648 => 'Keine';

  @override
  String get commonNotRecorded305cc364 => 'Nicht erfasst';

  @override
  String get commonNotes70440046 => 'Anmerkungen';

  @override
  String get commonNurNachManuellemStartca69930e =>
      'Nur nach manuellem Start · begrenzte Abfrage, keine nationalen Downloads';

  @override
  String get commonObservationNotForecastMissingb7760aa1 =>
      'Beobachtung, nicht vorhergesagt. Fehlende Pixel und fehlende Daten dürfen nicht als trockenes Wetter interpretiert werden.';

  @override
  String get commonOffizielleBakomStandorteStationstyp81519366 =>
      'Offizielle BAKOM-Standorte. Stationstyp, Leistungsklasse und Technologie werden nur nach Quellenangabe angezeigt. Die Koordinaten bezeichnen den ersten Mast einer Station. Sie sind keine Hindernisgeometrie und messen keine FPV-Abdeckung.';

  @override
  String get commonOfflineFlatMapShownaa2963ed =>
      'Offline ist die Karte flach. Geländehöhen sind nicht verfügbar.';

  @override
  String get commonOfflineKartenUndBackups5cb5d797 =>
      'Offline-Karten und Backups';

  @override
  String commonOfflinePaketGrobMibeae634d2(String arg0, String arg1) {
    return 'Offline-Paket grob $arg0 MiB (Karteninhalt variiert), maximal 64 MiB. Originaldateien für die Aufbereitung können deutlich größer sein.$arg1';
  }

  @override
  String get commonOfflineUndPersoenlicheDaten7b8d1b0c =>
      'Offline und persönliche Daten';

  @override
  String get commonOnePairPerLine94168101 =>
      'Ein Paar pro Linie. Nur Levelflug, ohne Kletterleistung. Keine Extrapolation außerhalb der Kurve.';

  @override
  String get commonOpenCurrentBazlMap31b230a4 =>
      '1. Öffnen Sie die aktuelle BAZL-Karte, überprüfen Sie alle anwendbaren überlappenden Zonen und kontaktieren Sie die zuständige Behörde, wenn nötig.';

  @override
  String get commonOpenMeteoCcBy8eb16c41 =>
      'Open-Meteo · CC BY 4.0; kostenloser Zugang für nicht kommerzielle Nutzung. Aktueller Modellwind wird bei aktiver Darstellung oder im Flug alle 15 Minuten aktualisiert. Prognosen verwenden den nächsten verfügbaren Stundenwert. Sonnenzeit und Windzeit sind unabhängig. Zwischen Rasterpunkten und Modellhöhen (10, 80, 120, 180 m AGL) werden Windvektoren interpoliert. Außerhalb bekannter Höhen wird die nächste Schicht konstant fortgesetzt. Außerhalb des geladenen Ausschnitts oder bei fehlenden Daten gibt es keinen Windeinfluss. Keine zusätzlichen künstlichen Böen und keine Berechnung von Gebäudeverwirbelungen, Thermik oder kleinräumiger Geländeströmung.';

  @override
  String get commonOpenSettingsfd7108f8 => 'Einstellungen öffnen';

  @override
  String get commonOptionalAdsbLolCommunity571b79fc =>
      'Optionaler adsb.lol Community-Empfangs-Snapshot innerhalb von 25 Seemeilen. Keine automatische Abstimmung, Historie oder Extrapolation. Bis zur Anforderung werden keine Daten heruntergeladen. OpenSky wird nicht verwendet, da die Applikationsintegration eine schriftliche Lizenz erfordert.';

  @override
  String get commonOptionalCircularAglObservations3ad9fcc1 =>
      'Optionale kreisförmige AGL-Beobachtungen, wie in der Vorfluganalyse. Sichtbare 3D-Gebäude, Wälder, Masten und Kabel sind nicht automatisch enthalten.';

  @override
  String get commonOptionalNearbyPointsFrom6d1c26fc =>
      'Optionale Nahpunkte von OpenStreetMap via Overpass. Jede Anfrage wird manuell initiiert, begrenzt auf 2 km und sechs Kategorien. Fehlende Ergebnisse beweisen nicht, dass eine Anlage nicht existiert. Nutzen Sie diese Ergebnisse niemals als maßgebliche Quelle der Trinkwassersicherheit oder des Zugangs.';

  @override
  String get commonOptionalStationspunkteKeineMasthoehen32868013 =>
      'Optional · Stationspunkte, keine Masthöhen oder Signalabdeckung';

  @override
  String get commonOptionalerInnenwiderstandJeZelle8ca0db6d =>
      'Optionaler Innenwiderstand je Zelle (Ω; 0 = aus)';

  @override
  String get commonOrientierung74a0fc2b => 'Orientierung';

  @override
  String get commonOrtOderKoordinatenSuchen6904cb89 =>
      'Ort oder Koordinaten suchen';

  @override
  String get commonOrtSuchen06144b10 => 'Ort suchen';

  @override
  String get commonOutdoorKartenUndMessstationen76975577 =>
      'Outdoor-Karten und Messstationen';

  @override
  String get commonPersoenlicheDatenf0cbba56 => 'Persönliche Daten';

  @override
  String get commonPersoenlicheEintraegeBleibenLokal72d5b20b =>
      'Persönliche Einträge bleiben lokal. Kartenanbieter sehen angeforderte Kartenausschnitte; aktivierte Beschriftungen senden ebenfalls nur den benötigten Bereich. Eine bestätigte Route sendet Start/Ziel an den Routingdienst. Orts-/Adresssuchen werden erst beim Absenden übertragen. Standortanzeige ist freiwillig und arbeitet nur im Vordergrund; es wird kein Standortverlauf angelegt.';

  @override
  String get commonPfeileUndEinflussAuf9b831fb0 =>
      'Pfeile und Einfluss auf die Flugphysik sind unabhängig schaltbar. Eine feste Sonnen-/Mondzeit ändert die Winddaten nicht. Für eine andere Windprognose die Datenquelle/Zeit ausdrücklich wählen. Lokale Böen und Gelände-Effekte können von der Modellnäherung abweichen.';

  @override
  String get commonPhotosc8b2e864 => 'Fotos';

  @override
  String get commonPitchMaximalScbf3d02c => 'Pitch maximal (°/s)';

  @override
  String get commonPlanningChecksOnlyNo5a915c9e =>
      'Prüfungen zur Planung. Eine Flugfreigabe sowie sichere Gelände-, Hindernis- und Luftraumabstände lassen sich daraus nicht ableiten.';

  @override
  String get commonPlanungshilfen4c6529d9 => 'Planungshilfen';

  @override
  String get commonPlaygrounds2472110c => 'Spielplätze';

  @override
  String commonPotentialObstructionSurfaceMf0e561ae(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Mögliche Behinderung: $arg0, $arg1 · Oberfläche $arg2 m WGS84 ellipsoid';
  }

  @override
  String get commonPowerPerformance72b3155b => 'Leistung & Flugverhalten';

  @override
  String get commonPreparationa8bc3820 => 'Vorbereitung';

  @override
  String get commonProfileUndAuswahlSindd905de42 =>
      'Profile und Auswahl sind Bestandteil persönlicher Backups. Einzelne Profile können als versionierte .fpvprofile-Datei exportiert werden. Der Import zeigt eine Vorschau und ergänzt ein inaktives Profil, ohne vorhandene Profile zu überschreiben. Unterstützt werden höchstens 32 Profile und Dateien bis 128 KiB.';

  @override
  String get commonPropellerCount0e5ac786 => 'Propellerzahl';

  @override
  String get commonPropellerPitchb46bd729 => 'Propellerneigung';

  @override
  String get commonPropulsione8ec111d => 'Antrieb';

  @override
  String get commonProtocolSystemb95bcf23 => 'Protokoll / System';

  @override
  String commonQuelle25cfc7b8(String arg0) {
    return 'Quelle: $arg0';
  }

  @override
  String get commonQuelleBundesamtFuerEnergiea8a665a6 =>
      'Quelle: Bundesamt für Energie (BFE), sharedmobility.ch – Standorte und Verfügbarkeit von Shared-Mobility-Angeboten. Daten können verzögert oder unvollständig sein. Keine Buchung oder Reservierung.';

  @override
  String get commonRadiob11bf19e => 'Fernsteuerung';

  @override
  String get commonReady20c7c552 => 'Bereit';

  @override
  String get commonReceiverAntenna09c32a42 => 'Empfänger & Antenne';

  @override
  String get commonReceiverAntennaCharacteristics8fa01aa6 =>
      'Eigenschaften der Empfängerantenne';

  @override
  String get commonReceiverAntennaGain1e5045a8 => 'Receiver-Antennengewinn';

  @override
  String get commonReceiverCableConnectorLossa4943703 =>
      'Receiverkabel / Steckverbinderverlust';

  @override
  String get commonReceiverModel33350928 => 'Empfängermodell';

  @override
  String get commonReceiverPolarization24abf7a4 =>
      'Polarisation des Empfängers';

  @override
  String get commonReceiverSensitivity1118dfab =>
      'Empfindlichkeit des Empfängers';

  @override
  String get commonReceiverSpecificationsOperatingMode752249f6 =>
      'Receiver-Spezifikationen / Betriebsmodus';

  @override
  String commonRecordedTrajectoryNorthUp84f04fe5(String arg0) {
    return 'Aufgezeichnete Flugbahn, nach Norden, mit Höhenprofil. $arg0 Meter.';
  }

  @override
  String get commonRedMapSegmentsIndicate9cf68571 =>
      'Rote Kartenabschnitte weisen auf Ergebnisse zur Geländefreiheit, zur Akkureserve oder auf weitere Befunde der Routenprüfung hin. Öffne die Prüfungen für Details. Eine horizontale Zonenüberschneidung allein klärt die rechtliche Anwendbarkeit nicht.';

  @override
  String get commonReferenceVoltage24d76e09 => 'Bezugsspannung';

  @override
  String get commonRefresh56e3badc => 'Aktualisieren';

  @override
  String get commonRegenGrossraeumigH0f1e72be => 'Regen · großräumig (1 h)';

  @override
  String get commonRegionaleIndikatorenUndSatellitengestuetzte10059e46 =>
      'Regionale Indikatoren und satellitengestützte Modelle, keine Messung der lokalen Bodenfeuchte. Weder Feuerverbote noch Wasserentnahmebeschränkungen werden aus diesen Karten abgeleitet. Fehlende Kacheln sind keine Entwarnung.';

  @override
  String get commonReliefbe53bb74 => 'Relief';

  @override
  String get commonReloadcce71553 => 'Erneut laden';

  @override
  String get commonRemoveKey582d9a78 => 'Schlüssel entfernen';

  @override
  String get commonRemovee963907d => 'Entfernen';

  @override
  String get commonRequestsAppearInProviderc028be67 =>
      'Anfragen erscheinen in Provider-Logs. Es werden keine Spotnamen, Notizen oder Kontodaten gesendet.';

  @override
  String get commonReset44c57abd => 'Zurücksetzen';

  @override
  String get commonResultsExpireAfterSecondsfc4e5dd8 =>
      'Die Ergebnisse laufen nach 5 Sekunden ab. Flugbewegungen, Pausen, Respawns und nicht vorhandenes Terrain können ein Ergebnis unbekannt machen. Terrain-Publikationszeit wird von dieser Probenahmeschnittstelle nicht geliefert. Funkausbreitung, Interferenz, Antennenmuster und Materialdämpfung werden nicht modelliert.';

  @override
  String get commonRetired37d1213e => 'Im Ruhestand';

  @override
  String get commonRetraceThePlannedPathec9e751c =>
      'Den geplanten Weg zurückverfolgen, mit Gegenrichtungswind. Beim Start wird kein Rücklauf hinzugefügt.';

  @override
  String commonRetrievedc0a8bd29(String arg0) {
    return 'Erhalten: $arg0';
  }

  @override
  String get commonRetry9f5cd8a2 => 'Erneut versuchen';

  @override
  String get commonReturnToTakeoffIs90ab579c =>
      'Die Rückkehr zum Start wird durch die Rückverfolgung des geplanten Pfades, mit Wind neu berechnet in umgekehrter.';

  @override
  String get commonReviewTheSavedRoute73d944db =>
      'Überprüfen Sie die gespeicherte Route vor dem realen Flug. Gemusterte Bewegung, Gelände und Timing werden simuliert; Drohnen- und Batteriezuweisungen können im Routeneditor hinzugefügt werden.';

  @override
  String get commonRollMaximalS70a32bd1 => 'Roll maximal (°/s)';

  @override
  String get commonRollPitchGasUndf22bbf00 =>
      'Roll, Pitch, Gas und Yaw benötigen vier verschiedene USB-Kanäle. Zuordnung und Richtung hängen von Fernsteuerung und Betriebssystem ab. Schalter lösen weder Zurücksetzen noch Beenden aus.';

  @override
  String get commonRouteName4421bcfb => 'Routenname';

  @override
  String get commonRoutenUndAnsagenSind26c916e8 =>
      'Routen und Ansagen sind Orientierungshilfen. Straßenregeln und die reale Situation gehen vor. Der Kompass richtet zuerst nach Norden aus; erneutes Antippen kehrt zur schrägen Verfolgungsansicht zurück. Ungenaue GPS-Signale begrenzen Richtung und Neuberechnung.';

  @override
  String get commonRoutesTrafficAircraft309ea855 =>
      'Strecken, Verkehr und Luftfahrzeuge';

  @override
  String get commonSampledModelPointsArounda07ce918 =>
      '49 abgetastete Modellpunkte um den ausgewählten Punkt. Anzeigeabstand zeigt NICHT die tatsächliche meteorologische Modellgenauigkeit; keine räumliche Interpolation. Dies ist NICHT eine MeteoSchweizer Schicht, auch wenn MeteoSchweizer oben ausgewählt ist.';

  @override
  String get commonSaveKeyf5216b3a => 'Schlüssel speichern';

  @override
  String get commonSaveSpotsImagesEquipmentdd4221ef =>
      'Speichern Sie Spots, Bilder, Geräte, Routen, Checklisten, Telemetrie und Planungseinstellungen in einer lokalen Datei (bis zu 64 MiB). Öffentliche Karten-/OSINT-Caches und API-Schlüssel sind ausgeschlossen.';

  @override
  String get commonSavedPlaces364519ea => 'Gespeicherte Orte';

  @override
  String get commonSavedSpot64ad0674 => 'Gespeicherte Stelle';

  @override
  String get commonSaveefc007a3 => 'Speichern';

  @override
  String get commonSaving56a2285c => 'Speichern..';

  @override
  String get commonSavingae7e8875 => 'Speichern...';

  @override
  String commonScaleThisSavedRoutes1968fc72(String arg0) {
    return 'Skalieren Sie diese gespeicherte Route-Power-Kurve um $arg0. Dies ist eine Pegelflug-Annäherung über das Protokoll-Geschwindigkeitsprofil; Anstiege, Wind, aggressive Manöver und Batterie/Sensor-Fehler können es verzerren. Das ursprüngliche CSV bleibt gespeichert. Andere Routen und Drohnenspezifikationen sind unverändert.';
  }

  @override
  String get commonSchliessen44424b18 => 'Schließen';

  @override
  String get commonSchneehoehe063f48a9 => 'Schneehöhe';

  @override
  String get commonSchneeschuhrouten232e5840 => 'Schneeschuhrouten';

  @override
  String get commonSchubkurveLinearQuadratischa35ca8b8 =>
      'Schubkurve (0 linear, 1 quadratisch)';

  @override
  String commonSelectedGlobeLocation8a849707(String arg0, String arg1) {
    return 'Ausgewählte Kugelposition ($arg0, $arg1)';
  }

  @override
  String get commonSendSelectedCenterRadiusdd0ed3a0 =>
      'Senden Sie ausgewählte Mitte, Radius und Kategorien an die öffentliche Überführung API.';

  @override
  String get commonSettingsc7f73bb5 => 'Einstellungen';

  @override
  String get commonSharedMobilityBfeSharedmobility7d5c9e61 =>
      'Shared Mobility (BFE / sharedmobility.ch). Punktuelle REST-Abfrage, ohne automatische Standortüberwachung oder Reservierung.';

  @override
  String get commonSichernUndTeilen9769e149 => 'Sichern und teilen';

  @override
  String get commonSichtfeldd835ebc7 => 'Sichtfeld';

  @override
  String get commonSimModellwertKeineEchte2ec26181 =>
      'SIM: Modellwert, keine echte Akkutelemetrie.';

  @override
  String get commonSimulierterAkkuHud043eb4df => 'Simulierter Akku (HUD)';

  @override
  String get commonSituationsmeldungenUndMessstellenSinde2636ae0 =>
      'Situationsmeldungen und Messstellen sind verschiedene Quellen mit eigenen Tokens. TMC-Codes benötigen die passende amtliche Ortstabelle. Unverortete, abgelaufene oder unvollständige Meldungen dürfen nicht als freie Strecke gelten. Messgeschwindigkeiten sind punktuelle Beobachtungen, keine flächendeckende Live-Staukarte.';

  @override
  String get commonSomeTerrainTilesAre771ea391 =>
      'Einige Geländekacheln fehlen. Das geladene 3D-Gelände bleibt sichtbar. In betroffenen Bereichen können Höhenangaben fehlen.';

  @override
  String get commonSource6da13add => 'Quelle';

  @override
  String get commonSourceMeteoswissFsdiStac0fd2fd76 =>
      'Quelle: MeteoSwiss · FSDI STAC · Schweizer Pollenüberwachungsnetzwerk. Abdeckung beschränkt sich auf veröffentlichte Stationen. Daten sind Beobachtungen, keine medizinische Beratung.';

  @override
  String get commonSourceNotSpecifieda922455d => 'Quelle nicht spezifiziert';

  @override
  String get commonSourceSnapshotIsDelayed341226cb =>
      'Quelle Snapshot wird verzögert, seine Veröffentlichungszeit ist unbekannt, oder die Source/Device-Uhren widersprechen. Retrieval/Importzeit macht alte Positionen nicht aktuell.';

  @override
  String get commonSourceSwisstopoTerrainValues0aaf6e16 =>
      'Quelle: swisstopo Terrain. Werte verwenden ein digitales Geländemodell, nicht gemessene Flugzeughöhe oder geprüfte Hindernisfreiheit.';

  @override
  String get commonSpecificationSourceMeasurementContextf57759cc =>
      'Spezifikationsquelle / Messkontext';

  @override
  String get commonSpeichern70b73bbc => 'Speichern';

  @override
  String get commonSperrung6e842243 => 'Sperrung';

  @override
  String get commonSperrungenUndUmleitungenMountainbike12e5ddcf =>
      'Sperrungen und Umleitungen · Mountainbike';

  @override
  String get commonSperrungenUndUmleitungenVelo88b39c0a =>
      'Sperrungen und Umleitungen · Velo';

  @override
  String get commonSperrungenUndUmleitungenWanderne50fe2ab =>
      'Sperrungen und Umleitungen · Wandern';

  @override
  String commonSpotPositiond64f0e9b(String arg0, String arg1) {
    return 'Position vorsortieren · $arg0, $arg1';
  }

  @override
  String commonStandOfflineNichtLive42b1bd9b(String arg0) {
    return 'Stand $arg0 · offline, nicht live';
  }

  @override
  String get commonStartZielUndReisezeit1a5914f9 =>
      'Start, Ziel und Reisezeit für die Abfrage an opentransportdata.swiss senden.';

  @override
  String get commonStartenUndAnpassen92258e7a => 'Starten und anpassen';

  @override
  String get commonStarthoeheUeberGrundMc947203e => 'Starthöhe über Grund (m)';

  @override
  String get commonStartladungSchaetzung865c309f =>
      'Startladung (%) · Schätzung';

  @override
  String commonStation5a5e3cd7(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return 'Station $arg0$arg1 $arg2, $arg3';
  }

  @override
  String get commonStauStockenderVerkehr5b47c80a => 'Stau / stockender Verkehr';

  @override
  String get commonSteigenSinkenMaximalM011fe6b0 =>
      'Steigen / Sinken maximal (m/s)';

  @override
  String get commonSteuerungUndSimulation3a676b6f => 'Steuerung und Simulation';

  @override
  String get commonSticksb0cca9f9 => 'Stäbe';

  @override
  String get commonStopRecordingee0d9dc8 => 'Aufzeichnung beenden';

  @override
  String get commonStrasseOrtOderMeldung26ebddfb =>
      'Straße, Ort oder Meldung suchen';

  @override
  String get commonStrassenUndWegea615580e => 'Straßen und Wege';

  @override
  String get commonSwisstopoTerrainViaCesium6cb5e495 =>
      'Geländedaten von swisstopo über Cesium mit ellipsoidischen WGS84-Höhen. Die gerade ECEF-Sichtlinie berücksichtigt die Erdkrümmung. Die Routenziele liegen höchstens 100 m auseinander. Jede Funkstrecke wird in Abständen von höchstens 25 m geprüft. Importierte Oberflächen erhöhen das Gelände innerhalb ihres Radius um die angegebene Höhe. Ziele über 50 km Entfernung oder mit unbekannter Höhe werden als unbekannt markiert. Die Karte zeigt den Abschnitt mit bis zu 128 Funkstrecken, der das ausgewählte Ergebnis enthält. Berechne die Analyse nach Änderungen an Route, Pilotstandort oder Gelände erneut.';

  @override
  String get commonSynthetischesModellPortaleUnd61794358 =>
      'Synthetisches Modell · Portale und Abmessungen geschätzt. Nur Simulation, keine reale Durchflugfreigabe.';

  @override
  String get commonTakeoffWeightc5470a62 => 'Startgewicht';

  @override
  String get commonTastaturUndFunke92dc0407 => 'Tastatur und Funke';

  @override
  String get commonTerrainChecksSampleAt803435c1 =>
      'Die Geländeprüfung tastet die Route in Abständen von bis zu 50 m ab. Gelände zwischen Messpunkten, der rechtlich maßgebliche Abstand zur nächstgelegenen Erdoberfläche, Höhenlimits der Zonen, Aktivierungszeiten und Ausnahmen werden nicht automatisch geprüft.';

  @override
  String get commonTerrainInformation6e2466e7 => 'Geländeinformationen';

  @override
  String get commonTerrainRadioPathe61f3070 => 'Terrain- & Funkpfad';

  @override
  String commonTerrainSamples1a8cac51(String arg0, String arg1) {
    return '$arg0 / $arg1 Geländeproben';
  }

  @override
  String commonTerrainSamplesAtMost4dfad6d1(String arg0) {
    return '$arg0 Geländeproben, höchstens 50 m auseinander horizontal. Höhen interpolieren linear zwischen den Wegpunkten; AGL gilt bei Wegpunkten und impliziert kein Geländefolgen.';
  }

  @override
  String get commonTerrainSamplesDoNote2bd895f =>
      'Geländehöhen an einzelnen Messpunkten belegen keinen durchgehenden Abstand. Kleine Strukturen zwischen Messpunkten, Fehler im Höhenmodell, Seile, Bäume und andere unbekannte Hindernisse können unentdeckt bleiben. Prüfe die Route vor Ort und anhand aktueller amtlicher Informationen.';

  @override
  String get commonTerrainUsesWgsEllipsoid7e8c1f46 =>
      'Terrain verwendet WGS84 Ellipsoidhöhen. Andere absolute Referenzen bleiben erhalten, können aber noch nicht für die 3D-Ansicht oder Freiraumberechnung konvertiert werden. Ein * Marker zeigt nur eine 30 m AGL-Vorschau.';

  @override
  String get commonTheAstraApiRejectsdfbcd277 =>
      'Die ASTRA API lehnt direkte Browser-Anfragen (CORS) ab, bevor ein Token gesendet werden kann. Verwenden Sie Android zum direkten Aktualisieren oder importieren Sie einen mit Ihrem eigenen registrierten Zugriff heruntergeladenen DATAX XML-Snapshot. Es wird kein öffentlicher Proxy verwendet.';

  @override
  String get commonTheDefaultMAgld0e44124 =>
      'Der voreingestellte Wert von 120 m über Grund dient als Planungsreferenz für die offene Kategorie in der Schweiz. Der eingestellte Wert bestimmt weder die geltenden Vorschriften noch eine Ausnahme oder Bewilligung. Der senkrecht ermittelte Abstand über Grund berücksichtigt an Steilhängen nicht die nächstgelegene Geländeoberfläche.';

  @override
  String get commonTheseArePersonalLimits77b30a8a =>
      'Das sind persönliche Grenzen, keine herstellergenehmigten Windtoleranzen.';

  @override
  String get commonTheseValuesDescribeAa43d2a95 =>
      'Diese Werte beschreiben ein vereinfachtes Planungsmodell. Sie sind nicht für Böen, Manöver, Batteriesack, Temperatur, Batteriealterung oder unbekannte Hindernisse verantwortlich.';

  @override
  String get commonThisReplacesYourCurrentf961d89e =>
      'Dies ersetzt Ihre aktuellen Spots, Geräte, Routen, Bilder, Checklisten, Telemetrie und gesicherte Einstellungen. Wiederherstellungskarteneinstellungen können aktivierte Ebenen wieder verbinden. API-Schlüssel und heruntergeladene Karten/Daten bleiben auf diesem Gerät. Erstellen Sie zuerst eine Sicherung Ihrer aktuellen Daten.';

  @override
  String get commonTmcBeschreibtVorAllem56166f9f =>
      'TMC beschreibt vor allem Hauptverkehrsstraßen. Unbekannte Codes, Versionskonflikte und nicht eindeutige Abschnitte bleiben ohne Einfluss auf die Routenempfehlung.';

  @override
  String get commonToilets610d13f5 => 'Toiletten';

  @override
  String get commonTokenVerwendenNichtToken28179d00 =>
      'Token verwenden, nicht Token Hash.';

  @override
  String get commonTouchSteuerungAusblenden26a72091 =>
      'Touch-Steuerung ausblenden';

  @override
  String get commonTransmitterAntennaCharacteristics19b4fc52 =>
      'Eigenschaften der Senderantenne';

  @override
  String get commonTransmitterAntennaGain38da48c0 =>
      'Verstärkung der Senderantenne';

  @override
  String get commonTransmitterCableConnectorLoss9df9b0dd =>
      'Transmitterkabel / Steckerverlust';

  @override
  String get commonTransmitterPolarization34dcaed8 => 'Transmitterpolarisation';

  @override
  String get commonTunnelStammenAusDema4a6630f =>
      'Tunnel stammen aus dem vorbereiteten Schweizer Offlineindex. Fehlt dieser, sendet die Online-Ersatzsuche den Kartenausschnitt an die Datenquelle. Querschnitt, Portale und Höhen sind nicht vermessen. Nur Simulation, keine reale Durchflugfreigabe.';

  @override
  String get commonType3deb7456 => 'Typ';

  @override
  String get commonUasZonen81937e88 => 'UAS-Zonen';

  @override
  String get commonUberProfilWaehlenOdera22070c5 =>
      'Über „Profil wählen“ oder Einstellungen → Aktivitätsprofile wählst du eine Vorlage, erstellst ein leeres Profil oder überspringst die Auswahl. Vorlagen lassen sich bearbeiten, duplizieren und löschen. Bevorzugte Werkzeuge stehen im Menü zuerst; die Kartenaktionen folgen deinen Schnellaktionen. „Alle Werkzeuge“ öffnet jederzeit den vollständigen Funktionsumfang. Flugrouten und Ausrüstung behalten ihre Bedeutung. Den Fuß- oder Velomodus wählst du im Bereich Bodenrouten; ein Aktivitätsprofil ändert den Routingmodus nicht automatisch.';

  @override
  String get commonUnableToLoadDronecc1e0297 =>
      'Drohnenprofile können nicht geladen werden.';

  @override
  String get commonUnavailable2c9c1f79 => 'Nicht verfügbar';

  @override
  String get commonUnbekanntd0b00a9f => 'Unbekannt';

  @override
  String get commonUnfallfb1a68ca => 'Unfall';

  @override
  String get commonUnknownbc7819b3 => 'Unbekannt';

  @override
  String get commonUnprotectedBackupsContainReadableec1db6d0 =>
      'Ungeschützte Backups enthalten lesbare personenbezogene Daten, einschließlich Koordinaten, Notizen und Bilder.';

  @override
  String get commonUnterEinstellungenNavigationOder48dcba83 =>
      'Unter Einstellungen → Navigation oder Kartendarstellung → 3D-Umgebung lassen sich Gebäude und Vegetation jeweils auf Wie Karte, Aus oder Ein stellen. Die normale Karte und Luftfahrthindernisse behalten eigene Einstellungen. Fehlende Streaming-Daten unterbrechen die Navigation nicht. Die geglättete Anzeige bleibt beim letzten GPS-Punkt stehen; Geschwindigkeit und Routenführung verwenden die ursprünglichen Messwerte.';

  @override
  String get commonUseTheTokenFor892c903f =>
      'Verwenden Sie den Token für den Straßenverkehr - Verkehrssituationen, nicht Token Hash oder OJP.';

  @override
  String get commonVeloba303bca => 'Velo';

  @override
  String get commonVelorouten02063824 => 'Veloruten';

  @override
  String get commonVerkehrsdaten47bcd2e4 => 'Verkehrsdaten';

  @override
  String get commonVeroeffentlichteHindernissedcee0df6 =>
      'Veröffentlichte Hindernisse';

  @override
  String get commonVeroeffentlichungszeitTtlNichtBelegtd74df01f =>
      'Veröffentlichungszeit/TTL nicht belegt. Gemeldete Zustände werden angezeigt, aktuelle Verfügbarkeit bleibt unbekannt.';

  @override
  String get commonVerwerfen24cc57bc => 'Verwerfen';

  @override
  String get commonViewpointse28a6555 => 'Sichtpunkte';

  @override
  String get commonVorDemStartce7119a6 => 'Vor dem Start';

  @override
  String get commonVorbereiteteKartenUndGelaende4e8adf4f =>
      'Vorbereitete Karten und Gelände ersetzen keine Liveinformationen. UAS-, Hindernis- und SLF-Snapshots behalten ihre Quelldaten und Gültigkeit. WMS, Orts-/Straßenbeschriftungen, Streaming-3D und Liveverkehr/Wetter sind nicht als vollständige Offlineebenen enthalten. Fehlende Beschriftungen führen im Nur-Cache-Modus nicht zu einem heimlichen Onlineabruf.';

  @override
  String get commonWaehrendDieNavigationGeoeffnet32560395 =>
      'Während die Navigation geöffnet ist, wird dein Standort laufend genutzt. Bei Routenabweichungen werden Standort und Ziel zur Neuberechnung an FOSSGIS gesendet. Im Hintergrund pausiert die Navigation.';

  @override
  String get commonWanderVeloMountainbikeUnd0dc3c854 =>
      'Wander-, Velo-, Mountainbike- und Winterrouten sind veröffentlichte Netze. Legenden erklären die jeweiligen Kategorien; ohne entsprechende Quelldaten wird keine Schwierigkeit berechnet. Diese Online-Kartenebenen sind von deinen gespeicherten Boden- und Flugrouten getrennt. Kartenstand, Öffnung und aktuelle Bedingungen sind eigenständig zu prüfen.';

  @override
  String get commonWanderwege93acd7ea => 'Wanderwege';

  @override
  String get commonWarnings1430f976 => 'Warnungen';

  @override
  String get commonWarnungZellspannungV6655c81c => 'Warnung Zellspannung (V)';

  @override
  String get commonWasFehltb7799bca => 'Was ist los?';

  @override
  String get commonWeatherForecastsArePlanning5820a8ab =>
      'Wettervorhersagen sind Planungshilfen, keine Echtzeitflugsicherheit oder gesetzliche Genehmigung.';

  @override
  String get commonWegenetzeNaturUndSperrungen0e7d404e =>
      'Wegenetze, Natur und Sperrungen';

  @override
  String get commonWeiterBearbeitencc234070 => 'Weiter bearbeiten';

  @override
  String get commonWeitereMeldung12efe38b => 'Weitere Meldung';

  @override
  String get commonWetterUndDWindd3dd8c5c => 'Wetter und 3D-Wind';

  @override
  String get commonWetterUndGewaessermessstationendac59859 =>
      'Wetter- und Gewässermessstationen';

  @override
  String get commonWetterrasterb939701a => 'Wetterraster';

  @override
  String get commonWgsBreiteLaengeIna66287c0 =>
      'WGS84: Breite, Länge in Dezimalgrad, z. B. 46.7, 8.4. LV95: Ost / Nord, z. B. 2600000 / 1200000. Die lokale LV95-Umrechnung ist eine Näherung für Orientierung, keine Vermessung. Eine Orts- oder Adresssuche benötigt dagegen eine Verbindung.';

  @override
  String get commonWgsEllipsoidSchweizerLnc6e2dc07 =>
      'WGS84-Ellipsoid, Schweizer LN02 und Höhe über Gelände (AGL) sind unterschiedliche Bezüge. AGL bezieht sich auf das Gelände am jeweiligen Punkt, die Starthöhe auf den Startpunkt. Unbekannte Quellenbezüge bleiben unbekannt. Ein flacher Ersatzglobe liefert keine gemessene Geländehöhe.';

  @override
  String get commonWiderstandBeiHoechsttempoM510bfda4 =>
      'Widerstand bei Höchsttempo (m/s²)';

  @override
  String get commonWildruhezonen6d338347 => 'Wildruhezonen';

  @override
  String get commonWildruhezonenKoennenRechtsverbindlichOder5ba8618e =>
      'Wildruhezonen können rechtsverbindlich oder empfohlen sein. Schutzzeiten, örtliche Bestimmungen und zulässige Wege stehen in den offiziellen Details. Der räumliche Detailabruf ist ein begrenzter Auszug; fehlende kantonale Informationen oder fehlende Treffer bestätigen keine Zugänglichkeit. Sperrungen und Umleitungen haben eigene Gültigkeitsangaben. Eine Schutzfläche ist keine pauschale luftrechtliche Einstufung.';

  @override
  String get commonWindFunk4ce9bd21 => 'Wind & Funk';

  @override
  String get commonWindLegendMS1b571bdc =>
      'Windlegende (m/s): grün <3, gelb 3–7, orange 7–12, rot ≥12.';

  @override
  String get commonWinterwanderwege815871de => 'Winterwanderwege';

  @override
  String get commonWitterung98e69f2f => 'Witterung';

  @override
  String get commonYawMaximalS71fd433b => 'Yaw maximal (°/s)';

  @override
  String get commonYes5397e058 => 'Ja';

  @override
  String get commonZeitangabenb06eb18b => 'Zeitangaben';

  @override
  String get commonZuFussda918eb3 => 'Zu Fuß';

  @override
  String get commonZugaengec08f0ef3 => 'Zugänge';

  @override
  String get commonZurKarte4814658b => 'Zur Karte';

  @override
  String get commonZurueck40806243 => 'Zurück';

  @override
  String get commonZusaetzlicherSchubMS337bc8ea => 'Zusätzlicher Schub (m/s²)';

  @override
  String get commonZustaende1b49baf7 => 'Zustände';

  @override
  String get datamanagementAForgottenPasswordCannot76d00a6a =>
      'Ein vergessenes Passwort kann nicht wiederhergestellt werden.';

  @override
  String datamanagementBackupFrome163c3fa(String arg0) {
    return 'Sicherung von $arg0';
  }

  @override
  String get datamanagementBackupPasswordd96a6076 => 'Sicherungspasswort';

  @override
  String get datamanagementCreateBackup60e77f3b => 'Backup erstellen';

  @override
  String get datamanagementOfflinePersonalDatae0f55e89 =>
      'Offline & persönliche Daten';

  @override
  String get datamanagementPassword8be3c943 => 'Passwort';

  @override
  String get datamanagementPasswordAtLeastCharacters518d1ae0 =>
      'Passwort (mindestens 12 Zeichen)';

  @override
  String get datamanagementPortableBackups13832bb9 => 'Tragbare Sicherungen';

  @override
  String get datamanagementProtectBackupWithAf8add733 =>
      'Sicherung mit einem Passwort schützen';

  @override
  String get datamanagementRepeatPassword366c2415 => 'Passwort wiederholen';

  @override
  String get datamanagementReplaceAndRestoreee68c046 =>
      'Ersetzen und wiederherstellen';

  @override
  String get datamanagementReplacePersonalData946d9c54 =>
      'Persönliche Daten ersetzen?';

  @override
  String get datamanagementRestoreBackupa65eaa88 =>
      'Sicherung wiederherstellen';

  @override
  String get datamanagementTheMapCachePreference010bed10 =>
      'Die Karten-Cache-Einstellung konnte nicht gespeichert werden.';

  @override
  String get dronesAddDroneProfile9af5c042 => 'Drohnenprofil hinzufügen';

  @override
  String get dronesAddDroned971a88b => 'Drohne hinzufügen';

  @override
  String get dronesDeleteDroneProfilec10d6154 => 'Drohnenprofil löschen?';

  @override
  String get dronesDeleteProfile7035d2d9 => 'Profil löschen';

  @override
  String get dronesDroneProfile1ca23ee8 => 'Drohnenprofil';

  @override
  String get dronesDroneProfilesb57e7452 => 'Drohnenprofile';

  @override
  String get dronesEditDroneProfilefc4f435a => 'Drohnenprofil bearbeiten';

  @override
  String get dronesEditProfile15141eab => 'Profil bearbeiten';

  @override
  String get dronesNoDroneProfilesSavedca393a7c =>
      'Noch keine Drohnenprofile gespeichert. Fügen Sie ein Profil hinzu, um Ihre Ausrüstung aufzuzeichnen.';

  @override
  String get dronesNoNumericParametersRecorded530d76ed =>
      'Keine numerischen Parameter aufgezeichnet.';

  @override
  String dronesPermanentlyDeleteFlightPlansc2a19a5b(String arg0) {
    return 'Löschen Sie dauerhaft \"$arg0\"? Flugpläne werden ohne diese Drohnenzuweisung gehalten.';
  }

  @override
  String dronesSource0ef9cdaf(String arg0) {
    return '$arg0 Quelle';
  }

  @override
  String get dronesThisDroneProfileNob7ffc857 =>
      'Dieses Drohnenprofil existiert nicht mehr.';

  @override
  String get dronesUnableToLoadThis20f0daab =>
      'Dieses Drohnenprofil kann nicht geladen werden.';

  @override
  String globeAbfrageFehlgeschlagene25d055d(String arg0) {
    return 'Abfrage fehlgeschlagen: $arg0';
  }

  @override
  String get globeAktuellesGpsSignal291591fd => 'Aktuelles GPS-Signal';

  @override
  String get globeAllgemeineEinstellungen6f965a12 => 'Allgemeine Einstellungen';

  @override
  String get globeAmslIsHeightAbove8e48a714 =>
      'AMSL ist Höhe über dem mittleren Meeresspiegel. Die Schweizer Nationalkartenhöhen verwenden LN02; LHN95 ist ein separates Höhendatum.';

  @override
  String get globeAmslSwissLnNot9423d99b =>
      'AMSL (Schweizerische LN02): nicht konvertiert';

  @override
  String get globeAmtlicheQuellenSicherheit68a6f080 =>
      'Amtliche Quellen & Sicherheit';

  @override
  String get globeApproximateConversionSwisstopoFormulase7bb7ac3 =>
      'Ungefähre Umrechnung (Swisstopo-Formel)';

  @override
  String get globeAufStandortZentrierene8973c1b => 'Auf Standort zentrieren';

  @override
  String get globeAusAchseDGewoelbe0d1ef125 =>
      'Aus Achse 3D-Gewölbe simulieren';

  @override
  String get globeAusBeleuchtungDerKarte53fe9a28 =>
      'Aus: Beleuchtung der Karte verwenden.';

  @override
  String get globeAusgewaehltesBauwerke74d05ef => 'Ausgewähltes Bauwerk';

  @override
  String globeAutomatischDargestellteSchematischeTunnel4dea34ff(
    String arg0,
    String arg1,
  ) {
    return 'Automatisch dargestellte schematische Tunnel: $arg0 von maximal $arg1 (Grafikprofil).';
  }

  @override
  String get globeBeschriftungenErneutLaden53e7b713 =>
      'Beschriftungen erneut laden';

  @override
  String get globeBeschriftungenOfflineNichtVerfuegbar79eca86d =>
      'Beschriftungen offline nicht verfügbar.';

  @override
  String get globeBeschriftungenTeilweiseVerfuegbar5ada98f5 =>
      'Beschriftungen teilweise verfügbar.';

  @override
  String get globeBeschriftungenWerdenGeladenb8c71bdb =>
      'Beschriftungen werden geladen …';

  @override
  String globeBringForwardcf73f6a1(String arg0) {
    return '$arg0 vorwärts bringen';
  }

  @override
  String get globeCancelSpawn701b7923 => 'Start abbrechen';

  @override
  String get globeClearUasDatasetCacheaad7bb57 =>
      'Zwischenspeicher für UAS-Daten leeren';

  @override
  String get globeConvertToSwissHeight5c83b28a =>
      'Schweizer Höhe (LN02) umrechnen';

  @override
  String get globeConvertedWithSwisstopoReframe07d146f4 =>
      'Konvertiert mit swisstopo REFRAME';

  @override
  String get globeConverting3985de51 => 'Umwandeln..';

  @override
  String globeDAktionFehlgeschlagen11f40ae7(String arg0) {
    return '3D-Aktion fehlgeschlagen: $arg0';
  }

  @override
  String get globeDDatenDerzeitNichtec1d811a =>
      '3D-Daten derzeit nicht verfügbar.';

  @override
  String get globeDDatenOfflineNicht0512f9fe =>
      '3D-Daten offline nicht vollständig verfügbar.';

  @override
  String get globeDGewoelbetunnelErzeugenSynthetischcf487df5 =>
      '3D-Gewölbetunnel erzeugen (synthetisch)';

  @override
  String get globeDLicht8b58e045 => '3D & Licht';

  @override
  String get globeDModellkollisionenExperimentell6ac94586 =>
      '3D-Modellkollisionen (experimentell)';

  @override
  String get globeDTunnelAutomatischLadena71b41bc =>
      '3D-Tunnel automatisch laden';

  @override
  String get globeDTunnelEntfernenc327e7fe => '3D-Tunnel entfernen';

  @override
  String globeDTunnele1017c1e(String arg0) {
    return '3D-Tunnel: $arg0';
  }

  @override
  String get globeDatenQuellen0b5b5779 => 'Daten & Quellen';

  @override
  String get globeDatenstand0ce51d29 => 'Datenstand';

  @override
  String get globeDatumUndUhrzeit6b922369 => 'Datum und Uhrzeit';

  @override
  String get globeDeckkraft3c11c68b => 'Deckkraft';

  @override
  String globeDurchfluge383d59a(String arg0) {
    return 'Durchflug: $arg0';
  }

  @override
  String globeEastingM080f8cea(String arg0) {
    return 'Ostwert: $arg0 m';
  }

  @override
  String get globeEigeneSonnenUndMondzeit785565c8 =>
      'Eigene Sonnen- und Mondzeit';

  @override
  String get globeEinigeDKachelnFehlenbf4b88d2 =>
      'Einige 3D-Kacheln fehlen. Geladene Modelle bleiben sichtbar.';

  @override
  String get globeErneutLaden9c56689e => 'Erneut laden';

  @override
  String globeFahrtrichtung8ce70d3a(String arg0) {
    return 'Fahrtrichtung: $arg0°';
  }

  @override
  String get globeFailedToLoadDd6e93076 =>
      '3D-Globus konnte nicht geladen werden';

  @override
  String get globeFuerBeschriftungenNaeherHeranzoomen6f64dcb5 =>
      'Für Beschriftungen näher heranzoomen.';

  @override
  String globeGenauigkeitM4e998940(String arg0) {
    return 'Genauigkeit: ±$arg0 m';
  }

  @override
  String get globeGespeicherteSpots4f634531 => 'Gespeicherte Spots';

  @override
  String get globeGroundElevation5d588142 => 'Geländehöhe';

  @override
  String globeGroundViewb1f80610(String arg0) {
    return 'Grundansicht: $arg0';
  }

  @override
  String get globeHeightAboveLocalGround8c1c0da0 =>
      'Höhe über dem Gelände (AGL)';

  @override
  String get globeHeightAboveTerrainAglcbf70384 => 'Höhe über Gelände (AGL)';

  @override
  String get globeHeightAtThisAglfbdc9bdd => 'Höhe bei diesem AGL-Wert';

  @override
  String get globeHindernissed58845a0 => 'Hindernisse';

  @override
  String get globeImportiertesMeshHerkunftUnd538c26a9 =>
      'Importiertes Mesh · Herkunft und Höhenbezug nicht unabhängig geprüft. Geländeöffnung erforderlich.';

  @override
  String get globeImportiertesModellHerkunftUnd950bcbe2 =>
      'Importiertes Modell · Herkunft und Lichtraum ungeprüft. Keine reale Durchflugfreigabe.';

  @override
  String get globeJetzt6b627c53 => 'Jetzt';

  @override
  String get globeKarteb1636a3d => 'Karte';

  @override
  String get globeKarteinstellungenZuruecksetzen3bd1cc02 =>
      'Karteinstellungen zurücksetzen';

  @override
  String get globeKartenbewegungBeendetDieVerfolgung00211415 =>
      'Kartenbewegung beendet die Verfolgung. Online-Karten können beim Zentrieren und Folgen den Standortbereich erkennen lassen.';

  @override
  String get globeKarteneinstellungenWerdenGeladen349c7e7f =>
      'Karteneinstellungen werden geladen …';

  @override
  String get globeKeineImLokalenIndex7a2d66ae =>
      'Keine im lokalen Index erfassten Tunnel im Kartenausschnitt. Datenabdeckung möglicherweise unvollständig.';

  @override
  String get globeLetzterBekannterStandortVeraltet04a9e861 =>
      'Letzter bekannter Standort · veraltet';

  @override
  String get globeLetzterStandortErneutOrten9afe561d =>
      'Letzter Standort · erneut orten';

  @override
  String get globeLoadingZoneDatacd4362a5 => 'Zonendaten werden geladen...';

  @override
  String get globeLocalLibrary1c67cdf4 => 'Lokale Bibliothek';

  @override
  String get globeLuftraum0992aecb => 'Luftraum';

  @override
  String get globeLvConversionUnavailableOutsidedecfa6d5 =>
      'LV95-Konversion außerhalb der unterstützten Schweizer Region nicht verfügbar.';

  @override
  String globeMapLayerError65930212(String arg0) {
    return 'Kartenlayer-Fehler: $arg0';
  }

  @override
  String get globeMeinStandortLangeDrueckend4c6bff6 =>
      'Mein Standort · lange drücken für Optionen';

  @override
  String globeModellquelle05ae7da1(String arg0) {
    return 'Modellquelle: $arg0';
  }

  @override
  String get globeNativeDGlobeIsf8235971 =>
      'Native 3D globe wird derzeit auf Android und iOS unterstützt.';

  @override
  String get globeNeueBeschriftungenKonntenNicht08732593 =>
      'Neue Beschriftungen konnten nicht geladen werden.';

  @override
  String globeNichtModellierbareTunnelabschnitteVon25d903e4(
    String arg0,
    String arg1,
  ) {
    return 'Nicht modellierbare Tunnelabschnitte: $arg0 von $arg1 erfassten Achsen.';
  }

  @override
  String get globeNochKeineTunnelGefundenbdf89230 =>
      'Noch keine Tunnel gefunden.';

  @override
  String globeNorthingMc882004d(String arg0) {
    return 'Nordwert: $arg0 m';
  }

  @override
  String get globeNurSchweizUndLiechtenstein1516f8d3 =>
      'Nur Schweiz und Liechtenstein.';

  @override
  String get globeOnlineConversionSendsThis9f4e31f3 =>
      'Die Online-Umrechnung sendet diese Position und Geländehöhe an swisstopo.';

  @override
  String get globeOriginaldatenKeineDurchflugfreigabeb2bc03bb =>
      'Originaldaten · keine Durchflugfreigabe.';

  @override
  String get globeOrtsUndStrassennamenbe90f8a3 => 'Orts- und Straßennamen';

  @override
  String globePolygonFillOpacityd148d398(String arg0) {
    return 'Deckkraft der Flächenfüllung: $arg0 %';
  }

  @override
  String globeQuellkennung050247aa(String arg0) {
    return 'Quellkennung: $arg0';
  }

  @override
  String get globeRefreshUasData3aea6b96 => 'UAS-Daten aktualisieren';

  @override
  String get globeReihenfolgeDerEbenenf736c2db => 'Reihenfolge der Ebenen';

  @override
  String get globeRetryTerraine3f14f82 => 'Gelände erneut laden';

  @override
  String get globeReturnToGlobe687364e5 => 'Zurück zum 3D-Globus';

  @override
  String globeSamplinga7cf9539(String arg0) {
    return 'Höhenabfrage: $arg0';
  }

  @override
  String get globeSatellited1ffec93 => 'Satellit';

  @override
  String get globeSavedSpotsf65c2504 => 'Gespeicherte Stellen';

  @override
  String globeSichtdreieckeKollisionsdreiecke2eeb74c5(
    String arg0,
    String arg1,
  ) {
    return 'Sichtdreiecke: $arg0 · Kollisionsdreiecke: $arg1';
  }

  @override
  String globeSignalzeiteb1b8546(String arg0) {
    return 'Signalzeit: $arg0';
  }

  @override
  String get globeSimulationOnlineErsatzsucheSendet67c4c630 =>
      'Simulation · Online-Ersatzsuche sendet Kartenausschnitt.';

  @override
  String get globeSonnenUndMondlichtc6291e64 => 'Sonnen- und Mondlicht';

  @override
  String get globeSpawnHeref28d3450 => 'Hier starten';

  @override
  String get globeStandortAnzeigenca6f8a53 => 'Standort anzeigen';

  @override
  String get globeStandortVerfolgen14ee16f9 => 'Standort verfolgen';

  @override
  String get globeStandortWirdGesucht33b02f57 => 'Standort wird gesucht';

  @override
  String get globeStrassenLayerErneutLadenfb527544 =>
      'Straßen-Layer erneut laden';

  @override
  String get globeSwissCoordinatesLvb62ba2b6 => 'Schweizer Koordinaten (LV95)';

  @override
  String get globeSwissHeightConversionIsae058df0 =>
      'Die Schweizer Höhenumwandlung ist an dieser Stelle oder für diese Referenz nicht verfügbar.';

  @override
  String get globeTagUndNachtNach5c260567 => 'Tag und Nacht nach Gerätezeit.';

  @override
  String globeTerrainAussparungenWeitereSichtbaree67506d9(String arg0) {
    return 'Terrain-Aussparungen: $arg0. Weitere sichtbare Röhren sind ggf. vom Gelände verdeckt.';
  }

  @override
  String get globeTerrainInformation1a166cb2 => 'Geländeinformationen';

  @override
  String get globeTopo7416e691 => 'Topo';

  @override
  String globeTunnelDatenquellee8c8f0f5(String arg0) {
    return 'Tunnel-Datenquelle: $arg0';
  }

  @override
  String globeTunnelGeladen76365023(String arg0, String arg1) {
    return '$arg0 / $arg1 Tunnel geladen';
  }

  @override
  String get globeTunnelInDerNaehe75bf7c66 => 'Tunnel in der Nähe suchen';

  @override
  String get globeTunnelabdeckungUnvollstaendigcfa66c0f =>
      'Tunnelabdeckung unvollständig.';

  @override
  String get globeTunnelachsenDerzeitOfflineNicht2a3ab99c =>
      'Tunnelachsen derzeit offline nicht verfügbar.';

  @override
  String globeTunnelachsenGefundenAbdeckungUnvollstaendigdabfec20(String arg0) {
    return '$arg0 Tunnelachsen gefunden; Abdeckung unvollständig.';
  }

  @override
  String globeTunnelachsenImKartenausschnittGefundenbbd7f549(String arg0) {
    return '$arg0 Tunnelachsen im Kartenausschnitt gefunden (schematisch).';
  }

  @override
  String get globeTunnelachsenNurBeiBodennaherab983e29 =>
      'Tunnelachsen nur bei bodennaher Schweizer Kartenansicht automatisch laden.';

  @override
  String get globeTunnelachsenWerdenAutomatischFuer8bbff5f7 =>
      'Tunnelachsen werden automatisch für den nahen sichtbaren Kartenausschnitt gesucht.';

  @override
  String get globeTunnelaktionenc0d41bdb => 'Tunnelaktionen';

  @override
  String get globeTunnelindexKonnteNichtGeladen03a91e8e =>
      'Tunnelindex konnte nicht geladen werden. Quelle und Build-Daten prüfen.';

  @override
  String get globeTunnelmodellImportierenJson8ffcf7c7 =>
      'Tunnelmodell importieren (JSON)';

  @override
  String get globeTunnelstatusDatend6e42b7d => 'Tunnelstatus & Daten';

  @override
  String get globeTunnelwerkzeuge9873b3ba => 'Tunnelwerkzeuge';

  @override
  String get globeUnableToReconnectTo7f563fb8 =>
      'Es ist nicht möglich, sich wieder mit dem Gelände zu verbinden.';

  @override
  String get globeUnableToUpdateMap7af0a9ee =>
      'Karteneinstellungen können nicht aktualisiert werden. Bitte wiederholen.';

  @override
  String get globeUnableToUpdateMapefb1235c =>
      'Kartenansicht konnte nicht aktualisiert werden. Bitte erneut versuchen.';

  @override
  String get globeVorneNachHinten4d9d3fd7 => 'Vorne nach hinten';

  @override
  String get globeWeitereDatenebenenUnterMobilitaetd36898b1 =>
      'Weitere Datenebenen unter Mobilität & OSINT laden.';

  @override
  String get globeWeitereEinschraenkungenMoeglichVor9c93ae78 =>
      'Weitere Einschränkungen möglich. Vor dem Flug amtliche Quellen prüfen.';

  @override
  String globeWgsLatituded60b5fd1(String arg0) {
    return 'WGS84 Breite: $arg0°';
  }

  @override
  String globeWgsLongitudece917f86(String arg0) {
    return 'WGS84 Länge: $arg0°';
  }

  @override
  String get globeZumErstenAchsenpunkt95f01d68 => 'Zum ersten Achsenpunkt';

  @override
  String get globeZumLetztenAchsenpunkt5cbcd957 => 'Zum letzten Achsenpunkt';

  @override
  String get groundroutesAnderungenSpeichern00fe8153 => 'Änderungen speichern';

  @override
  String groundroutesAngezeigteRouteeceb9858(String arg0) {
    return 'Angezeigte Route: $arg0';
  }

  @override
  String get groundroutesAufGlobeAnzeigenb40c4518 => 'Auf Globe anzeigen';

  @override
  String get groundroutesBodenrouteBerechnena780689a => 'Bodenroute berechnen';

  @override
  String get groundroutesBodenrouteLoeschen3c5c9ab7 => 'Bodenroute löschen';

  @override
  String get groundroutesBodenrouteSpeichern5b0ba694 => 'Bodenroute speichern';

  @override
  String groundroutesBodenroutenGespeichert7c176a33(String arg0) {
    return '$arg0 Bodenrouten gespeichert';
  }

  @override
  String get groundroutesDieAngezeigteRouteGehoert7159dcb8 =>
      'Die angezeigte Route gehört zu den vorherigen Eingaben. Für die neuen Eingaben erneut berechnen.';

  @override
  String get groundroutesGespeicherteBodenroutenKonntenNicht88267d75 =>
      'Gespeicherte Bodenrouten konnten nicht geladen werden.';

  @override
  String get groundroutesGespeicherteBodenroutenSuchenf43e3c82 =>
      'Gespeicherte Bodenrouten suchen';

  @override
  String get groundroutesGespeichertenOrtAuswaehlenf23d82e2 =>
      'Gespeicherten Ort auswählen';

  @override
  String get groundroutesGewaehltenKartenpunktUebernehmen1c0caa9a =>
      'Gewählten Kartenpunkt übernehmen';

  @override
  String get groundroutesGpxBodenroutenImportierenbc579b06 =>
      'GPX-Bodenrouten importieren?';

  @override
  String get groundroutesGpxImportieren08a786c6 => 'GPX importieren';

  @override
  String get groundroutesKartenvorschauAusblenden048fe407 =>
      'Kartenvorschau ausblenden';

  @override
  String get groundroutesKeineGespeichertenBodenroutenGefunden7adb49f7 =>
      'Keine gespeicherten Bodenrouten gefunden';

  @override
  String groundroutesLoeschen42c1810b(String arg0) {
    return '„$arg0“ löschen?';
  }

  @override
  String groundroutesLokalGespeichertdafc6ec0(String arg0) {
    return '$arg0 · lokal gespeichert';
  }

  @override
  String get groundroutesLokalGespeicherteBodenrouten5824582d =>
      'Lokal gespeicherte Bodenrouten';

  @override
  String get groundroutesMessstationenEntlangDerRouted9e511cf =>
      'Messstationen entlang der Route';

  @override
  String get groundroutesNameDerBodenroute997555dc => 'Name der Bodenroute';

  @override
  String get groundroutesNeueRoutec6a2c583 => 'Neue Route';

  @override
  String groundroutesOberflaecheZugangHoehen28c32a79(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Oberfläche: $arg0 · Zugang: $arg1\nHöhen: $arg2';
  }

  @override
  String get groundroutesOvAnreiseZumBodenrouten39acd10e =>
      'ÖV-Anreise zum Bodenrouten-Start planen';

  @override
  String get groundroutesPassendesFussOderVeloprofilc351a9b0 =>
      'Passendes Fuß- oder Veloprofil · OpenStreetMap-Grundlage';

  @override
  String groundroutesPunkte525d4984(String arg0, String arg1, String arg2) {
    return '$arg0 · $arg1 · $arg2 Punkte';
  }

  @override
  String groundroutesPunkte9b66050f(String arg0, String arg1, String arg2) {
    return '$arg0 Punkte · $arg1 · $arg2';
  }

  @override
  String groundroutesQuelleBerechnet7150764e(String arg0, String arg1) {
    return 'Quelle: $arg0\nBerechnet: $arg1';
  }

  @override
  String get groundroutesRoutenmodusAusdruecklichWaehlen420b0d52 =>
      'Routenmodus ausdrücklich wählen';

  @override
  String get groundroutesSperrungenImRoutenumfeld41a77f10 =>
      'Sperrungen im Routenumfeld';

  @override
  String get groundroutesStartUndZielZur5a6b9fef =>
      'Start und Ziel zur Berechnung an FOSSGIS / OSRM senden';

  @override
  String get groundroutesStartWaehlendb986579 => 'Start wählen';

  @override
  String get groundroutesTrefferAngezeigtBitteDiefb7ecafc =>
      '500 Treffer angezeigt. Bitte die Suche eingrenzen.';

  @override
  String get groundroutesUngespeichertenEntwurfVerlassenff7b8bc6 =>
      'Ungespeicherten Entwurf verlassen?';

  @override
  String get groundroutesWeitereBodenroutenAnzeigen6060cffc =>
      'Weitere Bodenrouten anzeigen';

  @override
  String get groundroutesZielWaehlenaaa64252 => 'Ziel wählen';

  @override
  String get helpGuidesUndHilfeecbecc1f => 'Guides und Hilfe';

  @override
  String helpKurzhilfec825661f(String arg0) {
    return 'Kurzhilfe: $arg0';
  }

  @override
  String get homeAkkusa10fdf22 => 'Akkus';

  @override
  String homeAktivitaetsprofilfef983f3(String arg0) {
    return 'Aktivitätsprofil: $arg0';
  }

  @override
  String get homeAlleKartenebenenc5387977 => 'Alle Kartenebenen';

  @override
  String get homeAlleWerkzeuge80af8bd2 => 'Alle Werkzeuge';

  @override
  String get homeArbeitsbereichGewechseltKartenstartwerteFolgen74793f38 =>
      'Arbeitsbereich gewechselt. Kartenstartwerte folgen nach der laufenden Ansicht.';

  @override
  String get homeArbeitsbereichb5371daf => 'Arbeitsbereich';

  @override
  String get homeAusruestung67d2d167 => 'Ausrüstung';

  @override
  String get homeBevorzugteEbenen39447c21 => 'Bevorzugte Ebenen';

  @override
  String get homeCancelRouteReplayPreparationb6a2fd00 =>
      'Routenreplay-Vorbereitung abbrechen';

  @override
  String get homeCheckAirspace81aa4af7 => 'Luftraum überprüfen';

  @override
  String get homeCloseMapStatusbaaf9b31 => 'Kartenstatus schließen';

  @override
  String get homeCloseSpotDetailsb8c47dc2 => 'Details zum Spot schließen';

  @override
  String get homeDGlobeReady1847f54f => '3D-Globus bereit';

  @override
  String get homeDetailsdc3decbb => 'Details';

  @override
  String get homeDrohnen1cb44d64 => 'Drohnen';

  @override
  String get homeEinstellungen3e5af3d1 => 'Einstellungen';

  @override
  String get homeFlatMapTerrainHeightsd993a5d7 =>
      'Flachkarte — Geländehöhen nicht verfügbar';

  @override
  String get homeFlugvorbereitungfc3259ae => 'Flugvorbereitung';

  @override
  String get homeFlyToSpot253cde4f => 'Zum Spot fliegen';

  @override
  String get homeFunkVideo955c11e1 => 'Funk & Video';

  @override
  String get homeGespeicherteOrte681d182b => 'Gespeicherte Orte';

  @override
  String get homeKarteUndAktivitaetena2cfdeff => 'Karte und Aktivitäten';

  @override
  String get homeKartenaktionen61a84371 => 'Kartenaktionen';

  @override
  String get homeKartenstartwerteKonntenNichtUebernommen8dd81e2c =>
      'Kartenstartwerte konnten nicht übernommen werden.';

  @override
  String get homeLoadingGlobe79eb5f94 => 'Globe wird geladen...';

  @override
  String homeMapError05472eae(String arg0) {
    return 'Kartenfehler: $arg0';
  }

  @override
  String get homeMapStatus5f4e7ac0 => 'Kartenstatus';

  @override
  String get homeMenueSchliessen82332f74 => 'Menü schließen';

  @override
  String get homeMoreSpotActionsec926581 => 'Mehr Spotaktionen';

  @override
  String get homeNoMapDataWarnings4f085b42 => 'Keine Kartendatenwarnungen';

  @override
  String get homeOfflineDaten07b28abe => 'Offline & Daten';

  @override
  String get homeOpenNavigationMenu5f83b0b6 => 'Navigationsmenü öffnen';

  @override
  String get homePlanenEntdecken9b5160ec => 'Planen & Entdecken';

  @override
  String get homeProfilWaehlencae393b1 => 'Profil wählen';

  @override
  String homeSpotMarkerSyncFailed5c7dee42(String arg0) {
    return 'Spotmarker-Synchronisation fehlgeschlagen: $arg0';
  }

  @override
  String get homeSuchen20a96919 => 'Suchen';

  @override
  String homeTerrainQueryFailed53f78995(String arg0) {
    return 'Terrain-Abfrage fehlgeschlagen: $arg0';
  }

  @override
  String homeUnableToLoadStored9e66c17d(String arg0) {
    return 'Die gespeicherten Spots können nicht geladen werden: $arg0';
  }

  @override
  String get homeWetter72a9fa32 => 'Wetter';

  @override
  String get mobilityAbdeckungUndZusaetzlicheVerkehrsdatenca67bb5b =>
      'Abdeckung und zusätzliche Verkehrsdaten';

  @override
  String mobilityAbdeckungWgsc9cd562f(String arg0) {
    return 'Abdeckung (WGS84): $arg0';
  }

  @override
  String get mobilityAbfahrt3cca3329 => 'Abfahrt';

  @override
  String get mobilityAbfrageBegrenztWeitereOder5efa5f1a =>
      'Abfrage begrenzt. Weitere oder überlappende Regeln möglich.';

  @override
  String mobilityAbgerufenAma792bdd8(String arg0, String arg1, String arg2) {
    return 'Abgerufen am $arg0 · $arg1 → $arg2';
  }

  @override
  String mobilityAbgerufenUtc47bb4052(String arg0, String arg1, String arg2) {
    return 'Abgerufen: $arg0 (UTC)$arg1$arg2';
  }

  @override
  String mobilityAbrufQuellenpublikation2c701097(String arg0, String arg1) {
    return 'Abruf: $arg0 · Quellenpublikation: $arg1';
  }

  @override
  String get mobilityAbrufVeraltetErneutAktualisieren5ed4d00d =>
      'Abruf veraltet · erneut aktualisieren';

  @override
  String get mobilityAbrufVeraltetOderFehlgeschlagen4afc83f7 =>
      'Abruf veraltet oder fehlgeschlagen · Messzeit jedes Werts prüfen.';

  @override
  String get mobilityAdresseOderOrtInfa9d68ac =>
      'Adresse oder Ort in der Schweiz';

  @override
  String get mobilityAktiverOjpApiPlan5dce0b6f =>
      'Aktiver OJP-API-Plan (Sitzung)';

  @override
  String get mobilityAktualisieren87c65f26 => 'Aktualisieren';

  @override
  String get mobilityAktualisierungFehlgeschlagenAlteStandortdatenb2f09fc6 =>
      'Aktualisierung fehlgeschlagen: alte Standortdaten; Verfügbarkeit unbekannt.';

  @override
  String get mobilityAktualisierungFehlgeschlagenLetzterDatenstand97d6ca24 =>
      'Aktualisierung fehlgeschlagen · letzter Datenstand bleibt sichtbar';

  @override
  String get mobilityAktualisierungFehlgeschlagenVorhandenerStand6dbee97c =>
      'Aktualisierung fehlgeschlagen: vorhandener Stand bleibt erhalten.';

  @override
  String get mobilityAktualisierungFehlgeschlagenVorherigerStand6cb8348b =>
      'Aktualisierung fehlgeschlagen; vorheriger Stand wird beibehalten.';

  @override
  String get mobilityAktualitaetNichtBestaetigtAngaben58f3aa99 =>
      'Aktualität nicht bestätigt – Angaben können überholt sein. Lokale Anordnungen prüfen.';

  @override
  String get mobilityAktuelleAmtlicheMassnahmen1078b943 =>
      'Aktuelle amtliche Massnahmen';

  @override
  String get mobilityAktuelleMeldungenAufKarte65e8ab99 =>
      'Aktuelle Meldungen auf Karte zeigen';

  @override
  String get mobilityAlleAnbieter9c59c226 => 'Alle Anbieter';

  @override
  String get mobilityAlleAngebote766cc617 => 'Alle Angebote';

  @override
  String get mobilityAlleEreignistypenf0956deb => 'Alle Ereignistypen';

  @override
  String get mobilityAlleFahrzeugtypenc3d9470c => 'Alle Fahrzeugtypen';

  @override
  String get mobilityAlleSekundenWaehrendDer0476b439 =>
      'Alle 60 Sekunden während der aktiven Navigation';

  @override
  String get mobilityAllowSendingStartAnde6a35229 =>
      'Senden von Start und Ziel an FOSSGIS / OpenStreetMap Routing zulassen.';

  @override
  String get mobilityAllowSendingThisAread1710796 =>
      'Lassen Sie dieses Bereichszentrum an adsb.lol senden.';

  @override
  String get mobilityAlsFahrzielWaehlen89ab104c => 'Als Fahrziel wählen';

  @override
  String get mobilityAmtlicheCollectiond0ebbd40 => 'Amtliche Sammlung';

  @override
  String get mobilityAmtlicheLegendeProduktinformation73ec6293 =>
      'Amtliche Legende / Produktinformation';

  @override
  String get mobilityAmtlicheMassnahmenAbfragen08c2e83d =>
      'Amtliche Massnahmen abfragen';

  @override
  String get mobilityAmtlicheQuelleAnsicht283a8bdd =>
      'Amtliche Quelle / Ansicht';

  @override
  String mobilityAmtlicherTitelf2b2a993(String arg0) {
    return 'Amtlicher Titel: $arg0';
  }

  @override
  String get mobilityAnbieterOeffnenKeineReservierung97c86374 =>
      'Anbieter öffnen (keine Reservierung)';

  @override
  String get mobilityAnbieterd062d4fe => 'Anbieter';

  @override
  String get mobilityAnfragebudgetGiltNurFuer8bf6ad74 =>
      'Anfragebudget gilt nur für diese App-Sitzung. Die offiziellen Quoten gelten gemeinsam für alle Geräte mit demselben Schlüssel; HTTP 429 wird respektiert.';

  @override
  String get mobilityAngebotsart3d303646 => 'Angebotsart';

  @override
  String get mobilityAnkunft0b4333da => 'Ankunft';

  @override
  String get mobilityAnschluesseNichtVeroeffentlicht1584b8b8 =>
      'Anschlüsse: nicht veröffentlicht';

  @override
  String get mobilityAnzeigereferenzGenaueAusdehnungUnbekannt92e1ba4c =>
      'Anzeigereferenz · genaue Ausdehnung unbekannt';

  @override
  String get mobilityAstraMesswerteLadencc594459 => 'ASTRA-Messwerte laden';

  @override
  String mobilityAstraTabellenstandLokalBezogenfdd31ddb(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'ASTRA · Tabellenstand: $arg0\nLokal bezogen: $arg1$arg2';
  }

  @override
  String get mobilityAstraVerkehrsmeldungenLadenf278469c =>
      'ASTRA-Verkehrsmeldungen laden';

  @override
  String mobilityAstraVmzChEreignis5068b250(String arg0, String arg1) {
    return 'ASTRA / VMZ-CH · Ereignis $arg0 · $arg1 Teilmeldungen';
  }

  @override
  String get mobilityAstraVmzChTraffic19a07166 =>
      'ASTRA / VMZ-CH Verkehrssituationen · Schweizer Straßennetz. Registrierter API-Zugriff ist erforderlich. TMC-only-Referenzen erfordern die passende offizielle Topologie. Nicht zugeordnete oder unsichere Nachrichten bleiben Informationen; ausreichend abgestimmte aktuelle Daten können zum Routenvergleich aktiviert werden.';

  @override
  String get mobilityAstraVmzChVeroeffentlicht4c4e6620 =>
      'ASTRA / VMZ-CH veröffentlicht Ereignismeldungen. Ohne passende offizielle TMC-Ortstabelle können reine Ortscodes nicht auf der Karte verortet werden. Solche Meldungen bleiben hier durchsuchbar. Kartenpunkte können nur eine Anzeigereferenz sein; gerade Linien bilden keinen genauen Straßenverlauf ab.\n\nDurchgehende Verkehrsdichte und verkehrsabhängige Ankunftszeiten sind damit nicht verfügbar. ASTRA bietet zusätzlich Geschwindigkeiten und Fahrzeugmengen an Zählstellen über einen separaten API-Zugang an.';

  @override
  String get mobilityAufDKarteAnzeigen2ad897d8 =>
      'Auf 3D-Karte anzeigen (max. 150)';

  @override
  String get mobilityAufDKarteZeigenb9c8e9a8 =>
      'Auf 3D-Karte zeigen (max. 120)';

  @override
  String mobilityAufnahmeUtc809df7be(String arg0) {
    return 'Aufnahme (UTC): $arg0';
  }

  @override
  String get mobilityAusgewaehltenKartenpunktUebernehmen849683eb =>
      'Ausgewählten Kartenpunkt übernehmen';

  @override
  String get mobilityAusgewaehltenKartenpunktVerwenden90ebe0f5 =>
      'Ausgewählten Kartenpunkt verwenden';

  @override
  String get mobilityAutomatischAktualisierena2f998d7 =>
      'Automatisch aktualisieren';

  @override
  String mobilityBafuFeatureId27de0e54(String arg0) {
    return 'BAFU-Funktions-ID: $arg0';
  }

  @override
  String get mobilityBakomErklaerungenUndAmtliche7dfa13ad =>
      'BAKOM-Erklärungen und amtliche Quelle';

  @override
  String get mobilityBakomMobilfunkBasisstationenb5426d86 =>
      'BAKOM Mobilfunk-Basisstationen';

  @override
  String get mobilityBeendence9e650e => 'Beenden';

  @override
  String get mobilityBeiRoutenabweichungenSendetDie131b098f =>
      'Bei Routenabweichungen sendet die App Standort und Ziel an FOSSGIS. Der Dienst protokolliert die Anfrage. Im Hintergrund pausiert die Navigation.';

  @override
  String mobilityBeobachtungszeite60e71e7(String arg0) {
    return 'Beobachtungszeit: $arg0';
  }

  @override
  String mobilityBeobachtungszeitraumStac7f2d19f8(String arg0, String arg1) {
    return 'Beobachtungszeitraum (STAC): $arg0 – $arg1';
  }

  @override
  String get mobilityBewertungUnvollstaendigKeineVerkehrsbasierte655a9750 =>
      'Bewertung unvollständig · keine verkehrsbasierte Empfehlung';

  @override
  String get mobilityBfeDokumentationUndNutzungsbedingungen58dca300 =>
      'BFE-Dokumentation und Nutzungsbedingungen';

  @override
  String get mobilityBildebeneEntfernenBasiskarte8d450df2 =>
      'Bildebene entfernen / Basiskarte';

  @override
  String mobilityBildlayer7779aa56(String arg0, String arg1) {
    return 'Bildträger: $arg0$arg1';
  }

  @override
  String get mobilityBreiteWgsbf85fa1c => 'Breite (WGS84)';

  @override
  String get mobilityBreitengradf5eed2f2 => 'Breitengrad';

  @override
  String get mobilityCalculateDrivingRoute59eac3f8 => 'Fahrweg berechnen';

  @override
  String mobilityCalculatedTheRoutingService9f5e2267(String arg0, String arg1) {
    return 'Berechnet: $arg0 · $arg1. Der Routing-Dienst kann Endpunkte auf nahegelegene Straßen snapsen.';
  }

  @override
  String get mobilityCategories6ccb6007 => 'Kategorien';

  @override
  String get mobilityCdiZeitstandOffiziellerWms68eccda7 =>
      'CDI-Zeitstand (offizieller WMS-Parameter)';

  @override
  String get mobilityDDatenFehlenOderdd9b0af0 =>
      '3D-Daten fehlen oder sind offline nicht verfügbar.';

  @override
  String get mobilityDEinstellungKonnteNicht1dd69132 =>
      '3D-Einstellung konnte nicht übernommen werden.';

  @override
  String get mobilityDUmgebungInDer7e362fb8 => '3D-Umgebung in der Navigation';

  @override
  String get mobilityDUmgebungb7f47aad => '3D-Umgebung';

  @override
  String mobilityDarstellungsfehler750531ab(String arg0) {
    return 'Darstellungsfehler: $arg0';
  }

  @override
  String get mobilityDatenabrufAelterAlsStundenf8a928a3 =>
      'Datenabruf älter als 24 Stunden.';

  @override
  String get mobilityDatenstandUndBewertungsregeln47599d2e =>
      'Datenstand und Bewertungsregeln';

  @override
  String mobilityDatenstatusd3d7b1d5(String arg0) {
    return 'Datenstatus: $arg0';
  }

  @override
  String get mobilityDatierteAufnahmeAnzeigen461270db =>
      'Datierte Aufnahme anzeigen';

  @override
  String get mobilityDatierteBilderSuchen2f4ff702 => 'Datierte Bilder suchen';

  @override
  String get mobilityDatierteSatellitenRapidMappingf807e800 =>
      'Datierte Satelliten- & Rapid-Mapping-Bilder';

  @override
  String get mobilityDestinationSpotdfb0a64e => 'Zielort';

  @override
  String mobilityDetektorFahrstreifenFahrbahntype8312098(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Detektor: $arg0 · Fahrstreifen: $arg1 · Fahrbahntyp: $arg2';
  }

  @override
  String get mobilityDieQuelleNenntWiederkehrende01133c3c =>
      'Die Quelle nennt wiederkehrende Zeitfenster. Einzelne Zeitfenster vor Fahrtantritt prüfen.';

  @override
  String get mobilityDirectBrowserRequestsAre8f6307e5 =>
      'Direkte Browseranfragen werden von der Anbieterrichtlinie CORS blockiert. Importieren Sie einen  readsb/adsb.lol JSON Snapshot oder verwenden Sie Android; kein öffentlicher Proxy ist beteiligt.';

  @override
  String get mobilityDirekterAbrufAufAndroid7c4ac605 =>
      'Direkter Abruf auf Android verfügbar.';

  @override
  String get mobilityDreiUnabhaengigeAmtlicheKartenebenen6c0dfad0 =>
      'Drei unabhängige amtliche Kartenebenen · optional';

  @override
  String get mobilityEigenerTrafficCountersTokenff5ddb8b =>
      'Eigener Traffic-Counters-Token';

  @override
  String get mobilityEigenerZugangFuerTraffic1a7bd79b =>
      'Eigener Zugang für Traffic Counters. Der Schlüssel für Verkehrsmeldungen wird dafür nicht wiederverwendet. Daten bleiben in dieser Sitzung.';

  @override
  String get mobilityEinigeDKachelnFehlen747d8e09 =>
      'Einige 3D-Kacheln fehlen.';

  @override
  String mobilityEintraegeStandf4269e5b(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0 Einträge · Stand $arg1 · $arg2$arg3';
  }

  @override
  String mobilityEreignisEinsatzac1a3fa0(String arg0) {
    return 'Ereignis / Einsatz: $arg0';
  }

  @override
  String mobilityEreignisseOhneKartenpositionNichta9154e17(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return '$arg0 Ereignisse · $arg1 ohne Kartenposition · $arg2 nicht auswertbar';
  }

  @override
  String get mobilityErforderlichEigenerOjpApi4a8d7c41 =>
      'Erforderlich: eigener OJP-2.0-API-Schlüssel mit freigeschaltetem Produkt. Zugangsdaten bleiben in lokalem Secure Storage (Web: nur Arbeitsspeicher dieser Sitzung).';

  @override
  String get mobilityErgebnisBegrenztKleinereSuchflaeche4bec8127 =>
      'Ergebnis begrenzt; kleinere Suchfläche wählen. Keine vollständige Abdeckung.';

  @override
  String mobilityErneutLaden13159aac(String arg0) {
    return '$arg0 erneut laden';
  }

  @override
  String mobilityFahrplan10147b40(String arg0, String arg1) {
    return '$arg0 Fahrplan: $arg1';
  }

  @override
  String mobilityFahrzeugeLautAnbieterbf339e17(String arg0) {
    return 'Fahrzeuge laut Anbieter: $arg0';
  }

  @override
  String get mobilityFahrzeugtyp76a9b894 => 'Fahrzeugtyp';

  @override
  String get mobilityFehlendeBenoetigteTabellenLaden3eb0f8e9 =>
      'Fehlende benötigte Tabellen laden';

  @override
  String get mobilityFindNearbyPlacesd0091995 => 'Finden Sie in der Nähe Orte';

  @override
  String get mobilityFirstDetailsShownHere859f2457 =>
      'Die ersten 100 Details hier. Andere positionierte Datensätze bleiben auf der Karte wählbar.';

  @override
  String get mobilityFortschrittPausiertGpsPruefen63c6fa50 =>
      'Fortschritt pausiert · GPS prüfen';

  @override
  String get mobilityFossgisLogsTheRoute7ac53fd4 =>
      'FOSSGIS protokolliert die Routenanfrage. Spot-Namen und Notizen bleiben in der App.';

  @override
  String get mobilityFreeFloating38dd1268 => 'Freischwimmen';

  @override
  String get mobilityFreiesZiele762f189 => 'Freies Ziel';

  @override
  String get mobilityFuerDieseAnfrageWurden9803db4c =>
      'Für diese Anfrage wurden keine Verbindungen gefunden.';

  @override
  String get mobilityFuerDieseVersionIst88b3c175 =>
      'Für diese Version ist kein LTEF-ZIP hinterlegt. Im offiziellen Katalog prüfen; GeoPackage wird noch nicht unterstützt.';

  @override
  String get mobilityGeradeVerbindungZwischenQuellenpositionen0a65d12c =>
      'Gerade Verbindung zwischen Quellenpositionen; kein genauer Straßenverlauf.';

  @override
  String get mobilityGeraetestandorta680a346 => 'Gerätestandort';

  @override
  String mobilityGeraetezeit4dd99dec(String arg0, String arg1) {
    return '$arg0 $arg1 (Gerätezeit)';
  }

  @override
  String get mobilityGeschwindigkeitenUndFahrzeugmengenAn522f5906 =>
      'Geschwindigkeiten und Fahrzeugmengen an Messstellen';

  @override
  String get mobilityGeschwindigkeitenUndFahrzeugratenAnba71d451 =>
      'Geschwindigkeiten und Fahrzeugraten an bis zu 100 Detektoren im gewählten 30-km-Gebiet.';

  @override
  String get mobilityGespeicherteAbfrageAnzeigen62c7018c =>
      'Gespeicherte Abfrage anzeigen';

  @override
  String get mobilityGespeicherteDatenAktualitaetNichta41279f4 =>
      'Gespeicherte Daten · Aktualität nicht live geprüft';

  @override
  String mobilityGespeicherteVerbindungen895ea994(String arg0) {
    return 'Gespeicherte Verbindungen ($arg0)';
  }

  @override
  String get mobilityGespeichertenSpotUebernehmenOptionald048ef49 =>
      'Gespeicherten Spot übernehmen (optional)';

  @override
  String get mobilityGespeichertenStand0b0b171e => 'Gespeicherten Stand';

  @override
  String get mobilityGespeicherterAbrufIstAelterc7e97b86 =>
      'Gespeicherter Abruf ist älter als 15 Minuten.';

  @override
  String get mobilityGespeicherterMetadatenstandKeineAktuelle17c89c8f =>
      'Gespeicherter Metadatenstand – keine aktuelle Live-Bestätigung.';

  @override
  String get mobilityGespeicherterSpotOptional1c4bdc07 =>
      'Gespeicherter Spot (optional)';

  @override
  String get mobilityGespeicherterStandOfflineNutzbarc7dc6f17 =>
      'Gespeicherter Stand (offline nutzbar)';

  @override
  String get mobilityGpsErneutVerbindend3c0a56a => 'GPS erneut verbinden';

  @override
  String mobilityGueltigAbBisc0b768b9(String arg0, String arg1) {
    return 'Gültig ab: $arg0 · bis: $arg1';
  }

  @override
  String mobilityGueltigSeitBise1e05815(String arg0, String arg1) {
    return 'Gültig seit: $arg0 · bis: $arg1';
  }

  @override
  String get mobilityHidePoisOnD072cee45 => 'POIs auf 3D Karte ausblenden';

  @override
  String mobilityHinweisec38e74ed(String arg0, String arg1) {
    return '$arg0 Hinweise · $arg1';
  }

  @override
  String get mobilityIHaveRegisteredAccessa282c504 =>
      'Ich habe den Zugang registriert und akzeptiert die Provider-Bedingungen für meinen eigenen Gebrauch.';

  @override
  String get mobilityImWebDasOriginal2ebbbc3c =>
      'Im Web das Original-ZIP über den offiziellen Download beziehen und lokal importieren. Kein zusätzlicher API-Schlüssel erforderlich.';

  @override
  String get mobilityImportAircraftJson444ad3f1 => 'Importflugzeug JSON';

  @override
  String get mobilityImportDatexXml5eb44537 => 'DATAX XML importieren';

  @override
  String get mobilityImportierteDatenOnlineNicht8129ba14 =>
      'Importierte Daten · online nicht geprüft';

  @override
  String mobilityInKmImMf10f6e91(String arg0) {
    return 'In $arg0 km · im 300-m-Routenumfeld';
  }

  @override
  String get mobilityKachelnErneutVersuchenc1fb6d60 =>
      'Kacheln erneut versuchen';

  @override
  String mobilityKachelnQuelldatumNichtDurch5d14a5bc(String arg0, String arg1) {
    return '$arg0\nKacheln: $arg1 · Quelldatum nicht durch Kachelladen bestätigt';
  }

  @override
  String mobilityKantonGebiet2306a36c(String arg0, String arg1) {
    return 'Kanton: $arg0 · Gebiet: $arg1';
  }

  @override
  String get mobilityKantonaleFachstellen9b9d1abf => 'Kantonale Fachstellen';

  @override
  String get mobilityKantonaleWaldbrandPraeventionsmassnahmena6d2b302 =>
      'Kantonale Waldbrand-Präventionsmassnahmen';

  @override
  String get mobilityKarteFreiBewegene1d97140 => 'Karte frei bewegen';

  @override
  String get mobilityKartendarstellungefb26012 => 'Kartendarstellung';

  @override
  String get mobilityKartenpunkt8b21f720 => 'Kartenpunkt';

  @override
  String get mobilityKeinOeffentlicherBeschreibungstextVorhanden581108e5 =>
      'Kein öffentlicher Beschreibungstext vorhanden.';

  @override
  String get mobilityKeineAuswertbarenMesswerte4dc49063 =>
      'Keine auswertbaren Messwerte';

  @override
  String get mobilityKeineDatiertenMassnahmenFuer9c369d5c =>
      'Keine datierten Massnahmen für diesen Punkt ermittelt. Die Abdeckung kann unvollständig sein – KEINE Entwarnung.';

  @override
  String get mobilityKeineKontaktEMail7ee17077 =>
      'Keine Kontakt-E-Mail nötig: REST-v1-Schnittstelle ohne Login.';

  @override
  String get mobilityKeinePassendenMeldungenDas1634f284 =>
      'Keine passenden Meldungen. Das bestätigt keine freie Fahrt oder vollständige Quellenabdeckung.';

  @override
  String get mobilityKeineUeberpruefteQualitaetsmaskeWolken490d3ea2 =>
      'Keine überprüfte Qualitätsmaske – Wolken und Bildlücken können vorhanden sein.';

  @override
  String get mobilityKeineVerkehrsdatenGeladena56a2b8a =>
      'Keine Verkehrsdaten geladen';

  @override
  String get mobilityKeysUseDeviceSecuref60f66e8 =>
      'Keys verwenden eine gerätesichere Speicherung und werden nur an den offiziellen ASTRA-Endpunkt gesendet.';

  @override
  String mobilityKmMinEstimated439c5826(String arg0, String arg1) {
    return '$arg0 km · $arg1 min geschätzt';
  }

  @override
  String get mobilityKoordinatenFuerDieAbfrage631e8e79 =>
      'Koordinaten für die Abfrage an geo.admin.ch senden';

  @override
  String mobilityLadestandorteAbrufe451a0c3(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return '$arg0 Ladestandorte · Abruf $arg1$arg2';
  }

  @override
  String get mobilityLadestationenInDerSchweiza8bd739c =>
      'Ladestationen in der Schweiz · BFE / geo.admin.ch. Freie Plätze sind nur eine datierte Meldung und keine Reservierung. Ergebnisse können unvollständig sein.';

  @override
  String get mobilityLadestationenSuchen805f1685 => 'Ladestationen suchen';

  @override
  String get mobilityLaengeWgs7a5b794e => 'Länge (WGS84)';

  @override
  String get mobilityLaengengrad9436942a => 'Längengrad';

  @override
  String get mobilityLatitudeced3905e => 'Breite';

  @override
  String get mobilityLayerUpdateFailedPlease636e8a82 =>
      'Layer Update fehlgeschlagen. Bitte versuchen Sie es erneut.';

  @override
  String get mobilityLetzteAktualisierungFehlgeschlagenLetzterf5121616 =>
      'Letzte Aktualisierung fehlgeschlagen; letzter Stand wird angezeigt.';

  @override
  String get mobilityLetztenKatalogstandOeffnene2aafc7e =>
      'Letzten Katalogstand öffnen';

  @override
  String get mobilityLetzterAbrufAktuellfe37dd68 => 'Letzter Abruf aktuell';

  @override
  String mobilityLetzterAbrufImportea742e4d(String arg0) {
    return 'Letzter Abruf / Import: $arg0';
  }

  @override
  String get mobilityListeAufEintraegeBegrenzt46a09ccd =>
      'Liste auf 60 Einträge begrenzt. Filter oder Radius anpassen.';

  @override
  String get mobilityListeAufEintraegeBegrenzt47537bf9 =>
      'Liste auf 60 Einträge begrenzt; Radius verkleinern.';

  @override
  String get mobilityLiveMesswerteTrafficCountersaee8a401 =>
      'Live-Messwerte · Verkehrszähler';

  @override
  String mobilityLizenzMetadatenAssetVerweisedcf92706(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Lizenz-Metadaten: $arg0 · $arg1 Asset-Verweise; davon $arg2 als JSON/CSV klassifiziert.';
  }

  @override
  String get mobilityLocationAccessIsRequestedab7f6719 =>
      'Der Zugriff auf den Standort wird nur bei gedrückter Taste angefordert; Koordinaten werden nur dann an den Routing-Provider gesendet, wenn Sie berechnen.';

  @override
  String get mobilityLoestSchweizerOrtscodesUnd47816372 =>
      'Löst Schweizer Ortscodes und Tabellenrichtungen auf. Referenzdaten werden lokal gespeichert; die Aktualität der Verkehrsmeldungen bleibt unabhängig davon.';

  @override
  String get mobilityLongitude6f9f011c => 'Längengrad';

  @override
  String get mobilityMaximaleTrefferzahlErreichtNichtcbd9a35f =>
      'Maximale Trefferzahl erreicht: nicht alle Standorte erfasst. Radius verkleinern.';

  @override
  String get mobilityMehrereAmtlicheGebieteUeberlagern220c23d0 =>
      'Mehrere amtliche Gebiete überlagern sich. Geltungsbereich und Vorrang bitte bei den Kantonen prüfen.';

  @override
  String mobilityMeldungGeaenderta349466c(String arg0) {
    return 'Meldung geändert: $arg0';
  }

  @override
  String get mobilityMeldungenImMUmfeld417f6077 =>
      'Meldungen im 300-m-Umfeld; Straße und Fahrtrichtung sind nicht bestätigt. Die Ankunftsschätzung enthält keine Stauzeiten.';

  @override
  String get mobilityMessstellenAufKarteZeigen191576b4 =>
      'Messstellen auf Karte zeigen';

  @override
  String get mobilityMessstellenImGewaehltenGebietfb7f4f74 =>
      'Messstellen im gewählten Gebiet';

  @override
  String get mobilityMesswerteAktualisierendbc899d0 =>
      'Messwerte aktualisieren';

  @override
  String get mobilityMesswerteWerdenGeladence66c18a =>
      'Messwerte werden geladen …';

  @override
  String mobilityMesszeitIntervallSd22c606f(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
    String arg6,
  ) {
    return '$arg0 · $arg1: $arg2 $arg3\nMesszeit: $arg4 · Intervall: $arg5 s$arg6';
  }

  @override
  String get mobilityMetadatenAelterAlsHfcd2d03c =>
      'Metadaten älter als 24 h / Uhrzeit unplausibel.';

  @override
  String mobilityMetadatenHeruntergeladen4f8bd0e0(String arg0) {
    return 'Metadaten heruntergeladen: $arg0';
  }

  @override
  String mobilityMinAnkunft0b629c3a(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0 min · $arg1 · Ankunft $arg2:$arg3';
  }

  @override
  String get mobilityMobilityOsint1a8134ea => 'Mobilität & OSINT';

  @override
  String get mobilityNaeherHeranzoomenccfc2dce => 'Näher heranzoomen';

  @override
  String get mobilityNavigationcf03cf2e => 'Navigation';

  @override
  String get mobilityNeuberechnungenSindFruehestensAllea6a83143 =>
      'Neuberechnungen sind frühestens alle 30 Sekunden möglich. Die Ankunftsschätzung bleibt ohne Verkehrszuschläge.';

  @override
  String get mobilityNichtAlleAnbieterLiefernb166930b =>
      'Nicht alle Anbieter liefern Daten. Fehlende Treffer bedeuten keine vollständige Abdeckung.';

  @override
  String mobilityNichtKlassifiziert32692a7b(String arg0) {
    return 'Nicht klassifiziert: $arg0';
  }

  @override
  String get mobilityNichtUnterstuetzteDateiAssetsaf920b33 =>
      'Nicht unterstützte Datei-Assets (z. B. GeoPackage) werden nicht automatisch importiert.';

  @override
  String get mobilityNoAutomaticPollingQueries62b013f8 =>
      'Kein automatisches Polling. Anfragen sind lokal begrenzt auf 12/Stunde und mindestens 15 Sekunden Abstand. Der Anbieter kann strengere Grenzwerte anwenden.';

  @override
  String get mobilityNoInformationLoadedMissing2c3854cc =>
      'Keine Informationen geladen. Fehlende Daten bedeutet nicht, klare Straßen oder leeren Luftraum.';

  @override
  String get mobilityNoSavedSpotsChoose44cb95eb =>
      'Keine gespeicherten Spots. Wählen Sie Freies Ziel, um ein Ziel einzugeben.';

  @override
  String get mobilityNurAusreichendZugeordneteAktuellea3f9bd6d =>
      'Nur ausreichend zugeordnete aktuelle Daten. Neue Meldungen allein lösen keinen Routenwechsel aus.';

  @override
  String get mobilityNurBegrenzteStacAuswahla9abd316 =>
      'Nur begrenzte STAC-Auswahl geprüft; Vollständigkeit nicht bestätigt.';

  @override
  String get mobilityNurDurchAusdruecklichesSuchen62af35c2 =>
      'Nur durch ausdrückliches Suchen; keine Standortüberwachung.';

  @override
  String get mobilityNurMitKartenposition87e01213 => 'Nur mit Kartenposition';

  @override
  String get mobilityNutztDeinenGespeichertenZugang06987d0c =>
      'Nutzt deinen gespeicherten Zugang. Aktualisierung bei Bedarf in der Navigation; keine Stauzeiten in der Ankunftsschätzung.';

  @override
  String get mobilityNutztVorhandeneDatenBeeinflusst7a5969ac =>
      'Nutzt vorhandene Daten. Beeinflusst auch spätere Neuberechnungen; die Fahrzeit bleibt eine OSRM-Basisschätzung.';

  @override
  String get mobilityOfficialLegendSourcefc8aaddf =>
      'Offizielle Legende & Quelle';

  @override
  String get mobilityOffizielleEinzelabfrageUnabhaengigVon105d62b9 =>
      'Offizielle Einzelabfrage · unabhängig von der Waldbrand-Gefahrenstufe';

  @override
  String get mobilityOffizielleNutzungsbedingungen7ce05187 =>
      'Offizielle Nutzungsbedingungen';

  @override
  String get mobilityOffizielleStacCollectiond6ac1266 =>
      'Offizielle STAC-Sammlung';

  @override
  String get mobilityOffiziellerDownloadUndQuellen43d0f2a7 =>
      'Offizieller Download und Quellen';

  @override
  String get mobilityOffiziellerOpenJourneyPlanner328efb58 =>
      'Offizieller Open Journey Planner 2.0 (Schweiz). Verbindungssuche bis zum tatsächlichen gewählten Punkt; Parkplatz- und Autokoordinaten werden nicht eingesetzt.';

  @override
  String get mobilityOfflineCacheKatalogKeine803aa9f6 =>
      'Offline-/Cache-Katalog – keine Live-Bestätigung.';

  @override
  String get mobilityOfflineSprachausgabeEinschalten826f1a70 =>
      'Offline-Sprachausgabe einschalten';

  @override
  String get mobilityOhneKartenpositionTmcOrtstabelle29d7c796 =>
      'Ohne Kartenposition · TMC-Ortstabelle erforderlich';

  @override
  String get mobilityOhneNutzbareQuellenposition09a6b7b9 =>
      'Ohne nutzbare Quellenposition';

  @override
  String get mobilityOjpAbfrageergebnis539abae1 => 'OJP-Abfrageergebnis';

  @override
  String get mobilityOjpDokumentationUndQuelle808dc1c2 =>
      'OJP-Dokumentation und Quelle';

  @override
  String get mobilityOpenstreetmapCoverageIsIncompletee9ae81d0 =>
      'OpenStreetMap-Berichterstattung ist unvollständig und Attribute können fehlen oder veraltet sein.';

  @override
  String get mobilityOptionalParkingAccessPoints7538207e =>
      'Optionale Parkplätze & Zugangspunkte';

  @override
  String mobilityOsmPlacesRetrieved45a236fa(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return '$arg0 OSM Plätze · abgerufen $arg1$arg2';
  }

  @override
  String get mobilityOsrmLiefertNichtImmer92919ffd =>
      'OSRM liefert nicht immer Alternativen. Fehlende Meldungen oder Messungen bestätigen keinen freien Verkehrsfluss.';

  @override
  String get mobilityOutdatedThisOfflineSnapshot5eb25014 =>
      'OUTDATED: Dieser Offline-Snapshot kann nicht mehr die verfügbaren Einrichtungen widerspiegeln.';

  @override
  String get mobilityOvVerbindungenOjp3ac37a87 => 'ÖV-Verbindungen · OJP 2.0';

  @override
  String get mobilityOvVerbindungenSuchen7014824a => 'ÖV-Verbindungen suchen';

  @override
  String get mobilityOverpassApiDocumentationAnd4c33de59 =>
      'API-Dokumentation und Fair-Use-Politik überschreiten';

  @override
  String get mobilityOwnAstraApiKey38bbd3b9 => 'Eigener ASTRA API-Schlüssel';

  @override
  String mobilityPassendeEreignisse872c00ef(String arg0, String arg1) {
    return '$arg0 passende Ereignisse$arg1';
  }

  @override
  String mobilityPositionedRecordsWithoutUsable456e69a4(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0 $arg1 positionierte Datensätze · $arg2 ohne nutzbare Positionen · $arg3 weggelassen.';
  }

  @override
  String mobilityProduktbc93422a(String arg0, String arg1) {
    return 'Produkt: $arg0 · $arg1';
  }

  @override
  String get mobilityPrognosezeitstandKeineDirekteBeobachtungbef744b1 =>
      'Prognosezeitstand: keine direkte Beobachtung.';

  @override
  String get mobilityProviderUnavailableShowingA4e8d9841 =>
      'Anbieter nicht verfügbar; zeigt stattdessen einen veralteten Zwischenspeicher-Snapshot an.';

  @override
  String mobilityPublikationsstandDerQuellec3da8498(String arg0) {
    return 'Publikationsstand der Quelle: $arg0';
  }

  @override
  String get mobilityPunktuelleGeschwindigkeitenWerdenOhne74f8b6a6 =>
      'Punktuelle Geschwindigkeiten werden ohne vergleichbare Messungen aller Alternativen nicht gewichtet.';

  @override
  String get mobilityPunktuelleMessungenDerQuellee6b23c9f =>
      'Punktuelle Messungen der Quelle. Fahrzeugmengen sind Raten in Fahrzeugen pro Stunde. Werte verschiedener Fahrstreifen und Fahrzeuggruppen werden nicht addiert. Keine durchgehende Staukarte.';

  @override
  String get mobilityQualitaetsWolkenmaskeAlsEigenes3ad85811 =>
      'Qualitäts-/Wolkenmaske als eigenes Datenasset vorhanden; nicht automatisch als wolkenfrei interpretiert.';

  @override
  String get mobilityQuelleBafuKantoneGeo76ff0395 =>
      'Quelle: BAFU / Kantone · geo.admin.ch · waldbrandgefahr.ch';

  @override
  String get mobilityQuelleUndNutzungsbedingungene5956cc4 =>
      'Quelle und Nutzungsbedingungen';

  @override
  String get mobilityQuellenGrenzen4bc8454f => 'Quellen & Grenzen';

  @override
  String mobilityQuellenmeldung8bdd0b3c(String arg0) {
    return 'Quellenmeldung: $arg0';
  }

  @override
  String mobilityQuellenpublikationd60ff8d0(String arg0) {
    return 'Quellenpublikation: $arg0';
  }

  @override
  String mobilityQuellenveroeffentlichung5456a71d(String arg0) {
    return 'Quellenveröffentlichung: $arg0';
  }

  @override
  String get mobilityRasterkartenSendenDenKartenausschnittf2f4eb37 =>
      'Rasterkarten senden den Kartenausschnitt an geo.admin.ch. Das SLF-Bulletin wird ohne Standort als nationaler Datensatz geladen. Ladedaten bestätigen keine amtliche Gültigkeit. Flugplatzdaten ersetzen nicht das AIP; Brandgefahrenkarten ersetzen keine lokalen Anordnungen. Die Ebenen erteilen keine Flug- oder Zugangsfreigabe.';

  @override
  String mobilityReferenz917463e5(String arg0) {
    return 'Referenz: $arg0';
  }

  @override
  String get mobilityRefreshAircraftcf46fb55 => 'Luftfahrzeuge aktualisieren';

  @override
  String get mobilityRefreshFromOverpass6925d82f =>
      'Aktualisieren von Overpass';

  @override
  String get mobilityRefreshTrafficde6624d5 => 'Aktualisieren des Verkehrs';

  @override
  String mobilityRemoveLayer98fc17fe(String arg0) {
    return '$arg0 Ebene entfernen';
  }

  @override
  String get mobilityReportAMapError8ddb12c3 => 'Kartenfehler melden';

  @override
  String get mobilityResultsTruncatedToProtect98dcb26a =>
      'Ergebnisse gekürzt, um das Gerät zu schützen. Verringern Sie Ihren Radius oder Kategorie Auswahl.';

  @override
  String mobilityRetrievedImportedSourcePublicationadd5e4e8(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0 $arg1 Abruft/importiert: $arg2 Quelle: $arg3 Gültigkeit des Datensatzes: nicht deklariert; einzelne Datensätze können Daten angeben.';
  }

  @override
  String get mobilityRetryTilesa3340dc4 => 'Fliesen erneut versuchen';

  @override
  String get mobilityRouteNeuBerechnen8225e5ba => 'Route neu berechnen';

  @override
  String get mobilityRoutenalternativenNeuBerechnen5de70eb6 =>
      'Routenalternativen neu berechnen';

  @override
  String get mobilitySatellitenkarte6afd828c => 'Satellitenkarte';

  @override
  String get mobilitySaveAccessNotesLocallyf5e29d86 =>
      'Zugriffshinweise lokal speichern';

  @override
  String get mobilitySaveAsPersonalSpotc26312fd =>
      'Als persönlicher Ort speichern';

  @override
  String mobilitySavedAsSpota5bf3429(String arg0) {
    return 'Als Spot gespeichert #$arg0';
  }

  @override
  String get mobilitySavedSpotsUnavailableb5814146 =>
      'Gespeicherte Spots nicht verfügbar.';

  @override
  String get mobilitySearchAroundSavedSpot88def52e =>
      'Suche nach gespeichertem Spot (optional)';

  @override
  String get mobilitySearchRadiusMetres9f19e093 => 'Suchradius (Meter)';

  @override
  String get mobilitySharingAngeboteAmOvcb5d14df =>
      'Sharing-Angebote am ÖV-Ziel suchen';

  @override
  String get mobilitySharingAngeboteSuchen5659da3e => 'Sharing-Angebote suchen';

  @override
  String get mobilityShowDrivingRouteOn3860ee86 =>
      'Fahrende Route auf Karte anzeigen';

  @override
  String get mobilityShowPoisOnD87e9f7a8 => 'POIs auf 3D Karte anzeigen';

  @override
  String get mobilityShowSavedSearchOffline9f9ba558 =>
      'Gespeicherte Suche offline anzeigen';

  @override
  String get mobilityShowSnapshotOnMap1ce6224b => 'Snapshot auf Karte anzeigen';

  @override
  String get mobilityShowingTheFirstPoie98a81e6 =>
      'Zeigt die ersten 60 POI Detailkarten; bis zu 300 Punkte können auf der Karte angezeigt werden.';

  @override
  String mobilitySnapshotVisiblec86e4891(String arg0) {
    return '$arg0 Snapshot sichtbar';
  }

  @override
  String get mobilitySnapshotsAreDelayedAnd4458e3d6 =>
      'Schnappschüsse sind verspätet und unvollständig. Ambermarker sind älter als 30 Sekunden; Positionen älter als 5 Minuten sind versteckt. Marker sitzen auf dem Gelände; gemeldete Flugzeughöhen stehen in Details zur Verfügung. Benutzen Sie dies niemals, um die visuelle Luftraumbeobachtung oder offizielle Luftfahrtinformationen zu ersetzen.';

  @override
  String get mobilitySprachausgabeAusschalten212e3af6 =>
      'Sprachausgabe ausschalten';

  @override
  String mobilityStacAbgefragtTrefferIn004b3edc(String arg0, String arg1) {
    return 'STAC abgefragt: $arg0 · $arg1 Treffer in begrenzter Stichprobe';
  }

  @override
  String get mobilityStacAssetsPruefen15fce27f => 'STAC-Assets prüfen';

  @override
  String get mobilityStacDatenstandPruefen445b5f79 => 'STAC-Datenstand prüfen';

  @override
  String get mobilityStacMetadatenFuerSwisseofe06af42 =>
      'STAC-Metadaten für swissEO VHI werden nur auf Wunsch abgefragt. Der Abrufzeitpunkt und der Beobachtungszeitraum werden getrennt gespeichert. WMS-/WMTS-Kacheln werden nicht als Offline-Datensatz archiviert.';

  @override
  String mobilityStacStand0f0a2434(String arg0) {
    return 'STAC-Stand: $arg0';
  }

  @override
  String get mobilityStandortFolgen5650d84d => 'Standort folgen';

  @override
  String get mobilityStandortdatenAelterAlsFuenfe3719933 =>
      'Standortdaten älter als fünf Minuten; nicht live.';

  @override
  String get mobilityStarten2beb7350 => 'Starten';

  @override
  String mobilityStationen2bee7a5c(String arg0, String arg1) {
    return '$arg0 Stationen · $arg1';
  }

  @override
  String get mobilityStationenAufDemD84751cec => 'Stationen auf dem 3D-Globus';

  @override
  String get mobilityStationenSuchen87f44373 => 'Stationen suchen';

  @override
  String get mobilityStationencfddc861 => 'Stationieren';

  @override
  String get mobilityStationslayerAusblenden28212b4d =>
      'Stationslayer ausblenden';

  @override
  String get mobilitySuchkoordinatenAnGeoAdmin3849c24c =>
      'Suchkoordinaten an geo.admin.ch senden';

  @override
  String get mobilitySuchkoordinatenBeimBfeGeo298d1eb7 =>
      'Suchkoordinaten beim BFE / geo.admin.ch abfragen';

  @override
  String get mobilitySuchkoordinatenFuerEineAbfrage44b6f76d =>
      'Suchkoordinaten für eine Abfrage an sharedmobility.ch senden';

  @override
  String get mobilitySuchradius51fb2797 => 'Suchradius';

  @override
  String get mobilitySuchzentrumGespeicherterSpotOptional8f6f54a7 =>
      'Suchzentrum: gespeicherter Spot (optional)';

  @override
  String get mobilitySwisseoSentinelVAmtlichedcab45cb =>
      'swissEO Sentinel-2 v200 / amtliche Ereignisaufnahmen · optional';

  @override
  String mobilitySwisseoVhiDatenstatus0fe52fab(String arg0) {
    return 'swissEO VHI · Datenstatus: $arg0';
  }

  @override
  String mobilityTabelleEntfernenad464a91(String arg0) {
    return 'Tabelle $arg0 entfernen';
  }

  @override
  String mobilityTabelleLaden750049fc(String arg0) {
    return 'Tabelle $arg0 laden';
  }

  @override
  String mobilityTabellenLokal09ba7ffc(String arg0, String arg1) {
    return '$arg0 Tabellen lokal$arg1';
  }

  @override
  String get mobilityTabellenversionb0986031 => 'Tabellenversion';

  @override
  String get mobilityTechnologieUnbekanntbdb10475 => 'Technologie unbekannt';

  @override
  String mobilityTeilmeldungenAufgeloestNochOffenaa8196c8(
    String arg0,
    String arg1,
  ) {
    return '$arg0 Teilmeldungen aufgelöst · $arg1 noch offen';
  }

  @override
  String mobilityTmcOrted224adb9(String arg0, String arg1) {
    return 'TMC $arg0 · $arg1 Orte';
  }

  @override
  String get mobilityTmcOrtsdatene977fc3e => 'TMC-Ortsdaten';

  @override
  String get mobilityTmcTabellenbezugKeinGenauer361692b0 =>
      'TMC-Tabellenbezug · kein genauer Straßenverlauf';

  @override
  String mobilityTmcVersionOrteRichtungscodecfd846ff(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'TMC-Version $arg0 · Orte $arg1 · Richtungscode $arg2';
  }

  @override
  String get mobilityTmcZipImportieren41204dbf => 'TMC-ZIP importieren';

  @override
  String get mobilityTopografischeKarte0698a0c0 => 'Topografische Karte';

  @override
  String mobilityTrefferNachFilterd2e8e9db(String arg0) {
    return '$arg0 Treffer nach Filter';
  }

  @override
  String get mobilityTrefferlimitErreichtKeineVollstaendigedb231641 =>
      'Trefferlimit erreicht: keine vollständige Gebietserfassung. Suchradius verkleinern.';

  @override
  String get mobilityTrockenheitVegetationszustandBafuSwisseoa63812c2 =>
      'Trockenheit & Vegetationszustand (BAFU / swissEO)';

  @override
  String mobilityUmstiegeFusswege891d4f80(String arg0, String arg1) {
    return '$arg0 Umstiege · $arg1 Fußwege';
  }

  @override
  String mobilityUnlocated0f6d01d4(String arg0) {
    return 'Nicht zugewiesen · $arg0';
  }

  @override
  String get mobilityUseDeviceLocation37b5a739 => 'Geräteort verwenden';

  @override
  String mobilityVerbindungc49ec173(String arg0, String arg1, String arg2) {
    return 'Verbindung $arg0: $arg1 – $arg2';
  }

  @override
  String get mobilityVerbindungenOfflineAlsMomentaufnahme0524e3f4 =>
      'Verbindungen offline als Momentaufnahme speichern';

  @override
  String get mobilityVergleichbareGesamtverkehrsMessungenAller0e5faa9f =>
      'Vergleichbare Gesamtverkehrs-Messungen aller Alternativen beeinflussen den Vergleich geringfügig (höchstens ein Vergleichspunkt).';

  @override
  String mobilityVergleichd42555f6(String arg0) {
    return 'Vergleich: $arg0';
  }

  @override
  String get mobilityVerkehrAktualisieren7e12eefe => 'Verkehr aktualisieren';

  @override
  String get mobilityVerkehrAutomatischAktualisieren83ed17ce =>
      'Verkehr automatisch aktualisieren';

  @override
  String get mobilityVerkehrBeiDerRoutenbewertung65a144f1 =>
      'Verkehr bei der Routenbewertung berücksichtigen';

  @override
  String get mobilityVerkehrBeiNeuberechnungBeruecksichtigen47577e32 =>
      'Verkehr bei Neuberechnung berücksichtigen';

  @override
  String get mobilityVerkehrEntlangDerRoute746b9545 =>
      'Verkehr entlang der Route';

  @override
  String get mobilityVerkehrsdatenAusgeschalteta2ae8d43 =>
      'Verkehrsdaten ausgeschaltet';

  @override
  String get mobilityVerkehrsdatenLadenPruefen27aded3f =>
      'Verkehrsdaten laden / prüfen';

  @override
  String get mobilityVerkehrsmeldungenWerdenAktualisiert10e1b261 =>
      'Verkehrsmeldungen werden aktualisiert …';

  @override
  String mobilityVeroeffentlichtf559efaf(String arg0) {
    return 'Veröffentlicht: $arg0';
  }

  @override
  String get mobilityVhiVWirdLaute6dca0e6 =>
      'VHI v100 wird laut swisstopo bis Ende 2026 durch v200 ersetzt. Bis zur verifizierten Umstellung ist der aktuelle Layer eine Übergangslösung.';

  @override
  String get mobilityViewOsmSource395c9b71 => 'OSM-Quelle anzeigen';

  @override
  String get mobilityWebAvailabilityDependsOna0047196 =>
      'Web-Verfügbarkeit hängt von der öffentlichen Endpoint-CoRS-Richtlinie ab; direkte Anfragen können in Browsern fehlschlagen. Es wird kein Proxy oder Intermediär konfiguriert.';

  @override
  String get mobilityWebCorsNichtVerifiziert29e7d189 =>
      'Web: CORS nicht verifiziert. Bei Browser-Sperre ist ein eigener Proxy erforderlich; keiner eingerichtet.';

  @override
  String get mobilityWebOjpCorsUndd96e47d9 =>
      'Web: OJP-CORS und Browser-Zugriff nicht verifiziert. Direkte Anfrage kann fehlschlagen. Kein Relay/Proxy vorhanden; Keys im Browser sind gegenüber Seitenskripten nicht geschützt.';

  @override
  String get mobilityWeiterHerauszoomen212b4f14 => 'Weiter herauszoomen';

  @override
  String mobilityWeitereMeldungenc11d95f1(String arg0) {
    return 'Weitere Meldungen ($arg0)';
  }

  @override
  String get mobilityWeitereMessstellene0dab34a => 'Weitere Messstellen';

  @override
  String get mobilityWeitereStacSeitenVorhanden8ac44f7a =>
      'Weitere STAC-Seiten vorhanden bzw. Trefferlimit erreicht. Abdeckung unvollständig.';

  @override
  String mobilityWeitereUngueltigeAlternativenNichtc1e16f33(String arg0) {
    return '$arg0 weitere / ungültige Alternativen nicht dargestellt.';
  }

  @override
  String mobilityWeitereZugeordneteHinweise883d2761(String arg0) {
    return '$arg0 weitere zugeordnete Hinweise';
  }

  @override
  String get mobilityWieKarte9cb7c6de => 'Wie Karte';

  @override
  String mobilityWolkenanteilGemaessQuelle15e9a8e3(String arg0) {
    return 'Wolkenanteil gemäss Quelle: $arg0 %';
  }

  @override
  String get mobilityWolkenanteilNichtAngegeben76ffb608 =>
      'Wolkenanteil: nicht angegeben';

  @override
  String get mobilityZaehlstellenTokenEntfernen15b8092b =>
      'Zählstellen-Token entfernen';

  @override
  String get mobilityZaehlstellenTokenSpeichern6579a132 =>
      'Zählstellen-Token speichern';

  @override
  String get mobilityZaehlstellenzugangFreigeschaltetUndAstraa64cddb1 =>
      'Zählstellenzugang freigeschaltet und ASTRA-Bedingungen akzeptiert';

  @override
  String get mobilityZiel44d12621 => 'Ziel';

  @override
  String mobilityZiel85926175(String arg0) {
    return 'Ziel: $arg0';
  }

  @override
  String get mobilityZielSuchen5a773b38 => 'Ziel suchen';

  @override
  String get mobilityZuerstImTrafficTab4547f06d =>
      'Zuerst im Traffic-Tab den Token für Road traffic - traffic situations speichern und die Anbieterbedingungen akzeptieren.';

  @override
  String get mobilityZuerstWerdenRoutenMit9d2c4bb2 =>
      'Zuerst werden Routen mit zugeordneten Sperrmeldungen nachrangig angezeigt. Danach zählen OSRM-Basiszeit und der größte publizierte Verzögerungswert. Verzögerungen werden nicht summiert und verändern die angezeigte Ankunftszeit nicht.';

  @override
  String mobilityZugeordneteDetektorenOhnePassende637e378d(
    String arg0,
    String arg1,
  ) {
    return '$arg0 zugeordnete Detektoren · $arg1 ohne passende Metadaten';
  }

  @override
  String mobilityZugeordneteSperrmeldungenZugeordneteQuellenhinweiseee632e99(
    String arg0,
    String arg1,
  ) {
    return '$arg0 zugeordnete Sperrmeldungen · $arg1 zugeordnete Quellenhinweise';
  }

  @override
  String get mobilityZuordnungUndQuellend088f13c => 'Zuordnung und Quellen';

  @override
  String get mobilityZusaetzlicheDatenebenenAngabenKoennen3a7acd85 =>
      'Zusätzliche Datenebenen · Angaben können unvollständig oder veraltet sein.';

  @override
  String observationsAbgerufenZuletztGeprueft118070fc(
    String arg0,
    String arg1,
  ) {
    return 'Abgerufen: $arg0\nZuletzt geprüft: $arg1';
  }

  @override
  String get observationsAbrufenSendetBeiBafu0559cc82 =>
      'Abrufen sendet bei BAFU eine Auswahl naher Stationsnummern; MeteoSwiss wird als landesweite Datei geladen.';

  @override
  String get observationsDatenNichtVerfuegbar85f19360 =>
      'Daten nicht verfügbar';

  @override
  String get observationsGemesseneStationswerteKeinePrognosef2d35acc =>
      'Gemessene Stationswerte · keine Prognose';

  @override
  String get observationsKeineVerfuegbarenMessstationenImb3c601f8 =>
      'Keine verfügbaren Messstationen im gewählten Umfeld. Fehlende Werte bedeuten keine Entwarnung.';

  @override
  String get observationsLokalenSnapshotLoeschen500f4bea =>
      'Lokalen Snapshot löschen';

  @override
  String get observationsMesswerteAbrufen404711d9 => 'Messwerte abrufen';

  @override
  String get observationsOffizielleStationsdetails03ee57d0 =>
      'Offizielle Stationsdetails';

  @override
  String get observationsQuelleBafuHydrologischeBeobachtungenc7f7e996 =>
      'Quelle: BAFU · Hydrologische Beobachtungen. Live ist unkorrigiert; 10-Minuten-Mittel und Freigabestatus bleiben getrennt.';

  @override
  String get observationsQuelleMeteoschweizSwissmetnetCcd346cfc9 =>
      'Quelle: MeteoSchweiz · SwissMetNet · CC BY 4.0. Wind/Böen in km/h; Niederschlag als 10-Minuten-Summe.';

  @override
  String get observationsQuelleUndProduktbeschreibunga056e6fd =>
      'Quelle und Produktbeschreibung';

  @override
  String get observationsStationenAufDerKarte6bbce8f0 =>
      'Stationen auf der Karte';

  @override
  String observationsStationenOhneZuordenbareMetadaten7a9052fc(String arg0) {
    return '$arg0 Stationen ohne zuordenbare Metadaten.';
  }

  @override
  String get observationsUnvollstaendigerDatenauszugWeitereMesswerte5c0b8d49 =>
      'Unvollständiger Datenauszug; weitere Messwerte können fehlen.';

  @override
  String observationsVerfuegbareWerte3495e1b4(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0 · $arg1 verfügbare Werte$arg2$arg3';
  }

  @override
  String get obstaclesAmtlicherDatensatzNachImportd2d6162d =>
      'Amtlicher Datensatz · nach Import offline verfügbar.';

  @override
  String get obstaclesApproximateGeometryStraightConnectionsbd84ea99 =>
      'Ungefähre Geometrie: gerade Verbindungen / Polygonumrisse aus der Quelle. Tatsächliche Kabelsag- und Hindernisflächen sind nicht definiert.';

  @override
  String get obstaclesBazlObstacleLegend85da8229 => 'BAZL Hindernis Legende';

  @override
  String get obstaclesCheckSourceForUpdates9b2adfd6 =>
      'Quelle für Aktualisierungen prüfen';

  @override
  String get obstaclesCloseObstacleDetails12608787 =>
      'Details zum Hindernis schließen';

  @override
  String get obstaclesDObstacleModels82a00838 => '3D Hindernismodelle';

  @override
  String obstaclesDataStatusef822b6e(String arg0) {
    return 'Datenstatus: $arg0';
  }

  @override
  String get obstaclesDatenHoehenbezug36af217e => 'Daten & Höhenbezug';

  @override
  String get obstaclesDownloadVectorDataset689316d7 =>
      'Vektordatensatz herunterladen';

  @override
  String obstaclesEffectiveDateUtc90780bc8(String arg0) {
    return 'Wirksamwerden: $arg0 UTC';
  }

  @override
  String obstaclesFirstSourceVertexHeight6eebb9de(String arg0, String arg1) {
    return 'Erste Quelle Wirbel Höhe: $arg0 m · $arg1';
  }

  @override
  String get obstaclesHighlightHazardAreas0d0a655e =>
      'Gefahrenbereiche hervorheben';

  @override
  String obstaclesHorizontalBufferMc4e67f2c(String arg0) {
    return 'Horizontaler Puffer: $arg0 m';
  }

  @override
  String obstaclesImportedObjectsUnsupportedRecords947e6f13(
    String arg0,
    String arg1,
  ) {
    return '$arg0 importierte Objekte · $arg1 nicht unterstützte Datensätze';
  }

  @override
  String get obstaclesLegendUnavailableOpenThe1690ecec =>
      'Legende nicht verfügbar. Öffnen Sie den offiziellen Link unten.';

  @override
  String obstaclesLocalCacheSourceValidity2bcad0a6(String arg0, String arg1) {
    return 'Lokaler Cache: $arg0 · Gültigkeit der Quelle: $arg1';
  }

  @override
  String obstaclesMetadataChecked61ccc766(String arg0) {
    return 'Metadaten geprüft: $arg0';
  }

  @override
  String get obstaclesNotSupplied25fa1c12 => 'Nicht geliefert';

  @override
  String get obstaclesNurVeroeffentlichteHindernisseFehlende874c23fc =>
      'Nur veröffentlichte Hindernisse · fehlende Objekte möglich.';

  @override
  String obstaclesObstacleImageryOpacity83ec0630(String arg0) {
    return 'Undurchsichtige Bilder: $arg0%';
  }

  @override
  String get obstaclesOfficialWmsLegenda55cc700 => 'Offizielle WMS-Legende';

  @override
  String get obstaclesPlanungshilfeKeineFreigabeOder3f2c05b6 =>
      'Planungshilfe · keine Freigabe oder Abstandsprüfung.';

  @override
  String get obstaclesPublishedObstaclesWms03371ce2 =>
      'Herausgegebene Hindernisse · WMS';

  @override
  String obstaclesPublishedUtcc490142e(String arg0) {
    return 'Veröffentlicht: $arg0 UTC';
  }

  @override
  String obstaclesPublishedValidityUtcb1c25560(String arg0, String arg1) {
    return 'Veröffentlichte Gültigkeit: $arg0 → $arg1 UTC';
  }

  @override
  String get obstaclesRetryObstacleImagerya63bb8aa => 'Retry Hindernis Bilder';

  @override
  String get obstaclesSelectableObstaclesDVectore21d36db =>
      'Auswählbare Hindernisse · 3D-Vektor';

  @override
  String get obstaclesSourceAssetUnavailablebc4a043d =>
      'Nicht verfügbares Quellvermögen';

  @override
  String get obstaclesSourceAttributesf0c00259 => 'Quellattribute';

  @override
  String obstaclesSourceIdUuidc30a2ed8(String arg0, String arg1) {
    return 'Quelle ID: $arg0 UUID: $arg1';
  }

  @override
  String obstaclesSourceMaximumHeight03ba5af5(String arg0) {
    return 'Quelle maximale Höhe: $arg0';
  }

  @override
  String obstaclesSourceUpdated81b6e983(String arg0) {
    return 'Quelle aktualisiert: $arg0';
  }

  @override
  String obstaclesSourceUpdatedRetrieved4bba5e9c(String arg0, String arg1) {
    return 'Quelle aktualisiert: $arg0 abgerufen: $arg1';
  }

  @override
  String get obstaclesSwissAviationObstacles1befa7cf =>
      'Schweizer Luftfahrthindernisse';

  @override
  String obstaclesTopElevation140c7227(String arg0) {
    return 'Höchste Erhebung: $arg0';
  }

  @override
  String obstaclesTypeab721b15(String arg0, String arg1) {
    return 'Typ: $arg0 · $arg1';
  }

  @override
  String get obstaclesVeroeffentlichteHoeheFormUnd8f84873d =>
      'Veröffentlichte Höhe · Form und Breite geschätzt.';

  @override
  String obstaclesVerticesAltitudeModeddeefe8a(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0: $arg1 Eckpunkte · Höhenmodus: $arg2 · $arg3';
  }

  @override
  String get offlineAddOfflineRegion6d71cdd8 => 'Offline-Region hinzufügen';

  @override
  String get offlineAnsichtspufferUndOptionalerLaptop62f2efd5 =>
      'Ansichtspuffer und optionaler Laptop-Export';

  @override
  String get offlineBereichOfflineVorbereiten91421709 =>
      'Bereich offline vorbereiten';

  @override
  String get offlineCachedBaseMapTerrainecfb9aaf =>
      'Cached Grundkarte & Terrain · Abdeckung kann unvollständig oder veraltet sein. Live-Overlays und API-Aktionen erfordern eine separate Überprüfung.';

  @override
  String get offlineCentreLatitudea76075f4 => 'Breitengrad im Zentrum';

  @override
  String get offlineCentreLongitude1cbc4661 => 'Länge des Zentrums';

  @override
  String get offlineDGelaende41d0aed9 => '3D-Gelände';

  @override
  String get offlineDerZusaetzlicheAnsichtspufferEnthaeltb23a8c6c =>
      'Der zusätzliche Ansichtspuffer enthält nur tatsächlich betrachtete Kacheln und kann unvollständig bleiben. Er ist unabhängig vom automatischen offiziellen Regionsdownload oben.';

  @override
  String get offlineGelaendedetailFuerOfflinePaketcbde183b =>
      'Geländedetail für Offline-Paket';

  @override
  String get offlineGesamteSchweiz533dc2ed => 'Gesamte Schweiz';

  @override
  String get offlineGesamteSchweizOfflineVorbereiten7cb30202 =>
      'Gesamte Schweiz offline vorbereiten';

  @override
  String offlineGeschaetzterLokalerSpeicherMibae938fa8(
    String arg0,
    String arg1,
  ) {
    return 'Geschätzter lokaler Speicher: $arg0 MiB · $arg1 Kacheln. Originaldaten und Karteninhalt beeinflussen Downloadmenge und Dauer. Vorhandene Region bleibt bis zum erfolgreichen Abschluss aktiv.';
  }

  @override
  String offlineGespeicherteKartendatenMibDerf8af680d(String arg0) {
    return 'Gespeicherte Kartendaten: $arg0 MiB. Der zusätzliche Puffer für beim Betrachten geladene Kacheln ist auf 256 MiB begrenzt.';
  }

  @override
  String get offlineGewuenschtenMittelpunktAufDem999be642 =>
      'Gewünschten Mittelpunkt auf dem Globe antippen.';

  @override
  String get offlineGrosserDownloadDetailUnd759ef111 =>
      'Großer Download. Detail und Ebenen bestimmen den Speicherbedarf; der Browser prüft seinen verfügbaren Speicher vor dem Start.';

  @override
  String get offlineHoehenAusSwissaltiD5966fff3 =>
      'Höhen aus swissALTI3D; gewählte Detailstufe bestimmt die Auflösung im Globe.';

  @override
  String get offlineMaximumImageryDetaile83a21f6 =>
      'Maximale Abbildungsdetails';

  @override
  String get offlineMittelpunktAufGlobeMarkierenec84f922 =>
      'Mittelpunkt auf Globe markieren';

  @override
  String get offlineMittelpunktAufKarteWaehlen0129acc2 =>
      'Mittelpunkt auf Karte wählen';

  @override
  String get offlineMittelpunktUebernehmen654f1ce1 => 'Mittelpunkt übernehmen';

  @override
  String get offlineNeueVorbereitungsdateif618c1fc => 'Neue Vorbereitungsdatei';

  @override
  String get offlineOfflineBereichVorbereitene86172db =>
      'Offline-Bereich vorbereiten';

  @override
  String get offlineOfflineMapRegionse6d5c4de => 'Offline-Karten-Regionen';

  @override
  String get offlineOfflinePaketImportieren3e6d35a5 =>
      'Offline-Paket importieren';

  @override
  String get offlineOfflineVerfuegbareKartenebenen3eca4f37 =>
      'Offline verfügbare Kartenebenen';

  @override
  String get offlineRefreshStorageStatus889bb274 =>
      'Speicherstatus aktualisieren';

  @override
  String get offlineRegionAktualisieren789dbcf6 => 'Region aktualisieren';

  @override
  String get offlineRemoveCachedRegion3fb1230e =>
      'Zwischengespeicherte Region entfernen';

  @override
  String get offlineSaveRegionForCaching87de5600 =>
      'Region für das Caching speichern';

  @override
  String get offlineSpeicherlimitFuerDiesenDownload142a1d01 =>
      'Speicherlimit für diesen Download';

  @override
  String offlineStufed0ed7705(String arg0, String arg1) {
    return 'Stufe $arg0$arg1';
  }

  @override
  String get offlineSupportedMapb531fbb7 => 'Unterstützte Karte';

  @override
  String offlineTilesMib2f032565(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
  ) {
    return '$arg0 / $arg1 Kacheln · $arg2 MiB\n$arg3 · $arg4\n$arg5';
  }

  @override
  String get offlineTopographicd28af3fe => 'Topografisch';

  @override
  String get offlineUnterbrocheneAufbereitungVerwerfenf0149e36 =>
      'Unterbrochene Aufbereitung verwerfen';

  @override
  String get offlineUseCachedBaseMapcac83b59 =>
      'Zwischengespeicherte Grundkarte und Terrain verwenden';

  @override
  String get offlineVorbereitungsdateiFuerLaptopSpeichern42dca4b8 =>
      'Vorbereitungsdatei für Laptop speichern';

  @override
  String offlineZoomb67baf86(String arg0) {
    return '$arg0 vergrößern';
  }

  @override
  String get offlineZusaetzlicheDatierteMomentaufnahmenAktualisieren66eddff9 =>
      'Zusätzliche datierte Momentaufnahmen aktualisieren';

  @override
  String outdoorAbgerufenAmtlichesPublikationsdatumNicht1eb563a2(String arg0) {
    return 'Abgerufen: $arg0 · amtliches Publikationsdatum nicht mitgeteilt';
  }

  @override
  String get outdoorAmtlicheLegendeUndQuelle17cac2a2 =>
      'Amtliche Legende und Quelle';

  @override
  String get outdoorAmtlicheWegenetzeee6981c0 => 'Amtliche Wegenetze';

  @override
  String get outdoorAmtlicherOutdoorKontextab221e59 =>
      'Amtlicher Outdoor-Kontext';

  @override
  String get outdoorAusgewaehlterKartenpunktd902892e =>
      'Ausgewählter Kartenpunkt';

  @override
  String get outdoorAuszugAktualisieren55f223d5 => 'Auszug aktualisieren';

  @override
  String get outdoorAuszugAufKarteAnzeigen9105f450 =>
      'Auszug auf Karte anzeigen';

  @override
  String get outdoorBezugWaehlendcf73635 => 'Bezug wählen';

  @override
  String get outdoorDetailsUmDenKartenpunktdbe266e7 =>
      'Details um den Kartenpunkt abrufen';

  @override
  String get outdoorDieseDetailauszuegeWerdenNur71ff8d83 =>
      'Diese Detailauszüge werden nur im Arbeitsspeicher gehalten. Kantonsübergreifende Vektorpakete und deren Weitergabe benötigen jeweils passende Nutzungsbedingungen.';

  @override
  String get outdoorErgebnisgrenzeErreichtWeitereObjektefa8b4a21 =>
      'Ergebnisgrenze erreicht · weitere Objekte können fehlen.';

  @override
  String get outdoorFlugrouteAuswaehlenLetzteeb04100f =>
      'Flugroute auswählen · letzte 100';

  @override
  String get outdoorGespeicherteFlugroutede6dec82 => 'Gespeicherte Flugroute';

  @override
  String get outdoorGespeicherterOrt25ce06f0 => 'Gespeicherter Ort';

  @override
  String outdoorKartenebeneQuelldatumNichtVom78282b34(String arg0) {
    return 'Kartenebene: $arg0 · Quelldatum nicht vom Dienst mitgeteilt';
  }

  @override
  String get outdoorKartenkachelnErneutLadend22d2379 =>
      'Kartenkacheln erneut laden';

  @override
  String get outdoorKeineObjekteImAuszug3e189c68 =>
      'Keine Objekte im Auszug gefunden. Das bestätigt keine offene oder freie Route.';

  @override
  String get outdoorNaturUndWildruhezonen7304b9ec => 'Natur und Wildruhezonen';

  @override
  String get outdoorNochKeineFlugroutenGespeichertc7aeb7bc =>
      'Noch keine Flugrouten gespeichert';

  @override
  String get outdoorOffizielleDetails573452dd => 'Offizielle Details';

  @override
  String get outdoorOnlineEbeneOfflineKacheldownload52ce6e5a =>
      'Online-Ebene · Offline-Kacheldownload nicht freigegeben. Abdeckung und Aktualität können lückenhaft sein.';

  @override
  String get outdoorOriginalattribute38290624 => 'Ursprünglicher Attribut';

  @override
  String get outdoorOutdoorEbeneKonnteNichtdae0b0f9 =>
      'Outdoor-Ebene konnte nicht geändert werden. Erneut versuchen.';

  @override
  String outdoorQuellenIdba307a43(String arg0, String arg1) {
    return 'Quellen-ID: $arg0\n$arg1';
  }

  @override
  String get outdoorRouteOderAuszugUeberschreitene46a9d8f =>
      'Route oder Auszug überschreiten das Größenlimit für den vollständigen Einzelabgleich. Bitte einen kürzeren Abschnitt wählen. Die Originalgeometrie bleibt erhalten.';

  @override
  String get outdoorSperrungenUndUmleitungenc019df11 =>
      'Sperrungen und Umleitungen';

  @override
  String get preflightAnyDrone97497506 => 'Irgendeine Drohne';

  @override
  String get preflightAnyFlightPlan5d58f177 => 'Jeder Flugplan';

  @override
  String preflightChecklistCouldNotBe467e09ff(String arg0) {
    return 'Checkliste konnte nicht gespeichert werden: $arg0';
  }

  @override
  String get preflightChecklistTemplate9368b50e => 'Vorlage für die Checkliste';

  @override
  String get preflightCompletionIsSavedOna7956e8f =>
      'Der Fortschritt wird auf diesem Gerät gespeichert. Beginne für jeden Flug eine neue Checkliste. Das Abhaken erteilt keine Flugfreigabe.';

  @override
  String get preflightEditItemsAssociations032f939c =>
      'Elemente & Verknüpfungen bearbeiten';

  @override
  String get preflightFlightPlan4cb79e47 => 'Flugplan';

  @override
  String get preflightItemsOnePerLinee1c97f47 => 'Artikel · eins pro Zeile';

  @override
  String get preflightLocalChecklistsUnavailableReopende49292a =>
      'Lokale Checklisten sind nicht verfügbar. Öffnen Sie diesen Bildschirm erneut, um zu versuchen.';

  @override
  String get preflightNewTemplate865095cf => 'Neue Vorlage';

  @override
  String get preflightPreflightTelemetry0632b0c8 => 'Vorflug & Telemetrie';

  @override
  String preflightReusableTemplateItems8ec2077a(String arg0) {
    return 'Wiederverwendbare Vorlage · $arg0 Elemente';
  }

  @override
  String get preflightSaveLocally87522ab5 => 'Lokal speichern';

  @override
  String get preflightStartWithAllItems29c20291 =>
      'Starten Sie mit allen Elementen ungecheckt';

  @override
  String get preflightUnsupportedChecklistDatabe2cc486 =>
      'Nicht unterstützte Checklisten-Daten';

  @override
  String get preflightUpToItemsChangeda0ae0a06 =>
      'Bis zu 100 Elemente. Veränderte Elemente oder Assoziationen müssen erneut überprüft werden.';

  @override
  String get profilesAnderungenVerwerfen9af398c1 => 'Änderungen verwerfen?';

  @override
  String get profilesAusVorlage7a27bf2c => 'Aus Vorlage';

  @override
  String get profilesBearbeiten104f3bfd => 'Bearbeiten';

  @override
  String get profilesBeibehalten94ebabfe => 'Beibehalten';

  @override
  String get profilesDuplizieren8524c5cd => 'Duplizieren';

  @override
  String get profilesEigenesProfila1a7ad19 => 'Eigenes Profil';

  @override
  String get profilesExportieren4e4a0d71 => 'Exportieren';

  @override
  String get profilesHintergrundkarte2f67406f => 'Hintergrundkarte';

  @override
  String get profilesKartenstartwerteBeimAktivierenf2e700fc =>
      'Kartenstartwerte beim Aktivieren';

  @override
  String get profilesMaximalProfileZumHinzufuegene6d6ba7e =>
      'Maximal 32 Profile. Zum Hinzufügen zuerst ein Profil löschen.';

  @override
  String get profilesOhneProfilAlleWerkzeuge5ab1fd0c =>
      'Ohne Profil · alle Werkzeuge';

  @override
  String get profilesProfilBearbeitend4e69e62 => 'Profil bearbeiten';

  @override
  String get profilesProfilSpeichernfeda7fb0 => 'Profil speichern';

  @override
  String get profilesProfilWurdeNichtGespeichert24e088e3 =>
      'Profil wurde nicht gespeichert. Dein Entwurf bleibt erhalten; bitte erneut versuchen.';

  @override
  String get profilesProfilaktionFehlgeschlagenBitteErneutfc851528 =>
      'Profilaktion fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get profilesSatellit6020d8ce => 'Satellit';

  @override
  String get profilesTopografisch52f1415e => 'Topografisch';

  @override
  String get profilesUberspringenAlleWerkzeuge95410f7f =>
      'Überspringen · alle Werkzeuge';

  @override
  String get profilesVorlageWaehlen7df6eb54 => 'Vorlage wählen';

  @override
  String get profilesVorlagenSindFreiAnpassbarff309b1d =>
      'Vorlagen sind frei anpassbar. Alle Werkzeuge bleiben erreichbar.';

  @override
  String get profilesWerkzeugePassendZuDeiner8e101852 =>
      'Werkzeuge passend zu deiner Aktivität';

  @override
  String profilesWerkzeugeSchnellaktionenc271b295(String arg0, String arg1) {
    return '$arg0 Werkzeuge · $arg1 Schnellaktionen';
  }

  @override
  String get profilesWirdGespeichert129ed064 => 'Wird gespeichert…';

  @override
  String get profilesWomitMoechtestDuStartenee1d09d8 =>
      'Womit möchtest du starten?';

  @override
  String get radioADroneCanUsea385a1c2 =>
      'Eine Drohne kann mehrere unabhängige Konfigurationen verwenden.';

  @override
  String get radioAddEquipmentProfile85022529 => 'Ausrüstungsprofil hinzufügen';

  @override
  String get radioAddEquipmentda5d2801 => 'Ausrüstung hinzufügen';

  @override
  String get radioCreateIndependentControlAndf7437069 =>
      'Erstellen Sie unabhängige Steuer-und Video-Konfigurationen. Lassen Sie unbekannte Werte leer. Maximale Leistung ist der Sender-Ausgang vor Antennengewinn und Kabelverlust; notieren Sie den anwendbaren Modus und Quelle unten.';

  @override
  String get radioDeleteEquipmentProfile0d5a874b =>
      'Ausrüstungsprofil löschen?';

  @override
  String get radioEditEquipment92a5da88 => 'Geräte bearbeiten';

  @override
  String get radioEditEquipmentProfilef984d1a0 =>
      'Ausrüstungsprofil bearbeiten';

  @override
  String get radioEquipmentDetailse402502a => 'Angaben zur Ausrüstung';

  @override
  String get radioNoDroneProfilesYetd1f93a9e =>
      'Noch keine Drohnenprofile. Sie können diese Ausrüstung später zuweisen.';

  @override
  String radioPermanentlyDeleteAndIts53a62100(String arg0) {
    return 'Löschen Sie dauerhaft \"$arg0\" und seine Aufgaben? Drohnenprofile und andere Gerätekonfigurationen werden beibehalten.';
  }

  @override
  String get radioRadioVideoEquipment93933cea => 'Funk- und Videogeräte';

  @override
  String get radioRecordedSpecificationsUnknownValues7c5d9e94 =>
      'Aufgenommene Spezifikationen. Unbekannte Werte bleiben nicht aufgezeichnet. Maximale Sendeleistung ist vor Antennengewinn und Kabelverlust; die Betriebseinstellung kann niedriger sein.';

  @override
  String get radioRefreshDronesc1a9ec7c => 'Drohnen aktualisieren';

  @override
  String radioRemovedDroneUncheckTo9fe8cb40(String arg0) {
    return 'Entfernte Drohne (#$arg0) — Auschecken, um fortzufahren';
  }

  @override
  String get radioSystemCategorycc8be0ee => 'Systemkategorie';

  @override
  String get radioThisEquipmentProfileNo59977e24 =>
      'Dieses Geräteprofil existiert nicht mehr.';

  @override
  String get radioUnableToLoadEquipment2a0842d8 =>
      'Geräteprofile können nicht geladen werden.';

  @override
  String get radioUnableToLoadThise6da0797 =>
      'Dieses Geräteprofil kann nicht geladen werden.';

  @override
  String get routesAboveTerrainAgle2867f26 => 'Oberhalb des Geländes (AGL)';

  @override
  String get routesAirspeedMSPower705d4a92 =>
      'Luftgeschwindigkeit (m/s); Leistung (W)';

  @override
  String get routesApplyEquipmente3cb5483 => 'Geräte anwenden';

  @override
  String get routesApplyHeightAndSpeed4746e071 =>
      'Höhe und Geschwindigkeit auf alle Wegpunkte anwenden';

  @override
  String get routesApplyPlanningAssumptions8576b420 =>
      'Anwenden von Planungsannahmen';

  @override
  String get routesApplyRouteConstraintsf13386d6 =>
      'Anwendung von Routenbeschränkungen';

  @override
  String get routesApplyWaypointSettingsd66af84a =>
      'Wegpunkt-Einstellungen anwenden';

  @override
  String get routesApproximateDroneRadiuse7919b03 => 'Ungefährer Drohnenradius';

  @override
  String get routesApproximateGreatCircleDistances9807e68d =>
      'Approximate great-circle distances. Recorded segment times are used when available; modeled times ignore gusts and manoeuvres. Confirm the drone can achieve the required speed and climb rate.';

  @override
  String get routesAssignAnIndividualBatteryb5d65676 =>
      'Stellen Sie eine individuelle Batterie in Route Ausrüstung, um Kapazität und Reserve zu vergleichen. Kapazitäten von alternativen Packs werden nie hinzugefügt.';

  @override
  String get routesBackb52b36b7 => 'Zurück';

  @override
  String get routesBatteriesAreAlternativePackse90e4726 =>
      'Batterien sind alternative Packs für einen Flug. Ihre Kapazitäten werden individuell bewertet.';

  @override
  String get routesBatteryToInspectAnde2d405d0 =>
      'Batterie zu prüfen und zu markieren';

  @override
  String routesBazlFocaPublishedRetrievedede87b71(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'BAZL / FOCA · $arg0 · veröffentlicht $arg1 · abgerufen $arg2';
  }

  @override
  String routesBufferMSelectedCategories6b55c391(String arg0, String arg1) {
    return 'Puffer $arg0 m · ausgewählte Kategorien: $arg1';
  }

  @override
  String get routesBvlosPlannedVerifyThe1d105130 =>
      'BVLOS geplant: Prüfen Sie die erforderliche Betriebskategorie und Zulassung mit FOCA.';

  @override
  String get routesCalculateCurrentRoutea1896281 => 'Aktuelle Route berechnen';

  @override
  String get routesCalculatingRoute9e861349 => 'Berechnung der Route..';

  @override
  String get routesCancelChecks480fd8da => 'Überprüfungen abbrechen';

  @override
  String get routesCancelMove23385b79 => 'Bewegung abbrechen';

  @override
  String get routesCheckCurrentRoute87fb7469 => 'Aktuelle Route überprüfen';

  @override
  String get routesCheckRouteAirspaced4d383e6 =>
      'Luftraum der Streckenkontrolle';

  @override
  String get routesChecking820d6004 => 'Überprüft..';

  @override
  String get routesChooseASpotToc0d9ecad =>
      'Wählen Sie einen Punkt, um den ersten Wegpunkt an den gespeicherten Koordinaten hinzuzufügen.';

  @override
  String get routesClearanceIsIncompleteSet1a518685 =>
      'Clearance ist unvollständig: Legen Sie eine Höhe für jeden Wegpunkt fest. Absolute Höhen benötigen WGS84 Ellipsoid-Referenz; andere Datume können hier nicht konvertiert werden.';

  @override
  String get routesClickTheNewPosition88166db4 =>
      'Klicken Sie auf die neue Position auf der Karte.';

  @override
  String get routesCloseAnalysis232a00e4 => 'Enge Analyse';

  @override
  String get routesConfigureConstraintsf3a3a710 => 'Einschränkungen einrichten';

  @override
  String get routesConfiguredHeightsAreShowna9eb24e8 =>
      'Konfigurierte Höhen werden in 3D angezeigt. Punkte markiert * verwenden eine 30 m AGL-Vorschau, da ihre Höhe fehlt oder ein nicht unterstütztes Datum verwendet. Ausgewählte Routen bleiben in der Bodenansicht sichtbar.';

  @override
  String routesConfiguredLegalCeilingMe4d4520c(String arg0, String arg1) {
    return 'Konfigurierte gesetzliche Obergrenze: $arg0 m AGL · Betriebsobergrenze: $arg1 m AGL';
  }

  @override
  String get routesCopyAvailableDroneValues12ac7ef8 =>
      'Verfügbare Drohnenwerte für die Überprüfung kopieren';

  @override
  String get routesCreateBatteryProfilesIn4e35a626 =>
      'Erstellen Sie zuerst Batterieprofile in Ausrüstung.';

  @override
  String routesCriticalConservativeSegmentsfecdcba2(String arg0) {
    return 'Kritisch konservative Segmente: $arg0';
  }

  @override
  String get routesCurveSourceMeasurementConditions241dc3af =>
      'Kurvenquelle / Messbedingungen';

  @override
  String get routesDInfrastructureClearanceAdvisory02222668 =>
      '3D-Infrastrukturabfertigung (Beratung)';

  @override
  String get routesDRoutePreviewIs18af1855 =>
      '3D-Routenvorschau wird ausgeblendet, bis ein detailliertes Terrain verfügbar ist.';

  @override
  String get routesDeletePoint24dc6e65 => 'Ziffer streichen';

  @override
  String get routesDiscardRouteChanges71a9dbd8 => 'Routenänderungen verwerfen?';

  @override
  String get routesEditPlanningAssumptions84735a68 =>
      'Planungsannahmen bearbeiten';

  @override
  String get routesEmptyMeansUnknownApplies42bd9aa3 =>
      'Leer bedeutet unbekannt. Gilt für das nächste Segment.';

  @override
  String get routesEmptyMeansUnverifiedNotb3d057c4 =>
      'Leer bedeutet ungeprüft / nicht konfiguriert.';

  @override
  String routesExaminedUpToModel89dfac48(String arg0, String arg1) {
    return 'Bis zu $arg0 Musterproben untersucht; $arg1 unbekannte Höhensonden.';
  }

  @override
  String routesExport98e40159(String arg0) {
    return '$arg0 exportieren';
  }

  @override
  String get routesExportGeojsonbdc0686f => 'GeoJSON exportieren';

  @override
  String get routesExportGpxed2fd89b => 'GPX exportieren';

  @override
  String get routesFertig708ad54e => 'Fertig';

  @override
  String get routesFilterSavedSpotsf0054cfd => 'Gespeicherte Stellen filtern';

  @override
  String get routesFlightRoutescf03df8f => 'Flugrouten';

  @override
  String get routesFpvWithObserver0eb784aa => 'FPV mit Beobachter';

  @override
  String get routesHeightConstraintseeba8204 => 'Höhenbeschränkungen';

  @override
  String get routesHeightNotSpecifiedfec716ae => 'Höhe nicht angegeben';

  @override
  String get routesHeightReferenceec9764fc => 'Bezugshöhe';

  @override
  String get routesHeightSpeedd20ac922 => 'Höhe & Geschwindigkeit';

  @override
  String routesHorizontalDAirspeedMeb450600(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
    String arg6,
    String arg7,
  ) {
    return '$arg0 horizontal · $arg1 3D\nAirspeed $arg2 m/s ($arg3) · $arg4 ($arg5) · clearance $arg6\nGroundspeed: $arg7 m/s (simulated)';
  }

  @override
  String get routesHorizontalObstacleProximityb3d4572a =>
      'Horizontale Hindernisnähe';

  @override
  String get routesImportLocalBridgeSupport8cc6480f =>
      'Lokale Bridge/Support-Geometrie importieren (JSON)';

  @override
  String routesImportRoutes1b71c46b(String arg0) {
    return 'Importieren von $arg0-Routen?';
  }

  @override
  String get routesImportRoutesbbcd66ff => 'Einfuhrrouten';

  @override
  String get routesIncludeReturnToTakeoff90a464ac =>
      'Einschließlich Rückkehr zum Start';

  @override
  String get routesIncludeSteadyWind4a449918 => 'Einschließlich Dauerwind';

  @override
  String routesInfrastructureImportFailed68671f9d(String arg0) {
    return 'Infrastruktur-Import fehlgeschlagen: $arg0';
  }

  @override
  String get routesKeepEditingd4d9e382 => 'Weiterarbeiten';

  @override
  String get routesLevelFlightPowerCurve5cf82060 => 'Pegelflug-Leistungskurve';

  @override
  String routesLocalBridgeSupportSurfacesc5994174(String arg0) {
    return 'Lokale Brücken-/Stützflächen: $arg0. Importierte Abmessungen werden nicht unabhängig überprüft.';
  }

  @override
  String get routesLocalGeometryLoadedRe52972d93 =>
      'Lokale Geometrie geladen. Überprüfen Sie die aktuelle Route erneut. Quellenansprüche bleiben ungeprüft.';

  @override
  String get routesMAglPreviewOnly1b6aeb60 => '* = nur 30 m AGL Vorschau';

  @override
  String get routesManualVerificationRequireda6416489 =>
      'Manuelle Überprüfung erforderlich';

  @override
  String get routesMapCommandFailedPleasea043b9a7 =>
      'Der Map-Befehl ist fehlgeschlagen.';

  @override
  String get routesMovePoint4cfb85e2 => 'Punkt verschieben';

  @override
  String get routesNewLocalCopiesArec3efa17b =>
      'Neue lokale Kopien werden erstellt. Bestehende Routen und Ausrüstungszuweisungen bleiben erhalten.';

  @override
  String get routesNewRoutef39fa269 => 'Neue Route';

  @override
  String get routesNoConfiguredLimitExceedance5e7f8c0c =>
      'Keine konfigurierte Grenzüberschreitung in den ausgewerteten Eingängen erkannt.';

  @override
  String get routesNoConflictFoundIn4baaf950 =>
      'In den verfügbaren lokalen Modellen wurde kein Konflikt gefunden. Der Abstand zu Bauwerken außerhalb dieses Bereichs ist ungeprüft.';

  @override
  String get routesNoCurrentInfrastructureAssessmentc3d9ef92 =>
      'Keine aktuelle Infrastrukturbewertung. Verwendung Aktuelle Route prüfen.';

  @override
  String get routesNoDroneAssigned1a3203b5 => 'Keine Drohne zugewiesen';

  @override
  String get routesNoHorizontalMatchIne04da067 =>
      'Keine horizontale Übereinstimmung im geprüften Datensatz. Unbeschränkter Luftraum wird nicht ermittelt.';

  @override
  String get routesNoMatchingSavedSpots783f2c6f =>
      'Keine passenden gespeicherten Spots.';

  @override
  String get routesNoProximityDetectedIn75f77f3a =>
      'Keine Nähe, die in den ausgewerteten Daten erkannt wird. Dies stellt keine Hindernis-freie Route dar.';

  @override
  String get routesNoSavedFlightRoutesa271a04f =>
      'Noch keine gespeicherten Flugrouten. Erstellen Sie eine Route und platzieren Sie Wegpunkte auf der Karte.';

  @override
  String get routesNoSavedRoutesCreateca237d75 =>
      'Keine gespeicherten Routen. Erstellen Sie eine in Flugrouten.';

  @override
  String get routesNoSavedSpotsYet044a3542 =>
      'Noch keine gespeicherten Spots. Benutzen Sie die Ortssuche oder tippen Sie auf die Karte.';

  @override
  String get routesOfficialFocaFlightRulesa3ad892e =>
      'Offizielle FOCA-Flugregeln';

  @override
  String get routesOptInOnlyAvailable291368ee =>
      'Optional. Die Prüfung verwendet die verfügbaren lokalen Oberflächenmodelle. Aus 3D-Kacheln allein lässt sich kein sicherer Abstand ableiten.';

  @override
  String routesOptimisticConservativeReserveOf8919c819(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Optimistisch ×$arg0 · konservativ ×$arg1 · Reserve $arg2% der Nennkapazität.';
  }

  @override
  String get routesOutgoingAirspeedMS43d6115b =>
      'Abfliegende Fluggeschwindigkeit (m/s)';

  @override
  String get routesPlannedVisibilityScenario8c3dd9f7 =>
      'Geplantes Sichtbarkeitsszenario';

  @override
  String get routesPlanningAssumptions61ebf317 => 'Planungsannahmen';

  @override
  String routesPowerCurveSource26cb2f6e(String arg0) {
    return 'Leistungskurvenquelle: $arg0';
  }

  @override
  String get routesPowerIsInterpolatedBy90df4a57 =>
      'Die Leistung wird durch die Luftgeschwindigkeit interpoliert und skaliert durch (Take-Off-Masse / Referenzmasse)^1.5. Steigt hinzu m·g·Höhe / Effizienz. Abstieg nicht Energie zurückgewinnen. Dies setzt ein multirotor-ähnliches Verhalten voraus.';

  @override
  String get routesProcessingLimitReachedThe59278caf =>
      'Verarbeitungsgrenze erreicht. Die Prüfung oder die Ergebnisliste ist unvollständig.';

  @override
  String routesPublishedCoverageIsIncomplete8fda9cde(String arg0) {
    return 'Die veröffentlichte Berichterstattung ist unvollständig. $arg0 nicht unterstützte Quellaufzeichnungen. Fehlende Objekte und Kabel können vorhanden sein; Kategorie Filter schließen andere Objekte aus.';
  }

  @override
  String get routesRecalculateRoute3aa2250f => 'Route neu berechnen';

  @override
  String routesRecordedChargePackStatus6e905850(String arg0, String arg1) {
    return 'Aufgenommene Ladung: $arg0% · Packstatus: $arg1.';
  }

  @override
  String get routesRecordingDetailsUnavailable028143fa =>
      'Aufzeichnungsdetails nicht verfügbar';

  @override
  String get routesRedSegmentsTerrainReservefbd059b9 =>
      'Rote Segmente: Gelände / Reserveschätzungen · Offene Analyse';

  @override
  String get routesReplacesExistingHeightAndbb3345ca =>
      'Ersetzt vorhandene Höhen- und Geschwindigkeitseinstellungen für diesen Entwurf. Rückgängig ist verfügbar.';

  @override
  String get routesReserveAndUncertainty53aafdf4 => 'Reserve und Unsicherheit';

  @override
  String routesRetrieved06b37dcd(String arg0, String arg1, String arg2) {
    return '$arg0 · $arg1 · abgerufen $arg2';
  }

  @override
  String get routesRetryLoading54b15f12 => 'Beladen erneut testen';

  @override
  String get routesRetryRouteListd4c0bbae => 'Routenliste wiederholen';

  @override
  String get routesRetryRoutePreview25273ee7 => 'Routenvorschau wiederholen';

  @override
  String get routesReturnEnergyIsUnknownb2869d98 =>
      'Die Rücklaufenergie ist unbekannt; keine vollständige Machbarkeitsschätzung ist verfügbar.';

  @override
  String get routesReturnFlightIsExcluded22c87afc =>
      'Der Rückflug ist vom Budget ausgeschlossen.';

  @override
  String get routesReviewCoordinatesAndHeight88280ee0 =>
      'Prüfen Sie die Koordinaten und Höhenangaben vor der Planung eines Fluges.';

  @override
  String get routesRouteAnalysise04589ed => 'Streckenanalyse';

  @override
  String get routesRouteConstraints7de90cfc => 'Streckenbeschränkungen';

  @override
  String get routesRouteEditor9c06eac0 => 'Routeneditor';

  @override
  String get routesRouteEquipmentc4206690 => 'Streckenausrüstung';

  @override
  String get routesRouteOptions55d80b02 => 'Routenoptionen';

  @override
  String get routesRouteSavedLocally324d209a => 'Route lokal gespeichert';

  @override
  String routesSMah1c86b217(String arg0, String arg1, String arg2) {
    return '${arg0}S · $arg1 mAh · $arg2';
  }

  @override
  String routesSamplesHaveUnknownClearance53029fc6(String arg0) {
    return 'An $arg0 Messpunkten ist der Abstand unbekannt. Höhenlimits zwischen den Messpunkten sind ungeprüft.';
  }

  @override
  String get routesSavedc0ae8f6e => 'Gespeichert';

  @override
  String get routesSearchPlace48c850ed => 'Ort der Suche';

  @override
  String routesSegment2e9d80c3(String arg0) {
    return 'Segment $arg0';
  }

  @override
  String routesSegmentMHorizontalSource0f6d6b0d(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
  ) {
    return 'Segment $arg0 · $arg1 m horizontal $arg2 Quelle: $arg3$arg4';
  }

  @override
  String routesSegmentSimulatedSeparationM10cc26fd(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
  ) {
    return 'Segment $arg0 · simulierte Trennung $arg1 m $arg2 · $arg3 · $arg4 / $arg5 Nur Modellgeometrie; nicht wirkliche Flugfreiheit.';
  }

  @override
  String routesSegments5ae8cd98(String arg0, String arg1, String arg2) {
    return '$arg0\nSegments $arg1\n$arg2';
  }

  @override
  String get routesShowDInfrastructureClearancedcae1002 =>
      '3D Infrastructure Clearance Ergebnisse auf Karte anzeigen';

  @override
  String get routesShowEntireRoute7e936417 => 'Ganze Route anzeigen';

  @override
  String routesShowOnMapa1a4e0a9(String arg0) {
    return '$arg0 auf Karte anzeigen';
  }

  @override
  String routesSimulateFlight6c31fd20(String arg0) {
    return 'Flug simulieren: $arg0';
  }

  @override
  String get routesSonnenUndMondzeit1999dfbc => 'Sonnen- und Mondzeit';

  @override
  String get routesSonnenUndMondzeitDer90b0d9c4 =>
      'Sonnen- und Mondzeit der Route';

  @override
  String routesSteadyWindAssumptionM2884cea1(String arg0, String arg1) {
    return 'Steady Wind Annahme: $arg0 m/s von $arg1° true. Crosswind Kompensation ist enthalten; ein unerreichbarer Track bleibt unbekannt.';
  }

  @override
  String get routesStoredOnThisDevicece3661a2 => 'Auf diesem Gerät gespeichert';

  @override
  String get routesTapMapToAdddf97da9f =>
      'Tippen Sie auf Karte zum Hinzufügen · Wählen Sie einen Wegpunkt zum Bearbeiten';

  @override
  String get routesTapTheProfileTo8cbd2ae2 =>
      'Tippen Sie auf das Profil, um eine Probe zu prüfen. Geplante Höhe verwendet die primäre Farbe; Terrain verwendet grau.';

  @override
  String get routesTerrainAndPlannedAltitude8cc1136a =>
      'Gelände und geplante Höhe · WGS84 ellipsoid';

  @override
  String get routesTerrainClearanceRemainsUnknown8f8dbef8 =>
      'Der Geländeabstand bleibt unbekannt. Aus der Energiebilanz lässt sich die Sicherheit der Route nicht ableiten.';

  @override
  String routesTerrainSamples14ad50c1(String arg0, String arg1) {
    return 'Geländemesspunkte $arg0/$arg1';
  }

  @override
  String routesTerrainSamplingWgsEllipsoide722c804(String arg0) {
    return 'Bodenprobe: $arg0. WGS84 Ellipsenhöhen.';
  }

  @override
  String get routesTheAssignedDroneWas08ea7895 =>
      'Die zugewiesene Drohne wurde gelöscht. Wählen Sie ein anderes Profil oder löschen Sie die Zuordnung.';

  @override
  String get routesTheCurrentDraftHas0d9d9939 =>
      'Der aktuelle Entwurf hat Änderungen nicht gespeichert.';

  @override
  String get routesTheLevelFlightPower308a2473 =>
      'Die Level-Flight-Leistungskurve wird ohne Extrapolation interpoliert und massmäßig skaliert^1.5. Kletterarbeiten werden mit der konfigurierten Effizienz hinzugefügt; Abstieg hat keine Energierückgewinnung.';

  @override
  String get routesTheSameConfiguredTakeoff20e0843f =>
      'Die gleiche konfigurierte Startmasse wird für alternative Packs verwendet. Passen Sie sie für die installierte Batterie an.';

  @override
  String get routesUasZoneIntersections5bc17c8d => 'UAS-Zonenabschnitte';

  @override
  String get routesUnableToFrameThisbad8013a =>
      'Diese Route kann nicht gerahmt werden.';

  @override
  String get routesUnableToLoadSaved7cf6f705 =>
      'Gespeicherte Stellen können nicht geladen werden';

  @override
  String get routesUnableToLoadSavedda813904 =>
      'Gespeicherte Routen können nicht geladen werden.';

  @override
  String get routesUndoWaypointChange8a12e7bc =>
      'Wegpunktänderung rückgängig machen';

  @override
  String get routesUnsaved2ab06e25 => 'Nicht gerettet';

  @override
  String get routesUnverifiedeb27a190 => 'Unbestätigt';

  @override
  String get routesVisibilityScenarioUnverifiedConfirmd7996cb0 =>
      'Sichtszenario nicht überprüft. VLOS/FPV-Beobachteranforderungen und jegliche BVLOS-Zulassung bestätigen.';

  @override
  String get routesVlosPlannedVerifyActual5fbdce06 =>
      'VLOS geplant: Überprüfung der tatsächlichen Sicht und des umgebenden Luftraums vor Ort. Ein Kartenradius stellt keine VLOS fest.';

  @override
  String routesWaypoint2315aa1f(String arg0) {
    return 'Wegpunkt $arg0';
  }

  @override
  String get routesWaypointActionsf5f1d082 => 'Wegpunktaktionen';

  @override
  String routesWaypointMS5220bb0f(String arg0, String arg1, String arg2) {
    return 'Wegpunkt $arg0 · $arg1 · $arg2 m/s';
  }

  @override
  String routesWaypoints31c92956(String arg0, String arg1) {
    return '$arg0 · $arg1 Wegpunkte';
  }

  @override
  String get routesWaypoints8de9ac08 => 'Wegpunkte';

  @override
  String routesWaypointsbc27edbc(String arg0) {
    return '$arg0 Wegpunkte';
  }

  @override
  String get routesWindIsExcludedEnablee95610f8 =>
      'Wind ist ausgeschlossen. Ermöglichen Sie eine manuelle Windannahme in Planung Annahmen.';

  @override
  String get routesWirdMitDerRoutece20d1c9 =>
      'Wird mit der Route gespeichert. Eine feste Zeit bleibt stehen; „Jetzt“ läuft mit der Gerätezeit.';

  @override
  String get settingsEinstellungKonnteNichtUebernommenf7be0131 =>
      'Einstellung konnte nicht übernommen werden. Bitte erneut versuchen.';

  @override
  String get settingsFlugsimulatorControllerb56cd9ea =>
      'Flugsimulator & Controller';

  @override
  String get settingsFuerDieNaechsteSimulationfde989c1 =>
      'Für die nächste Simulation';

  @override
  String get settingsHilfeb74af50b => 'Hilfe';

  @override
  String get settingsKarteneinstellungenZuruecksetzen65775760 =>
      'Karteneinstellungen zurücksetzen';

  @override
  String get settingsLuftraumquellene57512f8 => 'Luftraumquellen';

  @override
  String get settingsOfflineKartenDatenefa573cc => 'Offline-Karten & Daten';

  @override
  String get settingsOpenSourceLizenzen225c9494 => 'Open-Source-Lizenzen';

  @override
  String get settingsPrivacyPolicy7ceacdca => 'Datenschutzerklärung';

  @override
  String get settingsSprache3d9f5cb4 => 'Sprache';

  @override
  String get settingsStandortanzeige3f41a9ee => 'Standortanzeige';

  @override
  String get settingsTouchSteuerungAnzeigen41a3a9f0 =>
      'Touch-Steuerung anzeigen';

  @override
  String get settingsVerkehrZugaenge27db3ea6 => 'Verkehr & Zugänge';

  @override
  String get settingsWetteranbietera62920c2 => 'Wetteranbieter';

  @override
  String get signalAnalyzeAppliesInputsSave2af97340 =>
      'Analysieren gilt Inputs; Speichern Sie die Route, um sie zu halten';

  @override
  String get signalAnalyzeRadioPathsf3709ab3 => 'Funkwege analysieren';

  @override
  String get signalApplyRadioPreview1e94fdf7 => 'Radio-Vorschau anwenden';

  @override
  String get signalCancelAnalysisdf18d195 => 'Analyse abbrechen';

  @override
  String get signalClearObservationsc6114e52 => 'Klare Beobachtungen';

  @override
  String get signalCloseSignalAnalysisad376625 => 'Enge Signalanalyse';

  @override
  String get signalCurrentFlightLaunchPointb1e984c0 =>
      'Aktueller Flugstartpunkt';

  @override
  String get signalEnableLiveRadioPreview96c70f99 =>
      'Live-Radio-Vorschau aktivieren';

  @override
  String get signalFixedSpotCoordinatese71de0f9 =>
      'Behobener Punkt / Koordinaten';

  @override
  String get signalImportSurfaceCsv07954aaf => 'Oberfläche CSV importieren';

  @override
  String signalImportedObservations6dc74f21(String arg0) {
    return '$arg0 importierte Beobachtungen';
  }

  @override
  String get signalIncludeImportedObservations2e110738 =>
      'Importierte Beobachtungen einschließen';

  @override
  String get signalIncludeImportedSurfaceObservations3dc9dc80 =>
      'Importierte Oberflächenbeobachtungen einschließen';

  @override
  String get signalInspectCommunicationPath2fdd77fe =>
      'Kommunikationspfad inspizieren';

  @override
  String signalLastCompletedProfileaec2638b(String arg0, String arg1) {
    return 'Zuletzt abgeschlossenes Profil: $arg0 · $arg1';
  }

  @override
  String get signalLatitudeWgsd5f5cf6c => 'Breite · WGS84';

  @override
  String get signalLiveRadioLineOfb3b60fda => 'Live-Radiolinie der Sicht';

  @override
  String signalLocalObservationsb6dacb84(String arg0, String arg1) {
    return '$arg0 Lokalbeobachtung · $arg1';
  }

  @override
  String get signalLocalSurfaceObservations5f83fa58 =>
      'Lokale Oberflächenbeobachtungen';

  @override
  String get signalLongitudeWgs63c0ff8c => 'Längengrad · WGS84';

  @override
  String signalMAglMRadiuscfb648b3(String arg0, String arg1, String arg2) {
    return '$arg0 · $arg1 m AGL · $arg2 m Radius';
  }

  @override
  String signalMapTargetsOf0a2ebaa0(String arg0, String arg1, String arg2) {
    return 'Kartenansicht · Ziele $arg0–$arg1 von $arg2';
  }

  @override
  String signalMinimumConfiguredFresnelMargin119fbdcf(String arg0) {
    return 'Mindest konfigurierte Fresnel-Marge: $arg0 m';
  }

  @override
  String signalMinimumSampledGeometricClearancecf242d36(String arg0) {
    return 'Minimum geometrische Freiraumprobe: $arg0 m';
  }

  @override
  String signalMinimumSampledLosClearance8c03754f(String arg0) {
    return 'Mindestprobe LOS-Freiraum: $arg0 m';
  }

  @override
  String get signalOptionalBuildingVegetationObservations7a6fce33 =>
      'Fakultative Beobachtung von Gebäude/Vegetation';

  @override
  String get signalPeriodicGeometricPreviewBetweenb75cb376 =>
      'Die geometrische Vorschau zwischen Sender und simulierter Drohne wird regelmäßig aktualisiert. Sie liefert weder eine Messung der Signalqualität noch eine garantierte Reichweite.';

  @override
  String get signalPilotFrequency12dc826d => 'Pilot & Frequenz';

  @override
  String get signalProfileBrownTerrainSurface4924cb6b =>
      'Profil: braunes Gelände/Oberfläche · cyan LOS · lila untere Fresnelgrenze. Höhe in WGS84 Ellipsoid.';

  @override
  String get signalRadioLineOfSight3d11d898 => 'Radiolinie der Sicht';

  @override
  String get signalRemoveObservationsa17d9d68 => 'Anmerkungen entfernen';

  @override
  String signalRouteTargetsCheckedf545b613(String arg0, String arg1) {
    return '$arg0 von $arg1 Routenzielen geprüft';
  }

  @override
  String signalRouteTargetsTerraind0166c82(String arg0, String arg1) {
    return '$arg0 Routenziele · Gelände: $arg1';
  }

  @override
  String get signalSamplingAndLimits81b895c4 => 'Probenahme und Grenzwerte';

  @override
  String get signalSelectedMapPoint1717e7f7 => 'Ausgewählter Kartenpunkt';

  @override
  String get signalSwisstopoTerrainViaCesium5961555e =>
      'swisstopo-Gelände über Cesium · Gelände-Level 12 · Live-LoS von 1 m bis 50 km mit adaptiver, zweistufiger Abtastung. Bis 6 km hohe Auflösung, danach priorisierte Verfeinerung. Große Stichprobenlücken werden als unsicher angezeigt. Höhenwerte können bis zu 30 Sekunden zwischengespeichert werden; schmale Hindernisse können unentdeckt bleiben.';

  @override
  String get signalTransmitterHeightIsAboveb50b536b =>
      'Transmitterhöhe liegt oberhalb des gemusterten Geländes. Der empfangende Endpunkt ist die simulierte WGS84-Ellipsoidhöhe der Drohne.';

  @override
  String get signalTransmitterPositiond87196e3 => 'Position des Senders';

  @override
  String get simulationAcroDrehratenf7001f19 => 'Acro-Drehraten';

  @override
  String get simulationAcroFreieDrehratena37d7b4c => 'Acro · freie Drehraten';

  @override
  String get simulationAcroHatKeineSelbststabilisierung83a2e981 =>
      'Acro hat keine Selbststabilisierung oder Höhenhaltung. Schub folgt der Drohnenlage; geringer Schub lässt sie frei fallen.';

  @override
  String get simulationAcroPhysikdf296beb => 'Acro-Physik';

  @override
  String get simulationAglFollowsTheTerrain71243353 =>
      'AGL folgt dem Terrain zwischen Wegpunkten und kann sich von der aufgezeichneten absoluten Flugbahn unterscheiden.';

  @override
  String get simulationAkkuprofilf5c68edf => 'Akkuprofil';

  @override
  String get simulationAngleSelbststabilisierenddb3cdc71 =>
      'Angle · selbststabilisierend';

  @override
  String get simulationAngleStabilisiertDieLage73f2f597 =>
      'Angle stabilisiert die Lage und begrenzt die Neigung auf 50°. Bei Neigung ist mehr Gas zum Halten der Höhe nötig.';

  @override
  String get simulationBalanced03342dbb => 'Ausgewogen';

  @override
  String get simulationBasedOnTerrainLoaded058810aa =>
      'Basiert auf dem während der Aufzeichnung geladenen Gelände.';

  @override
  String get simulationBetaflightaaa2dc4d => 'Betaflight';

  @override
  String get simulationCompatibility5d60c7dd => 'Kompatibilität';

  @override
  String get simulationContinuousSection1042d718 =>
      'Zusammenhängender Abschnitt';

  @override
  String get simulationControllera36a5ffa => 'Controller';

  @override
  String get simulationControllertyp247db158 => 'Controllertyp';

  @override
  String get simulationDieNiedrigeZellspannungMuss653c3f34 =>
      'Die niedrige Zellspannung muss höher als die kritische Zellspannung sein.';

  @override
  String get simulationDiscard36fff63c => 'Verwerfen';

  @override
  String get simulationDiscardRecording76dde3d6 => 'Aufzeichnung verwerfen?';

  @override
  String get simulationDrohnenprofil2c80fbb6 => 'Drohnenprofil';

  @override
  String get simulationDrohnenprofileUebernehmenGeschwindigkeitUndb7b1010f =>
      'Drohnenprofile übernehmen Geschwindigkeit und Steigrate für Angle und GPS. Acro-Physik und Beschleunigung bleiben geschätzte Modellwerte. Die Kamera beeinflusst nur die Ansicht.';

  @override
  String get simulationFlugEinstellenf142a101 => 'Flug einstellen';

  @override
  String get simulationFlugStarten8846a2e4 => 'Flug starten';

  @override
  String get simulationFlugeinstellungenSchliessen974d8874 =>
      'Flugeinstellungen schließen';

  @override
  String get simulationFlugmodus699cac43 => 'Flugmodus';

  @override
  String get simulationFlugsimulatore761527e => 'Flugsimulator';

  @override
  String get simulationGamepad4dde0030 => 'Gamepad';

  @override
  String get simulationGasNullMitte62e44939 => 'Gas null: Mitte (50 %)';

  @override
  String get simulationGasNullUntenc2617787 => 'Gas null: unten (0 %)';

  @override
  String get simulationGasNullstellungd92cd012 => 'Gas-Nullstellung';

  @override
  String get simulationGelaendeUndUnterstuetzteModellflaechen2d8c2c0b =>
      'Gelände und unterstützte Modellflächen können die Bewegung stoppen. Hindernisse und Kollisionen sind nicht vollständig erfasst. Die Simulation ist keine reale Leistungs- oder Sicherheitsprüfung.';

  @override
  String get simulationGeschaetzteAkkuspannungAnzeigen3fc4417b =>
      'Geschätzte Akkuspannung anzeigen';

  @override
  String simulationGeschaetztesHorizontaltempoBeiVollgasbf685b25(String arg0) {
    return 'Geschätztes Horizontaltempo bei Vollgas: $arg0 km/h. Höherer Luftwiderstand senkt diesen Wert; Sturzflug kann ihn überschreiten.';
  }

  @override
  String get simulationGoggles0b34f86f => 'FPV-Brille';

  @override
  String get simulationGpsBremstAutomatischLinker62b42159 =>
      'GPS bremst automatisch. Linker Stick: Bewegung; rechter Stick: Blickrichtung.';

  @override
  String get simulationGpsUnterstuetzt4fba7ae2 => 'GPS · unterstützt';

  @override
  String get simulationGrafikprofile6062f50 => 'Grafikprofil';

  @override
  String get simulationGueltigeSchubUndWiderstandswerted87ecf7c =>
      'Gültige Schub- und Widerstandswerte eingeben.';

  @override
  String get simulationGueltigeSchubwerteFuerDie9f739082 =>
      'Gültige Schubwerte für die Schwebeschätzung eingeben.';

  @override
  String get simulationHudStil9e126e51 => 'HUD-Stil';

  @override
  String simulationKanale8c667fd(String arg0) {
    return 'Kanal $arg0';
  }

  @override
  String get simulationKeepAllSamples1900da8c => 'Alle Messpunkte behalten';

  @override
  String get simulationKeepForLatera212630b => 'Für später behalten';

  @override
  String get simulationKeepRecording77ccc1b0 => 'Weiter aufzeichnen';

  @override
  String get simulationKeinAkkuAusgewaehltce2c46d1 => 'Kein Akku ausgewählt';

  @override
  String get simulationKeineAutomatischeAufzeichnungOder98df029c =>
      'Keine automatische Aufzeichnung oder Ausfuhr. Online-Karten- und Geländeabrufe übermitteln den betrachteten Bereich an die Anbieter.';

  @override
  String get simulationKoordinatenImHudAnzeigen5180787d =>
      'Koordinaten im HUD anzeigen';

  @override
  String simulationMInD2d9450e4(String arg0) {
    return '$arg0 m in 3D';
  }

  @override
  String simulationMInDSeefbaac5(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0 m in 3D · $arg1 s · $arg2 Proben → $arg3 Wegpunkte';
  }

  @override
  String get simulationManuelleWerte24267a01 => 'Manuelle Werte';

  @override
  String get simulationMaximumSimplificationDeviationd255b933 =>
      'Maximale Abweichung durch Vereinfachung';

  @override
  String get simulationMitteGamepad3ed3bc49 => '50 % · Mitte (Gamepad)';

  @override
  String get simulationMoreThanWaypointsIncrease766de83d =>
      'Mehr als 1000 Wegpunkte: Vereinfachung erhöhen oder den Abschnitt trimmen.';

  @override
  String get simulationPerformance63c90455 => 'Leistung';

  @override
  String get simulationQualitya60f2c73 => 'Qualität';

  @override
  String get simulationRecordOrSelectAt4a275e16 =>
      'Nehmen oder wählen Sie mindestens zwei Positionen mit Bewegung.';

  @override
  String simulationRecordedGroundSpeedTerrainb2579dd6(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Aufgezeichnete Geschwindigkeit über Grund: $arg0 · Geländemesspunkte: $arg1/$arg2';
  }

  @override
  String get simulationReviewSimulatedFlight21515c9f =>
      'Simulierten Flug ansehen';

  @override
  String get simulationSaveAContinuousSectionead8234c =>
      'Speichere einen zusammenhängenden Abschnitt als neue Planungsroute. Beim Schließen der App gehen ungespeicherte Aufzeichnungen verloren.';

  @override
  String get simulationSaveAsRouteb13386ba => 'Als Route speichern';

  @override
  String get simulationSavedHeightReferenceWgs6f44e746 =>
      'Höhenbezug der Aufzeichnung ist das WGS84-Ellipsoid. Aufgezeichnete absolute Höhen bleiben erhalten.';

  @override
  String simulationSchwebeschaetzungGas487da692(String arg0) {
    return 'Schwebeschätzung: $arg0 % Gas';
  }

  @override
  String simulationSectionSamplesb76afcf0(String arg0, String arg1) {
    return 'Abschnitt $arg0 · $arg1 Messpunkte';
  }

  @override
  String get simulationSimulationKeineRealenFlugeigenschaften596363e0 =>
      'Simulation · keine realen Flugeigenschaften';

  @override
  String get simulationStartAmMarkiertenPunktded1ae8f =>
      'Start am markierten Punkt.';

  @override
  String get simulationStartUnterDerKartenmitted55a2a7c =>
      'Start unter der Kartenmitte.';

  @override
  String get simulationTheUnsavedSimulatedFlight363d0ff5 =>
      'Der ungespeicherte simulierte Flug wird gelöscht.';

  @override
  String get simulationTrackNorthProfileHeight13701f87 =>
      'Strecke: Norden ↑ · Profil: Höhe in Metern';

  @override
  String simulationTrimSectionSamples9e88a826(String arg0, String arg1) {
    return 'Abschnitt zuschneiden · Messpunkte $arg0–$arg1';
  }

  @override
  String get simulationUbernehmen59430842 => 'Übernehmen';

  @override
  String get simulationUmkehren1e1918e6 => 'Umkehren';

  @override
  String simulationUmkehren7b06e49a(String arg0) {
    return '$arg0 umkehren';
  }

  @override
  String get simulationUnavailableTerrainHeightIs1122a292 =>
      'Nicht verfügbar: Für einen Teil dieses Abschnitts fehlt die Geländehöhe.';

  @override
  String get simulationUntenFernsteuerungb976566f =>
      '0 % · unten (Fernsteuerung)';

  @override
  String get simulationUsbFernsteuerungdab5ef74 => 'USB-Fernsteuerung';

  @override
  String get simulationUseHeightAboveTerrain0cc4fd11 =>
      'Höhe über Gelände (AGL) verwenden';

  @override
  String simulationUtcStartPerPoint7a1f6f82(String arg0) {
    return 'UTC-Start: $arg0 · Verstrichene Zeit pro Punkt beibehalten';
  }

  @override
  String simulationWertVonBisEingeben87edf0e9(String arg0, String arg1) {
    return 'Wert von $arg0 bis $arg1 eingeben.';
  }

  @override
  String get simulationZellspannungZusaetzlichAnzeigenb25b8602 =>
      'Zellspannung zusätzlich anzeigen';

  @override
  String get simulationZumVerbindenOderFortsetzenb43ff5ab =>
      'Zum Verbinden oder Fortsetzen Gas auf null und die übrigen Sticks zentrieren. R / Controller A setzt zurück; Escape / B beendet den Flug. Ein Moduswechsel startet am Ausgangspunkt neu.';

  @override
  String get spotsAddFavorite4914d44e => 'Favoriten hinzufügen';

  @override
  String get spotsAddPhotod1434930 => 'Foto hinzufügen';

  @override
  String get spotsAddSpot7e93bac9 => 'Spot hinzufügen';

  @override
  String get spotsAddTestSpotd92ef505 => 'Test Spot hinzufügen';

  @override
  String spotsAlleSpotsGeladen5c20251b(String arg0) {
    return 'Alle $arg0 Spots geladen.';
  }

  @override
  String get spotsApplycfea419c => 'Anwenden';

  @override
  String spotsCategoriesTags7627b3f2(String arg0) {
    return 'Kategorien / Stichworte$arg0';
  }

  @override
  String get spotsCategorya3c686e7 => 'Kategorie';

  @override
  String spotsCategorybe4f88dd(String arg0) {
    return 'Kategorie: $arg0';
  }

  @override
  String get spotsClearFilters41222671 => 'Filter löschen';

  @override
  String get spotsClearSearch67300d0f => 'Suche löschen';

  @override
  String spotsDatabaseErrora227b5c8(String arg0) {
    return 'Datenbankfehler: $arg0';
  }

  @override
  String spotsDeleteFailedfc2c6c69(String arg0) {
    return 'Löschen fehlgeschlagen: $arg0';
  }

  @override
  String get spotsDeleteSpot17e145be => 'Platz löschen?';

  @override
  String get spotsDescriptionNotesOptionalcfd33085 =>
      'Beschreibung / Anmerkungen (optional)';

  @override
  String get spotsDrivingRoute9ffe00fc => 'Fahrweg';

  @override
  String get spotsEdit5301648d => 'Bearbeiten';

  @override
  String get spotsEditSpot082811c9 => 'Punkt bearbeiten';

  @override
  String get spotsLatitudeWgs060b3235 => 'Breite (WGS84)';

  @override
  String get spotsLocalStorageTest1337323b => 'Lokaler Speichertest';

  @override
  String get spotsLocatinge46bab00 => 'Lokalisieren..';

  @override
  String get spotsLongitudeWgs39118820 => 'Längengrad (WGS84)';

  @override
  String get spotsMatchesTheCategoryAnd2b0693e2 =>
      'Entspricht der Kategorie und jedem ausgewählten Tag. Suchen und Favoriten gelten auch.';

  @override
  String get spotsNoDescriptionAdded0dc3dae3 =>
      'Keine Beschreibung hinzugefügt.';

  @override
  String get spotsNoPhotosYetEdit1cb7ab6f =>
      'Noch keine Fotos. Bearbeiten Sie diese Stelle, um Fotos hinzuzufügen.';

  @override
  String get spotsNoSpotsFoundAdd55a4157e =>
      'Keine Spots gefunden. Fügen Sie eine Stelle hinzu oder passen Sie Ihre Filter an.';

  @override
  String get spotsNoSpotsSavedYet3b576669 =>
      'Noch keine Punkte gespeichert. Fügen Sie einen Testpunkt hinzu, um die Persistenz zu überprüfen.';

  @override
  String get spotsOpenSpotPhoto9410015a => 'Foto des offenen Platzes';

  @override
  String spotsOpenstreetmapSource9af4238e(String arg0) {
    return 'OpenStreetMap-Quelle: $arg0';
  }

  @override
  String get spotsOptionalUpToCharactersbcc00326 =>
      'Optional · bis zu 40 Zeichen';

  @override
  String get spotsOriginalOsmSourceReferenceebdb9f0a =>
      'Original OSM-Quellreferenz wird getrennt von persönlichen Bearbeitungen aufbewahrt.';

  @override
  String spotsPermanentlyDeleteAndIts798ab781(String arg0) {
    return 'Dauerhaft \"$arg0\" und seine Fotos löschen?';
  }

  @override
  String spotsPhotosa324a5d2(String arg0) {
    return 'Fotos: $arg0';
  }

  @override
  String spotsPhotosc4363ac9(String arg0, String arg1) {
    return 'Fotos ($arg0/$arg1)';
  }

  @override
  String get spotsRemoveFavorite8b9da771 => 'Favoriten entfernen';

  @override
  String spotsRemovePhoto67e118ac(String arg0) {
    return 'Foto entfernen $arg0';
  }

  @override
  String get spotsRetryLoadingPhotos2e5d214a =>
      'Laden von Fotos erneut versuchen';

  @override
  String get spotsSavedSpotPhoto279ddf6a => 'Gespeicherte Stelle Foto';

  @override
  String get spotsSearchSpotsd3145737 => 'Suchpunkte';

  @override
  String get spotsShowOnMap5ed4f4c1 => 'Auf der Karte anzeigen';

  @override
  String get spotsSpotDetailse32d6442 => 'Einzelheiten zum Spot';

  @override
  String get spotsSpotName811bf0db => 'Name des Ortes';

  @override
  String get spotsSpotPhoto590ebf66 => 'Bild des Ortes';

  @override
  String get spotsThisPhotoIsNo08b26948 =>
      'Dieses Foto ist nicht mehr verfügbar.';

  @override
  String get spotsThisSpotNoLongeraffbf566 =>
      'Dieser Fleck existiert nicht mehr.';

  @override
  String get spotsUnableToDisplayThis38f897ec =>
      'Dieses Foto kann nicht angezeigt werden.';

  @override
  String get spotsUnableToLoadPhotos634c2fc3 =>
      'Fotos können nicht geladen werden. Schließen Sie dieses Fenster und versuchen Sie es erneut.';

  @override
  String get spotsUnableToLoadSpot827d0e55 =>
      'Details können nicht geladen werden.';

  @override
  String get spotsUnableToLoadThisc9e4faa4 =>
      'Dieses Foto kann nicht geladen werden.';

  @override
  String get spotsUnableToUpdateFavorite3001cf8d =>
      'Es ist nicht möglich, den Favoriten zu aktualisieren.';

  @override
  String get spotsUseCurrentLocation622c745f => 'Aktuelle Position verwenden';

  @override
  String get spotsWeitereSpotsWerdenBeim1f25ff94 =>
      'Weitere Spots werden beim Scrollen geladen.';

  @override
  String get telemetryApplyRouteCalibration5c654485 =>
      'Routenkalibrierung anwenden?';

  @override
  String get telemetryApplyToThisRoute1635cca9 => 'Auf diese Route anwenden';

  @override
  String get telemetryApproximationForAStill90100705 =>
      'Annäherung nur an eine Standluftaufnahme';

  @override
  String get telemetryDeleteLocalTelemetryfa6452e1 =>
      'Lokale Telemetrie löschen';

  @override
  String get telemetryDeleteRawTelemetryad6e4046 => 'Rohe Telemetrie löschen?';

  @override
  String get telemetryDifferentDronesAreAssociated17ab6eae =>
      'Verschiedene Drohnen sind mit dem Log und der Route verbunden. Kalibrierung ist deaktiviert.';

  @override
  String get telemetryDurationIncludesAllRecordedb1545492 =>
      'Die Dauer enthält auch aufgezeichnete Leerlauf- und Schwebezeiten. Schneide die Aufzeichnung vor dem Import auf einen Flug zu.';

  @override
  String get telemetryFlightPlanForComparison6e3eb9d5 =>
      'Flugplan zum Vergleich';

  @override
  String get telemetryImportOneContinuousFlight94f89be2 =>
      'Importieren Sie einen kontinuierlichen Flug. Raw CSV bleibt in der lokalen Datenbank. Es wird keine Telemetrie hochgeladen.';

  @override
  String get telemetryImportTelemetryCsveb2d1023 =>
      'Telemetrie importieren CSV';

  @override
  String get telemetryImportTelemetryLocallyf7626443 =>
      'Telemetrie lokal importieren?';

  @override
  String telemetryImportedbd3c3768(String arg0) {
    return '$arg0 importiert';
  }

  @override
  String get telemetryLocalTelemetryUnavailableReopencb8a0598 =>
      'Lokale Telemetrie nicht verfügbar. Öffnen Sie diesen Bildschirm erneut zu versuchen.';

  @override
  String telemetryMeasuredEnergyWhAverage9acf6860(String arg0, String arg1) {
    return 'Gemessene Energie: $arg0 Wh · mittlere Leistung $arg1 W';
  }

  @override
  String telemetryMeasuredModeledWhae99a8d2(String arg0, String arg1) {
    return 'Gemessen − modelliert: $arg0 Wh ($arg1%)';
  }

  @override
  String get telemetryModelComparisondaa80a44 => 'Modellvergleich';

  @override
  String telemetryModelEnergyOverRecorded6bf1955f(String arg0) {
    return 'Modellenergie über die aufgezeichneten Geschwindigkeiten: $arg0 Wh';
  }

  @override
  String get telemetryNoAssociatedFlightPlan5a0a6161 =>
      'Es steht kein zugehöriger Flugplan zur Verfügung. Verbinden Sie einen Plan beim Import, um sein Modell zu vergleichen.';

  @override
  String get telemetryPreviewApplyCalibrationa8b7db04 =>
      'Kalibrierung anzeigen & anwenden';

  @override
  String telemetryRecordedDurationSe198ddeb(String arg0) {
    return 'Aufgezeichnete Dauer: $arg0 s';
  }

  @override
  String get telemetryRouteComparisonUnavailableCheck13192917 =>
      'Der Routenvergleich ist nicht verfügbar. Überprüfen Sie die gespeicherten Routeneingaben.';

  @override
  String get telemetryRouteComparisonsAssumeThed64d19cc =>
      'Streckenvergleiche gehen davon aus, dass die Aufzeichnung den gleichen ausgehenden Pfad abdeckt. Rückflüge und Leerlaufzeiten werden nicht automatisch entfernt.';

  @override
  String telemetrySamples49577d36(String arg0, String arg1) {
    return '$arg0 · $arg1 Messpunkte';
  }

  @override
  String telemetrySavedOutboundRouteDuration18b87ca4(String arg0) {
    return 'Gespeicherte Streckendauer: $arg0';
  }

  @override
  String telemetrySavedOutboundRouteMean0818ac58(String arg0, String arg1) {
    return 'Gespeicherte Outbound-Route bedeutet $arg0 Geschwindigkeit: $arg1';
  }

  @override
  String get telemetrySupportedFormatsdf1bdc5f => 'Unterstützte Formate';

  @override
  String telemetryTelemetry9ac39ce5(String arg0) {
    return 'Telemetrie: $arg0';
  }

  @override
  String get telemetryTheRoutePowerCurvee9b27f2a =>
      'Die Streckenleistungskurve wird bei jeder aufgezeichneten Geschwindigkeit mit ihrer Massenkorrektur ausgewertet. Energie verwendet trapezförmige Integration von Spannung × Strom. Es wird keine Kletter- oder Manöverkorrektur abgeleitet.';

  @override
  String get telemetryUnassignede57016ed => 'Nicht zugewiesen';

  @override
  String get telemetryUseGroundSpeedAs5bb04e27 =>
      'Bodengeschwindigkeit als Fluggeschwindigkeit verwenden';

  @override
  String get weatherAbgelaufenPfeileUndWindeinfluss1572fe42 =>
      'Abgelaufen: Pfeile und Windeinfluss sind ausgesetzt.';

  @override
  String weatherAbgerufenRasterpunkte7532c53d(String arg0, String arg1) {
    return 'Abgerufen: $arg0 · $arg1/9 Rasterpunkte';
  }

  @override
  String get weatherActiveForecastProvider589a3851 =>
      'Aktiver Prognoseanbieter';

  @override
  String get weatherAktuellerModellwind402bf323 => 'Aktueller Modellwind';

  @override
  String get weatherAllComparisonResultsUse418051c7 =>
      'Alle Vergleichsergebnisse verwenden den ausgewählten Anbieter und identische Flugzeit und Kriterien; fehlende Daten ergeben nie ein positives Ergebnis.';

  @override
  String get weatherAngleAcroAbdriftGps88b761bf =>
      'Angle/Acro: Abdrift. GPS: Gegenhalten bis zur Leistungsgrenze.';

  @override
  String get weatherAusschnittUmDenGewaehlten25af0329 =>
      'Ausschnitt um den gewählten Punkt';

  @override
  String get weatherAutomaticObservationsFromAnda1a45d31 =>
      'Automatische Beobachtungen (ab 2023) und historische manuelle Messungen sind separate Methoden. Historische/manuelle Reihen werden hier nicht geladen.';

  @override
  String get weatherChooseASavedFlyingba7ecae9 =>
      'Wählen Sie einen gespeicherten Flugplatz oder eine Globenkoordinate, um in der Nähe von Überwachungsstationen zu inspizieren.';

  @override
  String get weatherClearRadar66544d4d => 'Klares Radar';

  @override
  String get weatherCompareSavedSpotsc7ce5e7e =>
      'Gespeicherte Spots vergleichen';

  @override
  String get weatherDPfeileAktivbfcd3c26 => '3D-Pfeile aktiv';

  @override
  String get weatherDWindUndFlugwinda2d72644 => '3D-Wind und Flugwind';

  @override
  String get weatherDWindUndPrognose6efb0829 => '3D-Wind und Prognose';

  @override
  String get weatherDWindpfeileAnzeigenbc5f17dc => '3D-Windpfeile anzeigen';

  @override
  String weatherDataState98888b0e(String arg0, String arg1, String arg2) {
    return 'Status der Daten: $arg0$arg1$arg2';
  }

  @override
  String get weatherDatenUndGrenzen98079772 => 'Daten und Grenzen';

  @override
  String get weatherDiesenAusschnittAktualisierenf0435deb =>
      'Diesen Ausschnitt aktualisieren';

  @override
  String get weatherDiesesRasterAusblendenc09fe0a2 =>
      'Dieses Raster ausblenden';

  @override
  String weatherDirection2373dfc9(String arg0) {
    return 'Richtung $arg0';
  }

  @override
  String get weatherDiscoverPublishedRadarTimes9528700a =>
      'Veröffentlichte Radarzeiten entdecken';

  @override
  String weatherDownloadedUtc177de02a(String arg0) {
    return 'Gedownloadet: $arg0 UTC';
  }

  @override
  String get weatherDroneProfileUserThresholdsf3e5ce7b =>
      'Drohnenprofil (Benutzerschwellen)';

  @override
  String get weatherEvaluateSavedSpotsbdd72b2d =>
      'Beurteilen Sie die gespeicherten Stellen';

  @override
  String get weatherFindMonitoringStations4d511534 =>
      'Überwachungsstationen finden';

  @override
  String get weatherForecastIssueTimeNot72c0daa9 =>
      'Voraussichtliche Ausgabezeit: nicht vom Anbieter geliefert';

  @override
  String weatherForecastIssued2ab834ac(String arg0) {
    return 'Prognose veröffentlicht: $arg0';
  }

  @override
  String get weatherFpvSuitabilityThresholdsd468f61f =>
      'FPV-Zulässigkeitsschwellen';

  @override
  String get weatherGemesseneWetterUndGewaesserstationen70b38f8d =>
      'Gemessene Wetter- und Gewässerstationen';

  @override
  String get weatherHourlyPrecipitationRefersTob7611db2 =>
      'Der stündliche Niederschlag bezieht sich auf die vorhergehende Stunde, die am prognostizierten Zeitstempel endet.';

  @override
  String weatherIndependentOpenMeteoSamples4c5f32a2(String arg0) {
    return '$arg0 unabhängige Open-Meteo-Proben auf dem Globus gezeigt.';
  }

  @override
  String get weatherInspectHourlyObservationUtcae90e45a =>
      'Inspizieren Sie stündliche Beobachtung (UTC)';

  @override
  String get weatherInspectLocalTerrainc851b2af =>
      'Inspizieren Sie lokales Gelände';

  @override
  String get weatherKartenebeneKonnteNichtAktualisiertab47fc9e =>
      'Kartenebene konnte nicht aktualisiert werden. Bitte erneut versuchen.';

  @override
  String get weatherKmLocal5e8c161b => '1 km vor Ort';

  @override
  String weatherLatestStationObservationHourly1d766dcb(
    String arg0,
    String arg1,
  ) {
    return 'Letzte Stationsbeobachtung: $arg0 · $arg1 · Stundendurchschnitt';
  }

  @override
  String get weatherLetzteAktualisierungFehlgeschlagenDie140dfc53 =>
      'Letzte Aktualisierung fehlgeschlagen. Die vorherigen Daten bleiben bis zum Ablauf verfügbar.';

  @override
  String get weatherLoadHourlyObservations7bc23c4c =>
      'Belastung stündliche Beobachtungen';

  @override
  String get weatherLocalTerrainExposuref78de89b => 'Lokale Geländebelichtung';

  @override
  String weatherLocation77d72845(String arg0, String arg1) {
    return 'Wohnort: $arg0$arg1';
  }

  @override
  String get weatherMeteoswissEDoesNota574859d =>
      'MeteoSwiss E4 liefert diesen Parameter nicht.';

  @override
  String get weatherMeteoswissStationDetails565885c8 =>
      'MeteoSwiss Bahnhof Details';

  @override
  String get weatherNativeModelResolutionNot32f4a5e7 =>
      'Native Modellauflösung: von dieser API-Antwort nicht geliefert. Der ausgewählte Abstand setzt nur das Display-Sample-Grid.';

  @override
  String weatherNearbyReliefMFrom3afbc3bf(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'In der Nähe Relief $arg0 m von $arg1 Geländeproben. $arg2';
  }

  @override
  String get weatherNearestMonitoringStationb112be37 =>
      'Nächstliegende Überwachungsstation';

  @override
  String weatherNiederschlagf18088c2(String arg0) {
    return 'Niederschlag $arg0';
  }

  @override
  String get weatherNoDroneProfilesSaved1b2919fa =>
      'Keine Drohnenprofile gespeichert; generische Schwellenwerte unten konfigurieren.';

  @override
  String get weatherNoOfficialSeverityClasses2d4def34 =>
      'Keine offiziellen Schweregradklassen sind abgeleitet. Fehlen ist nicht Null. Lesungen beschreiben nur die Überwachung.';

  @override
  String get weatherNoPublishedQualityFlag88577e1e =>
      'Für diesen Rahmen wurde keine Qualitätsflagge veröffentlicht (Qualität unbekannt).';

  @override
  String get weatherNoSavedSpotSelected8861bd5c =>
      'Kein gespeicherter Punkt ausgewählt. Wählen Sie einen Punkt auf dem Globus oder speichern Sie einen Punkt.';

  @override
  String get weatherNoValidAutomaticObservationse3251aaa =>
      'Keine gültigen automatischen Beobachtungen in dieser Datei veröffentlicht.';

  @override
  String weatherObserved6b54f9ec(String arg0, String arg1) {
    return 'Beobachtet: $arg0 · $arg1';
  }

  @override
  String get weatherOfficialAirspaceVerification1376fb67 =>
      'Offizielle Überprüfung des Luftraums';

  @override
  String get weatherOfficialMeteoswissFilesAre0450722a =>
      'Offizielle MeteoSwiss Dateien sind groß; der Vergleich ist auf 3 Spots pro Anfrage begrenzt, um den Datenverkehr zu reduzieren.';

  @override
  String get weatherOfficialMeteoswissPollenStations0d04b249 =>
      'Offizielle MeteoSchweizer Pollenstationen';

  @override
  String get weatherOfficialMeteoswissPrecipitationRadar58cad390 =>
      'Offizielles MeteoSchweizer Niederschlagsradar';

  @override
  String get weatherOptionalCesiumReliefCheckff9531d9 =>
      'Optional Cesium Relief Check innerhalb von 300 m (Mitte und vier Nachbarn). Keine aerodynamische Turbulenz Modell.';

  @override
  String get weatherOptionalWinddatenNochNicht638f2548 =>
      'Optional · Winddaten noch nicht geladen';

  @override
  String get weatherPlannedFlightTimeLocal410bf657 =>
      'Geplante Flugzeit (lokal)';

  @override
  String get weatherPlayForward4b395db1 => 'Vorwärts spielen';

  @override
  String weatherPrognoseAbgerufenFehlendeStichproben23fbbb89(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Prognose: $arg0\nAbgerufen: $arg1 · $arg2 fehlende Stichproben';
  }

  @override
  String get weatherProviderTermsDataSource3870b023 =>
      'Anbieter Begriffe / Datenquelle';

  @override
  String weatherPublishedCpcQualityFlagdf44398e(String arg0) {
    return 'Veröffentlichte CPC-Qualitätsflagge: $arg0/9';
  }

  @override
  String weatherPublishedFramesMaximumIrregular94a6ff40(String arg0) {
    return '$arg0 veröffentlichte Frames (maximal 12). Unregelmäßige Zeitstempellücken werden beibehalten.';
  }

  @override
  String get weatherRadarProducte1ab732e => 'Radarprodukt';

  @override
  String get weatherRasterAbgelaufenAufDer98608088 =>
      'Raster abgelaufen · auf der Karte ausgeblendet';

  @override
  String get weatherRefreshForecastfe3dbc62 => 'Prognose aktualisieren';

  @override
  String get weatherRefreshStationMetadataa5976bc4 =>
      'Metadaten von Stationen aktualisieren';

  @override
  String get weatherRequireVisibilityForecastc232c2a0 =>
      'Voraussichtliche Sichtbarkeit erforderlich';

  @override
  String weatherResolutiona39d34b8(String arg0) {
    return 'Entschließung: $arg0';
  }

  @override
  String get weatherSavedFlyingSpotedf5fa9d => 'Gespeicherter Flugplatz';

  @override
  String weatherSelectedObservation26593d3f(String arg0) {
    return 'Ausgewählte Beobachtung: $arg0';
  }

  @override
  String get weatherShowOnGlobe8ee06550 => 'Auf dem Globus anzeigen';

  @override
  String get weatherShowSelectedFrame26955c78 => 'Ausgewählten Rahmen anzeigen';

  @override
  String get weatherSourceMeteoswissFsdiStacb55f0dac =>
      'Quelle: MeteoSwiss · FSDI STAC · online HDF5/WASM · EPSG:2056. Radar kann im Web oder Android nicht verfügbar sein, wenn Daten- oder Decoderzugriff blockiert ist.';

  @override
  String get weatherSourcePublicationTimeNot23697f29 =>
      'Quelle Veröffentlichungszeit: nicht angegeben';

  @override
  String weatherSourceStacUpdateddde9e800(String arg0) {
    return 'Quelle STAC aktualisiert: $arg0';
  }

  @override
  String weatherStacUpdated73855d9d(String arg0) {
    return 'STAC aktualisiert: $arg0';
  }

  @override
  String get weatherStationDirectoryCachedLastf07e00ef =>
      'Stationsverzeichnis: zwischengespeichert; letzte Metadatenaktualisierung fehlgeschlagen (originale Veröffentlichungszeit nicht verfügbar).';

  @override
  String get weatherStationDirectoryLocallyCached005bbea0 =>
      'Stationsverzeichnis: lokal zwischengespeichert (originale Veröffentlichungszeit nicht verfügbar).';

  @override
  String weatherStationDirectoryRetrieved72729476(String arg0) {
    return 'Senderverzeichnis: abgerufen $arg0';
  }

  @override
  String weatherTerrainAndLegalAirspacedb03e335(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0 $arg1 $arg2 $arg3 · Terrain und legaler Luftraum nicht bewertet.';
  }

  @override
  String weatherUnsupportedSourceParametersNot75db504a(String arg0) {
    return 'Nicht unterstützte Quellparameter nicht klassifiziert: $arg0';
  }

  @override
  String weatherVisibility1b929d6e(String arg0) {
    return 'Sichtbarkeit $arg0';
  }

  @override
  String get weatherWeatherFpvSuitabilitye893355f =>
      'Wetter- & FPV-tauglichkeit';

  @override
  String get weatherWeatherMapOpenMeteodb0c967f =>
      'Wetterkarte (Open-Meteo-Musternetz)';

  @override
  String weatherWeatherOverlayUnavailablef9e466e1(String arg0) {
    return 'Wetterüberlagerung nicht verfügbar: $arg0';
  }

  @override
  String get weatherWeatherPreferencesCouldNot1aa91b1b =>
      'Wettervorlieben konnten nicht gespeichert werden';

  @override
  String get weatherWindBeeinflusstDenSimulator0792a00b =>
      'Wind beeinflusst den Simulator';

  @override
  String get weatherWindImFlugeffc2149 => 'Wind im Flug';

  @override
  String get weatherWindImFlugsimulatorBeruecksichtigen2a47223c =>
      'Wind im Flugsimulator berücksichtigen';

  @override
  String get weatherWinddarstellungUndEinflussAus5d5ce187 =>
      'Winddarstellung und Einfluss aus';

  @override
  String get weatherWinddatenAbgelaufend96548ce => 'Winddaten abgelaufen';

  @override
  String get weatherWinddatenFuerPunktAnsichtfa5e2d66 =>
      'Winddaten für Punkt / Ansicht laden';

  @override
  String get weatherWindpfeileWartenAufGeladenes9bd078a7 =>
      'Windpfeile warten auf geladenes 3D-Gelände.';

  @override
  String get weatherWindquelleZeitfc844a65 => 'Windquelle / Zeit';

  @override
  String get weatherZusaetzlichesPrognoseraster279c3ee9 =>
      'Zusätzliches Prognoseraster';

  @override
  String commonSavedRouteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gespeicherte Routen',
      one: 'Eine gespeicherte Route',
      zero: 'Keine gespeicherten Routen',
    );
    return '$_temp0';
  }

  @override
  String commonUpdatedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Aktualisiert am $dateString';
  }

  @override
  String get signalShowGroundStationMarker =>
      'Bodenstationsmarkierung anzeigen';

  @override
  String get signalShowLiveSignalPath => 'Live-Sichtlinie anzeigen';

  @override
  String get signalUseTakeoffAsGroundStation =>
      'Auf Startposition zurücksetzen';

  @override
  String get signalChooseGroundStationFromMap =>
      'Wähle einen Punkt auf der 3D-Karte aus. Öffne dieses Fenster erneut und tippe auf „Ausgewählter Kartenpunkt“.';

  @override
  String get signalHudDjiWarning => 'DJI: Signalwarnung am unteren Bildrand';

  @override
  String get signalHudBetaflightBars => 'Betaflight: Signalbalken anzeigen';

  @override
  String get signalHudAnalogNoise => 'Betaflight: analoges Videorauschen';

  @override
  String get signalHudTerrainIllustration =>
      'Geländerisiko als Videoeffekt illustrieren';

  @override
  String get signalHudTerrainDisclaimer =>
      'Nur eine Illustration, keine RF-Messung. RC-Signal bleibt unbekannt.';

  @override
  String get signalHudIntensity => 'Intensität des Bildrauschens';

  @override
  String get signalHudWeakThreshold => 'Schwaches Signal – Schwelle';

  @override
  String get signalHudCriticalThreshold => 'Kritisches Signal – Schwelle';

  @override
  String get signalHudLostThreshold => 'Signalverlust – Schwelle';

  @override
  String get failsafeSimulationTitle => 'Simulierter RC-Failsafe';

  @override
  String get failsafeSimulationDisclaimer =>
      'Nur bei explizit simuliertem RC-Verlust. Keine reale RF-Prognose.';

  @override
  String get failsafeSimulationAction => 'Failsafe-Aktion';

  @override
  String get batteryChemistryAutoThresholds =>
      'Chemieabhängige Warnschwellen (SIM)';

  @override
  String get batteryChemistryAutoThresholdsHint =>
      'Orientiert sich an der gewählten Akkuchemie; für eigene Spannungen deaktivieren.';

  @override
  String get batteryChemistryResistanceAutomatic =>
      'Innenwiderstand je Zelle (Ω; 0 = Chemie-Schätzwert)';

  @override
  String get batteryChemistryField => 'Akkuchemie';

  @override
  String get batteryUnknownChemistry => 'Nicht unterstützt (beibehalten): ';

  @override
  String get batteryContinuousDischarge => 'Dauerbelastbarkeit (C)';

  @override
  String get batteryBurstDischarge => 'Kurzzeitbelastbarkeit (C)';

  @override
  String get batteryBurstDuration => 'Kurzzeitdauer (s)';

  @override
  String get batteryInternalResistance => 'Innenwiderstand (mΩ/Zelle)';

  @override
  String get batteryElectricalHint =>
      'Individuelle Akkuwerte haben Vorrang vor Chemie-Schätzwerten. Kurzzeitbelastbarkeit und Dauer müssen gemeinsam angegeben werden.';

  @override
  String get batteryBurstValidation =>
      'Kurzzeitbelastbarkeit und Dauer gemeinsam eingeben. Die Kurzzeitbelastbarkeit darf nicht unter der Dauerbelastbarkeit liegen.';

  @override
  String get batteryTypeLiPo => 'LiPo — Lithium-Polymer';

  @override
  String get batteryTypeLiHV => 'LiHV — Hochvolt-Lithium-Polymer';

  @override
  String get batteryTypeLiIon => 'Li-ion — Lithium-Ionen';

  @override
  String get batteryTypeLiFePO4 => 'LiFePO₄ — Lithium-Eisenphosphat';

  @override
  String get batteryTypeNiMH => 'NiMH — Nickel-Metallhydrid';

  @override
  String get batteryTypeNiCd => 'NiCd — Nickel-Cadmium';

  @override
  String batteryChargingVoltageHint(String value) {
    return 'Ladehinweis: CC/CV, maximal $value V je Zelle. Herstellerangaben der Zellen prüfen.';
  }

  @override
  String get batteryNickelChargingHint =>
      'Ladehinweis: Nickel-Zellen benötigen Delta-Peak-/Temperaturüberwachung. Es gibt keine feste Ladeschlussspannung als alleinige Abschaltbedingung.';

  @override
  String get droneCurrentLimitsHint =>
      'Optionale ESC- und Motor-Dauerstromgrenzen gelten je ESC-Kanal bzw. Motor. Der Akkustrom geteilt durch die Motoranzahl ist nur ein grober Näherungswert und kein gemessener Phasenstrom.';
}
