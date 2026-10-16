#!/usr/bin/env bash
# 실제 WebRTC 로비 연결 검증(브라우저 2개). 필요: godot + 웹 내보내기 템플릿, node, playwright-core, Chromium.
#   PLAYWRIGHT_CORE=/경로/node_modules/playwright-core  CHROMIUM=/경로/chrome  bash tests/e2e/run_web_lobby_e2e.sh
# 프로젝트를 임시 폴더로 복사해 시작 씬을 테스트 씬으로 바꾼 웹 빌드를 만들어 로컬 서버로 띄운 뒤 두 브라우저로 방 만들기 -> 초대 -> 응답 -> 입장 -> 퇴장을 검사한다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
PORT="${E2E_PORT:-8765}"
: "${PLAYWRIGHT_CORE:?PLAYWRIGHT_CORE (playwright-core 폴더)를 지정하세요}"
: "${CHROMIUM:?CHROMIUM (크롬/크로미움 실행 파일)을 지정하세요}"
tar --exclude=.git --exclude=build -cf - -C "$ROOT" . | tar -xf - -C "$WORK"
cd "$WORK"
sed -i 's|exclude_filter=.*|exclude_filter="docs/*, build/*, *.md, .github/*"|' export_presets.cfg
sed -i 's|^run/main_scene=.*|run/main_scene="res://tests/e2e/web_lobby_e2e.tscn"|' project.godot
godot --headless --path . --import >/dev/null 2>&1 || true
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html >/dev/null 2>&1
(cd build/web && python3 -m http.server "$PORT" >/dev/null 2>&1 & echo $! > "$WORK/server.pid")
trap 'kill "$(cat "$WORK/server.pid")" 2>/dev/null || true; rm -rf "$WORK"' EXIT
sleep 1
node "$ROOT/tests/e2e/run_web_lobby_e2e.mjs" "http://localhost:$PORT" "$PLAYWRIGHT_CORE" "$CHROMIUM"
