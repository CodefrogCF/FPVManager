"""Bake compact, Y-up vegetation GLBs for swisstopo's existing tree instances.

Each tree has a tapered trunk and a solid central crown. Five intersecting,
alpha-masked foliage surfaces add a broken silhouette at ground and aerial
angles. Their textures project seeded groups of leaves or needles in 3D.
One atlas and one indexed primitive replace the source's two primitives.
"""

import argparse
from dataclasses import dataclass
import json
import math
from pathlib import Path
import random
import struct
import zlib


OUTPUT = Path(__file__).resolve().parents[1] / 'web/assets/vegetation'
SIZE = 256
TOP, BASE, RADIUS = .97595, -.10, .20
GUTTER = 5
PALETTES = {
    'broadleaf': [(78, 112, 49), (91, 122, 51), (69, 105, 53)],
    'conifer': [(56, 91, 63), (65, 96, 58), (89, 117, 53)],
}
BARK = (103, 85, 64)


def dot(a, b):
    return sum(u * v for u, v in zip(a, b))


def vector_sum(a, b, scale=1):
    return tuple(u + scale * v for u, v in zip(a, b))


def tint(color, light):
    return tuple(max(0, min(255, round(channel * light))) for channel in color)


def groups(kind, variant, rng):
    """An irregular broad crown or tiers of flattened branch sprays."""
    if kind == 'broadleaf':
        width = (1, .72, .92)[variant]
        heights = ((.47, .58, .69, .79, .87), (.46, .57, .71, .83, .90), (.42, .54, .66, .78, .87))[variant]
        for level, height in enumerate(heights):
            count = (3, 6, 7, 5, 2)[level]
            for branch in range(count):
                angle = (branch / count + level * .31) * math.tau + rng.uniform(-.27, .27)
                distance = width * (.078, .129, .124, .088, .030)[level] * rng.uniform(.72, 1.16)
                size = width * rng.uniform(.053, .079)
                # Broadleaf 2 tapers below a high, narrow crown. Broadleaf 3
                # has a prevailing growth direction and an uneven base.
                height_offset = (.0, .05 * (1 - level / 4), .025 * math.cos(angle))[variant]
                lean = .045 * (level / 4) if variant == 2 else 0
                centre = (distance * math.cos(angle) + lean, height + height_offset
                          + rng.uniform(-.038, .023), distance * math.sin(angle))
                yield centre, (size, size * rng.uniform(.88, 1.34), size), 103
        yield (.014, .925, -.006), (.037, .037, .034), 82
        return

    for level in range(9):
        fraction = level / 8
        width = (.146, .190, .175)[variant] * (1 - .90 * fraction)
        height = (.24, .30, .36)[variant] + (.65, .59, .53)[variant] * fraction
        count = 5 if variant == 2 else 6
        for branch in range(count):
            angle = (branch / count + .27 * level) * math.tau + rng.uniform(-.20, .20)
            length = width * rng.uniform(.80, 1.03)
            elevation = rng.uniform(-.022, .020)
            for fraction_along in (.45, .72, .92):
                radius = length * fraction_along
                # Curved tips and staggered whorls let the trunk show through.
                tip = (.049, .026, .042)[variant] * (fraction_along - .72)
                lean = .018 * fraction if variant == 2 else 0
                centre = (radius * math.cos(angle) + lean, height + elevation + tip, radius * math.sin(angle))
                lateral = min(.032, width * .32) * rng.uniform(.78, 1.12)
                yield centre, (lateral, rng.uniform(.014, .024), lateral), 22
    yield (.004, .927, .002), (.023, .035, .022), 90
    yield (.008, .952, .006), (.012, .019, .013), 43


def foliage(kind, variant, rng):
    for centre, axes, count in groups(kind, variant, rng):
        shade = rng.uniform(.83, 1.13)
        for _ in range(count):
            # Dense inner clumps with individual leaves or needles near their tips.
            vertical = rng.uniform(-1, 1)
            angle = rng.uniform(0, math.tau)
            radius = rng.random() ** .48
            sideways = math.sqrt(1 - vertical * vertical) * radius
            unit = (sideways * math.cos(angle), vertical * radius, sideways * math.sin(angle))
            point = tuple(c + r * v for c, r, v in zip(centre, axes, unit))
            leaf_size = rng.uniform(.008, .016) if kind == 'broadleaf' else rng.uniform(.006, .014)
            if math.hypot(point[0], point[2]) + leaf_size > RADIUS or point[1] + leaf_size > TOP:
                continue
            light = shade * rng.uniform(.75, 1.25) * (.88 + .25 * point[1] + .15 * vertical)
            yield point, leaf_size, rng.uniform(0, math.tau), light


