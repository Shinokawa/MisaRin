#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-8080}"
DIR="${2:-build/web}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "Building web (wasm) ..."
flutter build web --wasm

if [[ ! -d "$DIR" ]]; then
  echo "Directory not found after build: $DIR"
  exit 1
fi

python3 - "$PORT" "$DIR" <<'PY'
import http.server
import mimetypes
import os
import socketserver
import sys

port = int(sys.argv[1])
root = os.path.abspath(sys.argv[2])

mimetypes.add_type("application/wasm", ".wasm")

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        super().end_headers()

    def translate_path(self, path):
        path = super().translate_path(path)
        rel = os.path.relpath(path, os.getcwd())
        return os.path.join(root, rel)

os.chdir(root)
with socketserver.TCPServer(("", port), Handler) as httpd:
    print(f"Serving {root} at http://localhost:{port}")
    httpd.serve_forever()
PY
