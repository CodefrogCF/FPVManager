import json
import struct
import tempfile
import unittest
from pathlib import Path
import numpy as np
from build_collision import read_glb, build


def fixture(path):
    positions=np.array([[0,0,0],[1,0,0],[0,1,0],[0,0,0]],dtype='<f4')
    indices=np.array([3,1,2],dtype='<u2')
    payload=positions.tobytes()+indices.tobytes()+b'\0\0'
    doc={'asset':{'version':'2.0'},'buffers':[{'byteLength':len(payload)}],
         'bufferViews':[{'buffer':0,'byteLength':48},{'buffer':0,'byteOffset':48,'byteLength':6}],
         'accessors':[{'bufferView':0,'componentType':5126,'count':4,'type':'VEC3'},{'bufferView':1,'componentType':5123,'count':3,'type':'SCALAR'}],
         'meshes':[{'primitives':[{'attributes':{'POSITION':0},'indices':1}]}],
         'nodes':[{'translation':[2,3,4],'children':[1]},{'mesh':0}],
         'scenes':[{'nodes':[0]}]}
    js=json.dumps(doc).encode();js+=b' '*(-len(js)%4)
    chunks=struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(payload),b'BIN\0')+payload
    path.write_bytes(struct.pack('<4sII',b'glTF',2,12+len(chunks))+chunks)


class BuildCollisionTest(unittest.TestCase):
    def test_scene_transform_and_exact_weld(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'a.glb';fixture(p)
            v,t=read_glb(p)
            self.assertEqual(len(v),3)
            np.testing.assert_allclose(v[t[0]],[[4,2,3],[4,3,3],[4,2,4]])
    def test_deterministic_binary_and_header(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'a.glb';fixture(p);v,t=read_glb(p)
            a=Path(td)/'a.fpc';b=Path(td)/'b.fpc';report=build(v,t,a);build(v,t,b)
            self.assertEqual(a.read_bytes(),b.read_bytes())
            self.assertEqual(struct.unpack_from('<4sIII',a.read_bytes()),(b'FPC1',3,1,1))
            self.assertEqual(report['triangles'],1)
    def test_invalid_glb(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'a.glb';p.write_bytes(b'bad')
            with self.assertRaises(ValueError):read_glb(p)

if __name__=='__main__':unittest.main()
