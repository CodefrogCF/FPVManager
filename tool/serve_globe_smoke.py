"""Serve the local renderer and its visible smoke harness on loopback only."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
import argparse
import json
import struct
import threading
import time

ROOT = Path(__file__).resolve().parent.parent
WEB_ROOT = ROOT / 'web'
FIXTURE_APP = False
MODE = 'healthy'
LOCK = threading.Lock()
MODES = {'healthy', 'metadata-fail', 'metadata-fail-once', 'tile-404', 'tile-500', 'tile-stall'}
# Cesium heightmap-1.0: 65x65 little-endian encoded heights, child mask, water mask.
# 10000 / 5 - 1000 = 1000m. This is synthetic geometry, not swisstopo data.
HEIGHTS = struct.pack('<4225H', *([10000] * 4225))


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)

    def log_message(self, *_args):
        pass

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def reply(self, body, content_type='application/json', status=200):
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass  # A deliberately timed-out request can have been cancelled.

    def do_POST(self):
        global MODE
        # Only a same-origin fixture page can change this process-local test mode.
        if (urlsplit(self.path).path != '/terrain-control' or
                self.headers.get('Origin') != f'http://127.0.0.1:{self.server.server_port}'):
            self.reply(b'{}', status=403)
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 256:
                raise ValueError()
            mode = json.loads(self.rfile.read(length))['mode']
            if mode not in MODES:
                raise ValueError()
        except (ValueError, KeyError, TypeError):
            self.reply(b'{}', status=400)
            return
        with LOCK:
            MODE = mode
        self.reply(json.dumps({'mode': mode}).encode())

    def do_GET(self):
        global MODE
        path = urlsplit(self.path).path
        with LOCK:
            mode = MODE
        if path in {'/smoke', '/terrain-smoke'}:
            name = 'globe_smoke.html' if path == '/smoke' else 'terrain_smoke.html'
            self.reply((ROOT / 'test/web' / name).read_bytes(), 'text/html; charset=utf-8')
        elif path == '/interaction-smoke':
            self.reply((ROOT / 'test/web/interaction_smoke.html').read_bytes(), 'text/html; charset=utf-8')
        elif path == '/flight-smoke':
            self.reply((ROOT / 'test/web/flight_smoke.html').read_bytes(), 'text/html; charset=utf-8')
        elif path == '/signal-smoke':
            self.reply((ROOT / 'test/web/signal_smoke.html').read_bytes(), 'text/html; charset=utf-8')
        elif path == '/obstacle-smoke':
            self.reply((ROOT / 'test/web/obstacle_smoke.html').read_bytes(), 'text/html; charset=utf-8')
        elif path == '/terrain-fixture.js':
            self.reply((ROOT / 'test/web/terrain_fixture.js').read_bytes(), 'application/javascript')
        elif path == '/terrain-globe.html' or (FIXTURE_APP and path == '/globe.html'):
            body = (WEB_ROOT / 'globe.html').read_bytes().replace(
                b'<script src="globe.js"></script>',
                b'<script src="/terrain-fixture.js"></script><script src="globe.js"></script>')
            self.reply(body, 'text/html; charset=utf-8')
        elif path == '/terrain-data/layer.json':
            if mode in {'metadata-fail', 'metadata-fail-once'}:
                if mode == 'metadata-fail-once':
                    with LOCK:
                        MODE = 'healthy'
                self.reply(b'{}', status=503)
            else:
                self.reply(json.dumps({'tilejson': '2.1.0', 'format': 'heightmap-1.0',
                    'version': '1.0.0', 'scheme': 'tms', 'projection': 'EPSG:4326',
                    'tiles': ['{z}/{x}/{y}.terrain'], 'maxzoom': 8,
                    'available': [[{'startX': 0, 'startY': 0, 'endX': (2 << z) - 1,
                        'endY': (1 << z) - 1}] for z in range(9)]}).encode())
        elif path.startswith('/terrain-data/') and path.endswith('.terrain'):
            try:
                z, x, y = map(int, path.removeprefix('/terrain-data/').removesuffix('.terrain').split('/'))
                if not (0 <= z <= 8 and 0 <= x < (2 << z) and 0 <= y < (1 << z)):
                    raise ValueError()
            except ValueError:
                self.reply(b'', status=404)
                return
            if mode == 'tile-stall':
                time.sleep(15)  # Intentional local fault, beyond the app's deadline.
            if mode in {'tile-404', 'tile-500'} and z > 0:
                self.reply(b'', status=404 if mode == 'tile-404' else 500)
            else:
                self.reply(HEIGHTS + bytes([15 if z < 8 else 0, 0]), 'application/octet-stream')
        else:
            super().do_GET()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument('--build', action='store_true', help='Serve build/web instead of web')
    parser.add_argument('--terrain-fixture', action='store_true', help='Use synthetic terrain in the app preview')
    parser.add_argument('--fault', choices=sorted(MODES), default='healthy', help='Initial synthetic terrain service condition')
    args = parser.parse_args()
    if args.build:
        WEB_ROOT = ROOT / 'build/web'
    FIXTURE_APP = args.terrain_fixture
    MODE = args.fault
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'Open http://127.0.0.1:{server.server_port}/smoke (terrain faults: /terrain-smoke)', flush=True)
    server.serve_forever()
