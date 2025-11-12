#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PUBSPEC_FILE="$REPO_ROOT/pubspec.yaml"
ARTIFACT_DIR="$REPO_ROOT/artifacts"

current_version() {
  local raw
  raw="$(grep '^version:' "$PUBSPEC_FILE" | head -n 1 | awk -F'version:' '{print $2}' | xargs)"
  echo "${raw%%+*}"
}

current_build_number() {
  local raw build_part
  raw="$(grep '^version:' "$PUBSPEC_FILE" | head -n 1 | awk -F'version:' '{print $2}' | xargs)"
  if [[ "$raw" == *"+"* ]]; then
    build_part="${raw##*+}"
  else
    build_part="0"
  fi
  echo "$build_part"
}

next_patch_version() {
  local version major minor patch
  version="$(current_version)"
  IFS='.' read -r major minor patch <<<"$version"
  patch=$((patch + 1))
  echo "${major}.${minor}.${patch}"
}

next_build_number() {
  local build
  build="$(current_build_number)"
  echo $((build + 1))
}

artifact_name() {
  local platform arch
  platform="$1"
  arch="$2"
  echo "${platform}-${arch}-$(current_version)"
}

ensure_artifact_dir() {
  mkdir -p "$ARTIFACT_DIR"
}

export REPO_ROOT PUBSPEC_FILE ARTIFACT_DIR
