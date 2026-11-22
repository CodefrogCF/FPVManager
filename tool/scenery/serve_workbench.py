"""Local test-only bridge for the official BKG flat LoD2 dataset.
No caching, no credentials, no arbitrary upstream URLs.
Run from any directory: python tool/scenery/serve_workbench.py
"""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit, quote, unquote
from urllib.request import Request, build_opener, HTTPRedirectHandler
from urllib.error import HTTPError, URLError
import re
import shutil
import argparse

ROOT = Path(__file__).resolve().parents[2]
PREFIX = "/__bkg_lod2__/"
UPSTREAM = "https://sgx.geodatenzentrum.de/gdz_basemapde_3d_gebaeude/"
ROOT_NAME = "lod2_4326_null.json"
DATA_DIR = "lod2_4326_null_data/"

def upstream_url(raw_path):
    parts = urlsplit(raw_path)
    if parts.scheme or parts.netloc or not parts.path.startswith(PREFIX):
        raise ValueError("Invalid relay path")
    relative = unquote(parts.path[len(PREFIX):])
    if relative != ROOT_NAME:
        if not relative.startswith(DATA_DIR):
            raise ValueError("Only the flat LoD2 dataset is permitted")
        segments = relative.split("/")
        if any(not re.fullmatch(r"[A-Za-z0-9_.-]+", x) or x in (".", "..") for x in segments):
            raise ValueError("Invalid tile path")
    # Keep the upstream query intact for tile version parameters.
    return UPSTREAM + quote(relative, safe="/") + ("?" + parts.query if parts.query else "")

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

OPENER = build_opener(NoRedirect())

def relay_request(url, byte_range=None):
    # Keep the request as close as possible to a direct, working
    # urllib.request.urlopen() call. BKG's gateway can terminate connections
    # that carry a nonstandard relay-specific User-Agent. urllib supplies its
    # normal User-Agent automatically when the header is not overridden.
    headers = {"Accept-Encoding": "identity"}
    if byte_range:
        headers["Range"] = byte_range
    return Request(url, headers=headers)

class WorkbenchHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):
        if urlsplit(self.path).path.startswith(PREFIX):
            self.relay()
        else:
            super().do_GET()

    def relay(self):
        try:
            url = upstream_url(self.path)
        except ValueError as exc:
            self.send_error(400, str(exc))
            return
        try:
            response = OPENER.open(relay_request(url, self.headers.get("Range")), timeout=45)
        except HTTPError as exc:
            self.log_error("BKG upstream HTTP %s: %s", exc.code, url)
            # Do not follow redirects, bypass denial or retry rate limits.
            self.send_error(exc.code if 400 <= exc.code <= 599 else 502, "BKG upstream HTTP " + str(exc.code))
            exc.close()
            return
        except (URLError, TimeoutError, OSError) as exc:
            self.log_error("BKG upstream network error %s: %s (%r; reason=%r)",
                           url, type(exc).__name__, exc, getattr(exc, "reason", None))
            self.send_error(502, "BKG upstream network error; see local console")
            return
        with response:
            try:
                self.log_message("BKG upstream HTTP %s %s", response.status, url)
                self.send_response(response.status)
                for key in ("Content-Type", "Content-Length", "Content-Encoding", "Content-Range", "Accept-Ranges"):
                    value = response.headers.get(key)
                    if value is not None:
                        self.send_header(key, value)
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                shutil.copyfileobj(response, self.wfile, length=65536)
            except (BrokenPipeError, ConnectionResetError):
                pass
            except OSError as exc:
                self.log_error("BKG stream interrupted: %s", exc)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    with ThreadingHTTPServer(("127.0.0.1", args.port), WorkbenchHandler) as server:
        print(f"http://127.0.0.1:{args.port}/tool/scenery/cesium_georeference_workbench.html?lod2=relay", flush=True)
        server.serve_forever()

if __name__ == "__main__":
    main()
