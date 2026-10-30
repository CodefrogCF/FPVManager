enum GuideTopic {
  outdoor,
  profiles,
  map,
  controls,
  coordinates,
  airspace,
  freshness,
  offline,
  privacy,
  weather,
  obstacles,
  mobility,
}

class GuideSection {
  const GuideSection(this.title, this.text);
  final String title, text;
}

class GuideArticle {
  const GuideArticle(this.title, this.sections);
  final String title;
  final List<GuideSection> sections;
}

/// Bundled, offline-readable explanations. Immediate errors, source dates and
/// safety status belong in their original panels, not only in these guides.
const guideArticles = <GuideTopic, GuideArticle>{
  GuideTopic.outdoor: GuideArticle('Outdoor-Karten und Messstationen', [
    GuideSection(
      'Bodenrouten',
      'Im Bereich Bodenrouten wählst du ausdrücklich „Zu Fuß“ oder „Velo“. Nach deiner Zustimmung werden Start und Ziel an die dazu passenden FOSSGIS-/OSRM-Profile gesendet. Berechnete und importierte Routen bleiben als eigene lokale Datensätze auch ohne Netz verfügbar und werden mit dem persönlichen Backup gesichert. GPX erhält den Aktivitätsmodus und vorhandene Quellenhöhen, ohne daraus AGL-Höhen zu erzeugen. Unbekannte GPX-Typen benötigen den gewählten Importmodus; zusätzliche oder nicht unterstützte Angaben werden gemeldet. Ein gespeicherter Linienverlauf bestätigt keine aktuelle Öffnung. Der Bereich bietet Planung und Austausch; die bisherige Autonavigation ist eigenständig.',
    ),
    GuideSection(
      'Amtliche Wegenetze',
      'Wander-, Velo-, Mountainbike- und Winterrouten sind veröffentlichte Netze. Legenden erklären die jeweiligen Kategorien; ohne entsprechende Quelldaten wird keine Schwierigkeit berechnet. Diese Online-Kartenebenen sind von deinen gespeicherten Boden- und Flugrouten getrennt. Kartenstand, Öffnung und aktuelle Bedingungen sind eigenständig zu prüfen.',
    ),
    GuideSection(
      'Natur und Sperrungen',
      'Wildruhezonen können rechtsverbindlich oder empfohlen sein. Schutzzeiten, örtliche Bestimmungen und zulässige Wege stehen in den offiziellen Details. Der räumliche Detailabruf ist ein begrenzter Auszug; fehlende kantonale Informationen oder fehlende Treffer bestätigen keine Zugänglichkeit. Sperrungen und Umleitungen haben eigene Gültigkeitsangaben. Eine Schutzfläche ist keine pauschale luftrechtliche Einstufung.',
    ),
    GuideSection(
      'Gemessene Werte',
      'MeteoSwiss-Stationswerte sind Messungen an einem einzelnen Standort; Wind und Böen stehen im Quellenformat km/h, Niederschlag als Summe über zehn Minuten. Die Messzeiten sind UTC und werden zusätzlich lokal angezeigt. Sie beschreiben kein vollständiges Windfeld und ändern den Simulatorwind nicht. Fehlende Qualitätsflags bleiben unbekannt.',
    ),
    GuideSection(
      'Gewässer und Aktualität',
      'BAFU-Live-Werte sind unkorrigiert. 10-Minuten-Mittel enthalten die bereitgestellte Einheit und den verfügbaren Freigabestatus; unbekannte Referenzen bleiben unbekannt. Frische des lokalen Snapshots und Alter einer einzelnen Messung sind getrennte Angaben. Beobachtungen bewerten weder eine Aktivität als sicher noch ersetzen sie amtliche Warnungen. Abrufe erfolgen bewusst, in begrenzten Abständen; lokale Messwert-Snapshots lassen sich auch ohne Netz öffnen.',
    ),
  ]),
  GuideTopic.profiles: GuideArticle('Aktivitätsprofile und Arbeitsbereiche', [
    GuideSection(
      'Starten und anpassen',
      'Über „Profil wählen“ oder Einstellungen → Aktivitätsprofile wählst du eine Vorlage, erstellst ein leeres Profil oder überspringst die Auswahl. Vorlagen lassen sich bearbeiten, duplizieren und löschen. Bevorzugte Werkzeuge stehen im Menü zuerst; die Kartenaktionen folgen deinen Schnellaktionen. „Alle Werkzeuge“ öffnet jederzeit den vollständigen Funktionsumfang. Flugrouten und Ausrüstung behalten ihre Bedeutung. Den Fuß- oder Velomodus wählst du im Bereich Bodenrouten; ein Aktivitätsprofil ändert den Routingmodus nicht automatisch.',
    ),
    GuideSection(
      'Karte und laufende Aktivitäten',
      'Kartenstartwerte gelten beim App-Start, Aktivieren oder Speichern des aktiven Profils. Spätere Änderungen auf der Karte bleiben bis zur nächsten Aktivierung oder zum Neustart erhalten. Während Bodenansicht, Simulation, Navigation oder pausiertem Renderer werden Startwerte zurückgestellt und erst danach angewendet. Kamera, Auswahl, laufende Steuerung, Formulare und persönliche Datensätze werden beim Wechsel nicht zurückgesetzt. Ohne Profil bleibt die aktuelle Karte erhalten.',
    ),
    GuideSection(
      'Ebenen und Datenschutz',
      'Bevorzugte Ebenen sind Schnellzugriffe zu den bestehenden Ebenenreglern. Ein Profil aktiviert keine Datenquelle, Standortfreigabe, API-Verbindung oder automatische Aktualisierung. Quelleneinstellungen und Berechtigungen bleiben eigenständig. Profile speichern keine Zugangsdaten oder persönlichen Orte.',
    ),
    GuideSection(
      'Sichern und teilen',
      'Profile und Auswahl sind Bestandteil persönlicher Backups. Einzelne Profile können als versionierte .fpvprofile-Datei exportiert werden. Der Import zeigt eine Vorschau und ergänzt ein inaktives Profil, ohne vorhandene Profile zu überschreiben. Unterstützt werden höchstens 32 Profile und Dateien bis 128 KiB.',
    ),
  ]),
  GuideTopic.map: GuideArticle('Karte und Beschriftungen', [
    GuideSection(
      'Orientierung',
      'Der Kompass richtet die Karte nach Norden aus. „Mein Standort“ ortet erst nach Antippen. Langes Drücken öffnet Genauigkeit und Verfolgung; Kartenbewegungen beenden die Verfolgung. Die Suche akzeptiert Koordinaten, Orte und Straßen.',
    ),
    GuideSection(
      'Ebenen',
      'Satellit, Topo und Relief sind Hintergrundkarten. Straßen und Beschriftungen sind unabhängig zuschaltbar. Beschriftungen zeigen eine begrenzte, nach Bildschirmplatz ausgewählte Menge offizieller Schweizer Orts- und Straßennamen. Straßennamen aus dem amtlichen Verzeichnis erfassen vor allem Straßen mit Gebäudeadressen; nicht alle Wege und Autobahnen sind enthalten.',
    ),
    GuideSection(
      '3D und Quellen',
      'Gebäude werden aus Quelldaten gestreamt; Vegetation ist modelliert. Fehlende Objekte werden nicht ergänzt. Diese Darstellungen haben kein Kollisionsmodell. Eine Routen- oder Flugzeit überschreibt die Kartenbeleuchtung vorübergehend. Streaming-Modelle und Beschriftungen sind kein Bestandteil eines vorbereiteten Offline-Kartenpakets.',
    ),
  ]),
  GuideTopic.controls: GuideArticle('Steuerung und Simulation', [
    GuideSection(
      'Sticks',
      'Angle/Acro: links Gas und Yaw, rechts Pitch und Roll. GPS: links Bewegung, rechts Blickrichtung, separate Knöpfe für Steigen/Sinken. Beide Touch-Sticks sitzen fest. Die Schnelleinstellungen können sie ausblenden; Tastatur und externe Controller bleiben nutzbar.',
    ),
    GuideSection(
      'Tastatur und Funke',
      'Angle/Acro: E/Q Gas, A/D Yaw, W/S Pitch, Pfeile links/rechts Roll; IJKL steuert ebenfalls die Lage. GPS/Ego: WASD/Pfeile bewegen, Ziehen oder IJKL umsehen; GPS nutzt E/Q für die Höhe. Escape beendet die Ansicht. Für Controller nach Fokusverlust oder echter Trennung die passende Ruheposition einnehmen. Gas-Nullpunkt und Kanalzuordnung bleiben eigene Controller-Einstellungen.',
    ),
    GuideSection(
      'Grenzen',
      'Angle stabilisiert die Lage, Acro gibt Drehraten vor, GPS bremst und hält die Höhe. Die Physik ist eine Näherung. Gelände-Kontakt ersetzt keine Hinderniskollisionen; Kabel, Gebäude und Bäume sind keine vollständige Kollisionswelt. Einstellungen außerhalb eines aktiven Fluges gelten für die nächste Simulation.',
    ),
  ]),
  GuideTopic.coordinates: GuideArticle('Koordinaten und Höhen', [
    GuideSection(
      'Eingabe',
      'WGS84: Breite, Länge in Dezimalgrad, z. B. 46.7, 8.4. LV95: Ost / Nord, z. B. 2600000 / 1200000. Die lokale LV95-Umrechnung ist eine Näherung für Orientierung, keine Vermessung. Eine Orts- oder Adresssuche benötigt dagegen eine Verbindung.',
    ),
    GuideSection(
      'Höhenbezug',
      'WGS84-Ellipsoid, Schweizer LN02 und Höhe über Gelände (AGL) sind unterschiedliche Bezüge. AGL bezieht sich auf das Gelände am jeweiligen Punkt, die Starthöhe auf den Startpunkt. Unbekannte Quellenbezüge bleiben unbekannt. Ein flacher Ersatzglobe liefert keine gemessene Geländehöhe.',
    ),
  ]),
  GuideTopic.airspace: GuideArticle('Luftraum und Flugvorbereitung', [
    GuideSection(
      'Alle Zonen prüfen',
      'Eine UAS-Zone ist nicht automatisch ein vollständiges Flugverbot. Prüfe jede überlappende Einschränkung, zuständige Stelle, Zeit, Höhe und Freigabeanforderung. Farben beschreiben unterstützte Quellattribute; Blau ist keine Flugfreigabe. Räumliche Checks prüfen Geometrie und ersetzen keine rechtliche Beurteilung.',
    ),
    GuideSection(
      'Vor dem Start',
      'Aktuelle BAZL-Karte, DABS und Original-NOTAM für Flugzeit und Route sowie örtliche Regeln prüfen. DABS ist ein periodisches Bulletin; NOTAM können sich zwischen Ausgaben ändern. Der automatische DABS/NOTAM-Abruf ist derzeit nicht angeschlossen. Auch Wetter, Hindernisse und Höhenbezüge prüfen und unmittelbar vor Abflug erneut verifizieren.',
    ),
  ]),
  GuideTopic.freshness: GuideArticle('Datenstand und Verfügbarkeit', [
    GuideSection(
      'Zeitangaben',
      'Abrufzeit ist nicht Veröffentlichungszeit. Gültig von/bis beschreibt den angegebenen Zeitraum; ein frischer Download beweist nicht, dass der gesamte Inhalt aktuell ist. Fehlende Zeitangaben werden nicht ergänzt.',
    ),
    GuideSection(
      'Zustände',
      'Fresh: innerhalb der Abrufrichtlinie. Stale/expired: veraltet oder abgelaufen. Unavailable: kein nutzbarer Datenstand. Refresh failed: die Aktualisierung schlug fehl; ein vorheriger Stand kann noch angezeigt werden. Quellenstatus und Warnungen stehen weiterhin beim jeweiligen Werkzeug. Keine Anzeige garantiert einen sicheren oder erlaubten Flug.',
    ),
  ]),
  GuideTopic.offline: GuideArticle('Offline-Karten und Backups', [
    GuideSection(
      'Bereiche vorbereiten',
      'Mittelpunkt auf dem Globe wählen oder Koordinaten eingeben, Radius bis 25 km und gewünschte Details/Assets wählen. Web bietet zusätzlich die gesamte Schweiz. Download und Aufbereitung benötigen Zeit, freien Speicher und eine geöffnete App. Quelllücken und gewählte Details begrenzen die Abdeckung.',
    ),
    GuideSection(
      'Was fehlt',
      'Vorbereitete Karten und Gelände ersetzen keine Liveinformationen. UAS-, Hindernis- und SLF-Snapshots behalten ihre Quelldaten und Gültigkeit. WMS, Orts-/Straßenbeschriftungen, Streaming-3D und Liveverkehr/Wetter sind nicht als vollständige Offlineebenen enthalten. Fehlende Beschriftungen führen im Nur-Cache-Modus nicht zu einem heimlichen Onlineabruf.',
    ),
    GuideSection(
      'Persönliche Daten',
      'Backups schützen Spots, Bilder, Ausrüstung und Planung unabhängig vom Kartencache. Optionales Passwort schützt den Export; ungeschützte Backups sind lesbar. API-Schlüssel und öffentliche Karten-/OSINT-Caches gehören nicht zum persönlichen Backup. Browser können lokalen Speicher löschen; wichtige Daten zusätzlich sichern.',
    ),
  ]),
  GuideTopic.privacy: GuideArticle('Datenschutz und API-Zugänge', [
    GuideSection(
      'Lokal und online',
      'Persönliche Einträge bleiben lokal. Kartenanbieter sehen angeforderte Kartenausschnitte; aktivierte Beschriftungen senden ebenfalls nur den benötigten Bereich. Eine bestätigte Route sendet Start/Ziel an den Routingdienst. Orts-/Adresssuchen werden erst beim Absenden übertragen. Standortanzeige ist freiwillig und arbeitet nur im Vordergrund; es wird kein Standortverlauf angelegt.',
    ),
    GuideSection(
      'Zugänge',
      'Anbieterbedingungen und Berechtigungen gelten pro Quelle. Für ASTRA das Token des passenden Produkts verwenden, nicht Token-Hash oder OJP-Token. Android nutzt die bestehende sichere Schlüsselablage; Schlüssel gehören weder in einfache Einstellungen noch in Backups. Web-Zugänge bleiben in den bisher unterstützten Grenzen. Keine öffentlichen Proxys geben private Schlüssel weiter.',
    ),
  ]),
  GuideTopic.weather: GuideArticle('Wetter und 3D-Wind', [
    GuideSection(
      'Wetterraster',
      'Bewölkung, Niederschlag, Regen, Neuschnee, Schneehöhe und Temperatur sind getrennte Modellprognosen mit gemeinsamer Zeit. Summen gelten für eine Stunde; Schneehöhe ist davon unabhängig. Das Stichprobenraster ist kein Wetterradar und keine gemessene 3D-Wolke. Offizielle Radarprodukte benötigen eine gesonderte HDF5-/Projektionsaufbereitung und werden hier noch nicht angezeigt.',
    ),
    GuideSection(
      'Modell und Messung',
      'Eine Modellprognose ist keine lokale Windmessung am Flugpunkt. Die 3D-Pfeile folgen der Luftströmung, nicht der meteorologischen Herkunftsrichtung. Farben: grün <3, gelb 3–7, orange 7–12, rot ab 12 m/s. Fehlende oder abgelaufene Werte bleiben nicht verfügbar.',
    ),
    GuideSection(
      'Simulation',
      'Pfeile und Einfluss auf die Flugphysik sind unabhängig schaltbar. Eine feste Sonnen-/Mondzeit ändert die Winddaten nicht. Für eine andere Windprognose die Datenquelle/Zeit ausdrücklich wählen. Lokale Böen und Gelände-Effekte können von der Modellnäherung abweichen.',
    ),
  ]),
  GuideTopic.obstacles: GuideArticle('Hindernisse und Funkabschattung', [
    GuideSection(
      'Veröffentlichte Hindernisse',
      'BAZL-WMS zeigt kombinierte Rasterbilder; Kategorien und Höhen sind daraus nicht einzeln auswählbar. Vektordaten bieten Details, soweit die Quelle sie enthält. Unbekannte Höhen bleiben unbekannt. Gerade Kabelverbindungen und einfache Mast-/Kranmodelle sind Näherungen, keine exakte Bauwerksaufnahme.',
    ),
    GuideSection(
      'Planungshilfen',
      'Markierte Puffer um veröffentlichte Punkte/Linien sind Planungshilfen. Sie definieren weder rechtlichen Abstand noch vertikale Freigängigkeit. Funk-LOS/Fresnel prüft unterstützte Geländedaten und Annahmen; Gebäude, Vegetation und nicht erfasste Objekte können weiterhin abschatten. Fehlende Hindernisse oder freie Geometrie sind kein Sicherheitsnachweis.',
    ),
  ]),
  GuideTopic.mobility: GuideArticle('Navigation und Verkehr', [
    GuideSection(
      '3D-Umgebung',
      'Unter Einstellungen → Navigation oder Kartendarstellung → 3D-Umgebung lassen sich Gebäude und Vegetation jeweils auf Wie Karte, Aus oder Ein stellen. Die normale Karte und Luftfahrthindernisse behalten eigene Einstellungen. Fehlende Streaming-Daten unterbrechen die Navigation nicht. Die geglättete Anzeige bleibt beim letzten GPS-Punkt stehen; Geschwindigkeit und Routenführung verwenden die ursprünglichen Messwerte.',
    ),
    GuideSection(
      'Navigation',
      'Routen und Ansagen sind Orientierungshilfen. Straßenregeln und die reale Situation gehen vor. Der Kompass richtet zuerst nach Norden aus; erneutes Antippen kehrt zur schrägen Verfolgungsansicht zurück. Ungenaue GPS-Signale begrenzen Richtung und Neuberechnung.',
    ),
    GuideSection(
      'Verkehrsdaten',
      'Situationsmeldungen und Messstellen sind verschiedene Quellen mit eigenen Tokens. TMC-Codes benötigen die passende amtliche Ortstabelle. Unverortete, abgelaufene oder unvollständige Meldungen dürfen nicht als freie Strecke gelten. Messgeschwindigkeiten sind punktuelle Beobachtungen, keine flächendeckende Live-Staukarte.',
    ),
  ]),
};
