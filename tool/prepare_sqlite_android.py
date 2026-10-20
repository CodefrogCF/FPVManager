#!/usr/bin/env python3
"""Prefetch hash-verified SQLite Android assets for the locked Dart build hook.

The sqlite3 hook validates hashes but does not retry failed downloads. Keep its
validation intact and prepare its shared cache with bounded download retries.
No package sources, hashes or dependency versions are changed by this tool.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import tempfile
import time
from urllib.parse import urljoin, urlsplit
from urllib.request import Request, url2pathname, urlopen
import uuid


ARCHITECTURES = ("arm", "arm64", "x64")
MAX_BYTES = 16 * 1024 * 1024


def locked_assets(root):
    config_path = root / ".dart_tool/package_config.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    package = next(item for item in config["packages"] if item["name"] == "sqlite3")
    uri = urlsplit(urljoin(config_path.as_uri(), package["rootUri"]))
    if uri.scheme != "file" or uri.netloc not in ("", "localhost"):
        raise ValueError("Expected a local resolved sqlite3 package")
    package_root = Path(url2pathname(uri.path))
    manifest = (package_root / "lib/src/hook/asset_hashes.dart").read_text(
        encoding="utf-8"
    )
    tag = re.search(r"releaseTag\s*=\s*'(sqlite3-[\w.+-]+)'", manifest)
    if tag is None:
        raise ValueError("Unsupported sqlite3 release manifest; review the build hook")
    hashes = dict(re.findall(r"'([^']+)'\s*:\s*'([a-f0-9]{64})'", manifest))
    return tag[1], {
        f"libsqlite3.{arch}.android.so": hashes[f"libsqlite3.{arch}.android.so"]
        for arch in ARCHITECTURES
    }


def file_hash(path):
    if not path.is_file():
        return None
    with path.open("rb") as source:
        digest = hashlib.sha256()
        while chunk := source.read(64 * 1024):
            digest.update(chunk)
        return digest.hexdigest()


def prepare_asset(url, destination, expected, *, refresh=False, attempts=3):
    if not refresh and file_hash(destination) == expected:
        print(f"Verified cached {destination.parent.name}", flush=True)
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(1, attempts + 1):
        temporary = None
        try:
            # A unique URL also avoids reusing an expired cached release redirect.
            request = Request(
                f"{url}?fpvmanager_download={uuid.uuid4().hex}",
                headers={"User-Agent": "FPVManager SQLite asset preparation",
                         "Cache-Control": "no-cache"},
            )
            digest = hashlib.sha256()
            size = 0
            with urlopen(request, timeout=30) as response:
                if response.status != 200:
                    raise ValueError(f"Unexpected HTTP status {response.status}")
                with tempfile.NamedTemporaryFile(
                    dir=destination.parent, prefix="sqlite-download-", delete=False
                ) as target:
                    temporary = Path(target.name)
                    while chunk := response.read(64 * 1024):
                        size += len(chunk)
                        if size > MAX_BYTES:
                            raise ValueError("SQLite response exceeds the size limit")
                        digest.update(chunk)
                        target.write(chunk)
            actual = digest.hexdigest()
            if actual != expected:
                raise ValueError(f"SHA-256 mismatch: received {actual}, expected {expected}")
            temporary.replace(destination)
            print(f"Verified {url.rsplit('/', 1)[-1]} ({size} bytes)", flush=True)
            return
        except (OSError, ValueError) as error:
            print(f"SQLite download attempt {attempt}/{attempts}: {error}",
                  file=sys.stderr, flush=True)
            if attempt == attempts:
                raise RuntimeError("No verified SQLite binary received; build stopped") from error
            time.sleep(attempt)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh", action="store_true", help="Recheck fresh downloads")
    options = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    tag, assets = locked_assets(root)
    cache = root / ".dart_tool/hooks_runner/shared/sqlite3/build"
    print(f"Preparing locked {tag} for all Android ABIs", flush=True)
    for filename, expected in assets.items():
        prepare_asset(
            f"https://github.com/simolus3/sqlite3.dart/releases/download/{tag}/{filename}",
            cache / f"download-{expected[:8]}" / "libsqlite3.so",
            expected,
            refresh=options.refresh,
        )


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, StopIteration, RuntimeError) as error:
        sys.exit(str(error))
