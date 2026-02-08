#!/usr/bin/env python3
"""Simple HTTP server for more-loop web dashboard. Uses only stdlib."""

import json
import signal
import socket
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

RUN_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 0
SIGNAL_APPROVE = RUN_DIR / ".signal-approve"
SIGNAL_STOP = RUN_DIR / ".signal-stop"
DATA_DIR = Path.home() / ".local" / "share" / "more-loop"

class DashboardHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_GET(self):
        if self.path == "/":
            dashboard = DATA_DIR / "dashboard.html"
            if dashboard.exists():
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(dashboard.read_bytes())
            else:
                self.send_error(404, "dashboard.html not found")
        elif self.path == "/state.json":
            state_file = RUN_DIR / "state.json"
            if state_file.exists():
                try:
                    data = json.loads(state_file.read_text())
                    self.send_json(data)
                except (json.JSONDecodeError, IOError):
                    self.send_json({"error": "Failed to read state"}, 500)
            else:
                self.send_json({
                    "run_name": RUN_DIR.name,
                    "phase": "initializing",
                    "tasks_total": 0,
                    "tasks_completed": 0,
                    "iterations": []
                })
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path == "/approve":
            try:
                SIGNAL_APPROVE.touch()
                self.send_json({"status": "approved"})
            except IOError as e:
                self.send_json({"error": str(e)}, 500)
        elif self.path == "/stop":
            try:
                SIGNAL_STOP.touch()
                self.send_json({"status": "stopped"})
            except IOError as e:
                self.send_json({"error": str(e)}, 500)
        else:
            self.send_error(404)

def find_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        return s.getsockname()[1]

def main():
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    port = PORT if PORT > 0 else find_free_port()

    def signal_handler(*_):
        sys.exit(0)

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    server = HTTPServer(("", port), DashboardHandler)
    print(f"http://127.0.0.1:{port}", file=sys.stderr)
    sys.stderr.flush()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

if __name__ == "__main__":
    main()
