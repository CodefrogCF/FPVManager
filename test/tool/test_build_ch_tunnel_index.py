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

    def test_covered_passages_and_avalanche_protection_are_not_buried_tunnels(self):
        rows = [
            (101, {'highway': 'service', 'tunnel': 'building_passage'},
             [(8.2, 46.8), (8.2001, 46.8)]),
            (102, {'highway': 'primary', 'tunnel': 'avalanche_protector'},
             [(8.3, 46.8), (8.3001, 46.8)]),
            (103, {'highway': 'primary', 'covered': 'yes'},
             [(8.4, 46.8), (8.4001, 46.8)]),
            (104, {'highway': 'primary', 'tunnel': 'yes'},
             [(8.5, 46.8), (8.5001, 46.8)]),
        ]
        doc, skipped = builder.index_from_ways(rows, '2026-11-07T00:00:00Z')
        self.assertEqual(skipped, 0)
        self.assertEqual([entry[2] for entry in doc['routes']],
                         ['underpass', 'underpass', 'underpass', 'tunnel'])

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

    def test_xml_builder_preserves_connected_curved_road_metadata(self):
        with tempfile.TemporaryDirectory() as td:
            source = Path(td) / 'connected.osm'
            source.write_text('''<osm version="0.6">
                <node id="1" lon="8.2" lat="46.8"/>
                <node id="2" lon="8.2004" lat="46.8"/>
                <node id="3" lon="8.19985" lat="46.8"/>
                <node id="4" lon="8.19965" lat="46.80005"/>
                <node id="5" lon="8.1994" lat="46.8001"/>
                <way id="101"><nd ref="1"/><nd ref="2"/>
                  <tag k="highway" v="primary"/><tag k="tunnel" v="yes"/></way>
                <way id="102"><nd ref="1"/><nd ref="3"/><nd ref="4"/><nd ref="5"/>
                  <tag k="highway" v="primary"/></way>
                </osm>''', encoding='utf8')
            dest = Path(td) / 'tunnel-index.json'
            builder.build(source, is_xml=True, output=dest)
            doc = json.loads(dest.read_text(encoding='utf8'))
            self.assertEqual(len(doc['routes']), 1)
            self.assertEqual(len(doc['routes'][0][6][0]), 5)
            self.assertIsNone(doc['routes'][0][6][1])

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

    def test_shared_node_curved_road_provides_five_actual_approach_points(self):
        tagged = [(20, {'highway': 'primary', 'tunnel': 'yes'},
                   [(8.2, 46.8), (8.2003, 46.8)], [1, 2])]
        connected = [(21, {'highway': 'primary'},
                      [(8.19945, 46.80012), (8.19965, 46.80006),
                       (8.19985, 46.8), (8.2, 46.8)], [4, 5, 6, 1])]
        nearby_but_disconnected = [(22, {'highway': 'primary'},
                      [(8.1999, 46.8), (8.1997, 46.8)], [50, 60])]
        linked = builder.attach_connected_road_approaches(tagged, connected + nearby_but_disconnected)
        document, _ = builder.index_from_ways(linked, '2026-11-07T00:00:00Z')
        self.assertEqual(len(document['routes'][0]), 7)
        samples, other = document['routes'][0][6]
        self.assertEqual(len(samples), 5)
        self.assertIsNone(other)
        self.assertLess(samples[0][0], 8.2)
        self.assertLess(samples[-1][0], samples[0][0])
        self.assertGreater(samples[-1][1], samples[0][1],
                           'road approach follows its curve instead of a straight tunnel extension')
        self.assertTrue(all(builder.valid(*p) for p in samples))

    def test_no_shared_node_or_two_ambiguous_road_branches_does_not_guess_an_approach(self):
        tagged = [(20, {'highway': 'primary', 'tunnel': 'yes'},
                   [(8.2, 46.8), (8.2003, 46.8)], [1, 2])]
        roads = [(21, {'highway': 'primary'},
                 [(8.1995, 46.8), (8.2, 46.8)], [3, 1]),
                 (22, {'highway': 'primary'},
                 [(8.1995, 46.8), (8.2, 46.8)], [4, 1])]
        linked = builder.attach_connected_road_approaches(tagged, roads)
        self.assertEqual(linked[0][3], [None, None], 'ambiguous junction stays unverified')
        document, _ = builder.index_from_ways(linked, '2026-11-07T00:00:00Z')
        self.assertEqual(len(document['routes'][0]), 6)

    def test_tunnel_connected_directly_to_bridge_keeps_deck_source_metadata(self):
        tunnel = [(401, {'highway': 'primary', 'tunnel': 'yes'},
                   [(8.2, 46.8), (8.2002, 46.8)], [10, 11])]
        bridge = [(402, {'highway': 'primary', 'bridge': 'yes', 'layer': '1'},
                   [(8.19945, 46.8), (8.2, 46.8)], [12, 10])]
        enriched = builder.attach_connected_road_approaches(tunnel, bridge)
        self.assertEqual(enriched[0][4], ['bridge', None])
        document, _ = builder.index_from_ways(enriched, '2026-11-07T00:00:00Z')
        record = document['routes'][0]
        self.assertEqual(len(record), 8)
        self.assertEqual(record[7], ['bridge', None])
        self.assertEqual(len(record[6][0]), 5)

    def test_free_bridge_crossing_does_not_generate_3d_tunnel(self):
        with tempfile.TemporaryDirectory() as td:
            source = Path(td) / 'bridge.osm'
            source.write_text("""<osm version="0.6">
                <node id="1" lon="8.1995" lat="46.8"/>
                <node id="2" lon="8.2003" lat="46.8"/>
                <node id="3" lon="8.1999" lat="46.7997"/>
                <node id="4" lon="8.1999" lat="46.8003"/>
                <way id="100"><nd ref="1"/><nd ref="2"/>
                  <tag k="highway" v="secondary"/></way>
                <way id="101"><nd ref="3"/><nd ref="4"/>
                  <tag k="highway" v="primary"/><tag k="bridge" v="yes"/>
                  <tag k="layer" v="1"/></way>
                </osm>""", encoding='utf8')
            self.assertEqual(list(builder.xml_ways(source)), [],
                'A free bridge leaves open space beneath, not a covered tunnel')

    def test_railway_under_free_bridge_is_not_fabricated_as_tunnel(self):
        with tempfile.TemporaryDirectory() as td:
            source = Path(td) / 'railway_bridge.osm'
            source.write_text("""<osm version="0.6">
                <node id="1" lon="8.1995" lat="46.8"/>
                <node id="2" lon="8.2003" lat="46.8"/>
                <node id="3" lon="8.1999" lat="46.7997"/>
                <node id="4" lon="8.1999" lat="46.8003"/>
                <way id="100"><nd ref="1"/><nd ref="2"/>
                  <tag k="railway" v="rail"/></way>
                <way id="101"><nd ref="3"/><nd ref="4"/>
                  <tag k="highway" v="primary"/><tag k="bridge" v="yes"/></way>
                </osm>""", encoding='utf8')
            self.assertEqual(list(builder.xml_ways(source)), [])

    def test_untagged_ways_are_not_guessed(self):
        with self.assertRaises(RuntimeError):
            builder.index_from_ways([(12, {'highway': 'residential'}, [(8, 46), (8.1, 46)])],
                                     '2026-11-06T00:00:00Z')

if __name__ == '__main__':
    unittest.main()
