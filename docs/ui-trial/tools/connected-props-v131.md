# 1.3.1 직접 조작 연출 자산 연결

2026-11-26. 다른 AI의 `feature/v1.3.1` 8d79dd82 직접 조작 흐름과 로컬 제작 자산을 통합했다.

- 포춘쿠키: `CookiePlatterPick`이 기존 `cookie_platter_heaped.tscn`을 읽는다. 접시와 쿠키 16개가 실제 3D이며 기존 쿠키 메시·텍스처를 공유한다. 카메라 광선을 각 쿠키의 로컬 메시 경계와 비교해 앞쪽 쿠키를 고른다. 선택한 인스턴스만 위로 올라온 뒤 기존 3D 개봉 연출로 이어진다. 대기 시 SubViewport 렌더를 멈춘다.
- 아이스크림: `IceboxPickArt`에 7개의 개별 포장지 입력을 연결했다. 얼음·앞 테두리는 기존 그림의 마스크로 포장지 아래를 가린다. 선택된 포장지는 앞 레이어로 나오고 딸기·초코·민트 중 해당 그림으로 전환된다. `IceCreamView.set_flavor()`로 먹는 장면에도 선택한 맛을 넘긴다. 보상 RNG와 맛은 별개다.
- 오미쿠지: `ToolHandGate.interacted` 때 RollPresenter의 8초 무입력 대기를 초기화한다. 연속 흔들기는 이전 Tween을 취소해 회전이 충돌하지 않는다. 게임 전체 차례 시간 제한은 유지한다.
- 마작·캡슐 레버·홀덤 교환·화투 3장 중 2장 선택·해적 룰렛은 다른 AI의 엔진/입력 흐름을 유지한다. 기존 ToolPickModal의 공통 UI와 터치 중복 입력 방지는 보존했다.

검증: `ui_connected_props_test.gd` 48개 항목(홀덤 터치·가상 마우스 중복 토글 방지 포함), `ui_hand_tools_test.gd`, `ui_tool_pick_test.gd`, `ui_tool_pick_presentation_test.gd` 72개 항목, `TEST_ONLY=test_tool_pick` 7개 테스트/90개 항목. 모든 자동 검사는 `--audio-driver Dummy`로 무음 실행한다.

영상: `tools/capture_connected_tools.gd`는 실제 MainBoard에 도구를 장착하고 입력을 재현한다. 효과음만 켜고 보이스·배경음악은 끈다. Godot Movie Maker의 고정 30fps 원본 AVI와 `clips.json`의 프레임 구간으로 편집용 MP4를 만든다. 게임 배포 파일에는 영상 원본을 포함하지 않는다.
