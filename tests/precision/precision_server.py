#!/usr/bin/env python3
"""
Precision Click Test Server

Serves the test page and verifies click accuracy.
"""

import json
import threading
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse
import os
import sys

# Global state
clicks = []
targets = []
clicks_lock = threading.Lock()

# Accuracy threshold in pixels
ACCURACY_THRESHOLD = 5

class PrecisionTestHandler(SimpleHTTPRequestHandler):
    def do_POST(self):
        """Handle POST requests for click and target data"""
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8')

        parsed = urlparse(self.path)

        try:
            data = json.loads(body)

            if parsed.path == '/click':
                with clicks_lock:
                    clicks.append(data)

                # Print click result
                if data.get('success'):
                    print(f"✓ CLICK {data['target']}: ({data['clickX']}, {data['clickY']}) "
                          f"Δ={data['distance']}px - PASS")
                else:
                    print(f"✗ CLICK {data['target']}: ({data['clickX']}, {data['clickY']}) "
                          f"expected ({data['expectedX']}, {data['expectedY']}) "
                          f"Δ={data['distance']}px - FAIL")

                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(b'{"status": "ok"}')

            elif parsed.path == '/targets':
                global targets
                targets = data
                print(f"Registered {len(data)} targets:")
                for t in data:
                    print(f"  - {t['id']}: ({t['x']},{t['y']}) {t['w']}x{t['h']} "
                          f"center=({t['centerX']},{t['centerY']})")

                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(b'{"status": "ok"}')

            else:
                self.send_response(404)
                self.end_headers()

        except Exception as e:
            print(f"Error: {e}")
            self.send_response(400)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)

        if parsed.path == '/results':
            with clicks_lock:
                response = {
                    'clicks': clicks,
                    'total': len(clicks),
                    'passed': sum(1 for c in clicks if c.get('success')),
                    'failed': sum(1 for c in clicks if not c.get('success')),
                    'threshold': ACCURACY_THRESHOLD
                }

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(response, indent=2).encode())

        elif parsed.path == '/clear':
            with clicks_lock:
                clicks.clear()

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'{"status": "cleared"}')

        elif parsed.path == '/targets':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(targets).encode())

        else:
            # Serve static files
            super().do_GET()

    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def log_message(self, format, *args):
        """Suppress normal request logging"""
        pass


def run_server(port=8766):
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    server = HTTPServer(('', port), PrecisionTestHandler)
    print(f"""
╔══════════════════════════════════════════════════════════╗
║     Zikuli Precision Click Test Server                   ║
╠══════════════════════════════════════════════════════════╣
║  Server: http://localhost:{port}                          ║
║  Test page: http://localhost:{port}/precision_test.html   ║
║                                                          ║
║  Endpoints:                                              ║
║    GET  /results  - Get click results                    ║
║    GET  /clear    - Clear click history                  ║
║    GET  /targets  - Get registered targets               ║
║    POST /click    - Record a click                       ║
║    POST /targets  - Register targets                     ║
║                                                          ║
║  Accuracy threshold: ±{ACCURACY_THRESHOLD}px                            ║
╚══════════════════════════════════════════════════════════╝
""")
    server.serve_forever()


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8766
    run_server(port)
