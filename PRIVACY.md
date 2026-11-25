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
