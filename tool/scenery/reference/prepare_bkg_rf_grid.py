#!/usr/bin/env python3
"""Generate a small local GCG2016 RF grid for the Ruedersdorf BKG test area."""
import argparse
import hashlib
import json
import math
from pathlib import Path

from pyproj import CRS, Transformer, datadir, network
from pyproj.transformer import TransformerGroup

PROVIDER = 'https://sgx.geodatenzentrum.de/gdz_basemapde_3d_gelaende/dgm5_4326_mesh/'
WEST, SOUTH, EAST, NORTH = 13.775, 52.481, 13.800, 52.491
COLS, ROWS = 11, 11


def prepare(grid, report):
    if grid.name != 'de_bkg_gcg2016.tif' or not grid.is_file():
        raise ValueError('Expected the local de_bkg_gcg2016.tif PROJ grid')
    if report.get('providerUrl') != PROVIDER:
        raise ValueError('Unexpected terrain provider')
    if report.get('coldVsNativeMaxM') != 0 or report.get('warmVsNativeMaxM') != 0:
        raise ValueError('Terrain cache comparison must agree with native samples')
    network.set_network_enabled(False)
    datadir.append_data_dir(str(grid.parent.resolve()))
    # Use the same explicitly DHHN2016-aware operation as the control tool.
    group = TransformerGroup(CRS.from_user_input('EPSG:25833+7837'), CRS.from_epsg(4979), always_xy=True, allow_ballpark=False)
    if not group.best_available or not group.transformers:
        raise ValueError('Local GCG2016 transformation unavailable')
    transform = group.transformers[0]
    grids = [g for op in transform.operations for g in op.grids]
    if not any(g.short_name == grid.name and g.available for g in grids):
        raise ValueError('Transformation does not use the required GCG2016 grid')
    to_utm = Transformer.from_crs(4326, 25833, always_xy=True)

    def offset(lon, lat):
        x, y = to_utm.transform(lon, lat, errcheck=True)
        _, _, z = transform.transform(x, y, 0, errcheck=True)
        if not math.isfinite(z) or not 10 < z < 100:
            raise ValueError('Missing or implausible grid value')
        return z

    seen, accepted, excluded = set(), [], []
    for p in report['points']:
        lon, lat, normal, ellipsoid, mesh = (float(p[k]) for k in ('longitude', 'latitude', 'dhhn2016M', 'ellipsoidM', 'meshM'))
        if not all(map(math.isfinite, (lon, lat, normal, ellipsoid, mesh))) or (lon, lat) in seen:
            raise ValueError('Invalid or duplicate control')
        seen.add((lon, lat))
        if not WEST <= lon <= EAST or not SOUTH <= lat <= NORTH:
            excluded.append(p)
            continue
        if abs(mesh-normal) > 2 or abs(mesh-ellipsoid) < 10 or abs(offset(lon, lat)-(ellipsoid-normal)) > .03:
            raise ValueError('Control within test coverage does not match the normal-height hypothesis/grid')
        accepted.append(p)
    if len(accepted) < 8:
        raise ValueError('At least eight agreeing local controls required')
    if max(p['longitude'] for p in accepted)-min(p['longitude'] for p in accepted)<.008 or max(p['latitude'] for p in accepted)-min(p['latitude'] for p in accepted)<.004:
        raise ValueError('Insufficient spatial spread of local controls')
    dx, dy = (EAST-WEST)/(COLS-1), (NORTH-SOUTH)/(ROWS-1)
    values = [round(offset(WEST+i*dx,SOUTH+j*dy),6) for j in range(ROWS) for i in range(COLS)]
    # Check cell midpoints independently rather than assuming grid spacing is adequate.
    for j in range(ROWS-1):
        for i in range(COLS-1):
            k=j*COLS+i
            if abs(offset(WEST+(i+.5)*dx,SOUTH+(j+.5)*dy)-sum(values[t] for t in (k,k+1,k+COLS,k+COLS+1))/4)>.01:
                raise ValueError('Grid interpolation error exceeds 1 cm at a cell midpoint')
    return dict(schema=1,datum='DHHN2016',provider=PROVIDER,west=WEST,south=SOUTH,stepLon=dx,stepLat=dy,cols=COLS,rows=ROWS,values=values,
                source='BKG GCG2016 via PROJ-data; © BKG, CC BY 4.0; local interpolated derivative',gridSha256=hashlib.sha256(grid.read_bytes()).hexdigest(),
                controlSource=report['source'],acceptedControls=len(accepted),excludedControls=len(excluded),
                controls=[{k:p[k] for k in ('longitude','latitude','dhhn2016M')} for p in accepted],
                normalRmsM=math.sqrt(sum((p['meshM']-p['dhhn2016M'])**2 for p in accepted)/len(accepted)))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--grid',required=True,type=Path)
    p.add_argument('--report',required=True,type=Path)
    p.add_argument('--output',type=Path,default=Path('web/features/terrain/bkg_rf_grid.generated.js'))
    a=p.parse_args()
    data=prepare(a.grid,json.loads(a.report.read_text(encoding='utf-8-sig')))
    a.output.write_text('globalThis.FPVBkgRfGrid = '+json.dumps(data,allow_nan=False,separators=(',',':'))+';\n',encoding='utf-8')
    print(f"Local experimental grid: {data['acceptedControls']} controls, {data['excludedControls']} outside test coverage, RMS {data['normalRmsM']:.3f} m")


if __name__=='__main__':
    main()
