#!/usr/bin/env python3
"""매 정시 통계 집계: 디스코드 통계 채널에 쌓인 알림을 세어 총합을 웹후크로 올린다.

게임(웹 빌드)은 MatchTelemetry로 세 가지 한 줄 알림을 웹후크에 보낸다.
  [👋 로비 입장] 닉네임(#TAG) | PC | v...
  [🎮 매치 시작] 닉네임(#TAG) | 놀이터 | 3번째 판 시작
  [📊 매치 완료] 닉네임(#TAG) (3번째 판) | ...
서버가 따로 없으므로 채널에 쌓인 알림이 곧 기록이다. 이 스크립트는 채널 기록을 처음부터 읽어
입장·시작·완료 횟수와 고유 인원(익명 태그 수), 지난 1시간 증가분을 세어 [⏰ 정시 집계] 한 줄을 올린다.

환경 변수
  DISCORD_BOT_TOKEN       채널 기록을 읽을 봇 토큰 (필수. 웹후크로는 기록을 읽을 수 없다)
  TELEMETRY_WEBHOOK_URL   집계를 올리고 채널을 알아낼 웹후크 (없으면 scenes/feedback_modal.gd의 DISCORD_WEBHOOK_URL)
  TELEMETRY_CHANNEL_ID    읽을 채널 (없으면 웹후크 정보에서 알아낸다)

python3 tools/telemetry/hourly_report.py --self-test 로 집계 규칙만 검사할 수 있다 (네트워크 없음).
"""
from __future__ import annotations

import datetime as dt
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = "https://discord.com/api/v10"
LOBBY = "[\U0001F44B 로비 입장]"
START = "[\U0001F3AE 매치 시작]"
FINISH = "[\U0001F4CA 매치 완료]"
REPORT = "[⏰ 정시 집계]"
KINDS = {LOBBY: "lobby", START: "start", FINISH: "finish"}
TAG_RE = re.compile(r"\(#([A-Za-z0-9]{4})\)")
KST = dt.timezone(dt.timedelta(hours=9))
REPO = Path(__file__).resolve().parents[2]


def classify(line: str) -> tuple[str, str] | None:
    """알림 한 줄 -> (종류, 익명 태그). 집계 대상이 아니면 None."""
    for prefix, kind in KINDS.items():
        if line.startswith(prefix):
            found = TAG_RE.search(line)
            return kind, (found.group(1).upper() if found else "")
    return None


def _stamp(message: dict) -> dt.datetime:
    return dt.datetime.fromisoformat(str(message.get("timestamp", "1970-01-01T00:00:00+00:00")).replace("Z", "+00:00"))


def tally(messages: list[dict], since: dt.datetime) -> dict:
    """메시지들(content, timestamp)을 세어 종류별 {count, people, recent}를 돌려준다."""
    stats = {kind: {"count": 0, "people": set(), "recent": 0} for kind in KINDS.values()}
    for message in messages:
        stamp = _stamp(message)
        for line in str(message.get("content", "")).splitlines():
            hit = classify(line.strip())
            if hit is None:
                continue
            kind, tag = hit
            stats[kind]["count"] += 1
            if tag:
                stats[kind]["people"].add(tag)
            if stamp >= since:
                stats[kind]["recent"] += 1
    return stats


def report_line(stats: dict, now: dt.datetime) -> str:
    lobby, start, finish = stats["lobby"], stats["start"], stats["finish"]
    rate = f"{finish['count'] * 100 // start['count']}%" if start["count"] else "-"
    return (f"{REPORT} {now.astimezone(KST):%Y-%m-%d %H:00} KST 누적 | "
            f"입장 {len(lobby['people'])}명({lobby['count']}회) | "
            f"게임 시작 {len(start['people'])}명({start['count']}판) | "
            f"끝까지 {len(finish['people'])}명({finish['count']}판, 완주율 {rate}) | "
            f"지난 1시간 +{lobby['recent']}입장 · +{start['recent']}시작 · +{finish['recent']}완료")


def _request(url: str, token: str = "", body: dict | None = None) -> object:
    headers = {"User-Agent": "TRG-hourly-telemetry (github actions, 1.0)"}
    data = None
    if token:
        headers["Authorization"] = f"Bot {token}"
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode("utf-8")
    for _attempt in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers), timeout=20) as response:
                raw = response.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            if error.code == 429:  # 속도 제한: 알려 준 시간만큼 쉬었다 다시
                time.sleep(float(json.loads(error.read() or b"{}").get("retry_after", 1.0)) + 0.2)
                continue
            raise
    raise RuntimeError("디스코드 속도 제한이 풀리지 않았습니다")


