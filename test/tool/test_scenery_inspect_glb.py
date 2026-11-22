import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[2] / 'tool/scenery/inspect_glb.py'
spec = importlib.util.spec_from_file_location('inspect_glb', MODULE)
inspector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inspector)


def glb(document, binary=b''):
    manifest = json.dumps(document).encode('utf-8')
    manifest += b' ' * (-len(manifest) % 4)
    chunks = struct.pack('<I4s', len(manifest), b'JSON') + manifest
    if binary:
        binary += b'\0' * (-len(binary) % 4)
        chunks += struct.pack('<I4s', len(binary), b'BIN\0') + binary
    return struct.pack('<4sII', b'glTF', 2, 12 + len(chunks)) + chunks


class GLBInspectorTest(unittest.TestCase):
    def inspect(self, contents):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / 'synthetic.glb'
            file.write_bytes(contents)
            return inspector.summarize(file)

    def test_count_indexed_triangles_and_local_bounds(self):
        report = self.inspect(glb({'asset': {'version': '2.0'}, 'meshes': [{
            'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1}]}],
            'accessors': [
                {'count': 4, 'min': [0, 0, 0], 'max': [2, 3, 4]},
                {'count': 6}], 'materials': [{}, {}], 'images': [{'bufferView': 0}],
            'textures': [{}], 'extensionsUsed': ['KHR_draco_mesh_compression']}, b'1234'))
        self.assertEqual(report['approximate_triangles'], 2)
        self.assertEqual(report['primitive_vertices_sum'], 4)
        self.assertEqual(report['materials'], 2)
        self.assertTrue(report['has_khr_draco'])
        self.assertEqual(report['accessor_local_bounds'][0]['max'], [2, 3, 4])
        self.assertEqual(report['binary_chunk_bytes'], 4)

    def test_reject_invalid_lengths(self):
        with self.assertRaises(inspector.InvalidGLB):
            self.inspect(glb({'asset': {'version': '2.0'}})[:-1])
        with self.assertRaises(inspector.InvalidGLB):
            self.inspect(b'not a model')

    def test_triangle_strip_and_unindexed_triangles(self):
        report=self.inspect(glb({'asset': {'version': '2.0'},
            'meshes': [{'primitives': [
                {'attributes': {'POSITION': 0}, 'mode': 5},
                {'attributes': {'POSITION': 1}}]}],
            'accessors': [{'count': 6}, {'count': 9}]}))
        self.assertEqual(report['approximate_triangles'], 7)


if __name__ == '__main__':
    unittest.main()
