#!/usr/bin/env python3
"""
tt_live.py — stateful TikTok LIVE monitor

Subcommands
-----------
  check  <username>   One-shot live status check; JSON to stdout
                      Exit 0 = live, 1 = offline, 2 = error
  url    <username>   Resolve current m3u8 stream URL; URL to stdout
                      Exit 0 = ok, 1 = offline, 2 = error
  daemon <username>   Poll over a timer window; emit events on transitions
                      Args: --hours N (default 24), --poll-min M (min 10)
                      Exit 0 always at clean end

Design
------
- Lower-level stateful component; use tiktok_dispatch.py for public-access
  classification, Playwright URL extraction, and gateway/node routing
- stdlib only (urllib + json + subprocess for optional fallbacks)
- Identity store: secUid is the primary key; uniqueId is a pointer with a
  "current" flag and a rename history
- State store: per-secUid, stream URLs retained 3 days via passive stale-strip
- Event log: append-only line file per secUid; sub-agents tail it and announce
- SIGI_STATE only; no UNIVERSAL_DATA fallback
- Stream extraction order: direct webcast API -> yt-dlp -> streamlink
- A Webcast ``live`` result may still be login/content restricted; the
  dispatcher resolves that distinction with the direct Playwright LIVE page
- HD is preferred; lower qualities are bounded fallbacks
- No Notifier class. No outbound notifications. Sub-agents own announcement.

Workspace
---------
  $TT_LIVE_WORKSPACE  ||  ~/.openclaw/workspace/tiktok-monitor/

  workspace/
    tiktok-names/identities/<sec_uid>.json
    tiktok-names/pointers/<unique_id>.json
    state/tt-live/<sec_uid>.state.json
    state/tt-live/<sec_uid>.events
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# ============================================================================
# Constants — none of these are configurable at runtime by design
# ============================================================================

DEFAULT_QUALITY = "auto"
MIN_POLL_MINUTES = 10            # daemon poll floor
DEFAULT_DAEMON_HOURS = 24        # daemon default duration
IDENTITY_RETENTION_DAYS = 90     # identity/address-book retention
NICKNAME_HISTORY_MAX = 20        # nickname transitions kept per identity
URL_RETENTION_DAYS = 3           # stream URL retention in state store
REQUEST_TIMEOUT_SEC = 15         # per HTTP request
TT_AID = "1988"                  # TikTok webcast app id
USERNAME_RE = re.compile(r"^[A-Za-z0-9._]{1,24}$")
SEC_UID_RE = re.compile(r"^[A-Za-z0-9_-]{1,256}$")

USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)
ALLOWED_TIKTOK_HOSTS = {"www.tiktok.com", "webcast.tiktok.com"}
ALLOWED_MEDIA_HOST_RE = re.compile(r"(^|\.)tiktokcdn(?:-[a-z0-9-]+)?\.com$")

DEFAULT_WORKSPACE = Path.home() / ".openclaw" / "workspace" / "tiktok-monitor"
DEFAULT_IDENTITY_DIR = Path.home() / ".openclaw" / "workspace" / "tiktok-names"


def normalize_username(raw: str) -> str:
    """Normalize @handle input and reject path/shell/control characters."""
    username = str(raw or "").strip().lstrip("@")
    if not USERNAME_RE.fullmatch(username):
        raise argparse.ArgumentTypeError(
            "username must contain 1-24 letters, digits, dots, or underscores"
        )
    return username


def validate_sec_uid(raw: Any) -> str | None:
    """Return a filesystem-safe TikTok secUid, or None for malformed data."""
    value = str(raw or "")
    return value if SEC_UID_RE.fullmatch(value) else None


# ============================================================================
# Workspace
# ============================================================================

def resolve_workspace() -> Path:
    """Pick workspace root: env override TT_LIVE_WORKSPACE or default."""
    env = os.environ.get("TT_LIVE_WORKSPACE", "").strip()
    if env:
        return Path(env).expanduser().resolve()
    return DEFAULT_WORKSPACE


def resolve_identity_dir(ws: Path) -> Path:
    """Resolve the independent TikTok identity/address-book directory."""
    env = os.environ.get("TT_LIVE_IDENTITY_DIR", "").strip()
    if env:
        return Path(env).expanduser().resolve()
    if os.environ.get("TT_LIVE_WORKSPACE", "").strip():
        return ws / "tiktok-names"
    return DEFAULT_IDENTITY_DIR


def ensure_dirs(ws: Path, identity_dir: Path) -> None:
    """Create workspace subdirectories if missing."""
    (identity_dir / "identities").mkdir(parents=True, exist_ok=True)
    (identity_dir / "pointers").mkdir(parents=True, exist_ok=True)
    (ws / "state" / "tt-live").mkdir(parents=True, exist_ok=True)


def now_iso() -> str:
    """UTC ISO-8601 with trailing Z, second precision."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ============================================================================
# HTTP
# ============================================================================

def http_get(url: str,
             timeout: int = REQUEST_TIMEOUT_SEC,
             extra_headers: dict | None = None) -> tuple[int, bytes]:
    """GET via stdlib urllib. Returns (status, body_bytes)."""
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "text/html,application/json,*/*",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": "https://www.tiktok.com/",
    }
    if extra_headers:
        headers.update(extra_headers)
    class TikTokRedirectHandler(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, response_headers, newurl):
            parsed = urllib.parse.urlparse(newurl)
            if parsed.scheme != "https" or parsed.hostname not in ALLOWED_TIKTOK_HOSTS:
                raise urllib.error.HTTPError(newurl, 403, "redirect blocked", response_headers, fp)
            return super().redirect_request(req, fp, code, msg, response_headers, newurl)

    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_TIKTOK_HOSTS:
        return 0, b""
    req = urllib.request.Request(url, headers=headers, method="GET")
    opener = urllib.request.build_opener(TikTokRedirectHandler())
    try:
        with opener.open(req, timeout=timeout) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        body = e.read() if hasattr(e, "read") else b""
        return e.code, body
    except (urllib.error.URLError, TimeoutError, OSError):
        return 0, b""


