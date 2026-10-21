"""Rebuild the bundled LN02 height grid from the pinned PROJ GeoTIFF (Pillow)."""
from pathlib import Path
import argparse
import hashlib
import struct
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE_SHA256 = 'ec9638c152f4519278b3e7a781d1a7c2769bd54de39accec099bd5036f4fd214'
OUTPUT_SHA256 = '533558782c5c30159264e1628de215a2446a9524f8e49af8deb8dcc83d370ae8'


def convert(path):
    assert hashlib.sha256(path.read_bytes()).hexdigest() == SOURCE_SHA256, 'Unexpected source grid'
    with Image.open(path) as image:
        assert image.size == (559, 253) and image.mode == 'F'
        samples = list(image.getdata())
    data = (b'CHLN02\x00\x01' + struct.pack('<II3d', 559, 253, 5.85, 47.85, 1 / 120) +
            struct.pack(f'<{len(samples)}f', *samples))
    assert hashlib.sha256(data).hexdigest() == OUTPUT_SHA256
    return data


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('geotiff', type=Path, help='ch_swisstopo_chgeo2004_ETRS89_LN02.tif from cdn.proj.org')
    args = parser.parse_args()
    (ROOT / 'assets/geo/chgeo2004_ln02.bin').write_bytes(convert(args.geotiff))
