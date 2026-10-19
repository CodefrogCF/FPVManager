"""Serve the local renderer and its visible smoke harness on loopback only."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT / 'web'), **kwargs)

    def do_GET(self):
        if urlsplit(self.path).path == '/smoke':
            body = (ROOT / 'test' / 'web' / 'globe_smoke.html').read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            super().do_GET()


if __name__ == '__main__':
    print('Open http://127.0.0.1:8765/smoke', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 8765), Handler).serve_forever()
