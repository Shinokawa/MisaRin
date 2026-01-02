#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.request
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


DEFAULT_REPO = "MCDFsteve/MisaRin"
DEFAULT_ASSET_REGEX = r"^(MisaRin-)?web-.*\.zip$"
DEFAULT_INTERVAL_SECONDS = 2 * 60 * 60


@dataclass(frozen=True)
class ReleaseAsset:
    name: str
    browser_download_url: str
    updated_at: str | None
    size: int | None


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def build_headers(token: str | None) -> dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "misa-rin-web-updater",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def http_get_json(url: str, *, headers: dict[str, str], timeout_seconds: int) -> dict[str, Any]:
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        data = response.read()
    return json.loads(data.decode("utf-8"))


def download_file(url: str, dest: Path, *, headers: dict[str, str], timeout_seconds: int) -> None:
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        dest.parent.mkdir(parents=True, exist_ok=True)
        with dest.open("wb") as fh:
            shutil.copyfileobj(response, fh)


def sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def safe_zip_members(zf: zipfile.ZipFile) -> Iterable[zipfile.ZipInfo]:
    for member in zf.infolist():
        name = member.filename
        if not name or name.endswith("/"):
            continue
        normalized = name.replace("\\", "/")
        if normalized.startswith("/") or normalized.startswith("../") or "/../" in normalized:
            raise ValueError(f"Unsafe zip path: {name}")
        yield member


def extract_zip_overwrite(zip_path: Path, dest_dir: Path, *, staging_dir: Path) -> None:
    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    staging_dir.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(zip_path, "r") as zf:
        for member in safe_zip_members(zf):
            target = staging_dir / member.filename
            target.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(member, "r") as src, target.open("wb") as dst:
                shutil.copyfileobj(src, dst)

    index_html = staging_dir / "index.html"
    if not index_html.is_file():
        raise FileNotFoundError(f"Zip 内未找到 index.html：{index_html}")

    for path in staging_dir.rglob("*"):
        if path.is_dir():
            continue
        relative = path.relative_to(staging_dir)
        destination = dest_dir / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)


def load_state(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def save_state(path: Path, state: dict[str, Any]) -> None:
    path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def find_web_asset(release: dict[str, Any], asset_regex: re.Pattern[str]) -> ReleaseAsset | None:
    assets = release.get("assets") or []
    for asset in assets:
        name = asset.get("name")
        url = asset.get("browser_download_url")
        if not isinstance(name, str) or not isinstance(url, str):
            continue
        if not asset_regex.search(name):
            continue
        updated_at = asset.get("updated_at")
        size = asset.get("size")
        return ReleaseAsset(
            name=name,
            browser_download_url=url,
            updated_at=updated_at if isinstance(updated_at, str) else None,
            size=size if isinstance(size, int) else None,
        )
    return None


def main(argv: list[str]) -> int:
    default_dest = str(Path(__file__).resolve().parent)
    parser = argparse.ArgumentParser(
        prog="update_web_release.py",
        description="每隔一段时间检查 GitHub Releases 的 Web 产物并下载解压覆盖到目标目录（默认脚本所在目录）。",
    )
    parser.add_argument("--repo", default=DEFAULT_REPO, help="GitHub 仓库，格式 owner/repo")
    parser.add_argument(
        "--asset-regex",
        default=DEFAULT_ASSET_REGEX,
        help="用于匹配 Web 产物 asset 名称的正则表达式（默认匹配 MisaRin-web-*.zip，也兼容 web-*.zip）",
    )
    parser.add_argument(
        "--dest",
        default=default_dest,
        help="解压覆盖到的目录（默认脚本所在目录）",
    )
    parser.add_argument(
        "--interval-seconds",
        type=int,
        default=DEFAULT_INTERVAL_SECONDS,
        help="检查间隔秒数（默认 7200 秒/2 小时）",
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="只检查一次并退出（便于配合 cron）",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=60,
        help="网络超时秒数（默认 60）",
    )
    args = parser.parse_args(argv)

    dest_dir = Path(args.dest).resolve()
    dest_dir.mkdir(parents=True, exist_ok=True)

    state_path = dest_dir / ".misa_rin_web_state.json"
    staging_dir = dest_dir / ".misa_rin_web_staging"
    download_path = dest_dir / ".misa_rin_web_download.zip"

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    headers = build_headers(token)

    asset_regex = re.compile(args.asset_regex)
    api_url = f"https://api.github.com/repos/{args.repo}/releases/latest"

    while True:
        try:
            state = load_state(state_path)
            release = http_get_json(api_url, headers=headers, timeout_seconds=args.timeout_seconds)

            tag = release.get("tag_name")
            if not isinstance(tag, str) or not tag:
                raise RuntimeError("未能从 GitHub API 获取 tag_name")

            asset = find_web_asset(release, asset_regex)
            if asset is None:
                raise RuntimeError(f"未找到匹配的 Web 产物（asset-regex={args.asset_regex}）")

            last_tag = state.get("tag")
            last_asset_name = state.get("asset_name")
            last_asset_updated_at = state.get("asset_updated_at")

            if last_tag == tag and last_asset_name == asset.name and last_asset_updated_at == asset.updated_at:
                print(f"[{utc_now_iso()}] 已是最新：{tag} / {asset.name}")
            else:
                print(f"[{utc_now_iso()}] 发现更新：{tag} / {asset.name} -> 下载中…")
                if download_path.exists():
                    download_path.unlink()
                download_file(
                    asset.browser_download_url,
                    download_path,
                    headers=headers,
                    timeout_seconds=args.timeout_seconds,
                )
                digest = sha256(download_path)
                print(f"[{utc_now_iso()}] 下载完成：{download_path.name} (sha256={digest}) -> 解压覆盖…")
                extract_zip_overwrite(download_path, dest_dir, staging_dir=staging_dir)

                new_state = {
                    "repo": args.repo,
                    "tag": tag,
                    "asset_name": asset.name,
                    "asset_updated_at": asset.updated_at,
                    "asset_size": asset.size,
                    "downloaded_at": utc_now_iso(),
                    "zip_sha256": digest,
                }
                save_state(state_path, new_state)
                print(f"[{utc_now_iso()}] 更新完成：{tag} / {asset.name}")

        except (urllib.error.URLError, urllib.error.HTTPError) as exc:
            print(f"[{utc_now_iso()}] 网络错误：{exc}", file=sys.stderr)
        except Exception as exc:
            print(f"[{utc_now_iso()}] 运行失败：{exc}", file=sys.stderr)

        if args.once:
            return 0

        time.sleep(max(1, args.interval_seconds))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
