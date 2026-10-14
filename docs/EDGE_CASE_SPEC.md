# 구현 예외 사항(Edge Cases) 공식 확정 명세 & 코드 매핑

기획서(`GDD_TDD_Master.md`)의 모호한 7개 지점에 대한 확정 규칙과, 이를 구현한 코드 위치·검증 테스트다.

| # | 확정 규칙 | 구현 | 테스트 |
|---|---|---|---|
| 1 | 판정 도구 7종: D6 / 윷(4·5 재굴림) / 인생게임 룰렛(7=7칸+재굴림) / 홀덤(1·3·5·7·10·15) / 할리갈리(1~3 + 종 보너스 +2 누적) / 777 슬롯(1·4·8·20) / 러시안 룰렛(+3 누적, 최대 15, 실탄=0칸+턴 종료) | `core_engine/tools/*` | `tests/test_tools.gd` |
| 2 | 22번: 통과 시 진입 방향 유지(21→23, 26→27), 정확히 멈췄다 출발하면 항상 27→28→0, 옷장(7·17) 워프는 22번에 멈춘 것으로 판정 | `BoardGraph.next_tile_forward`, `MoveExecutor._warp_to_center` | `test_board_graph.gd`, `test_move_executor.gd` |
| 3 | 코너(5·10)는 정확히 멈췄다 출발할 때만 지름길 진입. 비숍은 스쳐도 진입. `LAW_01` 활성 시 비숍도 외곽 | `BoardGraph.next_tile_forward`, `PlayerPawn.turns_at_corner_when_passing`, `LawShortcutConstruction` | `test_board_graph.gd` |
| 4 | 0번 후퇴 기본 19번, `step_history` 직전이 28번이면 28번. `ACT_04`는 19/28 도착 직후 완주 | `BoardGraph.advance_backward`, `CardBackdoGoal` | `test_board_graph.gd`, `test_rules_and_cards.gd`, `test_turn_manager.gd` |
| 5 | `PHASE_TURN_BEGIN`에서 `TurnSnapshot` 저장, `ACT_05`는 스냅샷 복원. 소모된 개입 카드·`ACT_05` 자체는 복구 안 됨 | `TurnSnapshot`, `RollbackCommand`, `TurnManager._close_resolution_window` | `test_snapshot.gd`, `test_turn_manager.gd` |
| 6 | 법전 > 기물 능력. `LAW_02` 중에는 윷 업기 불가(기존 업기는 유지). FIFO 밀어내기·`ACT_06`로 해제 | `MoveExecutor._resolve_stacking` (`ctx.allow_stacking`) | `test_move_executor.gd` |
| 7 | Listen Server: 방장이 서버 겸 클라이언트, 방장의 `TurnManager`가 모든 판정 후 `@rpc`로 브로드캐스트 | `TurnManager`, `NetworkService` | `tests/run_net_test.sh` (실제 WebSocket 2프로세스) |

## 명세에 없어서 내가 정한 해석 (변경 가능)

- **체스 3호기 비숍** → `PawnKind.CHESS_BISHOP`로 모델링했다. 고유 능력은 "코너를 스쳐도 지름길 진입"만 구현했다.
- **할리갈리**: 매 턴 시작에 바닥 카드 4장을 공개하고, 과일 합계가 5인 순간 `bell` 행동을 입력하면 +2 적립(카드당 1회). 다음 굴림에서 기본 1~3에 합산하고 소모한다.
- **러시안 룰렛**: 한 턴 안에서 `roll`로 방아쇠를 당기고(빈 총마다 +3), `stop`으로 누적치를 확정한다. 15칸에 닿으면 자동 확정, 실탄이면 0칸 + 턴 종료. 탄창은 6칸에 실탄 1발이다.
- **재굴림**: 재굴림이 붙은 눈금은 이동 대기열에 쌓이고(최대 8회), 개입 창 뒤에 눈금마다 기물을 따로 고른다.
- **완주**: 출발한 말이 0번에 도달하면 완주. `LAW_08`이 없으면 남는 눈금은 버린다. 승리 조건은 "4개 말 전원 완주"와 윷 4업 특수 승리다.
- **옷장 워프**: 옷장에 멈췄을 때만 발동하고 통과할 때는 발동하지 않는다.
- **`LAW_03`**: "눈금 6 이상"은 법전 통과 후 이동 칸수의 절댓값. 꼴찌 말은 이동한 플레이어 본인의 말을 제외하고 고른다.
- **`LAW_07`**: 말이 잡히면 *잡은 쪽*의 다른 출발한 말 중 결승에 가장 가까운 1개가 출발선으로 추방된다.
- **22번과 `LAW_01`**: `allow_shortcut`은 코너 5·10번의 `next_shortcut`만 막는다. 22번에서 멈췄다 출발하면 확정 명세 2번(무조건 최단 결승 루트)대로 항상 27번으로 나간다.
- **`step_history`**: 스택의 마지막 원소가 현재 타일이다(기본값 `[0]`). 후진은 한 칸 pop해서 되짚고, 이력이 현재 타일뿐이면 구조상 직전 타일(0번 → 19번)로 후퇴한다.
- **설치물**: `TileAttachment.on_step_trigger()`가 true를 반환하면 이동이 중단된다. 소모는 `duration_turns = 0`으로 표현하며 이동 실행기가 타일에서 제거한다.
- **개입 창**: `INTERRUPT_ROLL`·`RESOLUTION`은 누구의 손패에도 카드가 없으면 즉시 닫힌다. 카드가 있으면 3.5초 대기 후 LIFO로 해결한다.
- **개입 타이밍 B**: 이동은 호스트에서 한 번에 계산되므로 "도착 직전" 대신 이동 직후(`RESOLUTION`) 창에서 반응 카드를 받는다.
- **우노 리버스**: 턴 순서를 뒤집고 현재 라운드가 끝날 때까지 이동 방향을 반대로 한다.

## 아직 구현하지 않은 범위

- 생떼 카드 12종 중 `ACT_01·04·05·06`, `TRP_01`만 구현했다. 나머지(`ACT_02·03`, `TRP_02~04`, `SUM_01·02` 카드 자체)는 같은 `BaseCard`/`GameCommand`/`TileAttachment` 구조에 추가하면 된다. `SUM_01·02`의 NPC AI(`NeutralNPC`)는 구현되어 있다.
- 기물 고유 능력 중 비숍 지름길, 윷 업기만 구현했다. 나이트 점프, 포 넘기, 호텔, 바둑돌 등은 미구현이다.
- 증강 드래프트는 후보 풀(`TurnManager.draft_pool`)을 content 계층이 채워야 동작한다. 증강 효과 자체는 정의되지 않았다.
- 뷰(`scenes/`)와 `content_trickcal/`은 비어 있다. 코어는 시그널로만 외부에 알린다.
