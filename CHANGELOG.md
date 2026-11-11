# Change summary

## 2026-11-11

- Replaced the stock tree models with six textured broadleaf and conifer
  variants at the same triangle count. Existing swisstopo instance groups use
  a bundled BAFU/WSL forest composition raster to guide model choice.
- Resolved bare vegetation tile paths against the revision published in the
  official index, restoring coverage for affected parts of the tileset.
- Added a German and English language setting for the app, map controls and
  flight interface. The choice is saved on the device.
- Prepared the Sun, Moon and Sun bloom programs during flight preparation.
  Briefly reduced Cesium's terrain-loading time slice during fast rotations
  and low, fast climbs or dives.

## 2026-11-10

- Fixed premature disappearance of large buildings at the edge of the flight
  view. Geographic culling bounds now enclose overhanging source content and
  propagate through loaded parent tiles, including the header-memory fallback.
- Anchored saved-place markers and labels to terrain instead of roofs, trees
  or bridge decks, including restored places after restarting the renderer.
- Removed the bridge search's recurring horizon terrain pick during flight
  and ground navigation; discovery now follows the current aircraft position.
- Spread large explicit 3D tileset header construction over small local
  subtilesets while preserving source geometry, materials and LOD settings.
- Prepared the shared 3D material-lighting lookup before flight activation
  when a 3D layer is enabled, instead of waiting for its first streamed model.
- Moved common terrain shader preparation before flight activation, with
  progress, cancellation and reuse on repeat flights, to reduce first-use
  graphics-driver pauses without reducing the selected image quality.
- Limited terrain collision sweeps to reachable rendered tiles and reused exact
  terrain vertices with bounded spatial acceleration for height/contact queries.
- Applied flight and ground camera updates before Cesium's motion and
  underground-state detection during rapid maneuvers.
- Prevented an empty globe after transient terrain-root failures; startup now
  validates and reuses all required roots and retries twice in the background.
- Disabled Windows route snapshots of the live WebView2 texture to prevent a
  native engine crash when opening saved places after selecting a map point.
- Added temporary terrain-refinement relief during fast turns and low-altitude
  streaming stalls, with staged restoration of normal detail.
- Included long in-flight frame pauses in opt-in performance diagnostics.
- Fixed blank grey coordinate fields on first expansion of the BAKOM,
  forest-fire prevention and dated-imagery panels, and constrained long imagery
  collection labels on narrow screens.
- Adopted Apache-2.0 for original project material; preserved separate software,
  data and service rights and the additional notices bundled by dependencies.
- Consolidated and refreshed user/developer documentation and in-app help.
- Removed development-ticket references and superseded documentation.

## 2026-11-09

- Grouped map/globe controls in **Karte & Ansicht**; shortened navigation and
  simulator menus and moved secondary details into expandable sections.
- Replaced verbose map credits with a compact sources control while retaining
  full notices and required visible provider attributions.
- Removed legacy tunnel-axis overlays and surface exploration controls;
  automatic 3D tunnels and their internal source catalogue remain available.
- Stabilized long-tunnel handoffs, portal heights and underground junctions.
  Portal openings preserve roads; tunnel walls render opaque from both sides.
- Added schematic bridge supports using mapped or verified native deck data.
- Reduced tunnel-build and depth-query bursts; large render stalls no longer
  produce large simulation catch-up movements.

Synthetic fixtures and desktop measurements do not establish Android frame rate,
surveyed tunnel geometry, real-world obstacle clearance or permission to fly.
