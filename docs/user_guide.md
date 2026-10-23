# Using FPVManager

## Map and terrain

Open **Map layers** in the map menu. Its **Map**, **Airspace** and **Obstacles**
tabs separate display settings and data sources. Choose Satellite, Topographic or Relief, show UAS zones
and saved spots, adjust zone opacity and change spot/zone overlay order. These
preferences are saved locally. Overlay order does not make objects visible
through terrain. Failed preference loads offer Retry or Reset; failed saves
retain the current choice and offer Retry.

Select a map point to see coordinates and height information. Terrain heights
use the WGS84 ellipsoid; **Convert to Swiss height (LN02)** is an optional online
conversion. The AGL calculator adds a local vertical offset. See
[coordinates and heights](coordinates_and_heights.md) for the reference systems.

If terrain fails, the map shows a labelled flat fallback and disables terrain
queries and ground inspection. **Retry terrain** reconnects while preserving
the camera and layers. Select a fresh point after recovery. A flat map does not
provide a measured ground height.

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

The data covers published obstacles only and cannot establish absence of hazards
or permission to fly. WMS provides combined symbols without category selection
or precise heights. Vector LN02 elevations are converted locally with CHGeo2004;
unknown heights/modes use ground markers at the first source vertex. Straight
lines and polygon outlines are approximations; cable sag and clearance are not
calculated.

## Ground view

Select a terrain point or saved spot, then use the walking icon beside the
right-hand map menu to spawn approximately two metres above terrain. Move with
the arrow keys or transparent stick at the lower left; drag to look around.
Click the map to restore keyboard focus after using another control.

Use the globe icon or Escape to return to the previous camera. Home, coordinate
navigation, spot/route framing and opening another library also leave ground
view. Terrain loss ends it. Movement pauses where no rendered height is available.
This camera follows terrain detail; it does not model buildings, vegetation or
collisions.

## Flight routes

Open **Flight routes** in the navigation drawer and create or open a route.

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

**Route analysis** separates Profile, Flight and Energy. Terrain is sampled at
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

Personal records are local; there is no backup/export/sync interface. Map viewing
still contacts external providers. See [privacy and permissions](privacy_and_permissions.md)
and [map sources](map_sources_and_attribution.md).
