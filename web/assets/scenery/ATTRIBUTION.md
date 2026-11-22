# Ruedersdorf reference scenery R8 — separate asset license

**Abandoned Chemical plant Rüdersdorf – RAWscan**, Andrea Spognetta (Spogna), 2018-04-05.
Original: https://sketchfab.com/3d-models/abandoned-chemical-plant-rudersdorf-rawscan-d2464ec36fb644f28e904e5517f1da64
Mirror: https://zenodo.org/records/10288797 (original MD5 c687d665d1e0ee68f69477207941d103).
Author: https://sketchfab.com/spogna
License: [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/), as recorded in original GLB metadata. Model, textures, derived footprint and collision asset are not under FPVManager's source-code license. No commercial use without further permission. Keep this attribution with copies. Verify any other applicable third-party rights before public redistribution.

Changes: R1 radial refinement and texture tone correction; R2 bounded radial correction on two additional silo shells, replacement of selected scan regions by an approximate geometry reconstruction (long stepped hall, vaulted hall, open four-level factory frame, silo stair frame and platform, hollow middle chimney including reconstructed access opening), original procedural masonry/concrete/metal/roof/floor textures and matching triangle collider. The original scan remains outside the selected regions. Retained UVs and local placement unchanged except the bounded R2 silo corrections. The FPC is derived from the R2 visual triangles, with exact duplicate faces removed and precomputed BVH. No source photographs incorporated into the assets. Photographs used for visual reference only, credited in REFINEMENT_R2.md. Not surveyed or a representation of today's condition or real-world flyability.

R3 changes: added approximate internal partitions and doorways, vessels, overhead pipes, service platforms, pedestals and deliberately closed (19) or partially obstructed (8) lateral window fields in the long hall. Retained R2 window frames. The locations and dimensions of new fittings and window obstructions are training approximations, not surveyed or verified against individual reference photographs. Regenerated matching collision asset from final visual triangles. No new third-party textures used. See REFINEMENT_R3.md.

R4 changes: paired lower chimney openings, mirrored jambs, lintels and sills (second portal confirmed by user), reference-inspired hall maintenance galleries and ladder, industrial apparatus, tank foundation, raised slab opening and stairs, damaged partition geometry, scattered rubble, fallen and hanging beams, loading hopper, roof aperture and revised procedural weathering textures. The actual dimensions and placement of the new interior features are approximate. GLB and matching FPC rebuilt from the exact R1 scan with R3 reconstructions preserved except as documented. No external reference photographs embedded. See REFINEMENT_R4.md.

R5 changes: reconstructed long hall from scan facade projections and multiple published photos (four longitudinal tanks on common foundation, adjacent elevated structure, central pier, high/low window bands and solid rear infill). Removed speculative R3/R4 workshop maze and additional vessels from this hall. Individual bay states and longitudinal tank positioning remain approximate. Original R4 chimney with two openings retained. New tank material is procedural; no photos embedded. See REFINEMENT_R5.md.

R6 changes: reference- and scan-constrained vaulted hall, eastern and western production blocks, silo plinths, rails, seven-level stair framework and upper gallery; rooftop gangway and approximate stair/portal connection; bounded cylindrical and roof surface repairs. R5 hall/tank geometry and R4 two-port chimney unchanged. Matching FPC regenerated; unknown small-building interiors and terrain retained. No external photos embedded; reconstructed details not surveyed. See REFINEMENT_R6.md and refinement_R6_report.json.

R7 changes: weathered original procedural R6 materials, irregular and partly broken modeled frame bars, bounded courtyard height adjustment (up to 0.10 m) and matching FPC rebuild. The optional terrain replacement certificate covers only a small scanned courtyard patch, not the site as a whole. Geometry is not surveyed; no reference photographs embedded. See REFINEMENT_R7.md.

R8 changes: bounded removal of 291 low, near-vertical cutoff-strip scan triangles, matching FPC regenerated; 16 geometry-backed candidate terrain patches with runtime sampled-height checks. No new survey data, reference photographs, synthetic ground or complete site terrain replacement. See REFINEMENT_R8.md.

R12 changes: Alternating stair flights on two silo structures, local scan overlap reduction,
sloped roof of eastern production building, high-hall opening/landing approximation; R8 and
R11 terrain assets remain separately controlled. See PATCH_NOTES_v0.20.0_ruedersdorf_r12_refinement.md.

R13 changes: Conservative scan-surface corrections on five well-observed outer ancillary
roof planes (maximum vertex displacement 10 cm, preserving original UVs); removal of 48
exactly duplicated modeled triangles; added one 40-tread exterior stair segment with
cantilever supports on the exposed south side of the western double-silo group.
The presence of an exterior curved stair is photographed (Abandoned Berlin) but this
particular length, placement, pitch, number of treads and supports are **not surveyed**.
Treat them as an approximation for simulation rather than a 1:1 reconstruction.
The FPC collider derives from the exact rendered R13 triangles. Original author/license
remain CC BY-NC 4.0; no photographs were embedded or redistributed.

R14 changes: Surface-specific photoreference-guided procedural material changes to the vaulted hall roof, four-silo plinth concrete and west production-block masonry. All existing triangle positions, collisions, georeferencing, openings and UVs remain unchanged. Reference photographers' images were used for visual analysis only and are not embedded, copied or distributed. Photo dates should not be inferred from publication dates. See REFINEMENT_R14.md. The original mesh author/license remains CC BY-NC 4.0.


### R15 – user-supplied 2023 FPV reference reconstruction

- Added an external former-ladder platform and handrails at the long hall. The long-hall roof is **not** perforated. The missing ladder is not reconstructed.
- Rebuilt the prominent six-silo staircase as an open frame with alternately rising flights. Removed the roof and gallery slab across a bounded central opening so a vertically descending 25 cm radius test collider passes unobstructed. No continuous inter-flight wall has been added.
- The 2023 frames were supplied by the user and used **only as visual references**; they are not embedded or redistributed. Dimensions are photo-guided approximations, not surveyed measurements.
- Original RAWscan by Andrea Spognetta (Spogna), CC BY-NC 4.0; derivative retains attribution and original restrictions.
