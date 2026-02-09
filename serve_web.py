#!/usr/bin/env python3
"""Threaded HTTP server for Flutter web app with gzip compression."""
import http.server
import socketserver
import sys
import os
import gzip
import io
import threading

WEBDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')

COMPRESS_TYPES = {
    'application/javascript', 'application/wasm', 'application/json',
    'text/html', 'text/css', 'text/plain',
}

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEBDIR, **kwargs)

    def guess_type(self, path):
        if path.endswith('.wasm'):
            return 'application/wasm'
        if path.endswith('.js'):
            return 'application/javascript'
        if path.endswith('.json'):
            return 'application/json'
        return super().guess_type(path)

    def do_GET(self):
        accept_enc = self.headers.get('Accept-Encoding', '')
        if 'gzip' not in accept_enc:
            return super().do_GET()

        path = self.translate_path(self.path)
        if os.path.isdir(path):
            path = os.path.join(path, 'index.html')

        if not os.path.isfile(path):
            return super().do_GET()

        ctype = self.guess_type(path)
        if ctype not in COMPRESS_TYPES:
            return super().do_GET()

        try:
            with open(path, 'rb') as f:
                content = f.read()

            buf = io.BytesIO()
            with gzip.GzipFile(fileobj=buf, mode='wb', compresslevel=6) as gz:
                gz.write(content)
            compressed = buf.getvalue()

            self.send_response(200)
            self.send_header('Content-Type', ctype)
            self.send_header('Content-Encoding', 'gzip')
            self.send_header('Content-Length', str(len(compressed)))
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(compressed)
        except Exception as e:
            print(f'Error serving {self.path}: {e}', flush=True)
            super().do_GET()

    def log_message(self, format, *args):
        print("%s - %s" % (self.address_string(), format % args), flush=True)

class ThreadedServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
server = ThreadedServer(('0.0.0.0', port), Handler)
print(f'Serving Zing (threaded+gzip) at http://0.0.0.0:{port}', flush=True)
server.serve_forever()
