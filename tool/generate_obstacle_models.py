"""Generate texture-free schematic glTF models; every mesh is exactly 1 m high.

Run from the repository root: python tool/generate_obstacle_models.py
Only the vertical dimension is surveyed. Widths and headings are schematic.
"""
import argparse
import json
import math
from pathlib import Path
import struct

OUTPUT = Path(__file__).resolve().parent.parent / 'web/models/obstacles'


class Mesh:
    def __init__(self):
        self.positions, self.normals, self.indices = [], [], []

    def face(self, points):
        a, b, c = points[:3]
        u, v = [b[i]-a[i] for i in range(3)], [c[i]-a[i] for i in range(3)]
        normal = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
        length = math.sqrt(sum(x*x for x in normal))
        if length < 1e-12:
            raise ValueError('Degenerate face')
        start = len(self.positions)
        self.positions.extend(points)
        self.normals.extend([[x/length for x in normal]] * len(points))
        for i in range(1, len(points)-1):
            self.indices.extend([start, start+i, start+i+1])

    def beam(self, a, b, width):
        direction = [b[i]-a[i] for i in range(3)]
        length = math.sqrt(sum(x*x for x in direction))
        d = [x/length for x in direction]
        helper = [0, 1, 0] if abs(d[1]) < .9 else [1, 0, 0]
        u = [d[1]*helper[2]-d[2]*helper[1], d[2]*helper[0]-d[0]*helper[2], d[0]*helper[1]-d[1]*helper[0]]
        n = math.sqrt(sum(x*x for x in u))
        u = [x/n*width/2 for x in u]
        v = [d[1]*u[2]-d[2]*u[1], d[2]*u[0]-d[0]*u[2], d[0]*u[1]-d[1]*u[0]]
        rings = [[tuple(p[i]+s*u[i]+t*v[i] for i in range(3))
                  for s, t in [(1,1), (-1,1), (-1,-1), (1,-1)]] for p in [a,b]]
        self.face(list(reversed(rings[0])))
        self.face(rings[1])
        for i in range(4):
            j = (i+1) % 4
            self.face([rings[0][i], rings[0][j], rings[1][j], rings[1][i]])

    def box(self, x, y, z, w, h, depth):
        a = [(x+s*w/2, y-h/2, z+t*depth/2) for s,t in [(1,1),(-1,1),(-1,-1),(1,-1)]]
        b = [(px,y+h/2,pz) for px,_,pz in a]
        self.face(list(reversed(a)))
        self.face(b)
        for i in range(4):
            j=(i+1)%4
            self.face([a[i],a[j],b[j],b[i]])

    def cylinder(self, radius, bottom, top, sides=10):
        a = [(radius*math.cos(i*math.tau/sides),bottom,radius*math.sin(i*math.tau/sides)) for i in range(sides)]
        b = [(x,top,z) for x,_,z in a]
        self.face(a)
        self.face(list(reversed(b)))
        for i in range(sides):
            j=(i+1)%sides
            self.face([a[i],b[i],b[j],a[j]])

    def glb(self, name, color):
        # Normalize actual vertex positions, including beam caps and blades.
        # glTF uses metres and Y-up. The bottom is the terrain anchor.
        low = min(p[1] for p in self.positions)
        height = max(p[1] for p in self.positions)-low
        positions = [(x/height,(y-low)/height,z/height) for x,y,z in self.positions]
        binary, views, accessors = bytearray(), [], []
        for values, fmt, kind, component in [(positions,'f','VEC3',5126),(self.normals,'f','VEC3',5126),(self.indices,'H','SCALAR',5123)]:
            flat = [n for row in values for n in row] if kind=='VEC3' else values
            payload = struct.pack('<'+fmt*len(flat),*flat)
            views.append({'buffer':0,'byteOffset':len(binary),'byteLength':len(payload), 'target':34962 if kind=='VEC3' else 34963})
            binary.extend(payload)
            while len(binary)%4:
                binary.append(0)
            accessor = {'bufferView':len(views)-1,'componentType':component,'count':len(values),'type':kind}
            if not accessors:
                accessor.update(min=[min(p[i] for p in positions) for i in range(3)],max=[max(p[i] for p in positions) for i in range(3)])
            accessors.append(accessor)
        gltf = {'asset':{'version':'2.0','generator':'FPVManager schematic obstacle generator'},
                'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0,'name':name}],
                'meshes':[{'primitives':[{'attributes':{'POSITION':0,'NORMAL':1},'indices':2,'material':0}]}],
                'materials':[{'pbrMetallicRoughness':{'baseColorFactor':[*color,1],'metallicFactor':.15,'roughnessFactor':.85},'doubleSided':True}],
                'buffers':[{'byteLength':len(binary)}],'bufferViews':views,'accessors':accessors}
        header = json.dumps(gltf,separators=(',',':'),sort_keys=True).encode()
        header += b' '*((-len(header))%4)
        return struct.pack('<III',0x46546c67,2,12+8+len(header)+8+len(binary))+struct.pack('<II',len(header),0x4e4f534a)+header+struct.pack('<II',len(binary),0x004e4942)+binary


