#!/usr/bin/env python3
"""R23 regression: R22 input, 25 preceding meshes, hole topology and GLB/FPC parity."""
from __future__ import annotations
import hashlib
import json
import struct
import sys
from pathlib import Path

import numpy as np
from build_collision import read_glb
from refine_ruedersdorf_r13 import get_accessor
from refine_ruedersdorf_r23 import SOURCE_SHA


def load(path):
    raw = Path(path).read_bytes()
    n = struct.unpack_from('<I', raw, 12)[0]
    return json.loads(raw[20:20 + n]), raw[28 + n:]


def check(source, glb, fpc, catalog, report):
    assert hashlib.sha256(Path(source).read_bytes()).hexdigest() == SOURCE_SHA
    old, oldbuf = load(source)
    new, newbuf = load(glb)
    assert len(old['meshes']) == 26 and len(new['meshes']) == 27
    assert new['meshes'][-1]['name'].startswith('R23')
    assert old['nodes'][0] == new['nodes'][0], 'Original georeference changed'
    assert old['scenes'][old.get('scene', 0)]['nodes'] == new['scenes'][new.get('scene', 0)]['nodes'][:-1]
    # All original scan geometry and all preceding procedural geometry untouched,
    # except the prior last mesh where two solid R6 side-deck boxes were replaced.
    floor_materials = {i for i, mat in enumerate(old['materials']) if mat['name'] == 'R12 r6_floor'}
    for i in range(26):
        a, b = old['meshes'][i], new['meshes'][i]
        assert a['name'] == b['name'] and len(a['primitives']) == len(b['primitives']), i
        for ap, bp in zip(a['primitives'], b['primitives']):
            assert ap['material'] == bp['material'], i
            assert set(ap['attributes']) == set(bp['attributes']), i
            if i == 15 and ap['material'] in floor_materials:
                continue  # R23 replaces exactly 24 triangles of the upper side deck.
            assert np.array_equal(get_accessor(old, oldbuf, ap['indices']),
                                  get_accessor(new, newbuf, bp['indices'])), i
            for key in ap['attributes']:
                assert np.array_equal(get_accessor(old, oldbuf, ap['attributes'][key]),
                                      get_accessor(new, newbuf, bp['attributes'][key])), (i, key)
    def floor_triangles(doc, buf):
        return sum(len(get_accessor(doc, buf, p['indices'])) // 3
                   for p in doc['meshes'][15]['primitives'] if p['material'] in floor_materials)
    assert floor_triangles(old, oldbuf) - floor_triangles(new, newbuf) == 24

    report_data = json.loads(Path(report).read_text())
    assert report_data['removed_synthetic_side_deck_triangles'] == 24
    assert report_data['original_scan_meshes_preserved'] == 15
    assert report_data['production_block']['roof_unchanged']
    assert report_data['production_block']['replaced_R6_slabs'] == 2

    vertices, faces = read_glb(glb)
    unique_faces = np.unique(np.sort(faces, axis=1), axis=0)
    raw = Path(fpc).read_bytes()
    magic, nv, nt, _ = struct.unpack_from('<4sIII', raw)
    assert magic == b'FPC1' and nv == len(vertices) and nt == len(unique_faces)
    verts_fpc = np.frombuffer(raw, '<f4', nv * 3, offset=16).reshape(-1, 3)
    faces_fpc = np.frombuffer(raw, '<u4', nt * 3, offset=16 + nv * 12).reshape(-1, 3)
    assert np.array_equal(vertices, verts_fpc)
    assert np.array_equal(unique_faces, np.unique(np.sort(faces_fpc, axis=1), axis=0))

    target = next(s for s in json.loads(Path(catalog).read_text())['sceneries']
                  if s['id'] == 'de-bb-ruedersdorf-chemical-plant')
    sha = hashlib.sha256(raw).hexdigest()
    assert target['terrainCertificate']['collisionSha256'] == sha
    assert len(target['terrainCertificates']) == 16
    assert all(c['collisionSha256'] == sha for c in target['terrainCertificates'])
    assert target['alignment']['rotationDeg'] == 99.7993823133657
    assert target['alignment']['scale'] == 16.023268178233355
    assert target['surveyVerified'] is False
    assert report_data['glb_sha256'] == hashlib.sha256(Path(glb).read_bytes()).hexdigest()
    assert report_data['fpc_sha256'] == sha
    print(json.dumps({'passed': True, 'previous_meshes_preserved_except_floor_cutouts': True,
                      'synthetic_side_deck_triangles_replaced': 24,
                      'collision_parity': True, 'collision_triangles': nt,
                      'collision_sha256': sha}, indent=2))


if __name__ == '__main__':
    check(*sys.argv[1:])