@dataclass(frozen=True)
class Sheet:
    origin: tuple
    right: tuple
    up: tuple
    normal: tuple
    half_width: float
    half_height: float
    depth: float
    tile: tuple


def sheets(kind, variant):
    bottom = (.18, .23, .29)[variant] if kind == 'conifer' else (.28, .34, .28)[variant]
    centre_y = (TOP + bottom) / 2
    for index in range(3):
        angle = (index + variant * .28) * math.pi / 3
        cos, sin = math.cos(angle), math.sin(angle)
        yield Sheet((0, centre_y, 0), (cos, 0, sin), (0, 1, 0), (-sin, 0, cos),
                    RADIUS, (TOP - bottom) / 2, .122, (64 * index, 0, 64, 128))
    for index, height in enumerate((.51, .73) if kind == 'broadleaf' else (.41, .66)):
        angle = (.39 + index * math.pi * .55 + variant * .37)
        cos, sin = math.cos(angle), math.sin(angle)
        tilt = (.49, -.54)[index]
        lift, run = math.sin(tilt), math.cos(tilt)
        yield Sheet((0, height, 0), (cos, 0, sin), (sin * run, lift, -cos * run),
                    (-sin * lift, run, cos * lift), RADIUS, RADIUS, .10, (96 * index, 128, 96, 96))


def cell(tile):
    x, y, width, height = tile
    return x + GUTTER, y + GUTTER, width - 2 * GUTTER, height - 2 * GUTTER


def uv(tile, u, v):
    x, y, width, height = cell(tile)
    return ((x + .5 + u * (width - 1)) / SIZE, (y + .5 + v * (height - 1)) / SIZE)


def put(image, x, y, color, alpha=255):
    offset = (y * SIZE + x) * 4
    image[offset:offset + 4] = bytes((*color, alpha))


def paint_foliage(image, sheet, leaves, color, conifer):
    x0, y0, width, height = cell(sheet.tile)
    projected = []
    for point, size, angle, light in leaves:
        relative = vector_sum(point, sheet.origin, -1)
        depth = dot(relative, sheet.normal)
        if abs(depth) > sheet.depth:
            continue
        x = (dot(relative, sheet.right) / (2 * sheet.half_width) + .5) * (width - 1)
        y = (.5 - dot(relative, sheet.up) / (2 * sheet.half_height)) * (height - 1)
        # Light across the crown is baked into the texture; tiny leaves break
        # the silhouette without adding mesh geometry.
        projected.append((depth, x, y, size, angle, light))
    scale = min(width / (2 * sheet.half_width), height / (2 * sheet.half_height))
    for depth, x, y, size, angle, light in sorted(projected):
        length = size * scale
        breadth = length * (.46 if conifer else .76)
        cos, sin = math.cos(angle), math.sin(angle)
        radius = math.ceil(length + .5)
        for iy in range(max(0, int(y) - radius), min(height, int(y) + radius + 1)):
            for ix in range(max(0, int(x) - radius), min(width, int(x) + radius + 1)):
                dx, dy = ix - x, iy - y
                u = (dx * cos + dy * sin) / length
                v = (dy * cos - dx * sin) / breadth
                distance = u * u + v * v
                if distance >= 1.18:
                    continue
                shade = (.92 + .12 * (1 - min(1, distance)) + .075 * u) * light
                shade *= 1 + depth * .55
                if distance < .85:
                    put(image, x0 + ix, y0 + iy, tint(color, shade))
                else:
                    offset = ((y0 + iy) * SIZE + x0 + ix) * 4 + 3
                    alpha = round(255 * (1.18 - distance) / .33)
                    if alpha > image[offset]:
                        put(image, x0 + ix, y0 + iy, tint(color, shade), alpha)


BARK_TILE = (208, 0, 48, 112)
CORE_TILE = (208, 144, 48, 112)


