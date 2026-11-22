#!/usr/bin/env python3
"""R28.2 - attach north-east hall exterior platform to the hall wall.

The resized exterior platform from R24/R28.1 still stands slightly off the
hall facade. This pass keeps its position and dimensions, but adds a short
steel connector strip and braces so the platform touches the exterior wall.
"""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path
import numpy as np

from build_collision import AXIS, build, read_glb
from reconstruct_ruedersdorf_r6 import Mesh, beam
from refine_ruedersdorf_r13 import compact
from refine_ruedersdorf_r15_silo import append_accessor

SOURCE_SHA = 'd76558b93f78add1d042fc517e000853a226f00d1031f6b40d3572e6a8e094b5'
# Current small platform footprint from R24
PLATFORM_X0 = -4.955
PLATFORM_X1 = -4.805
PLATFORM_Y_WALL = -0.868  # hall exterior wall / facade line near platform
PLATFORM_Y0 = -0.805      # current inner platform edge facing the hall
PLATFORM_Y1 = -0.645
PLATFORM_Z = -0.117


def append_generated(doc, buf, geometry, name, node_name):
    available = {m.get('name'): idx for idx, m in enumerate(doc['materials'])}
    mats = {'metal': available['R15 safety steel']}
    parts = []
    count = {}
    for mat, faces in geometry.groups.items():
        if not faces:
            continue
        p = np.concatenate([f[0] for f in faces]).astype('<f4')
        normals = np.concatenate([np.repeat(f[1][None, :], 3, axis=0) for f in faces]).astype('<f4')
        uv = np.concatenate([f[2] for f in faces]).astype('<f4')
        ia = append_accessor(doc, buf, (p @ AXIS).astype('<f4'), 'VEC3', 5126, 34962)
        na = append_accessor(doc, buf, (normals @ AXIS).astype('<f4'), 'VEC3', 5126, 34962)
        ua = append_accessor(doc, buf, uv, 'VEC2', 5126, 34962)
        component = 5123 if len(p) < 65536 else 5125
        ind = np.arange(len(p), dtype='<u2' if component == 5123 else '<u4')
        idx = append_accessor(doc, buf, ind, 'SCALAR', component, 34963)
        parts.append({'attributes': {'POSITION': ia, 'NORMAL': na, 'TEXCOORD_0': ua},
                      'indices': idx, 'material': mats[mat], 'mode': 4})
        count[mat] = len(faces)
    meshno = len(doc['meshes'])
    doc['meshes'].append({'name': name, 'primitives': parts})
    nodeno = len(doc['nodes'])
    doc['nodes'].append({'name': node_name, 'mesh': meshno})
    doc['scenes'][doc.get('scene', 0)]['nodes'].append(nodeno)
    return count


def serialize_glb(doc, buf, dst):
    doc['buffers'][0]['byteLength'] = len(buf)
    text = json.dumps(doc, ensure_ascii=False, separators=(',', ':')).encode('utf8')
    text += b' ' * (-len(text) % 4)
    payload = struct.pack('<I4s', len(text), b'JSON') + text + struct.pack('<I4s', len(buf), b'BIN\0') + buf
    Path(dst).write_bytes(struct.pack('<4sII', b'glTF', 2, len(payload) + 12) + payload)


def build_platform_attachment(mesh: Mesh):
    mesh.part = 'R28.2 hall platform facade connection'
    x0, x1 = PLATFORM_X0, PLATFORM_X1
    yw, y0 = PLATFORM_Y_WALL, PLATFORM_Y0
    z = PLATFORM_Z
    # Main connector deck: short strip that closes the gap to the facade.
    mesh.box(x0 + 0.004, x1 - 0.004, yw, y0, z - 0.008, z, 'metal')
    # Slightly thicker side connection beams to visually tie into the frame.
    for x in (x0 + 0.018, x1 - 0.018):
        mesh.box(x - 0.006, x + 0.006, yw, y0 + 0.002, z - 0.028, z + 0.002, 'metal')
    # Top rail stub along the facade edge to suggest attachment frame.
    mesh.box(x0 + 0.010, x1 - 0.010, yw - 0.004, yw + 0.002, z + 0.095, z + 0.101, 'metal')
    # Two short braces under the connector.
    beam(mesh, (x0 + 0.026, yw + 0.004, z - 0.102), (x0 + 0.058, y0 - 0.002, z - 0.010), 0.006, 0.008, 'metal')
    beam(mesh, (x1 - 0.026, yw + 0.004, z - 0.102), (x1 - 0.058, y0 - 0.002, z - 0.010), 0.006, 0.008, 'metal')
    return {
        'connector_local_bounds': [x0 + 0.004, x1 - 0.004, yw, y0],
        'gap_closed_m': round((y0 - yw) * 16.023268178233355, 2),
        'platform_connected_to_wall': True,
    }


def main(source, output, collision, report):
    raw = Path(source).read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    if sha != SOURCE_SHA:
        raise ValueError(f'Expected R28.1 GLB {SOURCE_SHA}, got {sha}')
    n = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+n])
    buf = bytearray(raw[28+n:])

    mesh = Mesh()
    summary = build_platform_attachment(mesh)
    added = append_generated(
        doc, buf, mesh,
        'R28.2 platform attachment to hall wall',
        'R28.2 platform facade connector')

    doc['asset']['extras']['modifications'] += (
        ' R28.2: connect the north-east exterior platform at the main hall to the '
        'hall facade with a short steel deck/brace assembly so the platform no '
        'longer floats slightly off the wall.'
    )

    buf = compact(doc, buf)
    serialize_glb(doc, buf, output)
    verts, tris = read_glb(output)
    unique = np.unique(np.sort(tris, axis=1), axis=0)
    stats = build(verts, unique, collision)
    stats.update({
        'revision': 'R28.2',
        'source_sha256': sha,
        'glb_sha256': hashlib.sha256(Path(output).read_bytes()).hexdigest(),
        'fpc_sha256': hashlib.sha256(Path(collision).read_bytes()).hexdigest(),
        'visual_triangles': int(len(tris)),
        'unique_collision_triangles': int(len(unique)),
        'geometry_added_by_material': added,
        'platform_attachment': summary,
    })
    Path(report).parent.mkdir(parents=True, exist_ok=True)
    Path(report).write_text(json.dumps(stats, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps(stats, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('source')
    ap.add_argument('output')
    ap.add_argument('collision')
    ap.add_argument('report')
    args = ap.parse_args()
    main(args.source, args.output, args.collision, args.report)
