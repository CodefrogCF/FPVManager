# User guide

This guide follows the current menus. Some specialist tools retain English
labels; the shared map and settings menus use the German names shown below.

## Find the right control

| Where | What it contains |
|---|---|
| Navigation menu, upper left | Saved places, flight routes, weather, navigation/OSINT, ground routes, observations, equipment and offline data |
| **Karte & Ansicht**, layers button or map actions | **Karte**, **Luftraum**, **Hindernisse** and **OSINT** tabs |
| **Einstellungen** | Shortcuts to the same map hub, flight/controls, navigation overrides, data sources, offline data and help |
| **Quellen**, at the map edge | Complete active map-source notices and renderer acknowledgments |
| Selected map object | Coordinates, source attributes and actions relevant to that selection |

Activity profiles select shortcuts, not a different application. **Alle Werkzeuge**
keeps the full toolset reachable. Switching profiles does not erase personal
records or interrupt an active draft. Settings reuse the same saved values across
entry points. Long explanations and technical details are expandable; active
errors, validity and relevant use restrictions remain visible.

## Map, location and 3D

In **Karte & Ansicht → Karte**, choose Satellite, Topo or Relief. Place/street
names, roads/paths and saved places are independent switches. Overlay order is
under **Reihenfolge der Ebenen**; moving an overlay forward does not reveal it
through terrain. Names cover a bounded Swiss area and are not a complete street
index or an offline-region layer.

The compass faces north when tapped. **Mein Standort** requests foreground
location and recentres once; long-press it or open **Standortanzeige** for accuracy
and following controls. Moving the map stops following. Old fixes are grey.
**Ort suchen** accepts WGS84 latitude/longitude, LV95 east/north and submitted
Swiss place/street searches. Selecting a result does not save a place.

**3D & Licht** groups buildings, trees/forests, bridges/structures, automatic 3D
tunnels and sun/moon lighting. Models stream where source data is available;
they are separate from prepared offline maps. Schematic bridge supports and
tunnel interiors are approximations, not surveyed construction or clearance.
Automatic tunnels still load their source axes internally. The former separate
axis-overlay and surface-exploration switches are no longer offered. Explicit
catalogue search, model preparation/import and diagnostics remain under the
collapsed tunnel tools.

Route and flight settings can temporarily use a selected date/time for lighting.
Enter device-local time; stored values use UTC. Fixed time remains frozen, and
leaving the activity restores the map's lighting choice. Navigation has separate
**Wie Karte / Aus / Ein** overrides for buildings and vegetation under
**Einstellungen → Navigation**.

Select a raw map point for coordinates and terrain height. WGS84 ellipsoid,
Swiss LN02 and AGL are different references; see [coordinates and heights](coordinates_and_heights.md).
Missing terrain pauses ground-dependent actions. A labelled flat fallback is
not measured ground. Retry terrain, then select a fresh point after recovery.

## Places, equipment and routes

**Gespeicherte Orte** stores places, notes, favourites, categories, tags and photos.
A selected raw map point prefills a new place; device location is optional and
Save is required. Search/filtering affects the library, not the complete map
marker set. More summaries load while scrolling. Photo imports accept up to six
JPEG/PNG/WebP stills per place, each up to 12 MiB and 16 megapixels; stored copies
are resized and omit source EXIF/GPS metadata. Originals remain unchanged.
Map markers and labels follow terrain, including after a restart; buildings,
tree crowns and bridge decks do not raise them. Existing places need no re-save.

**Ausrüstung** groups **Drohnen**, **Akkus** and **Funk & Video**. Unknown values
stay empty; measured/estimated provenance belongs to the number entered. Battery
types are templates, while packs are physical batteries: later template edits
do not silently change existing packs. Equipment records do not certify RF
compatibility, permitted transmit power or endurance.

In **Flugrouten**, create a route and edit its waypoints on the globe. Use
**Height & speed** for AGL or an explicit absolute height and outgoing airspeed;
Save stores the draft and equipment/planning assumptions. Missing or incompatible
heights produce a marked 30 m AGL preview, not a clearance result.

**Route analysis** separates terrain Profile, Flight, Energy and Checks. Recalculate
after changing the route, inputs or datasets. Terrain is sampled between points;
power/energy results require a compatible speed/power curve and battery values.
No extrapolation, sampled clearance or reserve estimate guarantees feasibility.
**Checks** finds horizontal UAS intersections, configured height-limit findings
and approximate proximity to loaded obstacle data. Inspect the source records;
an empty result does not determine legal access or continuous clearance.

Import previews supported GeoJSON/GPX before adding new local routes. Exports are
explicit and exclude equipment assignments. Files support up to 4 MiB, 20 routes
and 10,000 total points, with 2–1,000 points per route. GPX segments remain
separate; undeclared elevation references remain unverified. Other tools may
ignore FPVManager's AGL, datum and airspeed extensions.

## Airspace and obstacles

**Karte & Ansicht → Luftraum** controls UAS zones and opacity. Select a zone to
inspect source restriction text, separate height limits, times and authority
contacts; expand source attributes for the remaining supplied fields. Saved
places and route drafts offer horizontal airspace checks. Activation, legal
applicability and unspecified height datums are not inferred. DABS/NOTAM data
is not integrated.

Data status, cache age, official validity and coverage are distinct. Failed
replacement retains the last displayed snapshot; explicit refresh retries the
source. **Daten & Quellen** contains detailed metadata and cache management.
Empty or limited data is reported and is never an all-clear.

