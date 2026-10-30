# Using FPVManager

## Map and terrain

The globe fills the main view. Floating controls open navigation (upper left),
map status and source warnings (info/warning badge), layers and map actions
(upper right). Selected objects appear over the map; details scroll without
resizing the globe. On short landscape screens, layers and status open at the
side. Equipment is grouped under **Equipment** in the navigation menu.

The compass at the upper right follows map rotation. Tap it to face north.

**Mein Standort** requests foreground location, shows an accuracy circle and recentres
once. Long-press it or open **Standortanzeige** for following and on/off controls;
moving the map stops following. Old fixes are grey. **Ort oder Koordinaten suchen**
accepts WGS84 latitude/longitude, LV95 east/north or Swiss place/street names.
Select a result to mark it; this does not save a spot. Coordinates work offline;
place/address queries are sent to swisstopo only when submitted.

Open **Map layers** in the map menu. Its **Map**, **Airspace** and **Obstacles**
tabs separate display settings and data sources. Choose Satellite, Topographic or Relief, show UAS zones
and saved spots, adjust zone opacity and change spot/zone overlay order. These
preferences are saved locally. Overlay order does not make objects visible
through terrain. Failed preference loads offer Retry or Reset; failed saves
retain the current choice and offer Retry.

**Map → 3D-Umgebung und Himmelslicht** optionally streams swisstopo buildings
and modelled vegetation, with a bounded memory cache and fewer details in the
Performance flight profile. These Swiss layers are separate from offline map
regions; missing objects stay missing and have no collision model.
**Aktueller Sonnen- und Mondstand** enables current-device-time day/night lighting.
In the route menu, **Sonnen- und Mondzeit** saves a date/time preview with the route.
The same choice is available before flight and in its HUD settings. Enter device-local
time; storage is UTC. A fixed time stays frozen. Flight exit restores route/map lighting.

Select a map point to see coordinates and height information. Terrain heights
use the WGS84 ellipsoid; **Convert to Swiss height (LN02)** is an optional online
conversion. The AGL calculator adds a local vertical offset. See
[coordinates and heights](coordinates_and_heights.md) for the reference systems.

Individual missing tiles show a warning while loaded 3D terrain stays visible.
An incomplete route profile cannot assess terrain clearance. If the terrain
provider is unavailable, the map shows a labelled flat fallback and disables terrain
queries and ground inspection. **Retry terrain** reconnects while preserving
the camera and layers. Select a fresh point after recovery. A flat map does not
provide a measured ground height.

## Offline maps and backups

Open **Offline & personal data → Add offline region**. Enter coordinates or mark
the centre on the globe; choose a radius up to **25 km**. Web additionally offers
**Gesamte Schweiz**. Choose map detail, terrain detail, topographic/SWISSIMAGE
satellite/neutral-relief imagery and a storage limit, then **Bereich offline
vorbereiten**. The estimate describes derived storage; transferred source data
can differ. Web checks its available browser quota and requests persistent storage.
Keep the app and preparation page open. Returning cancels the worker; repeating
the same selection resumes already prepared tiles. Existing regions stay active
until successful publication. Source editions, preparation time and gaps remain
distinct; no heights are invented where official rasters contain no data.

Tap a saved region to activate it. **Use cached base map and terrain** prevents
remote map/terrain fallback; other API actions remain separate. Personal records
are already local. UAS zones, vector obstacles and SLF bulletins can be selected
for an additional refresh before preparation; they remain dated snapshots.
Streaming buildings/vegetation, WMS images and live traffic/weather/aircraft data
are not promised as complete offline layers. Removing regions prunes their tiles.
The optional viewed-tile buffer is separate and can remain incomplete (256 MiB).

An optional laptop workflow remains available for small topographic packages:
choose **Vorbereitungsdatei für Laptop speichern**. The plan discovers official
Swiss Map Raster and swissALTI3D downloads. Copy the exported `.fpvofflineplan`
file to the laptop first. The command below assumes it is in the repository
folder; otherwise pass its actual path, for example in Downloads:

```powershell
python -m venv .dart_tool/offline-preparation
.dart_tool/offline-preparation/Scripts/python -m pip install -r tool/offline_region_requirements.txt
.dart_tool/offline-preparation/Scripts/python tool/prepare_offline_region.py "offline-region.fpvofflineplan" -o "region.fpvregion"
```