def lattice(mesh, height=1, bottom=.12, top=.025, levels=5):
    for level in range(levels):
        y0, y1 = height*level/levels, height*(level+1)/levels
        r0, r1 = bottom+(top-bottom)*level/levels, bottom+(top-bottom)*(level+1)/levels
        a = [(s*r0,y0,t*r0) for s,t in [(1,1),(-1,1),(-1,-1),(1,-1)]]
        b = [(s*r1,y1,t*r1) for s,t in [(1,1),(-1,1),(-1,-1),(1,-1)]]
        for i in range(4):
            j=(i+1)%4
            mesh.beam(a[i],b[i],.012)
            mesh.beam(b[i],b[j],.009)
            mesh.beam(a[i],b[j],.008)


def generate():
    result = {}
    pylon = Mesh()
    lattice(pylon, bottom=.13, top=.012)
    for y,w in [(.68,.5),(.83,.38)]:
        pylon.box(0,y,0,w,.025,.035)
        for x in [-w/2,w/2]:
            pylon.box(x,y-.04,0,.018,.07,.018)
    result['power-pylon']=(pylon,[.64,.69,.72])
    pole = Mesh()
    pole.cylinder(.022,0,1)
    pole.box(0,.88,0,.36,.025,.035)
    result['utility-pole']=(pole,[.48,.36,.23])
    mast = Mesh()
    mast.cylinder(.018,0,1)
    for y in [.72,.87]:
        for x in [-.055,.055]:
            mast.box(x,y,0,.035,.12,.025)
            mast.beam([0,y,0],[x,y,0],.012)
    result['antenna-mast']=(mast,[.8,.81,.82])
    tower = Mesh()
    lattice(tower, bottom=.10, top=.04)
    result['lattice-tower']=(tower,[.65,.7,.74])
    crane = Mesh()
    lattice(crane, height=.96,bottom=.045,top=.045,levels=6)
    crane.box(.24,.90,0,.9,.035,.045)
    crane.box(-.18,.855,0,.12,.06,.10)
    crane.box(.065,.85,0,.08,.07,.09)
    crane.beam([0,.99,0],[.67,.92,0],.008)
    crane.beam([0,.99,0],[-.20,.92,0],.008)
    crane.beam([.60,.89,0],[.60,.55,0],.006)
    crane.box(.60,.54,0,.025,.025,.025)
    result['tower-crane']=(crane,[.94,.64,.15])
    chimney = Mesh()
    chimney.cylinder(.075,0,1,12)
    result['chimney']=(chimney,[.65,.32,.24])
    wind = Mesh()
    wind.cylinder(.022,0,.68)
    wind.box(0,.67,0,.08,.055,.12)
    # One upward blade makes the published overall height the highest tip.
    for angle in [0,2*math.pi/3,4*math.pi/3]:
        wind.beam([0,.68,.07],[.32*math.sin(angle),.68+.32*math.cos(angle),.07],.022)
    result['wind-turbine']=(wind,[.87,.88,.88])
    support = Mesh()
    support.cylinder(.025,0,.95)
    support.box(0,.96,0,.38,.045,.055)
    result['cableway-support']=(support,[.5,.63,.68])
    return {name: mesh.glb(name,color) for name,(mesh,color) in result.items()}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true',help='Check that bundled models match the generator, without writing')
    args=parser.parse_args()
    if not args.check:
        OUTPUT.mkdir(parents=True,exist_ok=True)
    for name, data in generate().items():
        target=OUTPUT/(name+'.glb')
        if args.check:
            if not target.exists() or target.read_bytes()!=data:
                raise SystemExit(f'Regenerate {name}.glb')
        else:
            target.write_bytes(data)
        print(f'{name}: {len(data)} bytes')
