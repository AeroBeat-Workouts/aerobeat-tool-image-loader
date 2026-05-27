#!/usr/bin/env python3
import argparse
import functools
import http.server
import pathlib
import socketserver
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--port-file", required=True)
    args = parser.parse_args()

    root = pathlib.Path(args.root).resolve()
    if not root.exists():
        print(f"missing root: {root}", file=sys.stderr)
        return 1

    handler = functools.partial(
        http.server.SimpleHTTPRequestHandler,
        directory=str(root),
    )

    class QuietTCPServer(socketserver.TCPServer):
        allow_reuse_address = True

    with QuietTCPServer(("127.0.0.1", 0), handler) as httpd:
        pathlib.Path(args.port_file).write_text(str(httpd.server_address[1]), encoding="utf-8")
        httpd.serve_forever()


if __name__ == "__main__":
    raise SystemExit(main())