Transfer the result and choose **Offline-Paket importieren**. The app checks the
whole package before activating it; tapping another saved region switches the
active area. Source editions and preparation time remain separate. The package
contains derived imagery and terrain only within its bounds and chosen detail;
it supplies no current restrictions, traffic, weather or obstacle updates.
Legacy import/export packages are limited to 64 MiB. The laptop retains checked source
files in `.fpv-sources` beside the output (up to 2 GiB); reruns reuse matching
checksums. Delete unused source files when no longer needed. A new plan checks
available source editions; `--replace` explicitly replaces an existing output.

**Create backup** exports personal records, images and planning preferences in a
portable file up to 64 MiB. Password protection is enabled by default; keep the
password separately. **Restore backup** validates the file and shows counts before
replacing current personal data. Back up your current data first. API keys and
public map/OSINT caches are excluded. A prepared Web build needs one complete
online installation before offline reopening; browser storage can be cleared or
evicted. Close all app tabs and reopen to activate a newly downloaded Web version.

## Aviation obstacles

Under **Map layers → Obstacles**, enable the transparent **WMS**
overlay, adjust its opacity or open the official legend. The separate **3D vector**
option imports the full official KMZ; its first download/import can take several
minutes. Zoom into a local area, choose categories and select an object for
source details. Both options are also available in the route editor. Visibility,
opacity and category choices persist locally. **Check source for updates** checks
metadata and downloads only a changed dataset; failed updates retain the last
valid snapshot. Cached vectors reopen offline, while terrain/imagery still need
network access. Publication, retrieval, cache age and source validity are shown
separately. Rendering is limited to a local viewport; zoom in when the display
limit is reached.

Enable **3D obstacle models** within the vector layer for schematic pylons, poles,
antenna masts, towers, cranes, chimneys, wind turbines and cableway supports.
Models use the published height above ground: 10 m AGL draws a 10 m model.
Shape, width and heading are illustrative. Missing types/heights, loading failures
and views beyond 6 km retain symbols; cables and ropes keep their existing geometry.
The preference persists locally and the models are bundled for offline use.

The data covers published obstacles only and cannot establish absence of hazards
or permission to fly. WMS provides combined symbols without category selection
or precise heights. Vector LN02 elevations are converted locally with CHGeo2004;
unknown heights/modes use ground markers at the first source vertex. Straight
lines and polygon outlines are approximations; cable sag and clearance are not
calculated.

**Highlight hazard areas** independently draws cyan horizontal buffers around
published points and lines. Set 0–1000 m in **Map layers → Obstacles**; visibility
and distance persist locally. Category filters apply. These calculated areas
are advisory, including in ground view, and do not specify legal separation.
Where a cable vertex matches a published mast, its display follows the mast's
terrain-adjusted top. This correction is approximate; source heights remain in
the details and are used for route checks.

## Ground view

Select a terrain point or saved spot, then use the walking icon beside the
right-hand map menu to spawn approximately two metres above terrain. Move with
WASD, arrow keys or the transparent stick at the lower left. Drag to look around,
or use the fixed transparent stick at the lower right. A controller uses its
left stick to move and right stick to look; B exits.
Click the map to restore keyboard focus after using another control.

Use the globe icon or Escape to return to the previous camera. Home, coordinate
navigation, spot/route framing and opening another library also leave ground
view. Terrain loss ends it. Movement pauses where no rendered height is available.
This camera follows terrain detail; it does not model buildings, vegetation or
collisions.

## Free flight simulation

Choose **Map menu → Spawn in map · simulated flight**. Set the spawn height AGL.
Angle/GPS use speed, climb and response limits, optionally copied from a drone
profile; missing values use defaults. Spawn uses the selected map point/spot, or terrain under the camera
target when no point is selected. Detailed terrain is required.

Choose **Angle** (default), **Acro** or **GPS** in the flight settings. Reopening
settings and spawning switches mode at the original spawn point, level and stationary.
**FPV camera tilt** sets 0–80° upward relative to the drone in Angle/Acro.
Open **HUD settings → Camera** to change it during flight without respawning;
camera tilt changes the view, not thrust or the drone's attitude.

**Graphics profile** offers Quality (100% resolution), Balanced (85%, default)
and Performance (75%), with progressively less multisample antialiasing. Change
it before spawning or in **HUD settings → Graphics** during flight. It affects image quality,
not terrain detail or flight physics. The choice stays in this session; exiting
flight restores the globe's previous graphics settings.

During flight, the globe retains recently viewed terrain and associated imagery
with a cache target of 512 tiles (normally 100), helping when circling or looking
back. Visible tiles can exceed this target; memory use depends on tile detail
and active imagery layers. Exiting restores the previous budget. This cache is
in memory for the current renderer, not persistent offline storage.

