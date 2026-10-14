# TRG - 에르핀의 억지 레이스: 보드게임 대격돌 (가제)

기획서: [`docs/GDD_TDD_Master.md`](docs/GDD_TDD_Master.md) · 예외 규칙 확정 명세: [`docs/EDGE_CASE_SPEC.md`](docs/EDGE_CASE_SPEC.md)

Godot 4.3+ / GDScript 2.0. `core_engine/`은 IP 종속성이 없는 보드게임 프레임워크이며 `content_trickcal/`, UI를 직접 참조하지 않는다.

## 테스트

```bash
godot --headless --path . --import                      # 최초 1회 (class_name 캐시 생성)
godot --headless --path . -s res://tests/run_tests.gd   # 단위/통합 테스트
bash tests/run_net_test.sh                              # Listen Server 2프로세스 WebSocket 테스트
```

## 플레이 (프로토타입 화면)

Godot 4.3+ 에디터에서 프로젝트를 열고 **F5**를 누르면 `res://scenes/main_board.tscn`이 실행된다. 혼자서 4명을 번갈아 조작하는 핫시트 화면이다.

- **굴리기 (R):** 현재 턴 플레이어의 판정 도구를 굴린다. 이동할 말 버튼을 누르면 한 칸씩 이동한다 (버튼에 마우스를 올리면 도착 경로가 노란 테두리로 보인다).
- **중앙 법전:** `교칙 추가(테스트)` 버튼으로 교칙을 넣고(5번째부터 가장 오래된 교칙이 밀려난다) 굴리거나 이동할 때 교칙이 작동하면 로그에 표시된다.
- **생떼 카드:** 손패의 카드를 누르면 해당 플레이어로 사용한다. 개입 창(`개입 타이밍 A/B`)에서는 `카드 사용 끝 - 넘기기`로 닫는다. 빵집(3·8·13·18번)에 멈추거나 `카드 지급`으로 카드를 얻는다.
- **테스트 도구:** 판정 도구 변경, NPC 소환, `제한 시간 사용`(기본 꺼짐), 새 게임.
- 한글은 시스템 폰트(Malgun Gothic 등)를 사용한다.

```bash
godot --headless --path . -s res://tests/ui_smoke.gd    # 화면 스크립트 스모크 테스트 (버튼 시그널로 한 판 진행)
```
