#!/usr/bin/env python3
"""Generate game sound effects with the ElevenLabs Sound Effects API from sfx_prompts_en.csv.

API key: read from the environment variable ELEVENLABS_API_KEY, or from a .env / .env.local file
(never hard-coded, never printed, never passed on the command line).

Examples (run from the repo root):
  python tools/audio/generate_elevenlabs_sfx.py --dry-run
  python tools/audio/generate_elevenlabs_sfx.py --priority high
  python tools/audio/generate_elevenlabs_sfx.py --only hop_01.ogg slam_01.ogg --variations 3
  python tools/audio/generate_elevenlabs_sfx.py --section "2-4"
  python tools/audio/generate_elevenlabs_sfx.py            # everything not generated yet

Output goes to content_trickcal/audio/sfx/ by default; files named like an existing event
(e.g. hop_01.ogg) replace the old sound with no code change. Needs only the Python standard
library. If ffmpeg is installed the clip is trimmed to the target length, faded out and saved as
.ogg; otherwise the raw mp3 is saved (Godot loads both).
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

API_URL = "https://api.elevenlabs.io/v1/sound-generation"
ENV_NAME = "ELEVENLABS_API_KEY"
API_MIN_SECONDS = 0.5   # the API does not accept shorter clips; ffmpeg trims them back down
API_MAX_TEXT = 450      # the API rejects longer prompts (validation_error text_too_long)
API_MAX_SECONDS = 22.0  # longer clips (the 2 BGM rows) cannot be generated here
DEFAULT_CSV = Path(__file__).with_name("sfx_prompts_en.csv")
DEFAULT_OUT = Path(__file__).resolve().parents[2] / "content_trickcal" / "audio" / "sfx"


def load_dotenv(path: Path) -> None:
    """Minimal KEY=VALUE parser. Existing environment variables win; nothing is printed."""
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip().removeprefix("export ").strip()
        value = value.strip().strip('"').strip("'")
        if key and value and key not in os.environ:
            os.environ[key] = value


def get_api_key() -> str:
    repo = Path(__file__).resolve().parents[2]
    for base in (Path.cwd(), repo):
        for name in (".env.local", ".env"):
            load_dotenv(base / name)
    key = os.environ.get(ENV_NAME, "").strip()
    if not key:
        sys.exit(f"{ENV_NAME} is not set. Put it in your environment or in a git-ignored .env.local file "
                 f"(a line `{ENV_NAME}=...`). Never commit it.")
    return key


def read_rows(csv_path: Path) -> list[dict]:
    with csv_path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def select_rows(rows: list[dict], args: argparse.Namespace) -> list[dict]:
    chosen = rows
    if args.only:
        wanted = set(args.only)
        chosen = [r for r in chosen if r["file"] in wanted or Path(r["file"]).stem in wanted]
    if args.priority:
        chosen = [r for r in chosen if r["priority"] == args.priority]
    if args.section:
        chosen = [r for r in chosen if r["section"].startswith(args.section)]
    return chosen


def variation_name(file_name: str, index: int) -> str:
    """hop_01.ogg -> hop_02.ogg for variation 2 (names without a _NN suffix are kept for variation 1)."""
    path = Path(file_name)
    stem = path.stem
    if index == 1:
        return file_name
    if stem[-3:-2] == "_" and stem[-2:].isdigit():
        return f"{stem[:-2]}{index:02d}{path.suffix}"
    return f"{stem}_{index:02d}{path.suffix}"


def fit_text(text: str) -> str:
    """Keep the prompt within the API limit: drop the shared 'Style:' sentence first, then cut at a word."""
    if len(text) <= API_MAX_TEXT:
        return text
    head = text.split(" Style:")[0]
    duration = text[text.rfind(" Duration:"):] if " Duration:" in text else ""
    text = (head + duration) if len(head + duration) <= API_MAX_TEXT else head
    return text if len(text) <= API_MAX_TEXT else text[:API_MAX_TEXT].rsplit(" ", 1)[0]


def request_sound(key: str, text: str, seconds: float, loop: bool, influence: float, fmt: str) -> bytes:
    """One API call with retry on rate limits / server errors. Raises RuntimeError with a readable reason."""
    body = {"text": fit_text(text), "duration_seconds": round(max(seconds, API_MIN_SECONDS), 2), "prompt_influence": influence}
    if loop:
        body["loop"] = True
    for attempt in range(1, 5):
        data = json.dumps(body).encode("utf-8")
        request = urllib.request.Request(f"{API_URL}?output_format={fmt}", data=data, method="POST",
                                         headers={"xi-api-key": key, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:300]
            if error.code == 401:
                raise SystemExit("401 Unauthorized: the API key was rejected (check the value, no quotes or spaces).")
            if error.code == 422 and "loop" in body and "loop" in detail.lower():
                body.pop("loop")  # this model version does not take 'loop'; retry as a normal clip
                continue
            if error.code in (429, 500, 502, 503, 504) and attempt < 4:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(f"HTTP {error.code}: {detail}")
        except (urllib.error.URLError, TimeoutError) as error:
            if attempt < 4:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(f"network error: {error}")
    raise RuntimeError("gave up after retries")


def finish_clip(audio: bytes, target: Path, seconds: float, loop: bool, use_ffmpeg: bool) -> Path:
    """Write the clip. With ffmpeg: trim to the target length, short fade-out (not for loops), save as ogg."""
    if not use_ffmpeg:
        target = target.with_suffix(".mp3")
        target.write_bytes(audio)
        return target
    with tempfile.TemporaryDirectory() as tmp:
        source = Path(tmp) / "in.mp3"
        source.write_bytes(audio)
        filters = [f"atrim=0:{seconds:.3f}"]
        if not loop:
            fade = min(0.08, seconds / 4)
            filters.append(f"afade=t=out:st={max(seconds - fade, 0):.3f}:d={fade:.3f}")
        command = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-ac", "1", "-af", ",".join(filters),
                   "-c:a", "libvorbis", "-q:a", "5", str(target.with_suffix(".ogg"))]
        subprocess.run(command, check=True)
    return target.with_suffix(".ogg")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV, help="prompt list (default: tools/audio/sfx_prompts_en.csv)")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output folder (default: content_trickcal/audio/sfx)")
    parser.add_argument("--only", nargs="+", metavar="NAME", help="generate only these files (hop_01.ogg or just hop_01)")
    parser.add_argument("--priority", choices=["high"], help="only rows marked high priority")
    parser.add_argument("--section", help='only rows whose section starts with this, e.g. "2-4" or "1-"')
    parser.add_argument("--variations", type=int, default=1, help="clips per row (_01, _02, ...) - repeated sounds sound better with 2-3")
    parser.add_argument("--influence", type=float, default=0.5, help="prompt_influence 0..1 (higher = follows the text more literally)")
    parser.add_argument("--format", default="mp3_44100_128", help="API output_format (default mp3_44100_128)")
    parser.add_argument("--overwrite", action="store_true", help="regenerate files that already exist")
    parser.add_argument("--delay", type=float, default=0.5, help="seconds to wait between calls")
    parser.add_argument("--dry-run", action="store_true", help="list what would be generated and the call count; no API call, no key needed")
    args = parser.parse_args()

    rows = select_rows(read_rows(args.csv), args)
    skipped_long = [r for r in rows if float(r["duration_s"]) > API_MAX_SECONDS]
    rows = [r for r in rows if float(r["duration_s"]) <= API_MAX_SECONDS]
    use_ffmpeg = shutil.which("ffmpeg") is not None

    jobs = []
    for row in rows:
        for index in range(1, max(args.variations, 1) + 1):
            name = variation_name(row["file"], index)
            existing = [args.out / name, args.out / Path(name).with_suffix(".mp3").name]
            if not args.overwrite and any(p.exists() for p in existing):
                continue
            jobs.append((row, name))

    print(f"{len(jobs)} clip(s) to generate -> {args.out}  (ffmpeg: {'yes, trim+ogg' if use_ffmpeg else 'no, raw mp3'})")
    for row in skipped_long:
        print(f"  skip {row['file']}: {row['duration_s']}s is longer than the API limit ({API_MAX_SECONDS:g}s) - make it elsewhere")
    if args.dry_run:
        for row, name in jobs:
            print(f"  {name:34s} {float(row['duration_s']):5.2f}s {'loop' if row['loop'] else ''}")
        print("dry run: nothing was sent. Each clip is one API call and uses ElevenLabs credits.")
        return
    if not jobs:
        return

    key = get_api_key()
    args.out.mkdir(parents=True, exist_ok=True)
    done, failed = 0, []
    for number, (row, name) in enumerate(jobs, 1):
        seconds = float(row["duration_s"])
        loop = bool(row["loop"])
        print(f"[{number}/{len(jobs)}] {name} ({seconds:g}s) ...", end=" ", flush=True)
        try:
            audio = request_sound(key, row["prompt"], seconds, loop, args.influence, args.format)
            saved = finish_clip(audio, args.out / name, seconds, loop, use_ffmpeg)
            print(f"ok -> {saved.name}")
            done += 1
        except (RuntimeError, subprocess.CalledProcessError) as error:
            print(f"FAILED: {error}")
            failed.append(name)
        time.sleep(args.delay)
    print(f"done: {done} ok, {len(failed)} failed")
    if failed:
        print("failed: " + " ".join(failed))
        print("re-run the same command to retry only the missing ones.")
        sys.exit(1)


if __name__ == "__main__":
    main()