- **Angle:** Mode 2 — left stick vertical is throttle, horizontal is yaw; right
  stick vertical controls pitch and horizontal controls roll. Tilt is limited to
  50° and levels when released. Tilting directs thrust and requires more gas to hold height.
- **Acro:** The same Mode 2 layout commands body rotation. **Acro rates** sets separate
  roll/pitch/yaw maximum rates (10–1,500°/s) and shared stick expo (0–1).
  Defaults retain 180°/s and linear input; expo softens the centre while retaining
  full-stick speed. Settings stay in this session, including camera changes and resets.
  Releasing pitch/roll stops rotation after a short response, retaining attitude.
  Rotor thrust follows the drone's body: inverted full throttle accelerates
  downward, zero throttle allows gravity/drag free fall and existing momentum
  continues. There is no assisted speed/climb limit, leveling or altitude hold.
  **Acro physics** adjusts estimated thrust/weight, thrust curve, motor response
  and terminal free-fall speed (air drag). Defaults are 4:1, quadratic, 0.04 s and
  22.5 m/s, giving about 159 km/h in steady full-throttle level flight. The
  settings show this estimate; diving can be faster. These remain simplified
  assumptions, independent of profile speed limits. The HUD shows horizontal
  speed in km/h and signed vertical speed **V** in m/s.
- **GPS:** The previous assisted mode — left stick translates, right stick looks,
  neutral input brakes and maintains height. Its controls match ground view.

FPV keyboard: E/Q throttle, A/D yaw, W/S (or up/down arrows) pitch, left/right
arrows roll; IJKL also controls pitch/roll. In GPS, WASD/arrows move, drag/IJKL
looks and E/Q climbs/descends. Both touch sticks stay at fixed opposite positions;
the separate ↑/↓ buttons appear only in GPS mode. **Touch-Steuerung anzeigen** in
HUD quick settings or map actions saves their visibility locally. Hiding them
releases touch input; keyboard and external controllers remain available.
Right/left triggers and R1/L1 provide additional gas/height controls.
  Angle touch/keyboard input retains its centred hover aid. Acro touch/keyboard uses the upper stick half for 0–100%
motor command: centre and downward input cut thrust; fully up gives 100%.
The estimated hover point depends on the physical settings (50% with defaults)
and applies only while level.
The Acro HUD shows signed vertical speed: negative is descent toward terrain.

Choose **Goggles** or **Betaflight OSD** before flight or in **HUD settings**.
Both show speed, AGL, **H START** (height above the ground at spawn), **D HOME**
(horizontal distance) and a home arrow relative to the view heading. At spawn,
H START equals the configured spawn height; below that ground elevation it is negative.
Unknown terrain heights stay unknown. The layout choice lasts for this session.
**Koordinaten im HUD anzeigen** before flight, or **HUD settings → Koordinaten anzeigen**
in flight, adds a small WGS84 latitude/longitude line below the mode label in
either HUD style. It is off by default; its choice lasts for this session.
**HUD settings → Reset**, R or controller A returns to spawn; **Exit**, Escape,
controller B or the globe icon restores the map camera. Saved routes/obstacles remain visible.

The recording icon captures a simulated flight; **HUD settings** provides pause,
resume and review. Stop opens a preview with continuous sections, trimming and
3D simplification (up to 1,000 route waypoints). **Save as route** creates a new
local route and opens its editor. WGS84 ellipsoidal heights are preserved by
default; AGL requires recorded terrain heights. Recording ends on reset or exit.
**Map actions → Review flight recording** reopens unsaved data, including samples
retained after a renderer interruption. Unsaved recordings are temporary and are
lost when closing the app. Capture is limited to 30 minutes / 4,096 samples.

**Radio line of sight** before flight, or **HUD settings → Radio link preview**,
enables an optional geometric LOS/Fresnel preview. Choose the launch point, a saved
spot or fixed coordinates as transmitter; set antenna height, frequency and Fresnel
clearance. The small **LOS** HUD field opens details. Profiles cover up to 6 km,
use terrain points at most 25 m apart and update at most every two seconds.
Results expire after five seconds. Missing terrain stays unknown. Imported local
surface observations are optional; visible 3D objects are not automatically included.
This previews sampled geometry, not measured radio quality or guaranteed range.

**External controller** (flight settings or HUD settings) selects **Standard gamepad**
or **USB radio**. Zero-throttle position is **50% · centre** for self-centring controllers
or **0% · bottom** for RC radios. In Angle/Acro, bottom zero uses the full travel
(bottom 0%, centre 50%, top 100% gas); centre zero uses only the upper half.
Touch/keyboard, GPS and ground-view controls keep their existing behaviour.
USB radio channels start as roll/pitch/throttle/yaw on channels 1–4; assign and
reverse them to match the model in your radio and the axes reported by the OS.
No radio switches are assigned to Reset/Exit. These choices last for this session.

