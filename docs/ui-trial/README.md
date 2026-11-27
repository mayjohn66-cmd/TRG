# 그림·UI 작업 기록 (ui-trial)

그림·연출·화면을 만들거나 바꿀 때마다 남긴 검수 기록이다. **지금 따라야 하는 규격은 [이미지·UI 제작 규격서](../visual/Visual_Asset_Guide_Draft.md)**에 있고, 이 폴더는 "그 그림을 왜·어떻게 만들었는지"를 찾아볼 때 쓴다.

- 폴더는 주제별로 나눴다. 문서와 같은 이름의 PNG(스크린샷)·MP4(녹화)·JSON(생성 프롬프트·해시 기록)이 같은 폴더에 있다.
- **상태**: `현행`은 그 주제의 가장 마지막 기록(뒤 판이 없음), `이전 판 → X`는 같은 작업의 뒤 판(X)으로 대체된 기록이다. 그 뒤 게임이 더 바뀌었을 수 있으니 실제 값은 규격서와 코드를 본다. 이전 판도 결정 이력이라 지우지 않는다.
- 이미지 생성 프롬프트 원문은 같은 그림을 다시 만들 때 그대로 써야 하므로 영어로 남겨 둔 곳이 있다 (설명은 한국어).
- 문서 날짜는 처음 기록한 날이다. 같은 문서에 뒤에 덧붙인 내용이 있을 수 있다.

## 판정 도구 연출 (주사위·윷·룰렛·리볼버·핀볼·블랙잭 등 3D·2D) — `tools/`

| 문서 | 내용 | 기록일 | 상태 |
|---|---|---|---|
| [blackjack-card-art-v01](tools/blackjack-card-art-v01.md) | 블랙잭 기존 카드 리소스 연결 | 2026-10-20 | 현행 |
| [blackjack-compact-v01](tools/blackjack-compact-v01.md) | 블랙잭 손패와 합계 중심 화면 | 2026-10-28 | 현행 |
| [chinchiro-roll-3d-v01](tools/chinchiro-roll-3d-v01.md) | 친치로 사기주사위 — 면 교체 v0.1 | 2026-10-18 | 현행 |
| [cylinder-only-v01](tools/cylinder-only-v01.md) | 약실 실린더 단독 3D 시제품 | 2026-10-18 | 이전 판 → [cylinder-only-v03](tools/cylinder-only-v03.md) |
| [cylinder-only-v02](tools/cylinder-only-v02.md) | 약실 실린더 디테일 v0.2 | 2026-10-18 | 이전 판 → [cylinder-only-v03](tools/cylinder-only-v03.md) |
| [cylinder-only-v03](tools/cylinder-only-v03.md) | 실린더 길이 조정 v0.3 | 2026-10-18 | 현행 |
| [d6-roll-3d-v01](tools/d6-roll-3d-v01.md) | 기본 D6 굴림 연출 v0.1 | 2026-10-18 | 현행 |
| [illustrated-revolver-v02](tools/illustrated-revolver-v02.md) | 폭죽 리볼버 v0.2 | 2026-10-18 | 현행 |
| [judgment-card-roll-v01](tools/judgment-card-roll-v01.md) | 카드 계열 판정 연출 v0.1 | 2026-10-18 | 현행 |
| [mahjong-slam-v01](tools/mahjong-slam-v01.md) | 마작 탁·탁·탁 착지 연출 v0.1 | 2026-10-18 | 현행 |
| [pinball-base-3d-v01](tools/pinball-base-3d-v01.md) | 핀볼 3D 베이스 v0.1 | 2026-10-20 | 현행 |
| [pinball-ingame-3d-v01](tools/pinball-ingame-3d-v01.md) | 핀볼 인게임 3D 연출 v0.1 | 2026-10-20 | 이전 판 → [pinball-ingame-3d-v02](tools/pinball-ingame-3d-v02.md) |
| [pinball-ingame-3d-v02](tools/pinball-ingame-3d-v02.md) | 핀볼 물리 낙하 연출 v0.2 | 2026-10-20 | 현행 |
| [pinball-steel-ball-v01](tools/pinball-steel-ball-v01.md) | 핀볼 쇠구슬 3D 모델 v0.1 | 2026-10-20 | 현행 |
| [revolver-3d-animation-v03](tools/revolver-3d-animation-v03.md) | 러시안 룰렛 실제 3D 연출 v0.3 | 2026-10-19 | 현행 |
| [revolver-assembled-v01](tools/revolver-assembled-v01.md) | 리볼버 조립본 v0.1 | 2026-10-19 | 현행 |
| [revolver-body-only-v01](tools/revolver-body-only-v01.md) | 실린더를 제외한 리볼버 본체 v0.1 | 2026-10-19 | 이전 판 → [revolver-reference-body-v02](tools/revolver-reference-body-v02.md) |
| [revolver-reference-body-v02](tools/revolver-reference-body-v02.md) | 사진 비율 기준 리볼버 본체 v0.2 | 2026-10-19 | 현행 |
| [roll-history-art-v01](tools/roll-history-art-v01.md) | 결과 표찰 이미지 보강 | 2026-10-28 | 현행 |
| [roll-history-v01](tools/roll-history-v01.md) | 연속 판정 결과 기록 | 2026-10-28 | 현행 |
| [roll-success-v01](tools/roll-success-v01.md) | 연속 성공 표시 | 2026-10-29 | 현행 |
| [roulette-spin-3d-v01](tools/roulette-spin-3d-v01.md) | 인생게임 룰렛 연출 v0.1 | 2026-10-18 | 현행 |
| [slot-machine-3d-v01](tools/slot-machine-3d-v01.md) | 777 슬롯머신 연출 v0.1 | 2026-10-18 | 현행 |
| [toy-flag-revolver-v01](tools/toy-flag-revolver-v01.md) | 러시안 룰렛 · 폭죽 깃발 장난감 총 v0.1 | 2026-10-18 | 현행 |
| [yacht-roll-3d-v01](tools/yacht-roll-3d-v01.md) | 야추 주사위 5개 투척 연출 v0.1 | 2026-10-20 | 현행 |
| [yut-throw-3d-v01](tools/yut-throw-3d-v01.md) | 네 가락 윷 던지기 v0.1 | 2026-10-18 | 현행 |
| [tool-pick-v131](tools/tool-pick-v131.md) | 직접 선택형 판정 도구 연출 | 2026-11-27 | 현행 |
| [connected-props-v131](tools/connected-props-v131.md) | 1.3.1 직접 조작 연출 자산 연결 | 2026-11-27 | 현행 |
| [seamless-tools-v131](tools/seamless-tools-v131.md) | 1.3.1 직접 조작 연출 연속성 보강 | 2026-11-27 | 현행 |
| [focused-reveal-v131](tools/focused-reveal-v131.md) | 선택 후 중앙 공개와 공통 테이블 UI | 2026-11-27 | 현행 |
| [tool-audio-v131](tools/tool-audio-v131.md) | 1.3.1 판정 도구 효과음 점검 | 2026-11-27 | 현행 |
| [model-lightweight-v131](tools/model-lightweight-v131.md) | 3D 게임용 리소스 경량화 | 2026-11-27 | 현행 |
| [web-3d-budget-v131](tools/web-3d-budget-v131.md) | 1.3.1 추가 3D 경량화 | 2026-11-27 | 현행 |

