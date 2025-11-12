#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ARCH="${1:-x64}"
TARGET_DIR="$REPO_ROOT/build/linux/${ARCH}/release/bundle"
ART_NAME="$(artifact_name linux "$ARCH")"
OUTPUT_PATH="$ARTIFACT_DIR/${ART_NAME}.tar.gz"

ensure_artifact_dir

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "未找到Linux构建产物目录: $TARGET_DIR" >&2
  exit 1
fi

rm -f "$OUTPUT_PATH"
tar -C "$TARGET_DIR" -czf "$OUTPUT_PATH" .

echo "生成: $OUTPUT_PATH"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "artifact-name=${ART_NAME}" >> "$GITHUB_OUTPUT"
  echo "artifact-path=${OUTPUT_PATH}" >> "$GITHUB_OUTPUT"
fi
