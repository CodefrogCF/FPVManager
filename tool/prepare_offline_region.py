"""Prepare an app-exported official source plan as a bounded .fpvregion package.

Install: python -m pip install -r tool/offline_region_requirements.txt
Run: python tool/prepare_offline_region.py offline-region.fpvofflineplan -o region.fpvregion
Only the official STAC download assets in the plan are fetched, never WMTS tiles.
"""
from pathlib import Path
from contextlib import ExitStack
from urllib.request import Request, build_opener, HTTPRedirectHandler
from urllib.parse import urlsplit
from datetime import datetime, timezone
from io import BytesIO
import argparse
import hashlib
import json
import math
import os
import struct
import uuid
import zipfile

import numpy as np
import rasterio
from rasterio.windows import Window
from pyproj import Transformer, network
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MAX_PACKAGE = 64 * 1024 * 1024
MAX_SOURCE = 512 * 1024 * 1024
MAX_CACHE = 2 * 1024 * 1024 * 1024
GRID_SHA = '533558782c5c30159264e1628de215a2446a9524f8e49af8deb8dcc83d370ae8'
COLLECTIONS = {'ch.swisstopo.swissalti3d', 'ch.swisstopo.pixelkarte-farbe-pk25.noscale'}


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def utc(value):
    if not isinstance(value, str) or not value.endswith('Z'):
        raise ValueError('UTC source timestamp missing')
    return datetime.fromisoformat(value.replace('Z', '+00:00'))


def validate_plan(plan, terrain_level):
    if plan.get('format') != 'fpvmanager-official-sources' or plan.get('version') != 1:
        raise ValueError('Export an official offline source plan from FPVManager first')
    r = dict(plan['region'], terrainLevel=terrain_level)
    values = [r[k] for k in ('west', 'south', 'east', 'north')]
    if not all(isinstance(v, (int, float)) and math.isfinite(v) for v in values):
        raise ValueError('Invalid region coordinates')
    if not (5.8 <= r['west'] < r['east'] <= 10.7 and 45.6 <= r['south'] < r['north'] <= 48):
        raise ValueError('Choose a Swiss region')
    if (not isinstance(r.get('id'), str) or not 1 <= len(r['id']) <= 100 or
            not isinstance(r.get('name'), str) or not 1 <= len(r['name']) <= 80 or
            r.get('style') != 'topographic' or not 10 <= r['imageryLevel'] <= 17 or not 8 <= terrain_level <= 16):
        raise ValueError('Unsupported offline region/detail')
    assets = plan.get('assets')
    if not isinstance(assets, list) or not 2 <= len(assets) <= 256:
        raise ValueError('Invalid source asset count')
    urls = set()
    kinds = set()
    for asset in assets:
        url = urlsplit(asset['url'])
        parts = url.path.strip('/').split('/')
        sha = asset.get('sha256', '')
        if (url.scheme != 'https' or url.netloc != 'data.geo.admin.ch' or url.query or url.fragment or
                len(parts) != 3 or parts[0] not in COLLECTIONS or parts[0] != asset['collection'] or
                parts[1] != asset['itemId'] or parts[2] != asset['assetId'] or not parts[2].endswith('.tif') or
                len(sha) != 64 or any(c not in '0123456789abcdef' for c in sha) or asset['url'] in urls or
                asset.get('horizontalReference') != 'EPSG:2056'):
            raise ValueError('Untrusted source asset or checksum')
        urls.add(asset['url'])
        terrain = asset['collection'].endswith('swissalti3d')
        if (asset.get('resolutionMeters') != (2 if terrain else 1.25) or
                asset.get('verticalReference') != ('LN02' if terrain else 'notApplicable')):
            raise ValueError('Unsupported source resolution or height reference')
        utc(asset['sourceTimeUtc'])
        kinds.add(terrain)
    if kinds != {True, False}:
        raise ValueError('Both map and terrain source data are required')
    count = 1 + sum((x1-x0+1)*(y1-y0+1) for terrain in (False, True)
                    for z in range(1+(terrain_level if terrain else r['imageryLevel']))
                    for x0, x1, y0, y1 in [tile_range(r, z, terrain)])
    if count > 5000:
        raise ValueError('Choose a smaller region or lower detail (5,000 tile limit)')
    return r


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise ValueError('Unexpected source redirect')


