# Germany-wide online map and experimental 3D sources

## User-facing behavior

- Nationwide: official **basemap.de Web Raster** (topographic / satellite-map
  fallback) and **basemap.de Web Raster Combshade** (relief). Both are remote
  WMS overlays under **CC BY 4.0**, not terrain elevation providers.
- Berlin/Brandenburg: LGB **DOP20c** orthoimagery is layered above the official
  country-wide *topographic* fallback in satellite mode; LGB **DGM1 hillshade**
  is shown above the nationwide relief. **No nationwide satellite imagery** is
  claimed. The underlying Swiss imagery remains unchanged.
- Optional: **basemap.de 3D DGM5 terrain and LoD2 3D Tiles**. The user can
  enable the clearly labeled online test service under *3D & Light*; this is
  initially off for public builds. Explicit diagnostic builds using
  `--dart-define=FPV_REGIONAL_3D_TEST=true` start it enabled.
- The automatic 3D switch is country-scoped using a low-resolution Natural
  Earth outline (public domain), **not the nationwide bounding rectangle**.
  Near national borders classification is approximate; it is not a cadastral
  boundary. The active provider changes outside that outline or above the
  defined camera height threshold. Flight/navigation transitions retain their
  existing pause-safe switch and recovery behavior.

## BKG 3D-specific license restrictions

Official terms: <https://sgx.geodatenzentrum.de/web_public/gdz/lizenz/deu/lizenz_basemapde_3d-testbetrieb.pdf>

- Licensed **only for test operation**, including testing in public electronic
  networks. No grant for ordinary indefinite production use is asserted.
- Download, extraction, export, offline preparation, permanent tile cache and
  reuse of 3D service data outside the 3D service are prohibited; electronic
  storage is permitted only *during runtime*.
- FPVManager fetches these resources directly from the BKG host; they are not
  included in `offline/maps`, route/region packages, the service-worker's
  same-origin application snapshot or the offline preparation worker.
  Cesium keeps bounded temporary in-memory working sets. For BKG 3D network
  resources `installRuntimeOnlyTransport` enforces Fetch `cache: no-store`
  (including descendant tiles), and fails closed when this transport cannot be
  installed. No persisted cache is implemented in FPVManager for these endpoints.
  Embedding hosts must additionally inspect third-party browser/proxy caching
  policies, because an application cannot control upstream intermediary storage.
- Display on-screen: `© GeoBasis-DE/BKG 2026` and a change notice for the
  combination with other map services, linked to the BKG test license.
- BKG DGM5/LoD2 are visual, experimental sources. The vertical datum is
  currently *unverified* for physics, RF line-of-sight and route elevation
  analysis. Do not infer height validity or surface collisions from a rendered
  building. Missing tiles/unknown height stay **unknown**, not clear or zero.

## Separate raster license

<https://sgx.geodatenzentrum.de/web_public/gdz/lizenz/deu/nutzungsbedingungen_basemapde.pdf>

Raster / hillshade are explicitly licensed under CC BY 4.0 (alternatively
DL-DE BY 2.0) and have different conditions than the 3D test services. Attribution
and change notice are shown as linked Cesium credits.

## Copernicus GLO-30 and regional DGM1

Copernicus DEM GLO-30 is a potential **future independently hosted** fallback.
The dataset itself is not a Cesium Quantized Mesh endpoint; there is no public
unrestricted endpoint selected in this integration. The conversion to mesh,
service hosting, vertical reference and associated credits must be verified
before wiring it in as a live 3D source. Do not silently substitute a different
provider or report this fallback as active. A regional DGM1/GCG2016 reference
for the Rüdersdorf scan continues to be handled independently; its existing
alignment/clipping approvals are unchanged.

References: <https://basemap.de/produkte-und-dienste/3d/>,
<https://basemap.de/produkte-und-dienste/web-raster/>,
<https://basemap.de/produkte-und-dienste/web-raster-schummerung/>.
