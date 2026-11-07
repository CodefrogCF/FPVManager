import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

FILE = Path(__file__).resolve().parents[2] / 'tool' / 'build_ch_tunnel_index.py'
spec = importlib.util.spec_from_file_location('build_ch_tunnel_index', FILE)
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class TunnelIndexBuildTest(unittest.TestCase):
    def test_tagged_tunnels_preserve_osm_way_coordinates_and_distinguish_bridges(self):
        rows = [
            (11, {'highway': 'primary', 'tunnel': 'yes', 'name': 'Alpine Tunnel'},
             [(8.1, 46.55), (8.2, 46.6), (8.3, 46.7)]),
            (12, {'highway': 'primary', 'bridge': 'yes'},
             [(8.1, 46.55), (8.3, 46.7)]),
            (13, {'railway': 'rail', 'covered': 'yes'},
             [(8.5, 46.7), (8.5001, 46.7)])
        ]
        document, skipped = builder.index_from_ways(rows, '2026-11-06T00:00:00Z')
        self.assertEqual(skipped, 0)
        self.assertEqual(len(document['routes']), 2)
        self.assertEqual(document['routes'][0],
            [11, 0, 'tunnel', 'road', 'Alpine Tunnel',
             [[8.1, 46.55], [8.2, 46.6], [8.3, 46.7]]])
        self.assertEqual(document['routes'][1][2:4], ['underpass', 'railway'])
        self.assertTrue(document['tiles'])
        self.assertEqual(document['license'], 'ODbL-1.0')

    def test_long_way_is_split_without_losing_edges(self):
        points = [(8.2 + i / 100000, 46.6) for i in range(1030)]
        document, _ = builder.index_from_ways([(21, {'highway': 'service', 'tunnel': 'yes'}, points)],
                                                '2026-11-06T00:00:00Z')
        chunks = [route[5] for route in document['routes']]
        self.assertEqual(len(chunks), 3)
        self.assertTrue(all(len(part) <= 512 for part in chunks))
        self.assertEqual(chunks[0][-1], chunks[1][0])
        self.assertEqual(chunks[1][-1], chunks[2][0])
        self.assertEqual(sum(len(part) for part in chunks) - (len(chunks) - 1), len(points))

    def test_xml_fixture_runs_without_pbf_dependency_or_network(self):
        with tempfile.TemporaryDirectory() as td:
            source = Path(td) / 'ways.osm'
            source.write_text('''<osm version="0.6">
                <node id="1" lon="8.1" lat="46.6"/><node id="2" lon="8.11" lat="46.61"/>
                <way id="123"><nd ref="1"/><nd ref="2"/>
                  <tag k="highway" v="secondary"/><tag k="tunnel" v="yes"/></way>
                </osm>''', encoding='utf8')
            destination = Path(td) / 'data.json'
            builder.build(source, is_xml=True, output=destination)
            doc = json.loads(destination.read_text(encoding='utf8'))
            self.assertEqual(doc['routes'][0][0], 123)
            self.assertTrue(doc['generated'])

    def test_windows_without_mmap_uses_supported_disk_index(self):
        with tempfile.TemporaryDirectory() as td:
            index = builder.choose_location_index(['flex_mem', 'sparse_file_array'], td)
            self.assertTrue(index.startswith('sparse_file_array,'))
            self.assertTrue(index.endswith('locations.idx'))
            self.assertNotIn('mmap', index)

    def test_windows_without_disk_store_falls_back_to_flex_mem(self):
        with tempfile.TemporaryDirectory() as td:
            self.assertEqual(builder.choose_location_index(['flex_mem'], td), 'flex_mem')
            with self.assertRaisesRegex(RuntimeError, 'not compiled'):
                builder.choose_location_index(['flex_mem'], td, 'sparse_file_array')

    def test_untagged_ways_are_not_guessed(self):
        with self.assertRaises(RuntimeError):
            builder.index_from_ways([(12, {'highway': 'residential'}, [(8, 46), (8.1, 46)])],
                                     '2026-11-06T00:00:00Z')

if __name__ == '__main__':
    unittest.main()
