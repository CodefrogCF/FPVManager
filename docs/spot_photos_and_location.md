# Spot photos and device location

The spot editor supports manual WGS84 coordinates, a one-time device-location
request, description/notes and up to six photos. Open it with **FPV Spots → Add
Spot**, or the spot's **Edit** action. A selected map point supplies initial
coordinates for new spots. **Use current location** replaces the form's
coordinates after a successful request; manual edits made while the request is
pending take precedence over a late result.

Photo additions/removals remain a draft until **Save** writes spot metadata and
photos in one transaction. **Cancel** leaves stored data untouched. A failed save
retains the draft for retry. Saving is disabled until existing photos have loaded,
to prevent accidental removal after a read failure. Deleting a spot cascades to
its photo records.

## Photo import and storage

**Add photo** opens the system/browser file selector. Inputs are still JPEG, PNG
and WebP images, up to **12 MiB**, **16 megapixels**, and 16384 pixels on either
source edge. GIF/animation and HEIC are not supported; export them as a supported
still image first. Select photos individually, up to six per spot.

The importer checks file length before reading, bounds the read and checks the
header before pixel decoding. It applies EXIF camera orientation, resizes the
longest edge to at most **1600 px** without upscaling, composites transparency
onto white and encodes a JPEG at quality 82. A separate thumbnail has a longest
edge of at most **256 px**, at quality 70. Full images are limited to **1 MiB**
and thumbnails to **64 KiB**. Outputs exceeding these limits are rejected.

Both outputs use a fresh image, so source EXIF, embedded GPS, text and other
metadata are not copied. Source files remain unchanged. Native processing uses
Flutter `compute` in an isolate; Web executes it on the browser event loop, where
large permitted inputs can briefly occupy that thread.

On Android the system-file-selector plugin may stage an original copy in the
app's temporary cache, managed separately by the plugin/operating system. The
normalization and metadata-removal guarantees above apply to the persisted
database images and thumbnails, not to originals in file providers or that cache.

`spot_photos` stores normalized JPEGs and thumbnails as local SQLite BLOBs with
dimensions, an indexed spot ID and a cascading foreign key. No temporary file
paths are saved. Android and Web use the same repository/storage contract. Spot
list and marker queries read only `spots`; preview queries select thumbnail
columns, and full photos load only when opened. **View photos** in the spot menu
and **Photos** in the selected map spot panel open the gallery. Photos support zoom.

## Location behavior and permissions

Location is requested only after **Use current location**, never at startup or
when opening the editor. Android declares `ACCESS_COARSE_LOCATION` and
`ACCESS_FINE_LOCATION`; the user may choose approximate location. No background
permission or continuous position stream is used. The one-time position lookup
has a **20-second** timeout after permission is resolved. Closing the editor
ignores a late result.

The position may come from GPS or other device/browser providers. The editor
shows reported horizontal accuracy, or states that accuracy is unavailable.
Only latitude/longitude are copied to the editable form; device altitude is not
imported or assigned a height reference. Denied/blocked permission, disabled
services, unsupported contexts and timeouts leave manual entry available.

Web location requires a secure context (HTTPS, or trusted localhost). Permission
decisions remain under user control. The app does not upload photos or publish
the position. OS location services and user-selected file providers have their
own behavior; map requests remain as described in [architecture](architecture.md).
Android and Web are the supported targets; an iOS runner/validation remains #2.

## Migration and verification

Schema **3** adds `spot_photos` and its index. The v1/v2 snapshots are retained.
Migration tests validate v1 → v3 and v2 → v3, preserving personal records and
height references. Repository tests cover ownership, limits, replacement,
cascading deletion and transaction rollback after forced write failures. A
temporary file-backed reopen test verifies photo bytes with all other domains.

Processor tests cover orientation, metadata removal, sizing, transparency and
malformed inputs. Location tests inject the platform; editor tests inject photo
and location services. Those tests do not prove a physical GPS fix or native
picker UI; check real permission/picker flows separately on supported targets.

Implementation references: [Flutter file_selector](https://pub.dev/packages/file_selector),
[Geolocator](https://pub.dev/packages/geolocator) and
[Dart image](https://pub.dev/packages/image). Versions are pinned in `pubspec.lock`.

## Validation record (2026-10-20)

- 129 Flutter tests and 7 JavaScript bridge tests passed; analysis and formatting passed.
- Web release and Android ARM64 debug APK built successfully. Both packaged
  Cesium bundles matched the pinned asset hashes; APK ZIP integrity passed.
- The merged Android debug manifest contains coarse/fine location permissions
  and no background-location permission.
- In the real Web release, a synthetic PNG was selected through the file picker,
  normalized, saved and opened in the gallery/full viewer. Spot, thumbnail and
  full photo remained available after a complete page reload. A second import
  also succeeded; its edit draft was cancelled.
- Automated file transfer through the browser picker stalled for an unusually
  long time. These observations establish functionality, not import-performance
  measurements. Android's actual picker and a physical GPS fix remain manual
  acceptance checks; this APK was not installed during this validation.