For a Tango 2, connect a data-capable USB cable and select **USB Joystick** on the
radio. Android needs USB host/OTG support and must recognize the radio as a joystick;
if a direct USB-C cable is not detected, try a suitable OTG adapter. Web needs a
secure context (HTTPS or localhost) and browser Gamepad API support.
Use zero throttle, centre the other sticks and release gamepad buttons after
connecting, changing assignments or resuming. Android also handles native gamepad axes/buttons. Input stops on focus loss and
disconnect. Brief input gaps pause controller commands; fresh values from the same
controller can resume within 750 ms without repeating the idle check. Longer gaps
require idle again. **HUD settings → External controller** shows recent input
interruptions for this session. Tap the view to resume; terrain loss returns to the globe. Movement
waits for terrain tiles and stops at terrain contact. Terrain refinement can
adjust the camera floor. Buildings, vegetation and cables have no collision model.

These simplified models do not predict real aircraft performance or verify
clearance. GPS assistance, rate control, motor response and isotropic drag are
approximations; individual motor/PID dynamics, propwash and battery sag are not modeled. State stays in memory;
there is no automatic flight recording/export. Online tile requests still reveal
the viewed area to map providers.

## Flight routes

Open **Flight routes** in the navigation drawer and create or open a route.
For an empty route, **Saved spot** adds waypoint 1 at a saved spot and links the
route to it. **Search place** moves the map to a Swiss address or place before
you set the first waypoint. The search sends your input only when submitted.

- Click terrain to append a waypoint; select a point to move or delete it.
- Use the selected waypoint's menu for **Height & speed**, **Move point** or **Delete point**.
- Drag to move, or right-click / Delete with the map focused to remove a point.
- The waypoint count opens a list; height/speed settings can also be applied to all points.
- **Undo waypoint change** reverses up to 50 edits; **Show entire route** frames it.
- **Save** stores the name and ordered waypoints together. Empty routes are allowed.

Changes remain a draft until Save. Leaving asks whether to discard edits, and a
failed save retains them for retry. Drafts survive renderer reloads while the
editor stays open, but not app termination or browser reload.

Under **Map layers → Map → Flight routes**, select up to 20 saved routes to display,
including in ground view. This selection lasts for the home-map session, not
across app restarts. The framing button returns to globe view.

Set AGL or an explicit absolute height and outgoing airspeed in **Height & speed**.
AGL applies at each waypoint; connecting lines do not follow terrain. WGS84
ellipsoid heights render directly. Missing heights and incompatible absolute
references retain a **30 m AGL preview** with a star marker; they do not supply clearance.
Use **Route options → Route equipment** to assign a drone and alternative battery
packs. Save also stores assignments and planning assumptions.

**Route analysis** separates Profile, Flight, Energy and Checks. Terrain is sampled at
most 50 m apart, up to 4,096 samples; split longer routes. The profile shows ground,
absolute WGS84 altitude and AGL, including intervening terrain. Distances are
approximate great-circle/3D estimates. Duration uses outgoing airspeed, optionally
with a manually entered steady wind. Unknown heights or impossible wind tracks
remain unknown. Recalculate after editing or terrain recovery.

In **Planning assumptions**, enter a level-flight speed/power curve, its source
and reference mass, total takeoff mass including battery, and reserve/scenario
assumptions. Available drone values can be copied for review. The model
interpolates without extrapolation, scales power by mass^1.5 and adds climb work;
descent does not recover energy. Wh and approximate mAh require known inputs.
Each battery is assessed individually using recorded charge and capacity.
Optional return flight retraces the planned path to takeoff with reverse wind.
Red segments indicate low sampled clearance or insufficient conservative reserve
for the inspected pack. These estimates do not guarantee flight feasibility or
detect cables, obstacles between samples, terrain errors, gusts or battery ageing.

