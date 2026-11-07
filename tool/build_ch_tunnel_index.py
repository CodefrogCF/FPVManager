#!/usr/bin/env python3
"""Create FPVManager's bundled Swiss tunnel index from a Geofabrik OSM PBF.

Run once before packaging an Android/iOS/Windows/Web release:
  python -m pip install osmium
  python tool/build_ch_tunnel_index.py --download

For testing without pyosmium/network:
  python tool/build_ch_tunnel_index.py --osm-xml test/tool/fixtures/ch_tunnels.osm

The app loads the generated asset locally and sends no coordinates to Overpass.
The exported OSM-derived dataset is subject to ODbL 1.0; see attribution.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import sys
import tempfile
import urllib.request
from xml.etree import ElementTree

SOURCE_URL = 'https://download.geofabrik.de/europe/switzerland-latest.osm.pbf'
SOURCE_LABEL = 'OpenStreetMap (Geofabrik Switzerland extract)'
WEST, SOUTH, STEP = 5.8, 45.6, .25
BOUNDS = (5.6, 45.4, 11.0, 48.0)
MAX_POINTS_PER_PART = 512
OUTPUT = Path(__file__).resolve().parent.parent / 'web/data/tunnels/ch_tunnels_v1.json'


def classified(tags: dict[str, str]):
    transport = 'railway' if tags.get('railway') else 'road' if tags.get('highway') else None
    if not transport:
        return None
    tunnel = tags.get('tunnel', '').lower()
    if tunnel in ('yes', 'building_passage', 'avalanche_protector'):
        return ('tunnel', transport)
    if tags.get('covered', '').lower() == 'yes':
        return ('underpass', transport)
    return None


def valid(lon: float, lat: float):
    return math.isfinite(lon) and math.isfinite(lat) and \
        BOUNDS[0] <= lon <= BOUNDS[2] and BOUNDS[1] <= lat <= BOUNDS[3]


def parts(coords):
    # Preserve each OSM segment. Adjacent parts repeat their common endpoint,
    # so a long tunnel is never truncated or re-routed to a straight shortcut.
    if len(coords) < 2:
        return
    offset = 0
    while offset < len(coords) - 1:
        chunk = coords[offset:offset + MAX_POINTS_PER_PART]
        if len(chunk) > 1:
            yield chunk
        offset += len(chunk) - 1


def tile_key(lon, lat):
    return f'{math.floor((lon - WEST) / STEP)}:{math.floor((lat - SOUTH) / STEP)}'


def index_from_ways(ways, snapshot_date_utc):
    entries = []
    tiles = defaultdict(set)
    seen = set()
    skipped = 0
    for way_id, tags, coordinates in ways:
        recognized = classified(tags)
        if not recognized or not isinstance(way_id, int) or way_id <= 0:
            continue
        if len(coordinates) < 2 or not all(valid(*p) for p in coordinates):
            skipped += 1
            continue
        kind, transport = recognized
        name = str(tags.get('name', '')).strip()[:120] or f'{transport.title()} {kind}'
        for i, chunk in enumerate(parts(coordinates)):
            if (way_id, i) in seen:
                continue
            seen.add((way_id, i))
            coords = [[round(p[0], 7), round(p[1], 7)] for p in chunk]
            index = len(entries)
            entries.append([way_id, i, kind, transport, name, coords])
            # Each route is registered in all intersecting tile envelopes.
            # JS further tests the real polyline against the viewport.
            minx, maxx = min(p[0] for p in coords), max(p[0] for p in coords)
            miny, maxy = min(p[1] for p in coords), max(p[1] for p in coords)
            for x in range(math.floor((minx-WEST)/STEP), math.floor((maxx-WEST)/STEP)+1):
                for y in range(math.floor((miny-SOUTH)/STEP), math.floor((maxy-SOUTH)/STEP)+1):
                    tiles[f'{x}:{y}'].add(index)
    if not entries:
        raise RuntimeError('No tagged Swiss tunnel or covered way found; refusing to ship an empty catalogue.')
    if len(entries) > 120000 or len(tiles) > 2000:
        raise RuntimeError('Tunnel catalogue exceeds the mobile safety budget.')
    index = {'schemaVersion': 1, 'generated': True, 'tileDegrees': STEP,
             'source': SOURCE_LABEL, 'snapshotDateUtc': snapshot_date_utc,
             'license': 'ODbL-1.0', 'attribution': '© OpenStreetMap contributors; extract © Geofabrik',
             'routes': entries, 'tiles': {k: sorted(v) for k, v in sorted(tiles.items())}}
    return index, skipped


def choose_location_index(available_types, temporary_dir, requested='auto'):
    """Choose a node-location store compiled into the installed pyosmium wheel.

    Windows wheels may omit mmap-based stores. A disk-backed sparse index keeps
    RAM use bounded for the full Swiss PBF; flex_mem is the portable fallback.
    """
    supported = set(available_types)
    if requested == 'auto':
        if 'sparse_file_array' in supported:
            requested = 'sparse_file_array'
        elif 'flex_mem' in supported:
            requested = 'flex_mem'
        else:
            raise RuntimeError(f'No supported location index found; available: {sorted(supported)}')
    elif requested not in supported:
        raise RuntimeError(f'Osmium location index {requested!r} not compiled into this binary; '
                           f'available: {sorted(supported)}')

    if requested == 'sparse_file_array':
        return f'sparse_file_array,{Path(temporary_dir) / "locations.idx"}'
    return requested


def pbf_ways(path, location_index='auto'):
    try:
        import osmium
    except ImportError as exc:
        raise RuntimeError('PBF processing needs pyosmium: python -m pip install osmium') from exc
    rows = []
    class Reader(osmium.SimpleHandler):
        def way(self, way):
            tags = dict(way.tags)
            if not classified(tags):
                return
            coords = []
            try:
                for node in way.nodes:
                    if not node.location.valid():
                        return
                    coords.append([node.location.lon, node.location.lat])
            except (ValueError, RuntimeError):
                return
            rows.append((int(way.id), tags, coords))
    reader = Reader()
    # mmap stores are not available in all Windows pyosmium wheels. Select
    # from the types actually compiled into the running binary, and remove any
    # temporary disk index when the PBF has been processed.
    with tempfile.TemporaryDirectory(prefix='fpvmanager-osmium-', dir=path.parent) as temp_dir:
        index = choose_location_index(osmium.index.map_types(), temp_dir, location_index)
        print(f'Osmium location index: {index.split(",", 1)[0]}', flush=True)
        reader.apply_file(str(path), locations=True, idx=index)
    return rows


def xml_ways(path):
    # Small XML fixture support for CI; production extracts always use PBF.
    root = ElementTree.parse(path).getroot()
    nodes = {int(n.attrib['id']): (float(n.attrib['lon']), float(n.attrib['lat']))
             for n in root.findall('node')}
    for way in root.findall('way'):
        tags = {tag.attrib['k']: tag.attrib['v'] for tag in way.findall('tag')}
        if not classified(tags):
            continue
        try:
            coords = [nodes[int(n.attrib['ref'])] for n in way.findall('nd')]
        except KeyError:
            continue
        yield int(way.attrib['id']), tags, coords


def download(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.stat().st_size > 1_000_000:
        print(f'Using existing extract: {path} ({path.stat().st_size:,} bytes)')
        return
    partial = path.with_suffix(path.suffix + '.partial')
    try:
        request = urllib.request.Request(SOURCE_URL, headers={'User-Agent': 'FPVManager-offline-tunnel-index/1.0'})
        with urllib.request.urlopen(request, timeout=90) as response, partial.open('wb') as output:
            total = int(response.headers.get('Content-Length') or 0)
            count = 0
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
                count += len(chunk)
                if count % (50 * 1024 * 1024) < 1024 * 1024:
                    print(f'Downloaded {count // (1024 * 1024)} MiB' +
                          (f' / {total // (1024 * 1024)} MiB' if total else ''), flush=True)
            if total and count != total:
                raise IOError('Incomplete Geofabrik download')
        if partial.stat().st_size < 1_000_000:
            raise IOError('Geofabrik response is too small to be a Swiss PBF extract')
        partial.replace(path)
    finally:
        partial.unlink(missing_ok=True)


def build(input_file, *, is_xml=False, output=OUTPUT, location_index='auto'):
    ways = xml_ways(input_file) if is_xml else pbf_ways(input_file, location_index)
    stamp = datetime.fromtimestamp(input_file.stat().st_mtime, timezone.utc).isoformat().replace('+00:00', 'Z')
    document, skipped = index_from_ways(ways, stamp)
    output.parent.mkdir(parents=True, exist_ok=True)
    scratch = output.with_suffix(output.suffix + '.tmp')
    try:
        scratch.write_text(json.dumps(document, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
        if scratch.stat().st_size > 24 * 1024 * 1024:
            raise RuntimeError('Generated Swiss tunnel index exceeds the 24 MiB app budget.')
        scratch.replace(output)
    finally:
        scratch.unlink(missing_ok=True)
    print(f'Wrote {output}: {len(document["routes"]):,} route parts, '
          f'{len(document["tiles"])} geographic tiles, {output.stat().st_size:,} bytes; '
          f'{skipped} invalid tagged ways skipped.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--download', action='store_true', help='download the current Swiss Geofabrik PBF automatically')
    group.add_argument('--pbf', type=Path, help='path to existing Swiss .osm.pbf extract')
    group.add_argument('--osm-xml', type=Path, help='small .osm XML fixture for tests')
    group.add_argument('--verify', action='store_true', help='verify that a real, nonempty offline tunnel index is bundled')
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--location-index', choices=('auto', 'flex_mem', 'sparse_file_array'),
                        default='auto', help='PBF node-location store (auto uses disk if supported)')
    args = parser.parse_args()
    cache = Path.home() / '.cache' / 'fpvmanager' / 'switzerland-latest.osm.pbf'
    try:
        if args.verify:
            doc = json.loads(args.output.read_text(encoding='utf-8'))
            if doc.get('schemaVersion') != 1 or doc.get('generated') is not True or not doc.get('routes'):
                raise RuntimeError('Only the ungenerated placeholder is bundled; generate the Swiss tunnel index first.')
            print(f'Bundled tunnel index verified: {len(doc["routes"]):,} route parts, {args.output.stat().st_size:,} bytes')
            return
        if args.download:
            download(cache)
        input_file = cache if args.download else args.pbf or args.osm_xml
        build(input_file, is_xml=args.osm_xml is not None, output=args.output,
              location_index=args.location_index)
    except (RuntimeError, OSError, ValueError) as exc:
        parser.exit(1, f'Tunnel index build failed: {exc}\n')


if __name__ == '__main__':
    main()
