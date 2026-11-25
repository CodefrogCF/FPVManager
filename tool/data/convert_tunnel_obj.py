#!/usr/bin/env python3
"""Offline OBJ (local ENU metres) -> FPVManager v2 EPSG:4979 triangle mesh.

Requires an explicitly supplied WGS84 ellipsoidal anchor. Does not transform
Swiss LV95/LN02 heights, certify engineering data, or generate tunnel portals.
Coordinates: OBJ x=East, y=North, z=Up, in metres relative to that anchor.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

A = 6378137.0
F = 1 / 298.257223563
E2 = F * (2 - F)
MAX_VERTICES = 8192
MAX_TRIANGLES = 12000
MAX_BYTES = 2097152


def anchor_and_basis(lon_deg: float, lat_deg: float, height: float):
    longitude = math.radians(lon_deg)
    latitude = math.radians(lat_deg)
    sl, cl = math.sin(longitude), math.cos(longitude)
    sp, cp = math.sin(latitude), math.cos(latitude)
    n = A / math.sqrt(1 - E2 * sp * sp)
    origin = ((n + height) * cp * cl, (n + height) * cp * sl,
              (n * (1 - E2) + height) * sp)
    east = (-sl, cl, 0.0)
    north = (-sp * cl, -sp * sl, cp)
    up = (cp * cl, cp * sl, sp)
    return origin, east, north, up


def enu_to_geodetic(east_m, north_m, up_m, basis):
    origin, east, north, up = basis
    x, y, z = (origin[i] + east_m * east[i] + north_m * north[i]
               + up_m * up[i] for i in range(3))
    lon = math.atan2(y, x)
    p = math.hypot(x, y)
    lat = math.atan2(z, p * (1 - E2))
    for _ in range(8):
        sp = math.sin(lat)
        n = A / math.sqrt(1 - E2 * sp * sp)
        h = p / math.cos(lat) - n
        lat = math.atan2(z, p * (1 - E2 * n / (n + h)))
    n = A / math.sqrt(1 - E2 * math.sin(lat) ** 2)
    height = p / math.cos(lat) - n
    return [math.degrees(lon), math.degrees(lat), height]


def read_obj(path: Path, basis):
    if path.stat().st_size > 16 * 1024 * 1024:
        raise ValueError(f"{path}: source OBJ exceeds the 16 MiB input limit")
    vertices, triangles, local_vertices = [], [], []
    for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        parts = line.split("#", 1)[0].split()
        if not parts:
            continue
        if parts[0] == "v":
            if len(parts) != 4:
                raise ValueError(f"{path}:{line_number}: expected three OBJ coordinates")
            coordinates = [float(part) for part in parts[1:]]
            if not all(map(math.isfinite, coordinates)):
                raise ValueError(f"{path}:{line_number}: nonfinite OBJ vertex")
            local_vertices.append(coordinates)
            vertices.append(enu_to_geodetic(*coordinates, basis))
            if len(vertices) > MAX_VERTICES:
                raise ValueError(f"{path}: too many vertices")
        elif parts[0] == "f":
            if len(parts) < 4 or len(parts) > 66:
                raise ValueError(f"{path}:{line_number}: unsupported OBJ face")
            indices = []
            for token in parts[1:]:
                position = int(token.split("/", 1)[0])
                index = position - 1 if position > 0 else len(vertices) + position
                if index < 0 or index >= len(vertices):
                    raise ValueError(f"{path}:{line_number}: invalid OBJ face index")
                indices.append(index)
            for j in range(1, len(indices) - 1):
                tri = [indices[0], indices[j], indices[j + 1]]
                if len(set(tri)) != 3:
                    raise ValueError(f"{path}:{line_number}: repeated triangle vertex")
                a, b, c = [local_vertices[k] for k in tri]
                ab = [b[k] - a[k] for k in range(3)]
                ac = [c[k] - a[k] for k in range(3)]
                cross = [ab[1] * ac[2] - ab[2] * ac[1],
                         ab[2] * ac[0] - ab[0] * ac[2],
                         ab[0] * ac[1] - ab[1] * ac[0]]
                if sum(x * x for x in cross) < 1e-12:
                    raise ValueError(f"{path}:{line_number}: degenerate triangle")
                triangles.append(tri)
                if len(triangles) > MAX_TRIANGLES:
                    raise ValueError(f"{path}: too many triangles")
    if len(vertices) < 3 or not triangles:
        raise ValueError(f"{path}: no mesh vertices or faces")
    return {"vertices": vertices, "triangles": triangles}


def convert(args):
    if not (5.8 <= args.lon <= 10.7 and 45.6 <= args.lat <= 47.9 and
            -500 <= args.height <= 9000):
        raise ValueError("Anchor must be in Switzerland with WGS84 ellipsoid height")
    if not args.source.strip() or len(args.source) > 256:
        raise ValueError("A documented, nonblank mesh source is required")
    basis = anchor_and_basis(args.lon, args.lat, args.height)
    visual = read_obj(args.visual, basis)
    colliders = read_obj(args.collision, basis)
    document = {"version": 2, "format": "fpvmanager-georeferenced-trimesh",
                "identity": args.identity, "source": args.source, "sourceId": args.source_id,
                "coordinateReference": "EPSG:4979", "elevationReference": "WGS84_ELLIPSOID",
                "visualMesh": visual, "collisionMesh": colliders}
    output = (json.dumps(document, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")
    if len(output) > MAX_BYTES:
        raise ValueError("Generated JSON exceeds 2 MiB; simplify both OBJ meshes first")
    args.output.write_bytes(output)
    print(f"Wrote {args.output}: {len(visual['triangles'])} visual and "
          f"{len(colliders['triangles'])} collision triangles, {len(output)} bytes")
    print("UNVERIFIED LOCAL MODEL: verify source CRS, ellipsoid heights and geometry independently")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--visual", type=Path, required=True, help="Visual OBJ in local East/North/Up metres")
    parser.add_argument("--collision", type=Path, required=True, help="Collision OBJ in the SAME local ENU frame")
    parser.add_argument("--lon", type=float, required=True, help="Explicit WGS84 anchor longitude, degrees")
    parser.add_argument("--lat", type=float, required=True, help="Explicit WGS84 anchor latitude, degrees")
    parser.add_argument("--height", type=float, required=True, help="Anchor WGS84 ELLIPSOID height, metres")
    parser.add_argument("--source", required=True, help="Provenance of the 3D geometry")
    parser.add_argument("--source-id", default="", help="Optional original dataset or feature ID")
    parser.add_argument("--identity", default="external-obj-mesh")
    parser.add_argument("--output", type=Path, required=True)
    convert(parser.parse_args())


if __name__ == "__main__":
    main()
