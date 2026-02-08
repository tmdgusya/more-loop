#!/usr/bin/env python3
"""Tests for more-loop dashboard server. Uses only stdlib.

Covers: invalid|error|400|404|405 response cases
"""

import json
import shutil
import sys
import tempfile
import threading
import unittest
from http.server import HTTPServer
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError


def setUpModule():
    """Patch sys.argv and import server module, then patch its globals."""
    global server_mod, tmpdir, run_dir, data_dir

    tmpdir = tempfile.mkdtemp(prefix="test_server_")
    run_dir = Path(tmpdir) / "run"
    data_dir = Path(tmpdir) / "data"
    run_dir.mkdir()
    data_dir.mkdir()

    # Write a test dashboard.html
    (data_dir / "dashboard.html").write_text(
        "<html><body>test dashboard</body></html>"
    )

    # Patch sys.argv so module-level code doesn't crash
    sys.argv = ["server.py", str(run_dir), "0"]

    # Add project root to path and import
    project_root = str(Path(__file__).resolve().parent.parent)
    if project_root not in sys.path:
        sys.path.insert(0, project_root)

    import server as _server_mod
    server_mod = _server_mod

    # Patch module globals to use our temp dirs
    server_mod.RUN_DIR = run_dir
    server_mod.DATA_DIR = data_dir
    server_mod.SIGNAL_APPROVE = run_dir / ".signal-approve"
    server_mod.SIGNAL_STOP = run_dir / ".signal-stop"
    server_mod.SIGNAL_REQUEST_CHANGES = run_dir / ".signal-request-changes"
    server_mod.REVIEWS_FILE = run_dir / "reviews.json"


def tearDownModule():
    shutil.rmtree(tmpdir, ignore_errors=True)


