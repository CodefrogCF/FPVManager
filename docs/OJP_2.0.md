# Public transport with Open Journey Planner 2.0

## Configuration and data boundary

* Register for the **OJP 2.0** product on https://api-manager.opentransportdata.swiss/ . The OJP 1.0 credential is not interchangeable.
* Open **Mobility & OSINT → Public transport**; enter a personal API key in the dedicated credentials section. It is saved in `LocalApiCredentialVault` (native platform secure storage; browser session memory). The key is not stored in Drift, app settings, backup files, activity profiles, globe JavaScript or journey snapshots.
* Endpoint: `https://api.opentransportdata.swiss/ojp20`, XML 2.0 with `POST`, `Content-Type: application/xml` and `Authorization: Bearer …`.
* Coordinates, requested time and the user's selected origin/destination are submitted to this third-party platform only upon explicit consent and pressing **ÖV-Verbindungen suchen**. The selected spot and map coordinate are **not** automatically replaced by road parking/access points.
* Date and time are entered in the **device's local timezone** and sent to OJP as UTC. The application rejects nonexistent device-local times across spring DST. Ambiguous autumn times follow the device runtime's local-time resolution. Returned dates include UTC/offset and are displayed in the device timezone.
* A journey may contain `TimedLeg`, `ContinuousLeg` (walking) or `TransferLeg`, and service `TimetabledTime` is not overwritten by optional `EstimatedTime`. Missing predictions are not interpreted as on-time operations.
* Users can save up to five result sets locally, each dated by `fetchedAtUtc`. They are restored offline as **archived, not live**. Snapshots are included in encrypted or unencrypted personal backups according to the user's backup choice; credentials are excluded.

## Rate plans and reliability

The default, free OJP 2.0 plan allows **50 requests/minute and 20,000/day**. The published CHF 500 and CHF 1,000 monthly products support larger quotas. The selected plan in FPVManager is **session-local**; changing the selector does not change the subscription purchased from the platform. The client enforces local, rolling rate limits, coalesces in-flight identical searches, caches repeated answers for 30 seconds and backs off after HTTP 429. This is **not** a cross-device / cross-session global quota tracker; server quotas still prevail.

Requests are not automatically retried. Invalid/missing credentials, HTTP 401/403, server 429, malformed XML and empty results are distinct paths. The API response body and credentials are not logged or shown to the user.

## Sources

* https://opentransportdata.swiss/en/cookbook/open-journey-planner-ojp-landing-page/
* https://opentransportdata.swiss/en/cookbook/open-journey-planner-ojp-landing-page/ojptriprequest-2-0/
* https://opentransportdata.swiss/en/limits-and-costs/
* https://opentransportdata.swiss/en/howto-access-apis
