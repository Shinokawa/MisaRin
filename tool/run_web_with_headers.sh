#!/usr/bin/env bash
set -euo pipefail

PORT=9000
DIR="${2:-build/web}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "Building web ..."
flutter build web

if [[ ! -d "$DIR" ]]; then
  echo "Directory not found after build: $DIR"
  exit 1
fi

echo "Building rust wasm (for FRB web) ..."
if ! command -v wasm-bindgen >/dev/null 2>&1; then
  echo "wasm-bindgen not found. Install with: cargo install wasm-bindgen-cli"
  exit 1
fi

if ! rustup target list --installed | grep -q '^wasm32-unknown-unknown$'; then
  echo "Adding Rust wasm target (wasm32-unknown-unknown) ..."
  rustup target add wasm32-unknown-unknown
fi

cargo build --manifest-path "$ROOT_DIR/rust/Cargo.toml" \
  --release \
  --target wasm32-unknown-unknown

RUST_WASM="$ROOT_DIR/rust/target/wasm32-unknown-unknown/release/rust_lib_misa_rin.wasm"
PKG_DIR="$DIR/pkg"
mkdir -p "$PKG_DIR"

wasm-bindgen \
  --target no-modules \
  --no-typescript \
  --out-dir "$PKG_DIR" \
  --out-name rust_lib_misa_rin \
  "$RUST_WASM"

if command -v lsof >/dev/null 2>&1; then
  PIDS="$(lsof -ti tcp:"$PORT" || true)"
  if [[ -n "$PIDS" ]]; then
    echo "Killing process(es) on port $PORT: $PIDS"
    kill $PIDS || true
    sleep 0.2
    STILL="$(lsof -ti tcp:"$PORT" || true)"
    if [[ -n "$STILL" ]]; then
      echo "Force killing process(es) on port $PORT: $STILL"
      kill -9 $STILL || true
    fi
  fi
else
  echo "lsof not found; cannot auto-kill port $PORT"
fi

python3 - "$PORT" "$DIR" <<'PY'
import http.server
import mimetypes
import os
import socketserver
import sys
import errno

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

try:
    with socketserver.TCPServer(("", port), Handler) as httpd:
        print(f"Serving {root} at http://localhost:{port}")
        httpd.serve_forever()
except OSError as exc:
    if exc.errno in (errno.EADDRINUSE, 48):
        raise SystemExit(
            f"Port {port} still in use. Please close it and retry."
        )
    raise
PY
