"""Prepare FPVManager's compact forest probability grid from the BAFU/WSL COG.

Reads the 320 m overview via two byte-range requests. The official 2023
dataset remains Opendata BY and is attributed to BAFU / WSL (LFI).
"""

from pathlib import Path
import hashlib
import struct
from urllib.request import Request, urlopen
import zlib


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'web/assets/vegetation/forest_composition.bin'
SOURCE = (
    'https://data.geo.admin.ch/ch.bafu.landesforstinventar-waldmischungsgrad/'
    'landesforstinventar-waldmischungsgrad/landesforstinventar-waldmischungsgrad_2056.tif'
)
SOURCE_BYTES = 170_912_760
GRID_SHA256 = '8c47d4eadab4c3341c4db55d5c5edc39d9bf6d8b91216bf02d17c7a6f8675627'
WIDTH, HEIGHT = 1125, 718
WEST, SOUTH, EAST, NORTH = 2480000, 1070000, 2840000, 1300000
TILE_SIZE = 512
NODATA = 128  # The TIFF's signed Int8 -128, stored as its original byte.


def read_range(offset, size):
    end = offset + size - 1
    request = Request(SOURCE, headers={'Range': f'bytes={offset}-{end}'})
    with urlopen(request, timeout=30) as response:
        expected = f'bytes {offset}-{end}/{SOURCE_BYTES}'
        if response.status != 206 or response.headers.get('Content-Range') != expected:
            raise ValueError('Unexpected source or byte range')
        data = response.read(size + 1)
    if len(data) != size:
        raise ValueError('Incomplete source range')
    return data


def read_overview(header):
    if header[:8] != b'II+\x00\x08\x00\x00\x00':
        raise ValueError('Expected the published little-endian BigTIFF')
    first_offset, = struct.unpack_from('<Q', header, 8)
    offset = first_offset
    while offset:
        entry_count, = struct.unpack_from('<Q', header, offset)
        end = offset + 8 + entry_count * 20
        if end + 8 > len(header):
            raise ValueError('TIFF directory exceeds the metadata range')
        tags = {}
        for entry in range(offset + 8, end, 20):
            tag, kind, count, value = struct.unpack_from('<HHQQ', header, entry)
            fmt = {3: 'H', 4: 'I', 12: 'd', 16: 'Q'}.get(kind)
            if fmt is None:
                continue
            size = struct.calcsize('<' + fmt) * count
            start = entry + 12 if size <= 8 else value
            if start + size <= len(header):
                tags[tag] = struct.unpack_from(f'<{count}{fmt}', header, start)
        if offset == first_offset and (
            tags.get(33550) != (10, 10, 0)
            or tags.get(33922) != (0, 0, 0, WEST, NORTH, 0)
            or tags.get(256) != (36000,)
            or tags.get(257) != (23000,)
        ):
            raise ValueError('Unexpected source georeferencing')
        if tags.get(256) == (WIDTH,) and tags.get(257) == (HEIGHT,):
            required = {258: (8,), 259: (8,), 277: (1,), 317: (1,),
                        322: (TILE_SIZE,), 323: (TILE_SIZE,), 339: (2,)}
            if any(tags.get(tag) != value for tag, value in required.items()):
                raise ValueError('Unexpected overview encoding')
            return tuple(zip(tags[324], tags[325], strict=True))
        next_offset, = struct.unpack_from('<Q', header, end)
        if next_offset and next_offset <= offset:
            raise ValueError('Invalid TIFF directory chain')
        offset = next_offset
    raise ValueError('Forest overview missing')


def build_grid():
    blocks = read_overview(read_range(0, 56332))
    blocks_wide = (WIDTH + TILE_SIZE - 1) // TILE_SIZE
    blocks_high = (HEIGHT + TILE_SIZE - 1) // TILE_SIZE
    if len(blocks) != blocks_wide * blocks_high:
        raise ValueError('Unexpected overview block count')
    lo = min(offset for offset, size in blocks if size)
    hi = max(offset + size for offset, size in blocks if size)
    if lo < 56332 or hi - lo > 1_000_000:
        raise ValueError('Overview no longer fits the bounded download')
    compressed = read_range(lo, hi - lo)
    grid = bytearray([NODATA]) * (WIDTH * HEIGHT)
    for index, (offset, size) in enumerate(blocks):
        if not size:
            continue
        decoder = zlib.decompressobj()
        block = decoder.decompress(compressed[offset - lo:offset - lo + size],
                                   TILE_SIZE * TILE_SIZE + 1)
        if not decoder.eof or len(block) != TILE_SIZE * TILE_SIZE:
            raise ValueError('Unexpected overview block size')
        x, y = index % blocks_wide * TILE_SIZE, index // blocks_wide * TILE_SIZE
        span = min(WIDTH - x, TILE_SIZE)
        for row in range(min(HEIGHT - y, TILE_SIZE)):
            target = (y + row) * WIDTH + x
            source = row * TILE_SIZE
            grid[target:target + span] = block[source:source + span]
    if hashlib.sha256(grid).hexdigest() != GRID_SHA256:
        raise ValueError('Overview values differ from the pinned dataset')
    return b'FPVFOR1\x00' + struct.pack('<IIiiii', WIDTH, HEIGHT, WEST, SOUTH, EAST, NORTH) + grid


if __name__ == '__main__':
    data = build_grid()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(data)
    print(f'{OUTPUT.relative_to(ROOT)}: {len(data):,} bytes, SHA-256 {hashlib.sha256(data).hexdigest()}')