## 생떼 카드 (삽화·카드 스킨·카드 얻기·BANG!) — `cards/`

| 문서 | 내용 | 기록일 | 상태 |
|---|---|---|---|
| [bang-card-v01](cards/bang-card-v01.md) | BANG! 카드 연출 | 2026-10-27 | 현행 |
| [card-actions-v01](cards/card-actions-v01.md) | 신규 즉발 카드 삽화 1차 | 2026-10-20 | 이전 판 → [card-actions-v02](cards/card-actions-v02.md) |
| [card-actions-v02](cards/card-actions-v02.md) | 카드 캐릭터와 동작 수정 | 2026-10-20 | 현행 |
| [card-art-direction](cards/card-art-direction.md) | 카드 일러스트 공통 제작 기준 | 2026-10-21 | 현행 |
| [card-defense-v01](cards/card-defense-v01.md) | 방어 카드 삽화 4종 | 2026-10-21 | 현행 |
| [card-domino-beni-v01](cards/card-domino-beni-v01.md) | 도미노 연쇄 — 베니 | 2026-10-26 | 현행 |
| [card-draw-fx-v02](cards/card-draw-fx-v02.md) | 카드 얻기 연출: 테이블 덱 → 확인 → 손패 | 2026-10-24 | 현행 |
| [card-illustrations-v02](cards/card-illustrations-v02.md) | 카드 일러스트 실제 적용 v0.2 | 2026-10-17 | 현행 |
| [card-scenes-v03](cards/card-scenes-v03.md) | 카드 장면 일러스트 4종과 명칭 수정 | 2026-10-21 | 현행 |
| [card-skin-v01](cards/card-skin-v01.md) | 카드 이미지 실제 적용 v0.1 · [스크린샷](cards/card-skin-v01.png) | 2026-10-17 | 이전 판 → [card-illustrations-v02](cards/card-illustrations-v02.md) |
| [card-traps-v04](cards/card-traps-v04.md) | 함정 카드 캐릭터 일러스트 6종 | 2026-10-21 | 현행 |

