#!/usr/bin/env python3
from __future__ import annotations
import json, struct, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, 'tool/scenery')
from build_collision import AXIS
from refine_ruedersdorf_r13 import get_accessor

REPORT = Path('tool/scenery/r28_2/refinement_R28_2_report.json')
GLB = Path('web/assets/scenery/local_reference.glb')


def main():
    report = json.loads(REPORT.read_text())
    assert report['platform_attachment']['platform_connected_to_wall'] is True
    raw = GLB.read_bytes()
    n = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+n])
    buf = bytearray(raw[28+n:])
    mesh_index = len(doc['meshes']) - 1
    connector_hits = 0
    for p in doc['meshes'][mesh_index]['primitives']:
        pos = get_accessor(doc, buf, p['attributes']['POSITION']) @ AXIS.T
        tri = get_accessor(doc, buf, p['indices']).reshape(-1, 3)
        cen = pos[tri].mean(1)
        sel = ((cen[:,0] > -4.96) & (cen[:,0] < -4.80) &
               (cen[:,1] > -0.87) & (cen[:,1] < -0.80) &
               (cen[:,2] > -0.26) & (cen[:,2] < 0.02))
        connector_hits += int(sel.sum())
    assert connector_hits >= 20, connector_hits
    print(json.dumps({'connector_hits': connector_hits, 'mesh_index': mesh_index}))


if __name__ == '__main__':
    main()
