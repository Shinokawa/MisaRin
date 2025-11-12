#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

if [[ $# -ne 2 ]]; then
  echo "用法: $0 <语义化版本> <构建号>" >&2
  exit 1
fi

NEW_VERSION="$1"
NEW_BUILD="$2"

python - <<'PY' "$PUBSPEC_FILE" "$NEW_VERSION" "$NEW_BUILD"
from pathlib import Path
import sys

pubspec_path, version, build = sys.argv[1:]
path = Path(pubspec_path)
lines = path.read_text().splitlines()
for idx, line in enumerate(lines):
    if line.startswith('version:'):
        lines[idx] = f'version: {version}+{build}'
        break
else:
    raise SystemExit('找不到version字段')
path.write_text('\n'.join(lines) + '\n')
PY

echo "已更新版本号 -> ${NEW_VERSION}+${NEW_BUILD}"
