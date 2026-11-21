#!/usr/bin/env bash
# Listen Server 통합 테스트: 호스트·클라이언트 두 프로세스를 띄워 실제 WebSocket RPC 흐름을 검증한다.
set -u
cd "$(dirname "$0")/.."
godot --headless --path . -s res://tests/net/net_host.gd > /tmp/trg_host.log 2>&1 &
HOST_PID=$!
sleep 3
godot --headless --path . -s res://tests/net/net_client.gd > /tmp/trg_client.log 2>&1
CLIENT_CODE=$?
wait $HOST_PID
HOST_CODE=$?
grep -E "HOST|CLIENT" /tmp/trg_host.log /tmp/trg_client.log | grep -v "^$"
echo "host=$HOST_CODE client=$CLIENT_CODE"
[ "$HOST_CODE" -eq 0 ] && [ "$CLIENT_CODE" -eq 0 ]
