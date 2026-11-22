import unittest
from serve_workbench import upstream_url, UPSTREAM, PREFIX

class RelayTests(unittest.TestCase):
    def test_root(self):
        self.assertEqual(upstream_url(PREFIX+"lod2_4326_null.json"), UPSTREAM+"lod2_4326_null.json")

    def test_relative_content_and_query(self):
        path="lod2_4326_null_data/sub/t_1.json?v=2"
        self.assertEqual(upstream_url(PREFIX+path), UPSTREAM+path)

    def test_reject_unrelated(self):
        for p in ["lod2_4326_dgm5.json","https://example.org/x","lod2_4326_null_data/../x",
                  "lod2_4326_null_data/%2e%2e/x","lod2_4326_null_data/a%5cb",
                  "lod2_4326_null_data//x"]:
            with self.subTest(p=p):
                with self.assertRaises(ValueError):
                    upstream_url(PREFIX+p)

if __name__=="__main__":
    unittest.main()