def webhook_url() -> str:
    url = os.environ.get("TELEMETRY_WEBHOOK_URL", "").strip()
    if url:
        return url
    source = (REPO / "scenes" / "feedback_modal.gd").read_text(encoding="utf-8")
    found = re.search(r'const DISCORD_WEBHOOK_URL: String = "([^"]+)"', source)
    return found.group(1) if found else ""


def read_channel(channel_id: str, token: str) -> list[dict]:
    """채널 기록 전체 (최신부터 100개씩 거꾸로)."""
    messages: list[dict] = []
    before = ""
    while True:
        page = _request(f"{API}/channels/{channel_id}/messages?limit=100" + (f"&before={before}" if before else ""), token)
        if not page:
            return messages
        messages.extend(page)
        before = page[-1]["id"]


def main() -> int:
    token = os.environ.get("DISCORD_BOT_TOKEN", "").strip()
    hook = webhook_url()
    if not token or not hook:
        print("::notice::DISCORD_BOT_TOKEN 시크릿(또는 웹후크 주소)이 없어 정시 집계를 건너뜁니다.")
        return 0
    channel = os.environ.get("TELEMETRY_CHANNEL_ID", "").strip() or str(_request(hook)["channel_id"])
    messages = read_channel(channel, token)
    if messages and not any(str(m.get("content", "")) for m in messages):
        print("::error::메시지 내용이 비어 있습니다. 디스코드 개발자 포털에서 봇의 MESSAGE CONTENT INTENT를 켜 주세요.")
        return 1
    # 예약 실행은 몇 분 늦게 돌 수 있다: 정시로 내려 맞춘 [직전 정시 ~ 이번 정시) 구간을 센다 (늦게 온 알림은 다음 집계에 들어간다)
    now = dt.datetime.now(dt.timezone.utc).replace(minute=0, second=0, microsecond=0)
    stats = tally([m for m in messages if _stamp(m) < now], now - dt.timedelta(hours=1))
    line = report_line(stats, now)
    print(line)
    _request(hook + ("&" if "?" in hook else "?") + "wait=true", body={"content": line, "flags": 4096, "allowed_mentions": {"parse": []}})
    return 0


def self_test() -> int:
    now = dt.datetime(2026, 10, 22, 12, 0, tzinfo=dt.timezone.utc)
    old = "2026-10-22T09:00:00+00:00"
    new = "2026-10-22T11:30:00+00:00"
    messages = [
        {"timestamp": old, "content": f"{LOBBY} 교주(#A7B2) | PC | v1"},
        {"timestamp": old, "content": f"{LOBBY} 교주(#A7B2) | PC | v1"},
        {"timestamp": new, "content": f"{LOBBY} 손님(#K9QZ) | 모바일 | v1"},
        {"timestamp": old, "content": f"{START} 교주(#A7B2) | 놀이터 | 1번째 판 시작"},
        {"timestamp": new, "content": f"{START} 손님(#K9QZ) | 친선 | 1번째 판 시작"},
        {"timestamp": new, "content": f"{FINISH} 교주(#A7B2) (1번째 판) | 놀이터 | 13라운드"},
        {"timestamp": new, "content": f"{REPORT} 이전 집계는 세지 않는다 (#ZZZZ)"},
        {"timestamp": new, "content": "피드백 글은 세지 않는다 (#A7B2)"},
    ]
    stats = tally(messages, now - dt.timedelta(hours=1))
    checks = [
        (stats["lobby"]["count"] == 3 and len(stats["lobby"]["people"]) == 2, "입장 3회 · 2명"),
        (stats["start"]["count"] == 2 and len(stats["start"]["people"]) == 2, "시작 2판 · 2명"),
        (stats["finish"]["count"] == 1 and len(stats["finish"]["people"]) == 1, "완료 1판 · 1명"),
        (stats["lobby"]["recent"] == 1 and stats["start"]["recent"] == 1 and stats["finish"]["recent"] == 1, "지난 1시간 증가분"),
    ]
    line = report_line(stats, now)
    checks.append(("입장 2명(3회)" in line and "게임 시작 2명(2판)" in line and "끝까지 1명(1판, 완주율 50%)" in line and "21:00 KST" in line, "보고 문구: " + line))
    failed = [name for ok, name in checks if not ok]
    for name in failed:
        print("SELF_TEST_FAIL:", name)
    if not failed:
        print("HOURLY_REPORT_SELF_TEST_OK:", line)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else main())