In **Checks**, choose **Check current route** for horizontal UAS intersections,
configured height-limit exceedances and proximity to locally imported obstacles.
Results identify affected segments and source records; edits, category changes,
buffer changes and dataset replacements invalidate them. Red segments also mark
these findings. Height checks use samples, and obstacle checks use approximate
Swiss metric geometry; neither proves continuous clearance. Missing data and
limits are shown explicitly. **Route constraints** configures legal/operational
AGL ceilings and a planning radius from waypoint 1; a radius does not prove VLOS.
The default 120 m is a Swiss open-category planning reference, not a determination
of the rules for a particular flight. Verify current
[FOCA rules](https://www.bazl.admin.ch/de/flugregeln-drohnen), observers, approvals,
zone activation, people and local conditions manually.

Use **Import routes** in the route library to preview GeoJSON/GPX, then confirm
new local copies. Files support up to 4 MiB, 20 routes and 10,000 total points
(2–1000 per route). GPX track segments remain separate. A route's export menu
saves GeoJSON or GPX only on request; Android opens the system document picker,
Web starts a download. Equipment assignments are excluded.
GeoJSON uses longitude/latitude and optional WGS84 ellipsoid metres. GPX elevation
without a declared datum stays unverified. AGL, named height datums and airspeed
round-trip in FPVManager metadata/extensions, which other tools may ignore.
KML was evaluated but is not imported: altitude modes and geoid references require
explicit conversion to a supported format.

## Spots and photos

Open **FPV Spots → Add Spot**, or edit an existing spot. A selected raw map point
prefills new coordinates. **Use current location** requests a one-time position;
manual entry remains available if permission or lookup fails. Web location needs
HTTPS or trusted localhost. Save is required to store the result.

Spots support notes, favorites, one category and up to ten comma-separated tags.
Search matches name, notes, category and tags without case sensitivity; every
search term and selected filter must match. List pages contain up to 50 spots.
List filters do not hide map markers; the complete map supports up to 10,000 spots.

Add up to six JPEG, PNG or WebP still photos per spot, each no larger than 12 MiB
and 16 megapixels (maximum source edge: 16,384 px). GIF/animation and HEIC are
unsupported. Imported images are orientation-corrected, resized to at most
1,600 px and stored as JPEGs with thumbnails and no source EXIF/GPS metadata.
Original files remain unchanged. Open the gallery to zoom; additions/removals
are saved with the spot, and Cancel discards the draft.

## Equipment

The navigation drawer provides independent local equipment libraries:

| Library | Main behavior |
|---|---|
| Drone profiles | Record dimensions, propulsion and performance values with explicit units and a Measured/Estimated/unspecified source per number. Editing a number resets its source. |
| Battery inventory | **Types** are templates; **Packs** are physical batteries. Creating a pack from a type copies specifications. Later template edits do not update packs; **Copy type specifications** copies them explicitly. |
| Radio & video equipment | Record separate control/video/telemetry configurations, transmitter/receiver and antenna details, with assignments to multiple drones. |

Empty optional fields mean unknown. Battery voltage is entered explicitly;
calculated nominal Wh is separate from recorded Wh. Pack charge, cycle count,
condition and availability are manual records. Packs can be linked to drones and
saved flight plans; deleting a template preserves packs and their specifications.
Equipment profiles do not calculate endurance, RF range, compatibility or
permitted transmit power.

## UAS zones

Enable UAS zones in **Map layers**, select a zone and choose **Inspect restrictions**.
The sheet shows source codes/text, separate lower/upper limits, time information,
authority/contact details and provenance. Expand **All source attributes** for
additional values. Missing, shortened or omitted details are indicated.

For a selected saved spot, choose **Check airspace**. In the route editor, use
the shield button (**Check route airspace**) to check the current draft, including
segments between waypoints. All intersecting zones are listed with restrictions
and links to their details. Holes are excluded; touching any polygon boundary
counts as an intersection. Checking does not change overlay visibility or save edits.

Checks use horizontal, straight WGS84 segments. Codes, height references and time
offsets remain as supplied; height limits, activation and legal applicability
are not evaluated. A match or an empty result is not flight authorization.
Download time is retrieval time, not official validity.

UAS data is cached locally across restarts (one-hour local lifetime, up to 30 days
on disk). **Refresh UAS data** checks the source even within that lifetime;
**Clear UAS dataset cache** removes the snapshot and hides the layer. Source-check,
retrieval and available publication times remain separate. Stale data, expired
validity and failed refreshes are shown explicitly; cached data is not verified
current airspace information. Official preflight checks remain necessary.

Layer details show downloaded/loaded counts and **Not independently verified**
or **Limited / incomplete data** coverage. Empty, partial or unusable data produces
a limitation notice; an empty map does not establish unrestricted airspace.
Failed replacements retain the last displayed snapshot. Explicit refresh retries
rejected data. DABS/NOTAM information is not integrated.

Personal records are local; routes can be explicitly exported, but there is no
complete backup or sync interface. Map viewing
still contacts external providers. See [privacy and permissions](privacy_and_permissions.md)
and [map sources](map_sources_and_attribution.md).