def paint_solid_surfaces(image, rng, color, variant):
    # Extend through the atlas gutters so the opaque trunk/crown stay solid
    # when mipmapping mixes texels across the mapped rectangle.
    for tile, base in [(BARK_TILE, BARK), (CORE_TILE, tint(color, .94))]:
        x0, y0, width, height = tile
        for y in range(height):
            for x in range(width):
                if tile == BARK_TILE:
                    stripe = math.sin(x * 1.9 + math.sin(y * .072) * 1.7)
                    grain = .89 + .16 * stripe + .17 * math.sin(x * .44 + y * .015)
                    if variant == 1:
                        grain += .24 * max(0, math.sin(x * .49 + y * .45))
                else:
                    grain = .86 + .14 * math.sin(x * .95 + math.sin(y * .43)) + .12 * math.sin(y * .84 + x * .65)
                put(image, x0 + x, y0 + y, tint(base, grain + rng.uniform(-.08, .13)))


class Mesh:
    def __init__(self):
        self.positions, self.normals, self.uvs, self.indices = [], [], [], []

    def face(self, positions, normals, texcoords, both_sides=False):
        start = len(self.positions)
        self.positions.extend(positions)
        self.normals.extend(normals)
        self.uvs.extend(texcoords)
        for index in range(1, len(positions) - 1):
            self.indices.extend([start, start + index, start + index + 1])
            if both_sides:
                self.indices.extend([start, start + index + 1, start + index])

    def trunk(self, kind, variant):
        top = .69 if kind == 'broadleaf' else .86
        rings = []
        sides = 3
        angles = [i * math.tau / sides for i in range(sides)]
        for y, radius, offset in [(BASE, .027, 0), (.32, .017, .006), (top, .004, .018)]:
            offset *= (1, .75, 1.4)[variant]
            rings.append([(radius * math.cos(angle) + offset, y,
                           radius * math.sin(angle) - offset / 2) for angle in angles])
        normals = [(math.cos(angle), 0, math.sin(angle)) for angle in angles]
        for lower, upper in zip(rings, rings[1:]):
            for side in range(sides):
                next_side = (side + 1) % sides
                positions = [lower[side], upper[side], upper[next_side], lower[next_side]]
                ns = [normals[side], normals[side], normals[next_side], normals[next_side]]
                us = [side / sides, side / sides, (side + 1) / sides, (side + 1) / sides]
                self.face(positions, ns, [uv(BARK_TILE, u, (top - p[1]) / (top - BASE))
                                          for u, p in zip(us, positions)])

    def crown_core(self, kind, variant, rng):
        centre = (.015, .63 if kind == 'broadleaf' else .46, -.006)
        width = (.105, .073, .102)[variant] if kind == 'broadleaf' else (.074, .092, .072)[variant]
        high = (centre[0] * .6, .87 if kind == 'broadleaf' else .90, centre[2])
        low = (centre[0] * .5, .38 if kind == 'broadleaf' else .30, centre[2])
        normals = [(math.cos(i * math.pi / 2), 0, math.sin(i * math.pi / 2)) for i in range(4)]
        ring = []
        for normal in normals:
            point = vector_sum(centre, normal, width * rng.uniform(.80, 1.10))
            ring.append(vector_sum(point, (0, 1, 0), rng.uniform(-.05, .05)))
        crown_normals = [(x * math.sqrt(.75), .5, z * math.sqrt(.75)) for x, _, z in normals]
        for i in range(4):
            j = (i + 1) % 4
            left, right = i / 4, (i + 1) / 4
            middle = (left + right) / 2
            self.face([ring[i], high, ring[j]], [crown_normals[i], (0, 1, 0), crown_normals[j]],
                      [uv(CORE_TILE, left, .52), uv(CORE_TILE, middle, 0), uv(CORE_TILE, right, .52)])
            self.face([ring[i], ring[j], low], [crown_normals[i], crown_normals[j], (0, 1, 0)],
                      [uv(CORE_TILE, left, .52), uv(CORE_TILE, right, .52), uv(CORE_TILE, middle, 1)])

    def sheet(self, sheet):
        corners = [(0, 1), (1, 1), (1, 0), (0, 0)]
        positions, normals = [], []
        for u, v in corners:
            point = vector_sum(sheet.origin, sheet.right, (2 * u - 1) * sheet.half_width)
            point = vector_sum(point, sheet.up, (1 - 2 * v) * sheet.half_height)
            positions.append(point)
            # Treat leaf clusters as a volume for lighting, independent of
            # which face of the thin surface is visible.
            normal = (point[0], .27 + .11 * (1 - v), point[2])
            length = math.sqrt(dot(normal, normal))
            normals.append(tuple(component / length for component in normal))
        self.face(positions, normals, [uv(sheet.tile, u, v) for u, v in corners], both_sides=True)