# ============================================================================
# SIGI_STATE scrape
# ============================================================================

def parse_sigi_state(html_bytes: bytes) -> dict | None:
    """Extract <script id="SIGI_STATE" ...> JSON from a TikTok page."""
    try:
        html = html_bytes.decode("utf-8", errors="replace")
    except Exception:
        return None
    marker = '<script id="SIGI_STATE" type="application/json">'
    start = html.find(marker)
    if start < 0:
        return None
    start += len(marker)
    end = html.find("</script>", start)
    if end < 0:
        return None
    try:
        return json.loads(html[start:end])
    except json.JSONDecodeError:
        return None


def fetch_user_live_page(username: str) -> dict | None:
    """GET /@<user>/live, scrape SIGI_STATE, return flattened identity+room dict."""
    url = f"https://www.tiktok.com/@{username}/live"
    status, body = http_get(url)
    if status != 200 or not body:
        return None
    state = parse_sigi_state(body)
    if not state:
        return None
    lr = state.get("LiveRoom", {}).get("liveRoomUserInfo", {})
    user = lr.get("user", {}) or {}
    room = lr.get("liveRoom", {}) or {}
    return {
        "unique_id": user.get("uniqueId"),
        "nickname": user.get("nickname"),
        "user_id": user.get("id"),
        "sec_uid": user.get("secUid"),
        "room_id": user.get("roomId"),
        "status": room.get("status"),
        "title": room.get("title"),
        "start_time": room.get("startTime"),
    }


def is_live_from_sigi(record: dict) -> bool:
    """Live if status==2 (TikTok webcast LIVE state); else fall back to roomId."""
    status = record.get("status")
    room_id = record.get("room_id")
    if isinstance(status, int):
        return status == 2
    return bool(room_id) and str(room_id) != "0"


# ============================================================================
# Webcast API (room_info, check_alive)
# ============================================================================

def fetch_room_info(room_id: str) -> dict | None:
    """webcast/room/info — returns data dict or None."""
    url = (
        f"https://webcast.tiktok.com/webcast/room/info/"
        f"?aid={TT_AID}&room_id={room_id}"
    )
    status, body = http_get(url)
    if status != 200 or not body:
        return None
    try:
        envelope = json.loads(body.decode("utf-8", errors="replace"))
    except json.JSONDecodeError:
        return None
    return envelope.get("data") or None


def fetch_check_alive(room_id: str) -> bool | None:
    """webcast/room/check_alive — True/False or None on error."""
    url = (
        f"https://webcast.tiktok.com/webcast/room/check_alive/"
        f"?aid={TT_AID}&room_ids={room_id}"
    )
    status, body = http_get(url)
    if status != 200 or not body:
        return None
    try:
        data = json.loads(body.decode("utf-8", errors="replace"))
    except json.JSONDecodeError:
        return None
    items = data.get("data") or []
    if not items:
        return None
    return bool((items[0] or {}).get("alive"))


# ============================================================================
# Stream URL extraction
# ============================================================================

# Quality key → estimated height.
# TikTok keys observed in stream_data: origin, uhd_60, hd_60, hd, sd, ld, ao
QUALITY_HEIGHT = {
    "ao": 0,        # audio-only; excluded unless nothing else
    "ld": 360,
    "sd": 540,
    "hd": 720,
    "hd_60": 720,
    "uhd_60": 1080,
    "origin": 1080,
}

# Public names mirror the quality labels exposed by TikTok's player.  Legacy
# names remain accepted so existing monitor jobs and skill calls keep working.
QUALITY_ALIASES = {
    "original": "original", "origin": "original",
    "1080p60": "1080p60", "uhd_60": "1080p60",
    "720p60": "720p60", "hd_60": "720p60",
    "720p": "720p", "hd": "720p",
    "540p": "540p", "sd": "540p",
    "360p": "360p", "ld": "360p",
    "auto": "auto",
}
QUALITY_CHOICES = tuple(QUALITY_ALIASES)


def canonical_quality(quality: str) -> str:
    return QUALITY_ALIASES.get(quality, "auto")


def quality_preference(quality: str) -> list[str]:
    """Return exact-first quality order with lower resolutions as fallback."""
    quality = canonical_quality(quality)
    return {
        "360p": ["ld", "sd", "hd", "hd_60", "uhd_60", "origin"],
        "540p": ["sd", "ld", "hd", "hd_60", "uhd_60", "origin"],
        "720p": ["hd", "sd", "ld", "hd_60", "uhd_60", "origin"],
        "720p60": ["hd_60", "hd", "sd", "ld", "uhd_60", "origin"],
        "1080p60": ["uhd_60", "hd_60", "hd", "sd", "ld", "origin"],
        "original": ["origin", "uhd_60", "hd_60", "hd", "sd", "ld"],
        "auto": ["origin", "uhd_60", "hd_60", "hd", "sd", "ld"],
    }[quality]


