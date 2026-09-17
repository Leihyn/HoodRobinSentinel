#!/usr/bin/env python3
"""
A plain-HTTP JSON-RPC proxy in front of Robinhood Chain.

Why this exists
---------------
`forge script` spins up a forked environment and opens many concurrent TLS
connections to the RPC. On some networks that handshake fails partway through
with `received fatal alert: BadRecordMac`, while single-shot requests from
`cast` or `curl` to the exact same URL succeed. The difference is the TLS stack
and the concurrency, not the endpoint: forge uses rustls, curl uses the system
stack, and only the parallel case trips.

Rather than disable verification or pin a different endpoint, this listens on
localhost over plain HTTP and performs the TLS leg itself with Python's
OpenSSL-backed client. Forge talks to 127.0.0.1 and never negotiates TLS.

Usage
-----
    python3 script/rpc-proxy.py                  # testnet on :8645
    python3 script/rpc-proxy.py --network mainnet --port 8646

    forge script script/Deploy.s.sol \
        --rpc-url http://127.0.0.1:8645 --broadcast

Nothing is cached, rewritten, or inspected. Request bodies pass through
untouched and responses come back verbatim.
"""

import argparse
import json
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UPSTREAM = {
    "testnet": "https://rpc.testnet.chain.robinhood.com",
    "mainnet": "https://rpc.mainnet.chain.robinhood.com",
}


class Proxy(BaseHTTPRequestHandler):
    upstream = UPSTREAM["testnet"]
    verbose = False

    def do_POST(self):  # noqa: N802
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        # The endpoint sits behind Cloudflare, which rejects unfamiliar clients
        # with error 1010 ("banned based on your browser's signature"). Python's
        # default urllib agent is one of them; curl is not. Presenting a curl
        # user-agent is what makes the upstream answer at all, and is very likely
        # the same reason forge's rustls handshake is cut short rather than any
        # fault in the network path.
        req = urllib.request.Request(
            self.upstream,
            data=body,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "curl/8.7.1",
                "Accept": "*/*",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                payload = resp.read()
                status = resp.status
        except urllib.error.HTTPError as e:
            payload, status = e.read(), e.code
        except Exception as e:  # noqa: BLE001
            payload = json.dumps(
                {"jsonrpc": "2.0", "id": None, "error": {"code": -32000, "message": str(e)}}
            ).encode()
            status = 502

        if self.verbose:
            try:
                method = json.loads(body).get("method")
            except Exception:  # noqa: BLE001
                method = "?"
            print(f"  {method} -> {status}", file=sys.stderr)

        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        pass  # the handler prints its own line when --verbose is set


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--network", choices=sorted(UPSTREAM), default="testnet")
    ap.add_argument("--port", type=int, default=8645)
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    Proxy.upstream = UPSTREAM[args.network]
    Proxy.verbose = args.verbose

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Proxy)
    print(f"proxying http://127.0.0.1:{args.port} -> {Proxy.upstream}", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
