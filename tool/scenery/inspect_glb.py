#!/usr/bin/env python3
"""Offline metadata-only glTF 2.0/GLB inspector for FPVManager issue #144.

Never executes model data, fetches remote URLs, or assumes georeferencing.
Run with: python tool/scenery/inspect_glb.py /path/to/asset.glb -o report.json
"""
import argparse
import json
from pathlib import Path
import struct


class InvalidGLB(ValueError):
    pass


def summarize(path: Path) -> dict:
    size = path.stat().st_size
    with path.open('rb') as f:
        header = f.read(12)
        if len(header) != 12:
            raise InvalidGLB('Truncated GLB header')
        magic, version, declared = struct.unpack('<4sII', header)
        if magic != b'glTF' or version != 2 or declared != size:
            raise InvalidGLB('Expected glTF 2.0 binary with a matching file length')
        json_data = None
        bin_size = 0
        consumed = 12
        while consumed < size:
            chunk = f.read(8)
            if len(chunk) != 8:
                raise InvalidGLB('Truncated chunk header')
            count, kind = struct.unpack('<I4s', chunk)
            consumed += 8 + count
            if count % 4 or consumed > size:
                raise InvalidGLB('Invalid GLB chunk length')
            if kind == b'JSON':
                if json_data is not None:
                    raise InvalidGLB('Duplicate JSON chunk')
                # A bounded manifest avoids reading arbitrary untrusted binary payloads.
                if count > 32 * 1024 * 1024:
                    raise InvalidGLB('JSON chunk exceeds 32 MiB')
                try:
                    json_data = json.loads(f.read(count).rstrip(b' \t\r\n\0').decode('utf-8'))
                except (UnicodeError, ValueError) as exc:
                    raise InvalidGLB('Malformed JSON chunk') from exc
            else:
                if kind == b'BIN\0':
                    bin_size += count
                f.seek(count, 1)
        if json_data is None or not isinstance(json_data, dict):
            raise InvalidGLB('Missing valid JSON scene description')
    accessors = json_data.get('accessors', [])
    meshes = json_data.get('meshes', [])
    images = json_data.get('images', [])
    materials = json_data.get('materials', [])
    triangles = 0
    vertices = 0
    other_modes = []
    primitive_count = 0
    bounds = []
    for mesh in meshes:
        for primitive in mesh.get('primitives', []):
            primitive_count += 1
            attrs = primitive.get('attributes', {})
            position = attrs.get('POSITION')
            if isinstance(position, int) and 0 <= position < len(accessors):
                item = accessors[position]
                vertices += item.get('count', 0)
                if 'min' in item and 'max' in item:
                    bounds.append({'min': item['min'], 'max': item['max']})
            index = primitive.get('indices')
            count = (accessors[index].get('count', 0)
                     if isinstance(index, int) and 0 <= index < len(accessors)
                     else accessors[position].get('count', 0)
                     if isinstance(position, int) and 0 <= position < len(accessors)
                     else 0)
            mode = primitive.get('mode', 4)
            if mode == 4:
                triangles += count // 3
            elif mode == 5:
                triangles += max(0, count - 2)
            elif mode == 6:
                triangles += max(0, count - 2)
            else:
                other_modes.append(mode)
    return {
        'file': path.name,
        'bytes': size,
        'asset_version': json_data.get('asset', {}).get('version'),
        'scenes': len(json_data.get('scenes', [])),
        'nodes': len(json_data.get('nodes', [])),
        'meshes': len(meshes),
        'primitives': primitive_count,
        'primitive_vertices_sum': vertices,
        'approximate_triangles': triangles,
        'unsupported_primitive_modes': sorted(set(other_modes)),
        'materials': len(materials),
        'textures': len(json_data.get('textures', [])),
        'images': len(images),
        'image_descriptors': [
            {'mimeType': image.get('mimeType'),
             'embedded': 'bufferView' in image,
             'external': 'uri' in image and not image['uri'].startswith('data:')}
            for image in images],
        'binary_chunk_bytes': bin_size,
        'accessor_local_bounds': bounds[:20],
        'has_khr_draco': 'KHR_draco_mesh_compression' in json_data.get('extensionsUsed', []),
        'extensions_used': json_data.get('extensionsUsed', []),
        'has_explicit_georeference': any('CESIUM' in str(e).upper() or 'GEO' in str(e).upper()
            for e in json_data.get('extensionsUsed', [])),
        'limitations': [
            'Primitive vertices may be shared; the sum is not a unique vertex count.',
            'Triangle count is derived from accessor counts and may not reflect decoded compression.',
            'Accessor bounds are local and omit node transforms, dimensions, CRS and map alignment.',
            'No proof of building interiors, gaps, manifold geometry, collisions or Cesium rendering.',
            'Source license and redistribution permission require independent verification.'
        ]
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb', type=Path)
    parser.add_argument('-o', '--output', type=Path)
    args = parser.parse_args()
    report = summarize(args.glb)
    result = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(result + '\n', encoding='utf-8')
    else:
        print(result)


if __name__ == '__main__':
    main()