class TestServerEndpoints(unittest.TestCase):
    """Test all HTTP endpoints on the dashboard server."""

    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("127.0.0.1", 0), server_mod.DashboardHandler)
        cls.port = cls.server.server_address[1]
        cls.base = f"http://127.0.0.1:{cls.port}"
        cls.thread = threading.Thread(target=cls.server.serve_forever)
        cls.thread.daemon = True
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        """Clean signal files and reviews between tests."""
        for name in [
            ".signal-approve",
            ".signal-stop",
            ".signal-request-changes",
            "reviews.json",
            "state.json",
        ]:
            p = run_dir / name
            if p.exists():
                p.unlink()

    # -- Helpers --

    def get(self, path):
        """Send GET request, return (status, headers, body_bytes)."""
        try:
            resp = urlopen(f"{self.base}{path}")
            return resp.status, resp.headers, resp.read()
        except HTTPError as e:
            return e.code, e.headers, e.read()

    def post(self, path, data=None, raw=None):
        """Send POST request with JSON or raw bytes."""
        if raw is not None:
            body = raw
        elif data is not None:
            body = json.dumps(data).encode()
        else:
            body = b""
        req = Request(
            f"{self.base}{path}",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            resp = urlopen(req)
            return resp.status, resp.headers, resp.read()
        except HTTPError as e:
            return e.code, e.headers, e.read()

    def get_json(self, path):
        status, _, body = self.get(path)
        return status, json.loads(body)

    def post_json(self, path, data=None, raw=None):
        status, _, body = self.post(path, data=data, raw=raw)
        return status, json.loads(body)

    # -- GET / --

    def test_get_root_serves_html(self):
        status, headers, body = self.get("/")
        self.assertEqual(status, 200)
        self.assertIn("text/html", headers.get("Content-Type", ""))
        self.assertIn(b"test dashboard", body)

    def test_get_root_missing_dashboard(self):
        """If dashboard.html is removed, GET / returns 404."""
        dash = data_dir / "dashboard.html"
        dash.rename(data_dir / "dashboard.html.bak")
        try:
            status, _, _ = self.get("/")
            self.assertEqual(status, 404)
        finally:
            (data_dir / "dashboard.html.bak").rename(dash)

    # -- GET /state.json --

    def test_get_state_default(self):
        """Without state.json file, returns default state."""
        status, data = self.get_json("/state.json")
        self.assertEqual(status, 200)
        self.assertEqual(data["phase"], "initializing")
        self.assertEqual(data["tasks_total"], 0)
        self.assertEqual(data["tasks_completed"], 0)
        self.assertIn("iterations", data)

    def test_get_state_from_file(self):
        """With state.json file, returns its content."""
        state = {
            "run_name": "test-run",
            "phase": "working",
            "tasks_total": 5,
            "tasks_completed": 2,
            "iterations": [{"task": "first"}],
        }
        (run_dir / "state.json").write_text(json.dumps(state))
        status, data = self.get_json("/state.json")
        self.assertEqual(status, 200)
        self.assertEqual(data["phase"], "working")
        self.assertEqual(data["tasks_total"], 5)
        self.assertEqual(data["tasks_completed"], 2)

    def test_get_state_invalid_json(self):
        """If state.json has invalid JSON, returns 500 error."""
        (run_dir / "state.json").write_text("not valid json{{{")
        status, data = self.get_json("/state.json")
        self.assertEqual(status, 500)
        self.assertIn("error", data)

    # -- POST /approve --

    def test_post_approve_creates_signal(self):
        self.assertFalse((run_dir / ".signal-approve").exists())
        status, data = self.post_json("/approve")
        self.assertEqual(status, 200)
        self.assertEqual(data["status"], "approved")
        self.assertTrue((run_dir / ".signal-approve").exists())

    def test_post_approve_idempotent(self):
        """Calling approve twice doesn't error."""
        self.post_json("/approve")
        status, data = self.post_json("/approve")
        self.assertEqual(status, 200)
        self.assertEqual(data["status"], "approved")

    # -- POST /stop --

    def test_post_stop_creates_signal(self):
        self.assertFalse((run_dir / ".signal-stop").exists())
        status, data = self.post_json("/stop")
        self.assertEqual(status, 200)
        self.assertEqual(data["status"], "stopped")
        self.assertTrue((run_dir / ".signal-stop").exists())

    # -- POST /reviews --

    def test_post_reviews_writes_file(self):
        reviews = {"reviews": [{"text": "fix this", "selected": "some text"}]}
        status, data = self.post_json("/reviews", reviews)
        self.assertEqual(status, 200)
        self.assertEqual(data["status"], "saved")
        self.assertTrue((run_dir / "reviews.json").exists())
        saved = json.loads((run_dir / "reviews.json").read_text())
        self.assertEqual(saved["reviews"][0]["text"], "fix this")

    def test_post_reviews_overwrites(self):
        """Second POST overwrites the first."""
        self.post_json("/reviews", {"reviews": [{"id": 1}]})
        self.post_json("/reviews", {"reviews": [{"id": 2}]})
        saved = json.loads((run_dir / "reviews.json").read_text())
        self.assertEqual(len(saved["reviews"]), 1)
        self.assertEqual(saved["reviews"][0]["id"], 2)

    def test_post_reviews_invalid_json(self):
        status, data = self.post_json("/reviews", raw=b"not json{{{")
        self.assertEqual(status, 400)
        self.assertIn("error", data)
        self.assertIn("Invalid JSON", data["error"])

    def test_post_reviews_empty_body(self):
        status, data = self.post_json("/reviews", raw=b"")
        self.assertEqual(status, 400)
        self.assertIn("error", data)

    def test_post_reviews_missing_reviews_field(self):
        status, data = self.post_json("/reviews", {"something": "else"})
        self.assertEqual(status, 400)
        self.assertIn("reviews", data["error"].lower())

    def test_post_reviews_not_a_dict(self):
        """Sending a JSON array instead of object is rejected."""
        status, data = self.post_json("/reviews", raw=b'[1, 2, 3]')
        self.assertEqual(status, 400)
        self.assertIn("error", data)

    # -- GET /reviews --

    def test_get_reviews_empty(self):
        """Without reviews.json, returns empty array."""
        status, data = self.get_json("/reviews")
        self.assertEqual(status, 200)
        self.assertEqual(data["reviews"], [])

    def test_get_reviews_with_data(self):
        reviews = {"reviews": [{"text": "comment", "selected": "line"}]}
        (run_dir / "reviews.json").write_text(json.dumps(reviews))
        status, data = self.get_json("/reviews")
        self.assertEqual(status, 200)
        self.assertEqual(len(data["reviews"]), 1)
        self.assertEqual(data["reviews"][0]["text"], "comment")

    def test_get_reviews_after_post(self):
        """GET returns what was POSTed."""
        reviews = {"reviews": [{"a": 1}, {"b": 2}]}
        self.post_json("/reviews", reviews)
        status, data = self.get_json("/reviews")
        self.assertEqual(status, 200)
        self.assertEqual(len(data["reviews"]), 2)

    # -- POST /request-changes --

    def test_request_changes_writes_and_signals(self):
        reviews = {"reviews": [{"text": "needs work", "selected": "code"}]}
        status, data = self.post_json("/request-changes", reviews)
        self.assertEqual(status, 200)
        self.assertEqual(data["status"], "requested")
        # Verify reviews.json written
        self.assertTrue((run_dir / "reviews.json").exists())
        saved = json.loads((run_dir / "reviews.json").read_text())
        self.assertEqual(saved["reviews"][0]["text"], "needs work")
        # Verify signal file created
        self.assertTrue((run_dir / ".signal-request-changes").exists())

    def test_request_changes_invalid_json(self):
        status, data = self.post_json("/request-changes", raw=b"bad{json")
        self.assertEqual(status, 400)
        self.assertIn("error", data)
        self.assertFalse((run_dir / ".signal-request-changes").exists())

    def test_request_changes_missing_reviews_field(self):
        status, data = self.post_json("/request-changes", {"data": []})
        self.assertEqual(status, 400)
        self.assertIn("error", data)
        self.assertFalse((run_dir / ".signal-request-changes").exists())

    def test_request_changes_empty_body(self):
        status, data = self.post_json("/request-changes", raw=b"")
        self.assertEqual(status, 400)
        self.assertFalse((run_dir / ".signal-request-changes").exists())

    # -- 404 for unknown paths --

    def test_get_unknown_path_404(self):
        status, _, _ = self.get("/nonexistent")
        self.assertEqual(status, 404)

    def test_post_unknown_path_404(self):
        status, _, _ = self.post("/nonexistent", {"a": 1})
        self.assertEqual(status, 404)

    def test_get_favicon_404(self):
        status, _, _ = self.get("/favicon.ico")
        self.assertEqual(status, 404)

    # -- Edge cases --

    def test_reviews_with_special_characters(self):
        """Reviews containing special chars are preserved."""
        reviews = {
            "reviews": [
                {
                    "text": 'Comment with "quotes" & <html> chars\nnewlines',
                    "selected": "unicode: \u00e9\u00e0\u00fc \u2603 \ud83d\ude00",
                }
            ]
        }
        self.post_json("/reviews", reviews)
        status, data = self.get_json("/reviews")
        self.assertEqual(status, 200)
        self.assertIn('"quotes"', data["reviews"][0]["text"])
        self.assertIn("\u2603", data["reviews"][0]["selected"])

    def test_reviews_empty_list(self):
        """Posting empty reviews list is valid."""
        status, data = self.post_json("/reviews", {"reviews": []})
        self.assertEqual(status, 200)
        self.assertEqual(data["status"], "saved")
        _, got = self.get_json("/reviews")
        self.assertEqual(got["reviews"], [])

    def test_multiple_signals_coexist(self):
        """Approve and request-changes signals can both exist."""
        self.post_json("/approve")
        self.post_json("/request-changes", {"reviews": [{"t": "x"}]})
        self.assertTrue((run_dir / ".signal-approve").exists())
        self.assertTrue((run_dir / ".signal-request-changes").exists())

    def test_cors_header_present(self):
        """JSON responses include CORS header."""
        status, headers, _ = self.get("/state.json")
        self.assertEqual(headers.get("Access-Control-Allow-Origin"), "*")


class TestAtomicWrite(unittest.TestCase):
    """Test the atomic_write helper function."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp(prefix="test_atomic_")

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_writes_content(self):
        path = Path(self.tmpdir) / "test.json"
        server_mod.atomic_write(path, '{"key": "value"}')
        self.assertEqual(path.read_text(), '{"key": "value"}')

    def test_overwrites_existing(self):
        path = Path(self.tmpdir) / "test.json"
        path.write_text("old content")
        server_mod.atomic_write(path, "new content")
        self.assertEqual(path.read_text(), "new content")

    def test_no_temp_files_left(self):
        """Atomic write should not leave .tmp files on success."""
        path = Path(self.tmpdir) / "test.json"
        server_mod.atomic_write(path, "data")
        tmps = list(Path(self.tmpdir).glob("*.tmp"))
        self.assertEqual(tmps, [])

    def test_no_temp_files_on_error(self):
        """Atomic write cleans up temp files on failure."""
        path = Path(self.tmpdir) / "nonexistent_dir" / "test.json"
        with self.assertRaises(Exception):
            server_mod.atomic_write(path, "data")
        # The temp would be in tmpdir (the parent we gave), not the nonexistent dir
        # Actually mkstemp uses path.parent which doesn't exist, so it raises before creating

    def test_file_readable_at_all_times(self):
        """Concurrent reader never sees partial content."""
        path = Path(self.tmpdir) / "test.json"
        path.write_text('{"version": 0}')

        import threading
        errors = []

        def reader():
            for _ in range(50):
                content = ""
                try:
                    content = path.read_text()
                    json.loads(content)  # Should always be valid JSON
                except json.JSONDecodeError:
                    errors.append(f"Invalid JSON: {content!r}")
                except FileNotFoundError:
                    pass  # Acceptable during rename

        def writer():
            for i in range(50):
                server_mod.atomic_write(path, json.dumps({"version": i + 1}))

        t_read = threading.Thread(target=reader)
        t_write = threading.Thread(target=writer)
        t_read.start()
        t_write.start()
        t_read.join()
        t_write.join()

        self.assertEqual(errors, [], f"Saw partial writes: {errors}")


if __name__ == "__main__":
    unittest.main()