**Hindernisse** separates the transparent official WMS imagery from selectable
3D/vector data. The first full KMZ import can take time. Zoom into a local area,
filter categories and inspect a feature for published values. Update checks fetch
a changed dataset; cached vectors can reopen offline. WMS imagery still needs
a connection. Category/opacity choices persist locally.

Optional bundled obstacle models draw supported masts, poles, cranes and similar
objects using available published heights. Shapes/headings remain illustrative;
unsupported objects retain symbols. Cable sag is not reconstructed. **Highlight
hazard areas** draws calculated advisory buffers, not mandatory legal separation.
The detailed height rules are in [coordinates and heights](coordinates_and_heights.md).

## Ground inspection and flight simulation

The walking icon starts a ground camera about two metres above a selected point
or place. WASD/arrows or the left stick move; dragging or the right stick looks.
Escape or the globe icon restores the previous map camera. Missing rendered
terrain pauses movement; this ground camera is not an exact object collider.

Choose **Kartenaktionen → Flugsimulator**. The compact form shows flight mode,
profile and spawn height; camera/HUD, graphics/time, controller and flight
parameters are expandable. **Flug starten** remains at the bottom. Spawn uses
the selected point/place or the terrain under the camera target. Detailed terrain
is required. Reapplying spawn settings starts level and stationary.

| Mode | Main controls |
|---|---|
| Angle | Mode 2: left stick throttle/yaw, right stick pitch/roll; limited tilt and self-levelling |
| Acro | Same sticks command body rotation; attitude and momentum persist; configurable rates, expo and simplified thrust/drag |
| GPS | Assisted translation/looking; neutral input brakes and holds height |

FPV keyboard uses E/Q for throttle, A/D for yaw, W/S for pitch and left/right
arrows for roll. IJKL also commands pitch/roll. In GPS, WASD/arrows move and
E/Q changes height. Touch sticks stay at fixed opposite positions. Hiding touch
controls releases their input without disabling keyboard/controllers.

The flight sliders button opens **Flugeinstellungen** with **Kamera & Anzeige**,
**Grafik & Licht**, **Controller**, **Wind** and **Funkvorschau** groups. Camera tilt
and horizontal FOV change the view without changing thrust. HUD layout and an
optional coordinate line are independent. Quality, Balanced, Performance and
Compatibility graphics can change during flight without respawning.

**Flug zurücksetzen**, R or controller A returns to spawn; Escape, controller B
or the exit button returns to the map. HUD AGL is local clearance above terrain;
**H START** is height above the spawn ground and **D HOME** is horizontal
straight-line distance home.

Synthetic tunnels use their lining, floor and roof for geometric contact.
Optional experimental native-model collision approximates nearby loaded top
surfaces; it does not reproduce every wall, tree or cable. Portal openings and
long-tunnel windows are model-derived. Contact or missing continuation can pause
movement. Background geometry/probe work is spread over frames, and long rendering
gaps do not replay a large unseen flight step. These measures do not guarantee a
particular device frame rate or a safe real-world passage.

External gamepads/USB radios need a matching layout, channel assignment and
zero-throttle position. Check directions before flight. Reconnect with zero gas,
other sticks centred and buttons released. Focus loss/disconnection stops input;
longer interruptions require the idle check again. Android needs joystick/USB-host
support; Web needs HTTPS/localhost and browser Gamepad API support.

The recording button captures a simulated flight. Review supports trimming and
conversion into a new local planning route, up to 1,000 waypoints. Recordings stop
on reset/exit and are temporary until saved. The capture limit is 30 minutes or
4,096 samples. **Flugaufzeichnung** reopens retained unsaved samples.

Optional wind and live radio-path previews are described in
[weather](weather.md) and [preflight/signal analysis](preflight.md).

## Offline maps and personal backups

Open **Offline & Daten** to prepare a region, activate an existing region or
manage personal backups. Mark a centre and choose a radius up to 25 km; Web also
offers **Gesamte Schweiz**. Select imagery, terrain/detail and storage limits,
then **Bereich offline vorbereiten**. Keep preparation open; cancelling leaves
the prior region active, and repeating the same choice can reuse prepared tiles.
Source editions, preparation time and gaps remain separate.

**Use cached base map and terrain** blocks remote fallback for those providers,
not every network action in the app. Streaming 3D, WMS overlays and live services
are not promised as complete offline layers. The viewed-tile buffer is separate
from a prepared region and can be incomplete. Browser storage can be evicted.

The optional laptop workflow exports `.fpvofflineplan`, prepares a `.fpvregion`
with `tool/prepare_offline_region.py`, then imports the validated package. Follow
the preparation instructions shown with that export; imported data is limited to
its bounds and selected detail. Package import does not fetch remote data.

**Create backup** exports personal records, images and planning preferences in a
portable file up to 64 MiB. Password protection is enabled by default. Keep that
password separately. Restore previews and validates the contents before replacing
personal data. API keys and public map/OSINT caches are excluded. Make a current
backup before restoring another one; no automatic account sync is provided.

## Specialist tools and data handling

- [Weather](weather.md): forecasts, observed radar, 3D wind and measured stations.
- [Navigation and OSINT](mobility_osint.md): driving, walking/cycling, traffic,
  aircraft, outdoor restrictions, wildfire, avalanche and dated imagery.
- [Preflight and signal analysis](preflight.md): checklists, LOS/Fresnel and telemetry.
- [Privacy](privacy_and_permissions.md): local storage, permissions and requests.
- [Sources and attribution](map_sources_and_attribution.md): data rights and credits.

**Einstellungen → Hilfe** provides bundled explanations offline. Source details
and current errors remain in their original tools. The app does not establish
flight permission, real-world obstacle clearance or current data completeness.
