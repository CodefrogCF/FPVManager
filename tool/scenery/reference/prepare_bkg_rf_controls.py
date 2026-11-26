#!/usr/bin/env python3
"""Prepare independent DHHN2016 / ellipsoid control heights from a trusted DEM."""
import argparse
import json
import math
from pathlib import Path

import numpy as np
import rasterio
from rasterio.windows import Window
from pyproj import CRS, Transformer, datadir, network
from pyproj.transformer import TransformerGroup


def prepare(path, points, source, grid_dir=None):
    if not source.strip() or not 3 <= len(points) <= 64:
        raise ValueError('Provide source/edition and 3–64 independent control locations')
    network.set_network_enabled(False)
    if grid_dir is not None:
        datadir.append_data_dir(str(grid_dir))
    with rasterio.open(path) as dem:
        if dem.scales[0] != 1 or dem.offsets[0] != 0:
            raise ValueError('Expected unscaled metre heights')
        horizontal = CRS.from_user_input(dem.crs).to_2d()
        epsg = horizontal.to_epsg()
        if epsg not in (25832, 25833):
            raise ValueError('Expected official ETRS89 UTM32/33 raster; verify DHHN2016 separately')
        if dem.crs.to_epsg() is None and not CRS.from_user_input(dem.crs).is_compound:
            raise ValueError('Unrecognized source CRS')
        compound = CRS.from_user_input(dem.crs)
        if compound.is_compound and compound.sub_crs_list[-1].to_epsg() != 7837:
            raise ValueError('Raster vertical CRS is not DHHN2016')
        group = TransformerGroup(CRS.from_user_input(f'EPSG:{epsg}+7837'), CRS.from_epsg(4979),
                                 always_xy=True, allow_ballpark=False)
        if not group.best_available or not group.transformers:
            raise ValueError('Required local GCG2016 / PROJ transformation unavailable')
        transform = group.transformers[0]
        grids = [g.short_name for op in transform.operations for g in op.grids]
        if not any('gcg2016' in g.lower() for g in grids):
            raise ValueError('Selected transformation does not explicitly use GCG2016')
        if not all(g.available for op in transform.operations for g in op.grids):
            raise ValueError('Required local transformation grid unavailable')
        to_grid = Transformer.from_crs(4326, horizontal, always_xy=True)
        controls = []
        cells = set()
        for lon, lat in points:
            if not all(map(math.isfinite, (lon, lat))) or not (-180 <= lon <= 180 and -90 <= lat <= 90):
                raise ValueError('Invalid geographic control coordinate')
            x, y = to_grid.transform(lon, lat, errcheck=True)
            row, col = dem.index(x, y)
            if not (1 <= row < dem.height-1 and 1 <= col < dem.width-1) or (row, col) in cells:
                raise ValueError('Control outside DEM interior or duplicate pixel')
            cells.add((row, col))
            block = dem.read(1, window=Window(col-1, row-1, 3, 3), masked=True)
            if block.shape != (3, 3) or np.any(np.ma.getmaskarray(block)) or not np.isfinite(block.data).all():
                raise ValueError('Missing control heights')
            if float(np.ptp(block.data)) > 2:
                raise ValueError('Choose flat, unobstructed ground; local DEM relief exceeds 2 m')
            x, y = dem.xy(row, col)
            h_normal = float(block[1, 1])
            lon, lat, h_ellipsoid = transform.transform(x, y, h_normal, errcheck=True)
            if not all(map(math.isfinite, (lon, lat, h_ellipsoid))) or not 10 < h_ellipsoid-h_normal < 100:
                raise ValueError('Implausible German geoid correction')
            controls.append(dict(longitude=lon, latitude=lat, dhhn2016M=h_normal, ellipsoidM=h_ellipsoid))
    return dict(source=source, horizontalCRS=f'EPSG:{epsg}', verticalCRS='EPSG:7837',
                transformation=transform.description, grids=grids, controls=controls)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('dem', type=Path)
    p.add_argument('--point', nargs=2, type=float, action='append', required=True, metavar=('LON', 'LAT'))
    p.add_argument('--source', required=True, help='Official DEM edition and attribution')
    p.add_argument('--grid-dir', type=Path, required=True, help='Local PROJ GCG2016 grid directory')
    p.add_argument('--confirm-dhhn2016', action='store_true', required=True,
                   help='Confirm source documentation specifies unscaled metre heights in DHHN2016')
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    try:
        report = prepare(args.dem, args.point, args.source, args.grid_dir)
        with args.output.open('x', encoding='utf-8') as f:
            json.dump(report, f, indent=2, allow_nan=False)
    except (ValueError, OSError, RuntimeError) as e:
        p.exit(2, f'Control preparation failed: {e}\n')


if __name__ == '__main__':
    main()
