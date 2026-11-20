# FPVManager – Schnellstart

FPVManager verbindet eine Schweizer 3D-Karte mit Werkzeugen zur FPV-Flugplanung,
Ausrüstungsverwaltung, Funkstreckenanalyse und Flugsimulation. Persönliche
Daten werden lokal verwaltet. Karten-, Wetter- und andere öffentliche
Informationsquellen können eine Internetverbindung benötigen.

## Karte und eigene Daten

1. Unter **Einstellungen → Sprache** Deutsch oder Englisch auswählen.
2. Über **Karte & Ansicht** die Kartenansicht, Luftraum-, Hindernis- und
   Informations-Ebenen aktivieren.
3. Einen Kartenpunkt auswählen und bei Bedarf als **gespeicherten Ort** anlegen.
4. Unter **Ausrüstung** Drohnen-, Akku- sowie Funk-/Videoprofile verwalten.
5. Unter **Flugrouten** Wegpunkte und Höhen bearbeiten und anschließend
   Gelände-, Funk- und Energieanalyse aufrufen.

**Wichtig:** Die Anzeige einer freien Strecke oder einer fehlenden Einschränkung
ist keine behördliche Flugfreigabe. Datenaktualität, Rechtslage und Hindernisse
müssen unabhängig geprüft werden.

## Flug simulieren

1. Einen Startpunkt wählen und **Kartenaktionen → Flugsimulator** öffnen.
2. Drohnenprofil, Flugmodus (**Angle**, **Acro** oder **GPS**) und Starthöhe wählen.
3. **Flug starten**; bei Bedarf Kamera, Steuerung, Wind und Anzeige anpassen.
4. Unter **Funkvorschau** den Bodenstationsstandort und die optionale
   Sichtlinien-Darstellung einstellen.
5. Für getrennte Video-/RC-Simulation **SIM RF profiles** auswählen. EU/CE,
   FCC und eigene Werte ändern **nur** die Simulation, nicht den Sender.

Die Live-Sichtlinienanalyse unterstützt Strecken bis 50 km. Unvollständige
Geländedaten werden als unsicher gekennzeichnet. Fehlende Kacheln können dazu
führen, dass die Drohne weiterfliegt, obwohl die Bodenfreiheit **nicht**
überprüft werden kann.

## Akku und GPS Rescue

- Akkuchemie auswählen (LiPo, LiHV, Li-ion, LiFePO₄, NiMH, NiCd),
  Kapazität/Zellzahl und optional C-Ratings sowie Innenwiderstand eintragen.
  0 mΩ wird als **keine eigene Widerstandsangabe** behandelt.
- Der Energieverbrauch und die Funkqualität sind **Schätzungen**, keine
  Messwerte des realen Copters.
- Der optionale GPS-Rescue-Test hält bei modelliertem RC-Verlust zunächst die
  Position, steigt ungefähr 100 m über die Ausfallhöhe, dreht zum Homepoint,
  fliegt zurück und landet. Nach stabiler RC-Wiederverbindung kann die
  Steuerung mit einer deutlichen Roll-/Nick-/Gier-Eingabe wieder übernommen
  werden; Gas allein genügt nicht.

## Vertiefende Informationen

- [Ausführliches Benutzerhandbuch (Englisch)](../user_guide.md)
- [Flugsimulator, Funkmodell und Rescue (Englisch)](flight_simulation.md)
- [Akku-, Motor- und ESC-Profile (Englisch)](battery_and_power.md)
- [Wetter](weather.md), [Flugvorbereitung](preflight.md),
  [Koordinaten und Höhen](coordinates_and_heights.md)
- [Datenschutz und Berechtigungen](privacy_and_permissions.md)

Die Anwendung bietet zudem kontextbezogene Hilfe unter **Einstellungen → Hilfe**.
