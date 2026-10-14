# TRG - 에르핀의 억지 레이스: 보드게임 대격돌 (가제)

기획서: [`docs/GDD_TDD_Master.md`](docs/GDD_TDD_Master.md) · 예외 규칙 확정 명세: [`docs/EDGE_CASE_SPEC.md`](docs/EDGE_CASE_SPEC.md)

Godot 4.3+ / GDScript 2.0. `core_engine/`은 IP 종속성이 없는 보드게임 프레임워크이며 `content_trickcal/`, UI를 직접 참조하지 않는다.

## 테스트

```bash
godot --headless --path . --import                      # 최초 1회 (class_name 캐시 생성)
godot --headless --path . -s res://tests/run_tests.gd   # 단위/통합 테스트
bash tests/run_net_test.sh                              # Listen Server 2프로세스 WebSocket 테스트
```
