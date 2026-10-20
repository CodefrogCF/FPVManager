import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError


SCRIPT = Path(__file__).resolve().parents[2] / "tool/prepare_sqlite_android.py"
SPEC = importlib.util.spec_from_file_location("prepare_sqlite_android", SCRIPT)
prepare = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(prepare)


def response(body):
    result = io.BytesIO(body)
    result.status = 200
    return result


class SQLiteAssetPreparationTest(unittest.TestCase):
    def test_reads_release_and_all_abis_from_resolved_package_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            config = root / '.dart_tool/package_config.json'
            config.parent.mkdir()
            package = root / 'resolved package'
            manifest = package / 'lib/src/hook/asset_hashes.dart'
            manifest.parent.mkdir(parents=True)
            manifest.write_text("const String? releaseTag = 'sqlite3-3.5.2';\n" +
                                '\n'.join(f"'libsqlite3.{arch}.android.so': '{index * 64}',"
                                          for arch, index in [('arm', 'a'), ('arm64', 'b'), ('x64', 'c')]),
                                encoding='utf-8')
            config.write_text(json.dumps({'packages': [
                {'name': 'sqlite3', 'rootUri': package.as_uri()}
            ]}), encoding='utf-8')
            tag, assets = prepare.locked_assets(root)
            self.assertEqual(tag, 'sqlite3-3.5.2')
            self.assertEqual(assets['libsqlite3.x64.android.so'], 'c' * 64)
            self.assertEqual(len(assets), 3)
            manifest.write_text("const String? releaseTag = 'sqlite3-3.5.2';", encoding='utf-8')
            with self.assertRaises(KeyError):
                prepare.locked_assets(root)

    def test_retries_bad_content_and_http_errors_then_caches_only_verified_bytes(self):
        good = b"synthetic verified fixture"
        expected = hashlib.sha256(good).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "download-fixture/libsqlite3.so"
            with patch.object(prepare, "urlopen", side_effect=[
                response(b"temporary error page"),
                HTTPError("https://example.test", 503, "unavailable", {}, None),
                response(good),
            ]) as opener, patch.object(prepare.time, "sleep"):
                prepare.prepare_asset("https://example.test/library", target, expected)
                self.assertEqual(opener.call_count, 3)
                urls = [call.args[0].full_url for call in opener.call_args_list]
                self.assertEqual(len(set(urls)), 3)
            self.assertEqual(target.read_bytes(), good)
            self.assertEqual(list(target.parent.iterdir()), [target])
            with patch.object(prepare, "urlopen") as opener:
                prepare.prepare_asset("https://example.test/library", target, expected)
                opener.assert_not_called()

    def test_failed_refresh_preserves_good_cache_and_removes_partial_files(self):
        good = b"existing verified fixture"
        expected = hashlib.sha256(good).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "libsqlite3.so"
            target.write_bytes(good)
            with patch.object(prepare, "urlopen", side_effect=lambda *_args, **_kw:
                              response(b"bad download")), patch.object(prepare.time, "sleep"):
                with self.assertRaises(RuntimeError):
                    prepare.prepare_asset("https://example.test/library", target,
                                          expected, refresh=True)
            self.assertEqual(target.read_bytes(), good)
            self.assertEqual(list(target.parent.iterdir()), [target])

    def test_oversized_response_never_becomes_a_cached_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'libsqlite3.so'
            with patch.object(prepare, 'urlopen', return_value=response(b'four')), \
                    patch.object(prepare, 'MAX_BYTES', 3):
                with self.assertRaises(RuntimeError):
                    prepare.prepare_asset('https://example.test/library', target,
                                          hashlib.sha256(b'four').hexdigest(), attempts=1)
            self.assertEqual(list(target.parent.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