def encode_png(image):
    def chunk(name, content):
        return struct.pack('>I', len(content)) + name + content + struct.pack('>I', zlib.crc32(name + content))

    # PNG's Sub filter compresses adjacent leaf shades and transparent margins.
    stride = SIZE * 4
    scanlines = bytearray()
    for offset in range(0, len(image), stride):
        row = image[offset:offset + stride]
        scanlines += b'\x01' + row[:4] + bytes((row[i] - row[i - 4]) & 255 for i in range(4, stride))
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(scanlines, 9)) + chunk(b'IEND', b''))


def glb(name, mesh, texture):
    binary = bytearray()
    views = []
    accessors = []

    def append(raw, target=None):
        view = {'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(raw)}
        if target:
            view['target'] = target
        binary.extend(raw)
        binary.extend(b'\0' * ((-len(binary)) % 4))
        views.append(view)
        return len(views) - 1

    for values, width in [(mesh.positions, 3), (mesh.normals, 3), (mesh.uvs, 2)]:
        packed = b''.join(struct.pack('<' + 'f' * width, *value) for value in values)
        accessors.append({'bufferView': append(packed, 34962), 'componentType': 5126,
                          'count': len(values), 'type': f'VEC{width}'})
    accessors[0]['min'] = [min(p[axis] for p in mesh.positions) for axis in range(3)]
    accessors[0]['max'] = [max(p[axis] for p in mesh.positions) for axis in range(3)]
    packed = struct.pack(f'<{len(mesh.indices)}H', *mesh.indices)
    accessors.append({'bufferView': append(packed, 34963), 'componentType': 5123,
                      'count': len(mesh.indices), 'type': 'SCALAR'})
    texture_view = append(texture)
    document = {
        'asset': {'version': '2.0', 'generator': 'FPVManager tree model generator'},
        'scene': 0,
        'scenes': [{'nodes': [0]}],
        'nodes': [{'mesh': 0, 'name': name}],
        'meshes': [{'primitives': [
            {'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2}, 'indices': 3, 'material': 0},
        ]}],
        'materials': [{'alphaMode': 'MASK', 'alphaCutoff': .50,
                       'pbrMetallicRoughness': {'baseColorTexture': {'index': 0},
                                                'metallicFactor': 0, 'roughnessFactor': 1}}],
        'textures': [{'source': 0, 'sampler': 0}],
        'images': [{'bufferView': texture_view, 'mimeType': 'image/png'}],
        'samplers': [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 33071, 'wrapT': 33071}],
        'buffers': [{'byteLength': len(binary)}],
        'bufferViews': views,
        'accessors': accessors,
    }
    header = json.dumps(document, separators=(',', ':')).encode()
    header += b' ' * ((-len(header)) % 4)
    return (struct.pack('<III', 0x46546c67, 2, 28 + len(header) + len(binary))
            + struct.pack('<II', len(header), 0x4e4f534a) + header
            + struct.pack('<II', len(binary), 0x004e4942) + binary)


def build(kind, variant, name):
    rng = random.Random(17131 + variant * 101 + (396 if kind == 'conifer' else 0))
    color = PALETTES[kind][variant]
    image = bytearray(bytes((*tint(color, .86), 0)) * (SIZE * SIZE))
    mesh = Mesh()
    mesh.trunk(kind, variant)
    mesh.crown_core(kind, variant, rng)
    leaves = list(foliage(kind, variant, rng))
    paint_solid_surfaces(image, rng, color, variant)
    for sheet in sheets(kind, variant):
        mesh.sheet(sheet)
        paint_foliage(image, sheet, leaves, color, kind == 'conifer')
    # Source Tree-1 through Tree-3 each contain 40 triangles and two textures.
    if len(mesh.indices) // 3 > 40 or min(p[1] for p in mesh.positions) != BASE:
        raise ValueError('Tree exceeds the source geometry budget or changes the trunk anchor')
    return glb(name, mesh, encode_png(image))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Check the committed GLBs against the generator.')
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for kind in PALETTES:
        for variant in range(3):
            name = f'tree-{kind}-{variant + 1}'
            destination = OUTPUT / f'{name}.glb'
            data = build(kind, variant, name)
            if args.check:
                if not destination.is_file() or destination.read_bytes() != data:
                    raise SystemExit(f'{destination.name} differs from its generated model')
            else:
                destination.write_bytes(data)
            print(f'{destination.name}: 40 triangles, one 256 px atlas, {len(data):,} bytes')


if __name__ == '__main__':
    main()
