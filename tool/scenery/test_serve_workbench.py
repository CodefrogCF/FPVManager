import unittest
from serve_workbench import upstream_url, relay_request, UPSTREAM, PREFIX

class RelayTests(unittest.TestCase):
    def test_root(self):
        self.assertEqual(upstream_url(PREFIX+"lod2_4326_null.json"), UPSTREAM+"lod2_4326_null.json")

    def test_relative_content_and_query(self):
        path="lod2_4326_null_data/sub/t_1.json?v=2"
        self.assertEqual(upstream_url(PREFIX+path), UPSTREAM+path)

    def test_upstream_request_uses_standard_urllib_user_agent(self):
        request = relay_request(UPSTREAM + "lod2_4326_null.json")
        self.assertIsNone(request.get_header("User-agent"))
        self.assertEqual(request.get_header("Accept-encoding"), "identity")
        self.assertIsNone(request.get_header("Range"))
        ranged = relay_request(UPSTREAM + "lod2_4326_null_data/tile.b3dm", "bytes=0-1023")
        self.assertEqual(ranged.get_header("Range"), "bytes=0-1023")

    def test_reject_unrelated(self):
        for p in ["lod2_4326_dgm5.json","https://example.org/x","lod2_4326_null_data/../x",
                  "lod2_4326_null_data/%2e%2e/x","lod2_4326_null_data/a%5cb",
                  "lod2_4326_null_data//x"]:
            with self.subTest(p=p):
                with self.assertRaises(ValueError):
                    upstream_url(PREFIX+p)

if __name__=="__main__":
    unittest.main()