문서 없이 남은 자료: [card-illustrations-hand-v02.png](cards/card-illustrations-hand-v02.png) · [card-illustrations-ingame-v02.png](cards/card-illustrations-ingame-v02.png)

## 증강·교칙·초증강 아이콘 — `augments/`

| 문서 | 내용 | 기록일 | 상태 |
|---|---|---|---|
| [augment-art-v04](augments/augment-art-v04.md) | 증강 그림 갱신: 아우토반·저격수 · [스크린샷](augments/augment-art-v04.png) · [생성 기록](augments/augment-art-v04.json) | 2026-10-19 | 현행 |
| [augment-display-consistency-20261121](augments/augment-display-consistency-20261121.md) | 증강 아이콘 표시 일관성 점검 | 2026-11-21 | 현행 |
| [augment-groups-v01](augments/augment-groups-v01.md) | 증강 표시 분류와 색상 (2026-10-27) | 2026-10-27 | 현행 |
| [augment-icon-audit-v03](augments/augment-icon-audit-v03.md) | 증강 아이콘 의미 점검 v0.3 | 2026-10-18 | 현행 |
| [law-symbols-v01](augments/law-symbols-v01.md) | 특수 승리 교칙 심볼 v0.1 | 2026-10-21 | 현행 |
| [super-symbols-v01](augments/super-symbols-v01.md) | 초증강 심볼 · [생성 기록](augments/super-symbols-v01.json) | 2026-10-21 | 현행 |
| [tool-symbols-v02](augments/tool-symbols-v02.md) | 야추·블랙잭·핀볼 심볼 교체 | 2026-10-21 | 현행 |

문서 없이 남은 자료: [augment-background-v01.json](augments/augment-background-v01.json) · [augment-medals-v01.png](augments/augment-medals-v01.png) · [augment-medals-v02.png](augments/augment-medals-v02.png) · [supply-symbols-v01.json](augments/supply-symbols-v01.json) · [utility-symbols-v01.json](augments/utility-symbols-v01.json)

## 아바타 (잡기 포즈·로비 대기 동작) — `avatars/`

| 문서 | 내용 | 기록일 | 상태 |
|---|---|---|---|
| [avatar-capture-v01](avatars/avatar-capture-v01.md) | 아바타별 잡기 연출 · [스크린샷](avatars/avatar-capture-v01.png) | 2026-10-19 | 이전 판 → [avatar-capture-v04](avatars/avatar-capture-v04.md) |
| [avatar-capture-v02](avatars/avatar-capture-v02.md) | 피격 방향 및 두 인물 간격 수정 · [스크린샷](avatars/avatar-capture-v02.png) | 2026-10-19 | 이전 판 → [avatar-capture-v04](avatars/avatar-capture-v04.md) |
| [avatar-capture-v03](avatars/avatar-capture-v03.md) | 셰이디·다야 피격 팔다리 수정 | 2026-10-19 | 이전 판 → [avatar-capture-v04](avatars/avatar-capture-v04.md) |
| [avatar-capture-v04](avatars/avatar-capture-v04.md) | 셰이디 피격 왼쪽 눈 수정 | 2026-10-19 | 현행 |
| [avatars-diet-v01](avatars/avatars-diet-v01.md) | 나머지 7명 아바타 대기 프레임 경량화 | 2026-10-25 | 이전 판 → [avatars-hq-v02](avatars/avatars-hq-v02.md) |
| [avatars-hq-v02](avatars/avatars-hq-v02.md) | 나머지 7명 로비 아바타 고해상도 대기 동작 | 2026-10-25 | 현행 |

문서 없이 남은 자료: [avatar-capture-poses.json](avatars/avatar-capture-poses.json) · [avatar-capture-v03-daya.png](avatars/avatar-capture-v03-daya.png) · [avatar-capture-v03-shady.png](avatars/avatar-capture-v03-shady.png) · [avatar-capture-v04-shady.png](avatars/avatar-capture-v04-shady.png)

## 보드·기물 (칸 심볼·말 그림·보호막·NPC 경고·알까기) — `board/`

