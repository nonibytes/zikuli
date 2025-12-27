#!/usr/bin/env python3
"""
Simple HTTP server that tracks events from the test page.
The test page will POST events here, and we can query them.
"""

import json
import threading
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import os

# Global event storage
events = []
events_lock = threading.Lock()

class TestHandler(SimpleHTTPRequestHandler):
    def do_POST(self):
        """Handle event POST from test page"""
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8')

        try:
            event = json.loads(body)
            with events_lock:
                events.append(event)
            print(f"EVENT: {event}")

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'{"status": "ok"}')
        except Exception as e:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def do_GET(self):
        """Handle GET requests - serve files or return events"""
        parsed = urlparse(self.path)

        if parsed.path == '/events':
            # Return all events as JSON
            with events_lock:
                response = json.dumps(events)

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(response.encode())

        elif parsed.path == '/clear':
            # Clear events
            with events_lock:
                events.clear()

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'{"status": "cleared"}')

        elif parsed.path == '/stats':
            # Return event counts
            with events_lock:
                stats = {
                    'total': len(events),
                    'clicks': len([e for e in events if e.get('type') == 'click']),
                    'double_clicks': len([e for e in events if e.get('type') == 'dblclick']),
                    'drags': len([e for e in events if e.get('type') == 'drag']),
                    'drops': len([e for e in events if e.get('type') == 'drop']),
                    'scrolls': len([e for e in events if e.get('type') == 'scroll']),
                }

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(stats).encode())

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

def run_server(port=8765):
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    server = HTTPServer(('', port), TestHandler)
    print(f"Test server running on http://localhost:{port}")
    print(f"  /events - get all events")
    print(f"  /clear  - clear events")
    print(f"  /stats  - get event counts")
    server.serve_forever()

if __name__ == '__main__':
    run_server()
