#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ARCH="${1:-universal}"
APP_NAME="misa_rin"
APP_PATH="$REPO_ROOT/build/macos/Build/Products/Release/${APP_NAME}.app"
ART_NAME="$(artifact_name macos "$ARCH")"
OUTPUT_PATH="$ARTIFACT_DIR/${ART_NAME}.dmg"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ensure_artifact_dir

if [[ ! -d "$APP_PATH" ]]; then
  echo "未找到macOS构建产物: $APP_PATH" >&2
  exit 1
fi

STAGING_DIR="$TMP_DIR/${APP_NAME}.app"
ditto "$APP_PATH" "$STAGING_DIR"

rm -f "$OUTPUT_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$OUTPUT_PATH" >/dev/null

echo "生成: $OUTPUT_PATH"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "artifact-name=${ART_NAME}" >> "$GITHUB_OUTPUT"
  echo "artifact-path=${OUTPUT_PATH}" >> "$GITHUB_OUTPUT"
fi