| 문서 | 내용 | 기록일 | 상태 |
|---|---|---|---|
| [alkkagi-v01](board/alkkagi-v01.md) | 실제 보드 위의 흑돌 알까기 | 2026-10-21 | 현행 |
| [arcade-pawns-art-v01](board/arcade-pawns-art-v01.md) | 아케이드 기물 이미지 v0.1 | 2026-10-20 | 현행 |
| [board-decals-v01](board/board-decals-v01.md) | 보드 평면 심볼과 부스터 존 v0.1 | 2026-10-21 | 현행 |
| [board-property-tiles-v01](board/board-property-tiles-v01.md) | 부루마불 느낌의 보드 발판 v0.1 · [스크린샷](board/board-property-tiles-v01.png) | 2026-10-17 | 현행 |
| [board-symbols-v02](board/board-symbols-v02.md) | 단색 심볼과 타일별 방향 v0.2 | 2026-10-21 | 이전 판 → [board-symbols-v03](board/board-symbols-v03.md) |
| [board-symbols-v03](board/board-symbols-v03.md) | 두툼한 빵과 블록 화살표 v0.3 | 2026-10-21 | 현행 |
| [npc-warning-v01](board/npc-warning-v01.md) | 중립 기물 경로 경고 그림 | 2026-10-21 | 현행 |
| [pawn-shield-v01](board/pawn-shield-v01.md) | 기물 보호막 표시 (2026-10-27) | 2026-10-27 | 현행 |

문서 없이 남은 자료: [board-v09-tilt.png](board/board-v09-tilt.png) · [pawn-token-gallery-v01.png](board/pawn-token-gallery-v01.png) · [pawn-tokens-v01.png](board/pawn-tokens-v01.png)

## 공통·특수 연출 효과 (잡기 컷인·초증강·모바일 좌표) — `fx/`

| 문서 | 내용 | 기록일 | 상태 |
|---|---|---|---|
| [aim-contrast-v01](fx/aim-contrast-v01.md) | 저격수·BANG! 조준 표시 대비 | 2026-10-28 | 현행 |
| [capture-fx-v05](fx/capture-fx-v05.md) | 잡기 타격감: 진입·정지·슬로모션·복귀 · [스크린샷](fx/capture-fx-v05.png) · [녹화](fx/capture-fx-v05.mp4) · [생성 기록](fx/capture-fx-v05.json) | 2026-10-19 | 현행 |
| [capture-fx-v06](fx/capture-fx-v06.md) | 무기별 잡기 강조 효과 · [스크린샷](fx/capture-fx-v06.png) · [녹화](fx/capture-fx-v06.mp4) · [생성 기록](fx/capture-fx-v06.json) | 2026-10-19 | 현행 |
| [capture-fx-v07](fx/capture-fx-v07.md) | 잡기 글자 연출 "A SINGULAR STRIKE!" · [스크린샷](fx/capture-fx-v07.png) · [녹화](fx/capture-fx-v07.mp4) · [생성 기록](fx/capture-fx-v07.json) | 2026-10-19 | 현행 |
| [capture-fx-v08](fx/capture-fx-v08.md) | 플레이어 사출 컷신의 그림 강조 효과 · [생성 기록](fx/capture-fx-v08.json) | 2026-10-27 | 현행 |
| [common-fx-v01](fx/common-fx-v01.md) | 공통 그림 타격 효과 | 2026-10-27 | 현행 |
| [fate-coin-v01](fx/fate-coin-v01.md) | 판 뒤집기: 양면 코인 판정 | 2026-10-24 | 현행 |
| [medium-fx-v01](fx/medium-fx-v01.md) | 중간 우선순위 연출 그림 | 2026-10-27 | 현행 |
| [mobile-fx-v01](fx/mobile-fx-v01.md) | 모바일 연출 좌표 | 2026-10-27 | 현행 |
| [priority-fx-v01](fx/priority-fx-v01.md) | 높은 우선순위 연출 그림 | 2026-10-27 | 현행 |
| [redistribution-v01](fx/redistribution-v01.md) | 공산주의 재분배 연출 | 2026-10-24 | 현행 |
| [remaining-fx-v01](fx/remaining-fx-v01.md) | 나머지 연출 강조 | 2026-10-27 | 현행 |
| [runaway-track-model-v01](fx/runaway-track-model-v01.md) | 조립식 직선 레일 조각 | 2026-10-21 | 현행 |
| [runaway-train-animation-v01](fx/runaway-train-animation-v01.md) | 보드 위의 폭주 기관차 | 2026-10-21 | 현행 |
| [runaway-train-model-v01](fx/runaway-train-model-v01.md) | 폭주 장난감 기차 모델 | 2026-10-21 | 현행 |

