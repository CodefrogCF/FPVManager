# Datenschutzerklärung für FPVManager

Stand 18. November 2026 · [English version](#fpvmanager-privacy-policy)

Codefrog betreibt das nichtkommerzielle Open-Source-Projekt FPVManager.
Datenschutzanfragen kannst du an [ribbit@codefrog.ch](mailto:ribbit@codefrog.ch)
senden.

## Daten auf deinem Gerät

FPVManager speichert Spots, Bilder, Notizen, Ausrüstung, Routen,
Aufzeichnungen und Einstellungen in seiner lokalen Datenbank. Die App
hat kein Benutzerkonto, keinen eigenen Synchronisierungsdienst und
keine integrierte Werbung oder Nutzungsanalyse. Standortzugriff erfolgt
auf deine Aktion hin im Vordergrund. Die App führt dabei keinen
automatischen GPS-Verlauf.

Persönliche Daten bleiben gespeichert, bis du sie in der App löschst
oder den App-Speicher entfernst. Exporte liegen am gewählten Ziel und
können mit einem Passwort verschlüsselt werden. Unverschlüsselte Exporte
sind lesbar. Android schließt den App-Speicher von automatischer
Sicherung und Geräteübertragung aus. Unter iOS kann die vom System
verwaltete Gerätesicherung persönliche App-Daten enthalten. Die App
schließt ihren separaten iOS-Speicher für Karten und öffentliche
Datensätze von Gerätesicherungen aus.

## Online-Funktionen

Die App verbindet sich für Karten, Gelände, Quellenabfragen und
aktivierte Live-Daten direkt mit den jeweiligen Anbietern. Sie
erhalten die IP-Adresse und die Informationen für die Anfrage,
etwa Kachel-IDs, einen Kartenausschnitt, Koordinaten, Suchbegriffe
oder von dir hinterlegte Zugangsdaten für den betreffenden Dienst.
Angefragte Online-Kacheln können beim Zentrieren oder Folgen
Rückschlüsse auf den Standortbereich zulassen.

FOSSGIS protokolliert Routenabfragen mit Start und Ziel. Bei einer
Neuberechnung während der Navigation kann der aktuelle Standort als
neuer Start übermittelt werden. Open-Meteo erklärt, dass seine
Serverprotokolle Koordinaten enthalten können und nach 90 Tagen
gelöscht werden. Andere Anbieter verarbeiten Anfragen nach ihren
eigenen Bedingungen. Die [technische Übersicht](docs/user/privacy_and_permissions.md#network-requests)
nennt die wichtigsten Empfänger, Anfragearten und Auslöser.
[FOSSGIS](https://routing.openstreetmap.de/about.html) ·
[Open-Meteo](https://open-meteo.com/en/terms#privacy)

Unter **Einstellungen → Offline & Daten** kannst du das Online-Nachladen
für Grundkarte und Gelände ausschalten. Die Einstellung gilt auch nach
einem Neustart. Live-Ebenen und ausdrücklich ausgelöste Online-Abfragen
haben eigene Bedienelemente. Standortberechtigungen kannst du in
deinem Betriebssystem oder Browser ändern.

Wende dich für Fragen, Auskunft, Berichtigung oder Löschung an
[Codefrog](mailto:ribbit@codefrog.ch). Codefrog hat keinen Zugriff auf
deine lokale App-Datenbank. Bei Daten, die ein externer Dienst führt,
gelten dessen Kontakt- und Datenschutzinformationen.

# FPVManager privacy policy

18 November 2026

Codefrog maintains FPVManager as a non-commercial open-source project.
For privacy enquiries, contact [ribbit@codefrog.ch](mailto:ribbit@codefrog.ch).

## Data on your device

FPVManager stores places, photos, notes, equipment, routes, recordings and
preferences in its local database. It has no account, app-managed sync,
integrated advertising or usage analytics. Foreground location access
starts in response to your actions. It does not create a GPS history
automatically.

Personal records remain until you delete them in the app or remove the
local app data. Exports go to the destination you choose. You can
encrypt them with a password. Unencrypted exports remain readable.
On Android the app excludes its data from automatic backup and device
transfer. On iOS, the system's device backup can include personal
records. The app excludes its separate iOS store for maps and public
datasets from device backups.

## Online features

FPVManager requests maps, terrain and enabled online data directly from
the relevant providers. They receive your IP address and the inputs for
their service, such as tile IDs, map bounds, coordinates, search text or
the credential you provided for that service. Centering or following
your position can reveal its area through online tile requests.

FOSSGIS logs route requests with their start and destination.
Rerouting can use your current location as the new start. Open-Meteo
says its server logs may contain coordinates and are deleted after
90 days. Other providers handle requests under their own terms.
The [technical guide](docs/user/privacy_and_permissions.md#network-requests)
lists the major destinations, request data and triggers.
[FOSSGIS](https://routing.openstreetmap.de/about.html) ·
[Open-Meteo](https://open-meteo.com/en/terms#privacy)

**Settings → Offline & personal data** can disable online fallback for
the base map and terrain. This choice persists after restarting.
Live overlays and explicitly requested online services have their
own controls. You can change location permissions in your system
or browser.

Contact [Codefrog](mailto:ribbit@codefrog.ch) for enquiries, access,
correction or deletion. Codefrog has no access to your local app
database. For data held by an external service, use its contact and
privacy information.