def obtain(asset, cache):
    target = cache / (asset['sha256'] + '.tif')
    if target.is_file() and target.stat().st_size <= MAX_SOURCE and digest(target) == asset['sha256']:
        return target
    used = sum(p.stat().st_size for p in cache.glob('*.tif') if p != target)
    temporary = cache / (asset['sha256'] + '-' + uuid.uuid4().hex + '.part')
    try:
        request = Request(asset['url'], headers={'User-Agent': 'FPVManager offline region preparation'})
        with build_opener(NoRedirect()).open(request, timeout=60) as response, temporary.open('xb') as output:
            if response.status != 200 or any(x in response.headers.get('Cache-Control', '').lower() for x in ('no-store', 'private')):
                raise ValueError('Source does not permit this download/cache response')
            declared = int(response.headers.get('Content-Length','0'))
            if declared > MAX_SOURCE or used + declared > MAX_CACHE:
                raise ValueError('Source/cache size limit reached before download')
            size = 0
            checksum = hashlib.sha256()
            while chunk := response.read(1024 * 1024):
                size += len(chunk)
                if size > MAX_SOURCE or used + size > MAX_CACHE:
                    raise ValueError('Source/cache limit reached; remove unused files from the source cache or choose a smaller region')
                checksum.update(chunk)
                output.write(chunk)
            if checksum.hexdigest() != asset['sha256']:
                raise ValueError('Official source checksum mismatch; export a new source plan')
        os.replace(temporary, target)
        return target
    finally:
        temporary.unlink(missing_ok=True)