## 일기토 결투 미니게임 — `duel/`

| 문서 | 내용 | 기록일 | 상태 |
|---|---|---|---|
| [duel-curling-v01](duel/duel-curling-v01.md) | 병뚜껑 절벽 컬링 | 2026-10-22 | 현행 |
| [duel-ecard-v01](duel/duel-ecard-v01.md) | 엘리아스 E카드 | 2026-10-22 | 현행 |
| [duel-halli-v01](duel/duel-halli-v01.md) | 할리갈리 디럭스 | 2026-10-22 | 현행 |
| [duel-quickdraw-v01](duel/duel-quickdraw-v01.md) | 석양의 무법자 | 2026-10-22 | 현행 |
| [duel-rps-v01](duel/duel-rps-v01.md) | 묵찌빠 단두대 — 가위바위보 연출 | 2026-10-21 | 현행 |
| [duel-slot-v01](duel/duel-slot-v01.md) | 결투 게임 고르기 슬롯 | 2026-10-21 | 현행 |

## 화면 (로비·로딩·타이틀·난이도·규칙 도감) — `screens/`

| 문서 | 내용 | 기록일 | 상태 |
|---|---|---|---|
| [difficulty-icons-v01](screens/difficulty-icons-v01.md) | 난이도 표정과 상태 아이콘 | 2026-10-27 | 현행 |
| [fire-level-picker-v02](screens/fire-level-picker-v02.md) | 볶음라면 난이도 선택 v02 | 2026-10-24 | 현행 |
| [loading-bar-v01](screens/loading-bar-v01.md) | 웹 시작 화면 로딩바 v0.1 | 2026-10-19 | 현행 |
| [loading-petit-speaki-v02](screens/loading-petit-speaki-v02.md) | 웹 로딩 화면: 쁘띠 스핔이 | 2026-10-19 | 현행 |
| [lobby-background-v01](screens/lobby-background-v01.md) | 로비 배경 v0.1 · [스크린샷](screens/lobby-background-v01.png) | 2026-10-17 | 이전 판 → [lobby-background-v02](screens/lobby-background-v02.md) |
| [lobby-background-v02](screens/lobby-background-v02.md) | 로비 풍경 배경 v0.2 | 2026-10-19 | 현행 |
| [match-background-v01](screens/match-background-v01.md) | 대전 풍경 배경 v0.1 | 2026-10-19 | 현행 |
| [ramen-3d-v01](screens/ramen-3d-v01.md) | 난이도 선택: 3D 라면 그릇 v01 | 2026-10-24 | 현행 |
| [rulebook-drag-v01](screens/rulebook-drag-v01.md) | 규칙 도감 끌어서 스크롤과 꽉 찬 카드 | 2026-10-28 | 현행 |
| [rulebook-modal-v02](screens/rulebook-modal-v02.md) | 크게 보는 도감 항목 상세 | 2026-10-28 | 현행 |
| [title-logo-localized-v01](screens/title-logo-localized-v01.md) | 언어별 타이틀 로고 | 2026-10-26 | 현행 |
| [title-logo-v01](screens/title-logo-v01.md) | 타이틀 로고 v0.1 적용 | 2026-10-17 | 이전 판 → [title-logo-localized-v01](screens/title-logo-localized-v01.md) |

문서 없이 남은 자료: [board.png](screens/board.png) · [button-border-comparison.png](screens/button-border-comparison.png) · [menu.png](screens/menu.png)

## 소리 (배경 음악·효과음) — `audio/`

| 문서 | 내용 | 기록일 | 상태 |
|---|---|---|---|
| [battle-monatium-bgm-v01](audio/battle-monatium-bgm-v01.md) | 대전 BGM: 모나티엄의 밤 | 2026-10-19 | 현행 |
| [lobby-daylife-bgm-v01](audio/lobby-daylife-bgm-v01.md) | 로비 BGM: DayLife | 2026-10-19 | 현행 |
| [presentation-sfx-v01](audio/presentation-sfx-v01.md) | 추가 연출 전용 효과음 (2026-10-26) | 2026-10-26 | 현행 |
| [sfx-curated-v01](audio/sfx-curated-v01.md) | 효과음 파일 도입 | 2026-10-19 | 현행 |
| [web-audio-fix-v01](audio/web-audio-fix-v01.md) | 웹 효과음 무음 수정 | 2026-10-19 | 현행 |
