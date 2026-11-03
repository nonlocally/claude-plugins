"""A stand-in market for the script tests: records each request and answers by path.

Usage: python3 mock_market.py <port-file> <log-file>. Writes the port it bound to <port-file>,
then appends one JSON line per request (method, path, headers, body) to <log-file>.
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def _answer(self) -> None:
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length).decode() if length else ""
        with open(sys.argv[2], "a") as log:
            log.write(
                json.dumps(
                    {
                        "method": self.command,
                        "path": self.path,
                        "headers": {k.lower(): v for k, v in self.headers.items()},
                        "body": body,
                    }
                )
                + "\n"
            )
        if self.path.startswith("/v1/missing"):
            status, payload = 404, {"error": {"code": "not_found", "message": "Not found"}}
        elif self.path == "/v1/me":
            status, payload = 200, {"handle": "ada", "account_id": "ac_test", "balance": 7}
        else:
            status, payload = 200, {"ok": True}
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_POST = do_PUT = do_DELETE = _answer

    def log_message(self, *args) -> None:  # keep test output quiet
        pass


server = HTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[1], "w") as port_file:
    port_file.write(str(server.server_address[1]))
server.serve_forever()
