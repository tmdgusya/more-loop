#!/usr/bin/env python3
"""Simple HTTP server for more-loop web dashboard. Uses only stdlib."""

import json
import os
import signal
import socket
import sys
import tempfile
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

RUN_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 0
SIGNAL_APPROVE = RUN_DIR / ".signal-approve"
SIGNAL_STOP = RUN_DIR / ".signal-stop"
SIGNAL_REQUEST_CHANGES = RUN_DIR / ".signal-request-changes"
REVIEWS_FILE = RUN_DIR / "reviews.json"
DATA_DIR = Path.home() / ".local" / "share" / "more-loop"


def atomic_write(path, content):
    """Write content to path atomically via temp file + rename.

    Prevents readers from seeing partial/truncated content during writes.
    os.rename() is atomic on the same filesystem (POSIX guarantee).
    """
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    closed = False
    try:
        os.write(fd, content.encode() if isinstance(content, str) else content)
        os.close(fd)
        closed = True
        os.rename(tmp, str(path))
    except BaseException:
        if not closed:
            os.close(fd)
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


class DashboardHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def read_json_body(self):
        """Read and parse JSON from request body. Returns (data, error_msg)."""
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length == 0:
            return None, "Empty request body"
        try:
            body = self.rfile.read(content_length)
            return json.loads(body), None
        except (json.JSONDecodeError, ValueError):
            return None, "Invalid JSON"

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
        elif self.path == "/reviews":
            if REVIEWS_FILE.exists():
                try:
                    data = json.loads(REVIEWS_FILE.read_text())
                    self.send_json(data)
                except (json.JSONDecodeError, IOError):
                    self.send_json({"reviews": []})
            else:
                self.send_json({"reviews": []})
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
        elif self.path == "/reviews":
            data, err = self.read_json_body()
            if err:
                self.send_json({"error": err}, 400)
                return
            if not isinstance(data, dict) or "reviews" not in data:
                self.send_json({"error": "Missing 'reviews' field"}, 400)
                return
            try:
                atomic_write(REVIEWS_FILE, json.dumps(data, indent=2))
                self.send_json({"status": "saved"})
            except IOError as e:
                self.send_json({"error": str(e)}, 500)
        elif self.path == "/request-changes":
            data, err = self.read_json_body()
            if err:
                self.send_json({"error": err}, 400)
                return
            if not isinstance(data, dict) or "reviews" not in data:
                self.send_json({"error": "Missing 'reviews' field"}, 400)
                return
            try:
                atomic_write(REVIEWS_FILE, json.dumps(data, indent=2))
                SIGNAL_REQUEST_CHANGES.touch()
                self.send_json({"status": "requested"})
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
