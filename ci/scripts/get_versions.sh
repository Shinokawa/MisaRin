#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

cat <<OUT
release_version=$(current_version)
release_build=$(current_build_number)
next_version=$(next_patch_version)
next_build=$(next_build_number)
OUT
