#!/usr/bin/env python3
# File: tests/e2e/mock_ntfy.py
# Role: 웹 로비 e2e용 ntfy 호환 가짜 릴레이. POST /{topic} 로 올리고 GET /{topic}/json?poll=1&since=all 로 읽는다 (CORS 허용)
import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

TOPICS: dict = {}
LOCK = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self) -> None:
        topic = urlparse(self.path).path.strip("/")
        size = int(self.headers.get("Content-Length", "0"))
        message = self.rfile.read(size).decode("utf-8")
        with LOCK:
            box = TOPICS.setdefault(topic, [])
            box.append({"id": "m%d" % (len(box) + 1), "time": time.time(), "event": "message", "topic": topic, "message": message})
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b"{}")

    do_PUT = do_POST

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        names = parsed.path.strip("/").removesuffix("/json").strip("/").split(",")
        since = parse_qs(parsed.query).get("since", ["all"])[0]
        limit = 0.0 if since == "all" else float(since.rstrip("s"))
        now = time.time()
        with LOCK:
            entries = [e for name in names for e in TOPICS.get(name, []) if limit <= 0 or now - e["time"] <= limit]
        entries.sort(key=lambda e: e["time"])
        lines = "".join(json.dumps(dict(entry, time=int(entry["time"])), ensure_ascii=False) + "\n" for entry in entries)
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "application/x-ndjson; charset=utf-8")
        self.end_headers()
        self.wfile.write(lines.encode("utf-8"))

    def log_message(self, *_args) -> None:
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