def tile_range(r, z, terrain):
    n = 2**z
    def x(lon): return (lon+180)/360*(2*n if terrain else n)
    def y(lat):
        return (lat+90)/180*n if terrain else (1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*n
    lo, hi = sorted((y(r['south']), y(r['north'])))
    return math.floor(x(r['west'])), math.ceil(x(r['east']))-1, math.floor(lo), math.ceil(hi)-1


class RasterSamples:
    """Read bounded 257x257 windows rather than materializing whole map sheets."""
    def __init__(self, datasets, terrain):
        self.datasets = datasets
        self.terrain = terrain
        self.transform = Transformer.from_crs(4326, 2056, always_xy=True, allow_ballpark=False)

    def sample(self, longitude, latitude):
        shape = longitude.shape
        x, y = self.transform.transform(longitude.ravel(), latitude.ravel())
        result = np.zeros((longitude.size, 1 if self.terrain else 4), dtype=np.float64)
        found = np.zeros(longitude.size, dtype=bool)
        for ds in self.datasets:
            mask = (~found & (x >= ds.bounds.left) & (x < ds.bounds.right) &
                    (y > ds.bounds.bottom) & (y <= ds.bounds.top))
            positions = np.flatnonzero(mask)
            if not positions.size:
                continue
            inverse = ~ds.transform
            cols = inverse.a*x[positions]+inverse.b*y[positions]+inverse.c
            rows = inverse.d*x[positions]+inverse.e*y[positions]+inverse.f
            if self.terrain:
                cols = np.clip(cols-.5, 0, ds.width-1)
                rows = np.clip(rows-.5, 0, ds.height-1)
            ci, ri = cols.astype(int), rows.astype(int)
            blocks = (ri//256)*((ds.width+255)//256) + ci//256
            palette = ds.colormap(1) if not self.terrain and ds.colorinterp[0].name == 'palette' else None
            for block in np.unique(blocks):
                choose = np.flatnonzero(blocks == block)
                ix = positions[choose]
                left, top = int(ci[choose].min()//256*256), int(ri[choose].min()//256*256)
                window = Window(left, top, min(257, ds.width-left), min(257, ds.height-top))
                data = ds.read(window=window, masked=True)
                rr, cc = ri[choose]-top, ci[choose]-left
                if self.terrain:
                    r1, c1 = np.minimum(rr+1, data.shape[1]-1), np.minimum(cc+1, data.shape[2]-1)
                    dx, dy = cols[choose]-ci[choose], rows[choose]-ri[choose]
                    values = (data[0, rr, cc]*(1-dx)*(1-dy) + data[0, rr, c1]*dx*(1-dy) +
                              data[0, r1, cc]*(1-dx)*dy + data[0, r1, c1]*dx*dy)
                    valid = ~np.ma.getmaskarray(values) & np.isfinite(values.filled(np.nan))
                    result[ix, 0] = values.filled(np.nan)
                else:
                    pixels = data[:, rr, cc]
                    valid = ~np.ma.getmaskarray(pixels).any(axis=0)
                    if palette:
                        colors = np.array([palette.get(int(v), (0, 0, 0, 0)) for v in pixels[0].filled(0)])
                    elif ds.count >= 3:
                        colors = np.column_stack((pixels[:3].filled(0).T, np.full(len(ix), 255)))
                    else:
                        raise ValueError('Unsupported map color encoding')
                    valid &= colors[:, 3] > 0
                    result[ix] = colors
                found[ix] = valid
        if not found.all():
            raise ValueError('Source coverage contains missing raster cells; choose a smaller region inside published coverage')
        return result.reshape((*shape, -1))


class HeightGrid:
    def __init__(self):
        data = (ROOT/'assets/geo/chgeo2004_ln02.bin').read_bytes()
        if hashlib.sha256(data).hexdigest() != GRID_SHA or data[:8] != b'CHLN02\x00\x01':
            raise ValueError('Bundled Swiss height-conversion grid is missing or modified')
        self.width, self.height, self.west, self.north, self.step = struct.unpack('<II3d', data[8:40])
        self.values = np.frombuffer(data, dtype='<f4', offset=40).reshape(self.height, self.width)

    def offsets(self, lon, lat):
        x, y = (lon-self.west)/self.step, (self.north-lat)/self.step
        if np.any(x < 0) or np.any(y < 0) or np.any(x > self.width-1) or np.any(y > self.height-1):
            raise ValueError('Region is outside the bundled Swiss height-conversion coverage')
        c, r = np.minimum(x.astype(int), self.width-2), np.minimum(y.astype(int), self.height-2)
        dx, dy = x-c, y-r
        return (self.values[r,c]*(1-dx)*(1-dy)+self.values[r,c+1]*dx*(1-dy)+
                self.values[r+1,c]*(1-dx)*dy+self.values[r+1,c+1]*dx*dy)


def quantized_mesh(r, z, x, y, samples, grid):
    width, height = 180/2**z, 180/2**z
    west, south = x*width-180, y*height-90
    w, e = max(west, r['west']), min(west+width, r['east'])
    s, n = max(south, r['south']), min(south+height, r['north'])
    lon, lat = np.meshgrid(np.linspace(w,e,65), np.linspace(s,n,65))
    heights = samples.sample(lon,lat)[:,:,0] + grid.offsets(lon,lat)
    if not np.isfinite(heights).all() or heights.min() < -1000 or heights.max() > 15000:
        raise ValueError('Invalid converted terrain elevation')
    low, high = float(heights.min()), float(heights.max())
    u0, u1 = max(0,math.floor((w-west)/width*32767)), min(32767,math.ceil((e-west)/width*32767))
    v0, v1 = max(0,math.floor((s-south)/height*32767)), min(32767,math.ceil((n-south)/height*32767))
    if u1 <= u0 or v1 <= v0:
        raise ValueError('Degenerate terrain coverage')
    u, v = np.meshgrid(np.rint(np.linspace(u0,u1,65)), np.rint(np.linspace(v0,v1,65)))
    h = np.rint((heights-low)/(high-low if high>low else 1)*32767)
    triangles = []
    for row in range(64):
        for col in range(64):
            i = row*65+col
            triangles.extend((i,i+1,i+65,i+1,i+66,i+65))
    order, remap = [], {}
    for i in triangles:
        if i not in remap:
            remap[i] = len(order)
            order.append(i)
    # The header bounds the actual quantized positions, including coarse LOD
    # boundary quantization. Runtime sampling is additionally limited to r.
    phi, lam = np.radians(south+v.ravel()/32767*height), np.radians(west+u.ravel()/32767*width)
    hh = heights.ravel()
    a, ecc = 6378137., 6.6943799901413165e-3
    normal = a/np.sqrt(1-ecc*np.sin(phi)**2)
    xyz = np.column_stack(((normal+hh)*np.cos(phi)*np.cos(lam),(normal+hh)*np.cos(phi)*np.sin(lam),(normal*(1-ecc)+hh)*np.sin(phi)))
    center = xyz.mean(axis=0)
    radius = float(np.linalg.norm(xyz-center,axis=1).max())+1
    scaled = xyz/np.array([a,a,a*math.sqrt(1-ecc)])
    direction = center/np.array([a,a,a*math.sqrt(1-ecc)])
    direction /= np.linalg.norm(direction)
    magnitude = np.maximum(np.linalg.norm(scaled,axis=1),1)
    cosine = np.clip((scaled/np.linalg.norm(scaled,axis=1)[:,None])@direction,-1,1)
    denominator = cosine/magnitude-np.sqrt(1-cosine*cosine)*np.sqrt(magnitude*magnitude-1)/magnitude
    if np.any(denominator<=0):
        raise ValueError('Unsupported terrain horizon extent')
    horizon = direction*float((1/denominator).max())
    output = bytearray(struct.pack('<3d2f4d3dI',*center,low,high,*center,radius,*horizon,65*65))
    for values in (u,v,h):
        reordered = values.ravel()[order].astype(np.int64)
        deltas = np.diff(reordered,prepend=0)
        output.extend(((deltas<<1)^(deltas>>63)).astype('<u2').tobytes())
    output.extend(struct.pack('<I',64*64*2))
    highest, codes = 0, []
    for index in triangles:
        index = remap[index]
        codes.append(highest-index)
        if index == highest:
            highest += 1
    output.extend(np.array(codes,dtype='<u2').tobytes())
    for edge in ([row*65 for row in range(65)],list(reversed(range(65))),
                 [row*65+64 for row in reversed(range(65))],[64*65+col for col in range(65)]):
        output.extend(struct.pack('<I',65))
        output.extend(np.array([remap[i] for i in edge],dtype='<u2').tobytes())
    return bytes(output)


def map_tile(r,z,x,y,samples):
    n = 2**z
    px, py = np.meshgrid((x+(np.arange(256)+.5)/256)/n,(y+(np.arange(256)+.5)/256)/n)
    lon, lat = px*360-180, np.degrees(np.arctan(np.sinh(math.pi*(1-2*py))))
    mask = (lon>=r['west'])&(lon<=r['east'])&(lat>=r['south'])&(lat<=r['north'])
    rgba = np.zeros((256,256,4),dtype=np.uint8)
    if mask.any():
        rgba[mask] = samples.sample(lon[mask],lat[mask]).astype(np.uint8)
    stream = BytesIO()
    Image.fromarray(rgba).save(stream,format='PNG')
    return stream.getvalue()


def prepare(plan, output, cache, terrain_level=None, replace=False):
    network.set_network_enabled(False)
    terrain_level = plan['region']['terrainLevel'] if terrain_level is None else terrain_level
    r = validate_plan(plan,terrain_level)
    if output.exists() and not replace:
        raise ValueError('Output exists; choose another name or explicitly pass --replace')
    output.parent.mkdir(parents=True,exist_ok=True)
    cache.mkdir(parents=True,exist_ok=True)
    paths = []
    for i,asset in enumerate(plan['assets']):
        print(f"Source {i+1}/{len(plan['assets'])}: {asset['assetId']}",flush=True)
        paths.append(obtain(asset,cache))
    manifest = {'format':'fpvmanager-region','version':1,'region':r,
        'preparedAtUtc':datetime.now(timezone.utc).isoformat().replace('+00:00','Z'),
        'sourcePlanRetrievedAtUtc':plan.get('retrievedAtUtc'),
        'attribution':'© swisstopo','sources':plan['assets'],
        'heightReference':'wgs84Ellipsoid','sourceHeightReference':'LN02',
        'heightGridSha256':GRID_SHA,'meshGridSize':65,
        'resampling':'bilinear terrain; nearest map pixels; ETRS89 used as WGS84 visualization approximation',
        'files':{}}
    temporary = output.with_name('.'+output.name+'-'+uuid.uuid4().hex+'.partial')
    total = 0
    try:
        with ExitStack() as stack:
            stack.enter_context(rasterio.Env(GDAL_CACHEMAX=32*1024*1024))
            terrain, imagery = [], []
            for asset,path in zip(plan['assets'],paths):
                ds = stack.enter_context(rasterio.open(path))
                if (ds.crs is None or ds.crs.to_epsg()!=2056 or ds.width*ds.height > 1024*1024*1024 or
                        ds.transform.b != 0 or ds.transform.d != 0 or ds.transform.e >= 0 or
                        not math.isclose(ds.transform.a,asset['resolutionMeters']) or
                        not math.isclose(-ds.transform.e,asset['resolutionMeters'])):
                    raise ValueError('Unsupported source raster coordinates/dimensions')
                (terrain if asset['collection'].endswith('swissalti3d') else imagery).append(ds)
            terrain, imagery, grid = RasterSamples(terrain,True), RasterSamples(imagery,False), HeightGrid()
            with zipfile.ZipFile(temporary,'x',compression=zipfile.ZIP_STORED,allowZip64=False) as archive:
                def add(name,body):
                    nonlocal total
                    total += len(body)
                    if len(body)>4*1024*1024 or total>MAX_PACKAGE-1024*1024:
                        raise ValueError('Prepared region exceeds 64 MiB; choose a smaller area/lower map detail')
                    archive.writestr(name,body)
                    manifest['files'][name]={'bytes':len(body),'sha256':hashlib.sha256(body).hexdigest()}
                available = []
                for z in range(terrain_level+1):
                    x0,x1,y0,y1 = tile_range(r,z,True)
                    available.append([dict(startX=x0,endX=x1,startY=y0,endY=y1)])
                    for x in range(x0,x1+1):
                        for y in range(y0,y1+1):
                            add(f'terrain/{z}/{x}/{y}.terrain',quantized_mesh(r,z,x,y,terrain,grid))
                    print(f'Terrain level {z}/{terrain_level}',flush=True)
                add('terrain/layer.json',json.dumps(dict(tilejson='2.1.0',format='quantized-mesh-1.0',version='1',
                    scheme='tms',projection='EPSG:4326',tiles=['{z}/{x}/{y}.terrain'],maxzoom=terrain_level,
                    available=available),separators=(',',':')).encode())
                for z in range(r['imageryLevel']+1):
                    x0,x1,y0,y1 = tile_range(r,z,False)
                    for x in range(x0,x1+1):
                        for y in range(y0,y1+1):
                            add(f'imagery/topographic/{z}/{x}/{y}.png',map_tile(r,z,x,y,imagery))
                    print(f'Map level {z}/{r["imageryLevel"]}',flush=True)
                archive.writestr('manifest.json',json.dumps(manifest,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode())
        if temporary.stat().st_size>MAX_PACKAGE:
            raise ValueError('Final package exceeds 64 MiB')
        if replace:
            os.replace(temporary,output)
        elif os.name == 'nt':
            os.rename(temporary,output)  # Windows rename fails if output exists.
        else:
            os.link(temporary,output)  # Atomic no-overwrite publication.
            temporary.unlink()
        print(f'Ready: {output} ({output.stat().st_size/1048576:.1f} MiB)',flush=True)
        return manifest
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan',type=Path,help='Path to the .fpvofflineplan file exported from FPVManager')
    parser.add_argument('-o','--output',type=Path,required=True)
    parser.add_argument('--source-cache',type=Path)
    parser.add_argument('--terrain-level',type=int,help='Override terrain detail from the app plan (8–16)')
    parser.add_argument('--replace',action='store_true')
    args=parser.parse_args()
    try:
        if not args.plan.is_file():
            parser.exit(1,
                f'Source plan not found: {args.plan.resolve()}\n'
                'In FPVManager, open Offline & personal data > Add offline region, choose the area,\n'
                'then select "Vorbereitungsdatei fuer Laptop speichern".\n'
                'Copy the exported .fpvofflineplan file to this laptop and pass its actual path\n'
                '(for example, a file in Downloads) as the first argument.\n')
        if args.plan.stat().st_size>1024*1024:
            raise ValueError('Source plan exceeds 1 MiB')
        prepare(json.loads(args.plan.read_text(encoding='utf-8')),args.output,
                args.source_cache or args.output.parent/'.fpv-sources',args.terrain_level,args.replace)
    except (ValueError,OSError,KeyError) as error:
        parser.exit(1,f'Preparation failed; previous package retained: {error}\n')