def _quality_sort_key(preference: list[str]):
    """Sort quality keys by preference order, unknown keys by height desc."""
    def sort_key(key: str) -> tuple[int, int]:
        try:
            return (0, preference.index(key))
        except ValueError:
            return (1, -QUALITY_HEIGHT.get(key, 0))
    return sort_key


def _parse_quality_entries(room_info: dict) -> dict[str, dict]:
    """
    Parse per-quality stream entries from both known payload layouts,
    including audio-only ("ao"). Every URL is validated; entries without any
    allowed URL are dropped. Layout A wins over Layout B for the same key.
    """
    entries: dict[str, dict] = {}
    if not isinstance(room_info, dict):
        return entries
    stream_url = room_info.get("stream_url") or {}
    if not isinstance(stream_url, dict) or not stream_url:
        return entries

    def entry(key: Any) -> dict:
        key = str(key)
        return entries.setdefault(key, {
            "label": QUALITY_ALIASES.get(key, key),
            "hls": None,
            "flv": None,
            "resolution": None,
            "bitrate_kbps": None,
        })

    # Layout A: stream_url.live_core_sdk_data.pull_data.stream_data
    # stream_data is JSON-encoded string; data.<quality>.main holds hls/flv
    # URLs plus sdk_params (another JSON-encoded string with resolution and
    # video bitrate).
    sdk = stream_url.get("live_core_sdk_data") or {}
    pull = sdk.get("pull_data") if isinstance(sdk, dict) else None
    sd_raw = pull.get("stream_data") if isinstance(pull, dict) else None
    if isinstance(sd_raw, str):
        try:
            sd = json.loads(sd_raw)
        except json.JSONDecodeError:
            sd = None
        data = (sd or {}).get("data") or {}
        if isinstance(data, dict):
            for key, quality_obj in data.items():
                main = (quality_obj or {}).get("main") or {}
                if not isinstance(main, dict):
                    continue
                item = entry(key)
                for proto in ("hls", "flv"):
                    value = main.get(proto)
                    if (
                        isinstance(value, str) and value
                        and is_allowed_media_url(value)
                        and not item[proto]
                    ):
                        item[proto] = value
                params_raw = main.get("sdk_params")
                if isinstance(params_raw, str):
                    try:
                        params = json.loads(params_raw)
                    except json.JSONDecodeError:
                        params = None
                    if isinstance(params, dict):
                        resolution = params.get("resolution")
                        if (
                            isinstance(resolution, str)
                            and re.fullmatch(r"\d{2,5}x\d{2,5}", resolution)
                            and not item["resolution"]
                        ):
                            item["resolution"] = resolution
                        try:
                            vbitrate = int(params.get("vbitrate"))
                        except (TypeError, ValueError):
                            vbitrate = 0
                        if vbitrate > 0 and not item["bitrate_kbps"]:
                            item["bitrate_kbps"] = max(1, vbitrate // 1000)

    # Layout B: flat {quality: url} dicts
    for proto, map_key in (("hls", "hls_pull_url_map"), ("flv", "flv_pull_url_map")):
        url_map = stream_url.get(map_key)
        if isinstance(url_map, dict):
            for key, url in url_map.items():
                if isinstance(url, str) and url and is_allowed_media_url(url):
                    item = entry(key)
                    if not item[proto]:
                        item[proto] = url

    return {
        key: item for key, item in entries.items()
        if item["hls"] or item["flv"]
    }


def collect_qualities(room_info: dict) -> dict[str, dict]:
    """
    Enumerate all available stream qualities, best-first. Audio-only ("ao")
    is included and sorts last. Returns
    {key: {label, hls, flv, resolution, bitrate_kbps}}.
    """
    entries = _parse_quality_entries(room_info)
    sort_key = _quality_sort_key(quality_preference("auto"))
    return {key: entries[key] for key in sorted(entries, key=sort_key)}


def pick_hls(room_info: dict, quality: str = DEFAULT_QUALITY) -> str | None:
    """
    Pick an allowed HLS URL, preferring the requested quality. For HD, SD and
    LD are fallbacks only when HD is unavailable.
    Audio-only ("ao") is excluded unless nothing else is available.
    """
    entries = {
        key: item for key, item in _parse_quality_entries(room_info).items()
        if item["hls"]
    }
    if not entries:
        return None

    # Exclude audio-only first; if all are audio-only, allow them
    non_audio = {key: item for key, item in entries.items() if key != "ao"}
    pool = non_audio if non_audio else entries

    sort_key = _quality_sort_key(quality_preference(quality))
    for key in sorted(pool, key=sort_key):
        return pool[key]["hls"]
    return None


def _safe_count(value: Any) -> int | None:
    """Coerce a payload value into a non-negative int, else None."""
    try:
        number = int(value)
    except (TypeError, ValueError):
        return None
    return number if number >= 0 else None


def collect_room_summary(room_info: dict) -> dict:
    """
    Defensive summary of public room metadata for user-facing output.
    Field names vary per region/app version; every field is optional and
    omitted when absent or malformed.
    """
    info = room_info if isinstance(room_info, dict) else {}
    stats = info.get("stats") if isinstance(info.get("stats"), dict) else {}
    owner = info.get("owner") if isinstance(info.get("owner"), dict) else {}
    follow = (
        owner.get("follow_info")
        if isinstance(owner.get("follow_info"), dict) else {}
    )
    owner_stats = (
        owner.get("stats") if isinstance(owner.get("stats"), dict) else {}
    )

    def clean_text(value: Any) -> str | None:
        return value.strip() if isinstance(value, str) and value.strip() else None

    hashtag = info.get("hashtag")
    if isinstance(hashtag, dict):
        hashtag = hashtag.get("title")

    start_epoch = _safe_count(info.get("create_time"))
    duration_sec = None
    if start_epoch:
        elapsed = int(time.time()) - start_epoch
        if 0 < elapsed < 7 * 86400:
            duration_sec = elapsed
        elif elapsed < 0 or start_epoch < 10**9:
            start_epoch = None  # implausible epoch

    summary = {
        "title": clean_text(info.get("title")),
        "nickname": clean_text(owner.get("nickname")),
        "hashtag": clean_text(hashtag),
        "viewers": _safe_count(info.get("user_count")),
        "total_viewers": _safe_count(
            stats.get("total_user") or info.get("total_user")
        ),
        "likes": _safe_count(info.get("like_count") or stats.get("like_count")),
        "follower_count": _safe_count(
            follow.get("follower_count") or owner_stats.get("follower_count")
        ),
        "following_count": _safe_count(
            follow.get("following_count") or owner_stats.get("following_count")
        ),
        "start_epoch": start_epoch,
        "duration_sec": duration_sec,
    }
    return {key: value for key, value in summary.items() if value is not None}


def is_allowed_media_url(value: str) -> bool:
    """Allow only HTTPS TikTok CDN media URLs."""
    try:
        parsed = urllib.parse.urlparse(value)
    except (TypeError, ValueError):
        return False
    hostname = (parsed.hostname or "").lower()
    return parsed.scheme == "https" and bool(ALLOWED_MEDIA_HOST_RE.search(hostname))


def extract_via_ytdlp(username: str, quality: str = DEFAULT_QUALITY) -> str | None:
    """Use yt-dlp -g with requested quality and bounded lower fallbacks."""
    if not shutil.which("yt-dlp"):
        return None
    quality = canonical_quality(quality)
    cmd = [
        "yt-dlp",
        "-g",
        "-f", {
            "360p": "hls-ld/flv-ld",
            "540p": "hls-sd/hls-ld/flv-sd/flv-ld",
            "720p": "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld",
            "720p60": "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd_60/flv-hd/flv-ld",
            "1080p60": "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-uhd_60/flv-hd_60/flv-hd/flv-ld",
            "original": "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld",
            "auto": "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld",
        }[quality],
        f"https://www.tiktok.com/@{username}/live",
    ]
    try:
        out = subprocess.run(
            cmd, capture_output=True, text=True,
            timeout=REQUEST_TIMEOUT_SEC * 2,
        )
    except (subprocess.TimeoutExpired, OSError):
        return None
    if out.returncode != 0:
        return None
    lines = [ln.strip() for ln in (out.stdout or "").splitlines() if ln.strip()]
    if not lines:
        return None
    for ln in lines:
        if ".m3u8" in ln and is_allowed_media_url(ln):
            return ln
    return next((ln for ln in lines if is_allowed_media_url(ln)), None)


def extract_via_streamlink(username: str, quality: str = DEFAULT_QUALITY) -> str | None:
    """Use streamlink --stream-url if available."""
    if not shutil.which("streamlink"):
        return None
    quality = canonical_quality(quality)
    cmd = [
        "streamlink",
        "--stream-url",
        f"https://www.tiktok.com/@{username}/live",
        {
            "360p": "ld,worst",
            "540p": "sd,ld,worst",
            "720p": "hd,sd,ld,worst",
            "720p60": "hd_60,hd,sd,ld,worst",
            "1080p60": "uhd_60,hd_60,hd,sd,ld,worst",
            "original": "origin,uhd_60,hd_60,hd,sd,ld,best,worst",
            "auto": "best,origin,uhd_60,hd_60,hd,sd,ld,worst",
        }[quality],
    ]
    try:
        out = subprocess.run(
            cmd, capture_output=True, text=True,
            timeout=REQUEST_TIMEOUT_SEC * 2,
        )
    except (subprocess.TimeoutExpired, OSError):
        return None
    if out.returncode != 0:
        return None
    line = (out.stdout or "").strip()
    return line if line and is_allowed_media_url(line) else None


_ROOM_INFO_UNSET = object()


def extract_stream_url(room_id: str, username: str,
                       quality: str = DEFAULT_QUALITY,
                       room_info: Any = _ROOM_INFO_UNSET) -> tuple[str | None, str]:
    """
    Orchestrate primary (direct API) and optional fallbacks (yt-dlp, streamlink).
    Returns (url, source). Source is 'api' / 'yt-dlp' / 'streamlink' / 'none'.
    Pass a pre-fetched room_info (may be None) to avoid a duplicate API call.
    """
    # Primary: direct webcast API
    info = fetch_room_info(room_id) if room_info is _ROOM_INFO_UNSET else room_info
    if info:
        url = pick_hls(info, quality)
        if url:
            return url, "api"

    # Fallback 1: yt-dlp
    url = extract_via_ytdlp(username, quality)
    if url:
        return url, "yt-dlp"

    # Fallback 2: streamlink
    url = extract_via_streamlink(username, quality)
    if url:
        return url, "streamlink"

    return None, "none"


# ============================================================================
# Identity store
# ============================================================================

class IdentityStore:
    """
    Filesystem identity registry.

      identities/<sec_uid>.json   — canonical record per user (sec_uid is primary key)
      pointers/<unique_id>.json   — uniqueId -> sec_uid pointer with current flag

    Username renames are detected by comparing prior unique_id_current with the
    fresh scrape's unique_id for the same sec_uid. Old pointer rows get
    current=false and remain available until the 90-day retention expires.
    """

    def __init__(self, identity_dir: Path):
        self.ident_dir = identity_dir / "identities"
        self.ptr_dir = identity_dir / "pointers"

    @staticmethod
    def _write_json_atomic(path: Path, record: dict) -> None:
        """Replace one JSON record atomically so concurrent readers see no partial file."""
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as tmp:
                json.dump(record, tmp, indent=2, ensure_ascii=False)
                tmp.write("\n")
                tmp.flush()
                os.fsync(tmp.fileno())
            os.replace(tmp_name, path)
        finally:
            try:
                os.unlink(tmp_name)
            except FileNotFoundError:
                pass

    @staticmethod
    def _iso_epoch(value: Any) -> float | None:
        if not isinstance(value, str) or not value.strip():
            return None
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
        except (TypeError, ValueError, OverflowError):
            return None

    def _ident_path(self, sec_uid: str) -> Path:
        if not validate_sec_uid(sec_uid):
            raise ValueError("invalid sec_uid")
        return self.ident_dir / f"{sec_uid}.json"

    def _ptr_path(self, unique_id: str) -> Path:
        unique_id = normalize_username(unique_id)
        return self.ptr_dir / f"{unique_id}.json"

    def load_identity(self, sec_uid: str) -> dict | None:
        p = self._ident_path(sec_uid)
        if not p.exists():
            return None
        try:
            return json.loads(p.read_text("utf-8"))
        except (OSError, json.JSONDecodeError):
            return None

    def save_identity(self, sec_uid: str, record: dict) -> None:
        record["sec_uid"] = sec_uid
        record["last_seen"] = now_iso()
        if "first_seen" not in record:
            record["first_seen"] = record["last_seen"]
        self._write_json_atomic(self._ident_path(sec_uid), record)

    def load_pointer(self, unique_id: str) -> dict | None:
        p = self._ptr_path(unique_id)
        if not p.exists():
            return None
        try:
            return json.loads(p.read_text("utf-8"))
        except (OSError, json.JSONDecodeError):
            return None

    def write_pointer(self, unique_id: str, sec_uid: str,
                      current: bool = True) -> None:
        existing = self.load_pointer(unique_id) or {}
        ts = now_iso()
        record = {
            "unique_id": unique_id,
            "sec_uid": sec_uid,
            "current": current,
            "first_pointed_at": existing.get("first_pointed_at", ts),
            "last_pointed_at": ts,
        }
        self._write_json_atomic(self._ptr_path(unique_id), record)

    def cleanup_stale(self, days: int = IDENTITY_RETENTION_DAYS) -> None:
        """Remove identity and pointer records not observed within the retention window."""
        cutoff = time.time() - max(1, int(days)) * 86400
        expired_sec_uids: set[str] = set()

        for path in self.ident_dir.glob("*.json"):
            try:
                record = json.loads(path.read_text("utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            observed = self._iso_epoch(record.get("last_seen") or record.get("first_seen"))
            if observed is None or observed >= cutoff:
                continue
            sec_uid = validate_sec_uid(record.get("sec_uid"))
            if sec_uid:
                expired_sec_uids.add(sec_uid)
            try:
                path.unlink()
            except FileNotFoundError:
                pass

        for path in self.ptr_dir.glob("*.json"):
            try:
                record = json.loads(path.read_text("utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            observed = self._iso_epoch(
                record.get("last_pointed_at") or record.get("first_pointed_at")
            )
            if record.get("sec_uid") not in expired_sec_uids and (
                observed is None or observed >= cutoff
            ):
                continue
            try:
                path.unlink()
            except FileNotFoundError:
                pass

    def resolve_sec_uid(self, username: str) -> str | None:
        """Look up sec_uid via pointer file. Returns None if no pointer."""
        ptr = self.load_pointer(username)
        return ptr.get("sec_uid") if ptr else None

    def update_from_scrape(self, scrape: dict) -> tuple[str | None, bool]:
        """
        Update identity + pointer files from a fresh scrape.
        Returns (sec_uid, rename_detected).
        """
        sec_uid = validate_sec_uid(scrape.get("sec_uid"))
        try:
            unique_id = normalize_username(scrape.get("unique_id"))
        except argparse.ArgumentTypeError:
            unique_id = None
        if not sec_uid or not unique_id:
            return None, False

        existing = self.load_identity(sec_uid) or {}
        prev_unique = existing.get("unique_id_current")
        rename_detected = bool(prev_unique) and prev_unique != unique_id

        new_record: dict[str, Any] = {
            "sec_uid": sec_uid,
            "unique_id_current": unique_id,
            "nickname": (
                scrape.get("nickname")
                if scrape.get("nickname") is not None
                else existing.get("nickname")
            ),
            "user_id": (
                scrape.get("user_id")
                if scrape.get("user_id") is not None
                else existing.get("user_id")
            ),
        }
        if existing:
            new_record["first_seen"] = existing.get("first_seen")
            nick_history = list(existing.get("nickname_history") or [])
            prev_nick = existing.get("nickname")
            new_nick = new_record.get("nickname")
            if (
                isinstance(prev_nick, str) and isinstance(new_nick, str)
                and prev_nick != new_nick
            ):
                nick_history.append({
                    "from": prev_nick,
                    "to": new_nick,
                    "detected_at": now_iso(),
                })
                nick_history = nick_history[-NICKNAME_HISTORY_MAX:]
            if nick_history:
                new_record["nickname_history"] = nick_history
            history = existing.get("rename_history") or []
            if rename_detected:
                transition = {"from": prev_unique, "to": unique_id}
                if not history or any(
                    history[-1].get(key) != value for key, value in transition.items()
                ):
                    history.append({**transition, "detected_at": now_iso()})
                # Mark old pointer not-current
                old_ptr = self.load_pointer(prev_unique) or {}
                if old_ptr.get("sec_uid") == sec_uid:
                    old_ptr["current"] = False
                    old_ptr["last_pointed_at"] = now_iso()
                    self._write_json_atomic(self._ptr_path(prev_unique), old_ptr)
            if history:
                new_record["rename_history"] = history

        self.save_identity(sec_uid, new_record)
        self.write_pointer(unique_id, sec_uid, current=True)
        self.cleanup_stale()
        return sec_uid, rename_detected


# ============================================================================
# State store
# ============================================================================

class StateStore:
    """
    Per-secUid live state + stream URL cache.

      <sec_uid>.state.json = {
        "sec_uid": "...",
        "is_live": bool,
        "current_room_id": "..." | null,
        "last_check_ts": iso,
        "stream_urls": [ {"room_id": "...", "url": "...", "captured_at": iso}, ... ]
      }

    Stream URL retention is enforced by passive stale-strip called on every
    state write path (no active garbage collector).
    """

    def __init__(self, workspace: Path):
        self.dir = workspace / "state" / "tt-live"

    def _path(self, sec_uid: str) -> Path:
        if not validate_sec_uid(sec_uid):
            raise ValueError("invalid sec_uid")
        return self.dir / f"{sec_uid}.state.json"

    def _default(self, sec_uid: str) -> dict:
        return {
            "sec_uid": sec_uid,
            "is_live": False,
            "current_room_id": None,
            "last_check_ts": None,
            "stream_urls": [],
        }

    def read(self, sec_uid: str) -> dict:
        p = self._path(sec_uid)
        if not p.exists():
            return self._default(sec_uid)
        try:
            return json.loads(p.read_text("utf-8"))
        except (OSError, json.JSONDecodeError):
            return self._default(sec_uid)

    def write(self, sec_uid: str, state: dict) -> None:
        state["sec_uid"] = sec_uid
        self._path(sec_uid).write_text(
            json.dumps(state, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

    def add_url(self, sec_uid: str, room_id: str, url: str) -> None:
        state = self.read(sec_uid)
        urls = state.get("stream_urls") or []
        for entry in urls:
            if entry.get("room_id") == room_id and entry.get("url") == url:
                return
        urls.append({
            "room_id": room_id,
            "url": url,
            "captured_at": now_iso(),
        })
        state["stream_urls"] = urls
        self.write(sec_uid, state)

    def strip_stale_urls(self, sec_uid: str,
                         days: int = URL_RETENTION_DAYS) -> None:
        state = self.read(sec_uid)
        urls = state.get("stream_urls") or []
        if not urls:
            return
        cutoff = time.time() - days * 86400
        fresh = []
        for entry in urls:
            captured = entry.get("captured_at")
            try:
                ts = datetime.strptime(captured, "%Y-%m-%dT%H:%M:%SZ").replace(
                    tzinfo=timezone.utc
                ).timestamp()
            except (ValueError, TypeError):
                continue  # malformed timestamp -> drop entry
            if ts >= cutoff:
                fresh.append(entry)
        if len(fresh) != len(urls):
            state["stream_urls"] = fresh
            self.write(sec_uid, state)

    def get_latest_url(self, sec_uid: str,
                       room_id: str | None = None) -> str | None:
        state = self.read(sec_uid)
        urls = state.get("stream_urls") or []
        if not urls:
            return None
        if room_id:
            for entry in reversed(urls):
                if entry.get("room_id") == room_id:
                    return entry.get("url")
        value = urls[-1].get("url")
        return value if is_allowed_media_url(value) else None


# ============================================================================
# Event writer
# ============================================================================

class EventWriter:
    """
    Append-only line writer for daemon-mode events.

    Line format:
      ts=<iso> evt=<type> sec_uid=<...> unique_id=<...> [k=v ...] [stream_url=...]

    - ts is always first, evt always second, then sec_uid, then unique_id
    - stream_url is always LAST if present (so values containing & and =
      don't need escaping; parsers can take the substring after 'stream_url=')
    - Values must not contain spaces; URLs are already space-free
    """

    def __init__(self, workspace: Path, sec_uid: str):
        if not validate_sec_uid(sec_uid):
            raise ValueError("invalid sec_uid")
        self.path = workspace / "state" / "tt-live" / f"{sec_uid}.events"

    def write(self, evt: str, **fields: Any) -> None:
        ts = now_iso()
        sec_uid = fields.pop("sec_uid", "")
        unique_id = fields.pop("unique_id", "")
        stream_url = fields.pop("stream_url", None)

        parts = [f"ts={ts}", f"evt={evt}"]
        if sec_uid:
            parts.append(f"sec_uid={sec_uid}")
        if unique_id:
            parts.append(f"unique_id={unique_id}")
        for k, v in fields.items():
            if v is None:
                continue
            parts.append(f"{k}={v}")
        if stream_url:
            parts.append(f"stream_url={stream_url}")

        line = " ".join(parts) + "\n"
        with self.path.open("a", encoding="utf-8") as f:
            f.write(line)


# ============================================================================
# Subcommand: check
# ============================================================================

def cmd_check(args: argparse.Namespace) -> int:
    """
    One-shot scrape + identity update.
    Emits a JSON record to stdout.
    Exit 0 = live, 1 = offline, 2 = error.
    """
    ws = resolve_workspace()
    identity_dir = resolve_identity_dir(ws)
    ensure_dirs(ws, identity_dir)
    ids = IdentityStore(identity_dir)
    state_store = StateStore(ws)

    username = args.username
    scrape = fetch_user_live_page(username)
    if not scrape:
        sys.stderr.write(f"error: could not fetch /@{username}/live\n")
        return 2
    if not scrape.get("sec_uid"):
        sys.stderr.write(
            f"error: SIGI_STATE missing user.secUid for /@{username}\n"
        )
        return 2

    sec_uid, rename = ids.update_from_scrape(scrape)
    if not sec_uid:
        sys.stderr.write("error: identity update failed\n")
        return 2

    live = is_live_from_sigi(scrape)
    room_id = scrape.get("room_id") if live else None

    state = state_store.read(sec_uid)
    state["is_live"] = live
    state["current_room_id"] = str(room_id) if room_id else None
    state["last_check_ts"] = now_iso()
    state_store.write(sec_uid, state)
    state_store.strip_stale_urls(sec_uid)

    out = {
        "sec_uid": sec_uid,
        "unique_id": scrape.get("unique_id"),
        "nickname": scrape.get("nickname"),
        "user_id": scrape.get("user_id"),
        "live": live,
        "room_id": str(room_id) if room_id else None,
        "title": scrape.get("title") if live else None,
        "start_time": scrape.get("start_time") if live else None,
        "rename_detected": rename,
        "checked_at": now_iso(),
    }
    if live and room_id and str(room_id) != "0":
        # Enrichment is best-effort: a parsing problem must never turn a
        # correct live result into an error.
        try:
            info = fetch_room_info(str(room_id))
            if info:
                room = collect_room_summary(info)
                qualities = collect_qualities(info)
                if room:
                    out["room"] = room
                if qualities:
                    out["qualities"] = qualities
        except Exception:
            pass
    print(json.dumps(out, indent=2, ensure_ascii=False))
    return 0 if live else 1


# ============================================================================
# Subcommand: url
# ============================================================================

def cmd_url(args: argparse.Namespace) -> int:
    """
    Resolve current m3u8 stream URL for a live user.
    Prints the URL to stdout. Exit 0 = ok, 1 = offline, 2 = error.
    """
    ws = resolve_workspace()
    identity_dir = resolve_identity_dir(ws)
    ensure_dirs(ws, identity_dir)
    ids = IdentityStore(identity_dir)
    state_store = StateStore(ws)

    username = args.username

    scrape = fetch_user_live_page(username)
    if not scrape:
        sys.stderr.write(f"error: could not fetch /@{username}/live\n")
        return 2

    sec_uid, _ = ids.update_from_scrape(scrape)
    if not sec_uid:
        sys.stderr.write("error: identity update failed\n")
        return 2

    if not is_live_from_sigi(scrape):
        sys.stderr.write(f"error: @{username} is not live\n")
        return 1

    room_id = scrape.get("room_id")
    if not room_id or str(room_id) == "0":
        sys.stderr.write(f"error: no room_id for live user @{username}\n")
        return 2
    room_id = str(room_id)

    # Stored stream URLs are history only. TikTok can revoke a signed URL
    # before its query-string expiry or reuse a room id for a new playback
    # session, so returning a cached value here can hand VLC a dead manifest.
    # Resolve every public playback request from the current room metadata.
    emit_json = bool(getattr(args, "json", False))
    room_info = fetch_room_info(room_id) if emit_json else _ROOM_INFO_UNSET
    url, source = extract_stream_url(
        room_id, username, args.quality, room_info=room_info
    )
    if not url:
        sys.stderr.write(
            "error: could not extract stream URL "
            "(tried direct API, yt-dlp, streamlink)\n"
        )
        return 2
    state_store.add_url(sec_uid, room_id, url)
    state_store.strip_stale_urls(sec_uid)

    if emit_json:
        payload: dict[str, Any] = {
            "status": "live",
            "live": True,
            "unique_id": scrape.get("unique_id"),
            "url": url,
            "source": source,
            "quality": canonical_quality(args.quality),
        }
        # Enrichment is best-effort; never fail a resolved URL over metadata.
        try:
            if isinstance(room_info, dict) and room_info:
                room = collect_room_summary(room_info)
                qualities = collect_qualities(room_info)
                if room:
                    payload["room"] = room
                if qualities:
                    payload["qualities"] = qualities
        except Exception:
            pass
        print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    else:
        print(url)
    if args.verbose:
        sys.stderr.write(f"# source: {source}\n")
    return 0


# ============================================================================
# Subcommand: daemon
# ============================================================================

def cmd_daemon(args: argparse.Namespace) -> int:
    """
    Poll the user over a timer window. Emit events on transitions.
    Returns 0 at clean end (timer expired or interrupted).
    """
    ws = resolve_workspace()
    identity_dir = resolve_identity_dir(ws)
    ensure_dirs(ws, identity_dir)
    ids = IdentityStore(identity_dir)
    state_store = StateStore(ws)

    username = args.username
    hours = max(1, int(args.hours))
    poll_min = max(MIN_POLL_MINUTES, int(args.poll_min))
    poll_sec = poll_min * 60

    # Anchor identity with first scrape
    first = fetch_user_live_page(username)
    if not first or not first.get("sec_uid"):
        sys.stderr.write(
            f"error: could not anchor identity for @{username}\n"
        )
        return 2
    sec_uid, _ = ids.update_from_scrape(first)
    if not sec_uid:
        sys.stderr.write("error: identity update failed\n")
        return 2

    events = EventWriter(ws, sec_uid)
    unique_id = first.get("unique_id")

    deadline = time.time() + hours * 3600
    transitions = 0
    last_was_live = state_store.read(sec_uid).get("is_live", False)
    end_reason = "timer_expired"

    events.write(
        "daemon_start",
        sec_uid=sec_uid,
        unique_id=unique_id,
        hours=hours,
        poll_sec=poll_sec,
    )
    sys.stderr.write(
        f"[tt-live] daemon started for @{username} "
        f"(sec_uid={sec_uid[:16]}..., hours={hours}, poll={poll_min}min)\n"
    )

    try:
        while time.time() < deadline:
            scrape = fetch_user_live_page(username)
            if not scrape:
                events.write(
                    "poll_err",
                    sec_uid=sec_uid,
                    unique_id=unique_id,
                    reason="fetch_failed",
                )
                _sleep_until(deadline, poll_sec)
                continue

            new_sec_uid, rename = ids.update_from_scrape(scrape)
            if new_sec_uid and new_sec_uid != sec_uid:
                events.write(
                    "poll_err",
                    sec_uid=sec_uid,
                    unique_id=unique_id,
                    reason="sec_uid_changed",
                    new_sec_uid=new_sec_uid,
                )
                _sleep_until(deadline, poll_sec)
                continue

            if rename:
                new_unique = scrape.get("unique_id")
                events.write(
                    "rename_detected",
                    sec_uid=sec_uid,
                    unique_id=new_unique,
                    old_unique_id=unique_id,
                )
                unique_id = new_unique

            live = is_live_from_sigi(scrape)
            events.write(
                "poll_ok",
                sec_uid=sec_uid,
                unique_id=unique_id,
                alive=("true" if live else "false"),
            )

            if live and not last_was_live:
                room_id = str(scrape.get("room_id") or "")
                if room_id:
                    url, _src = extract_stream_url(room_id, username, args.quality)
                    if url:
                        state_store.add_url(sec_uid, room_id, url)
                else:
                    url = None
                st = state_store.read(sec_uid)
                st["is_live"] = True
                st["current_room_id"] = room_id or None
                st["last_check_ts"] = now_iso()
                state_store.write(sec_uid, st)
                state_store.strip_stale_urls(sec_uid)
                events.write(
                    "go_live",
                    sec_uid=sec_uid,
                    unique_id=unique_id,
                    room_id=room_id,
                    stream_url=url,  # stream_url must be the LAST key
                )
                transitions += 1
                last_was_live = True

            elif not live and last_was_live:
                st = state_store.read(sec_uid)
                last_room = st.get("current_room_id")
                st["is_live"] = False
                st["current_room_id"] = None
                st["last_check_ts"] = now_iso()
                state_store.write(sec_uid, st)
                state_store.strip_stale_urls(sec_uid)
                events.write(
                    "go_offline",
                    sec_uid=sec_uid,
                    unique_id=unique_id,
                    last_room_id=last_room,
                )
                transitions += 1
                last_was_live = False

            else:
                # No transition; still keep stale URLs trimmed
                state_store.strip_stale_urls(sec_uid)

            _sleep_until(deadline, poll_sec)

    except KeyboardInterrupt:
        end_reason = "interrupted"

    events.write(
        "daemon_end",
        sec_uid=sec_uid,
        unique_id=unique_id,
        reason=end_reason,
        transitions=transitions,
    )
    sys.stderr.write(
        f"[tt-live] daemon ended ({end_reason}, transitions={transitions})\n"
    )
    return 0


def _sleep_until(deadline: float, max_sleep: int) -> None:
    """Sleep up to max_sleep seconds, capped at remaining time before deadline."""
    remaining = deadline - time.time()
    if remaining <= 0:
        return
    time.sleep(min(max_sleep, max(1.0, remaining)))


# ============================================================================
# Argparse / main
# ============================================================================

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="tt_live.py",
        description="TikTok LIVE monitor — check, url, daemon",
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    p_check = sub.add_parser(
        "check",
        help="One-shot live status check; JSON to stdout",
    )
    p_check.add_argument("username", type=normalize_username, help="TikTok @username")
    p_check.set_defaults(func=cmd_check)

    p_url = sub.add_parser(
        "url",
        help="Print current m3u8 stream URL (cached or fresh)",
    )
    p_url.add_argument("username", type=normalize_username)
    p_url.add_argument("--quality", choices=QUALITY_CHOICES, default=DEFAULT_QUALITY)
    p_url.add_argument(
        "--json", action="store_true",
        help="Emit compact JSON with url, source, room metadata and all "
             "available qualities (success only; failures stay on stderr)",
    )
    p_url.add_argument(
        "--verbose", "-v", action="store_true",
        help="Print extraction source to stderr",
    )
    p_url.set_defaults(func=cmd_url)

    p_daemon = sub.add_parser(
        "daemon",
        help="Poll user over a timer window; emit events on transitions",
    )
    p_daemon.add_argument("username", type=normalize_username)
    p_daemon.add_argument("--quality", choices=QUALITY_CHOICES, default=DEFAULT_QUALITY)
    p_daemon.add_argument(
        "--hours", type=int, default=DEFAULT_DAEMON_HOURS,
        help=f"Watch duration in hours (default {DEFAULT_DAEMON_HOURS})",
    )
    p_daemon.add_argument(
        "--poll-min", type=int, default=MIN_POLL_MINUTES,
        help=f"Poll interval in minutes (floor {MIN_POLL_MINUTES})",
    )
    p_daemon.set_defaults(func=cmd_daemon)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
