# 증강 아이콘 의미 점검 v0.3

기물 19 + 도구 9 + 교칙 8 + 카드 패키지 1 = 전체 37개 증강을 실제 MainBoard 카드와 설명으로 대조했다. 기물·도구·교칙의 실제 데이터는 변경하지 않았다.

## 수정 및 표현 보강

| 대상 | 기존 문제 | 적용 |
|---|---|---|
| 윷말 진화 EVO_1_1 | YUT_MAL 별칭이 실제 YUT.png와 연결되지 않아 윷막대·마스코트 대표 그림 사용 | 실제 둥근 윷말 PNG로 연결 |
| 카드 패키지 | 2장 획득 설명에 3장 그림 | 정확히 2장인 CARD_PACKAGE.png |
| 리볼버 | 앞면 6약실 외 측면 홈이 약실처럼 보여 개수 식별이 모호함 | 정면에 가까운 6약실·실탄 1개·빈칸 5개 그림 |
| LAW_01 | 공통 망치·책 그림 | 포탈 앞 공사 차단막 |
| LAW_02 | 공통 망치·책 그림 | 같은 색 업은 말과 금지 표시 |
| LAW_03 | 공통 망치·책 그림 | 서로 다른 두 말과 위치 교환 화살표 |
| LAW_04 | 공통 망치·책 그림 | 개구리와 반대 방향 화살표 |
| LAW_05 | 공통 망치·책 그림 | 전방으로 달리는 기관차·속도선 |
| LAW_06 | 공통 망치·책 그림 | 단속 카메라·플래시 |
| LAW_07 | 공통 망치·책 그림 | 상대편 두 말의 연결·동반 피격 |
| LAW_08 | 공통 망치·책 그림 | 결승 깃발과 되돌아오는 말·화살표 |

새 이미지 10종을 native image_gen.imagegen으로 각각 생성하고 원본 픽셀을 보존했다. 모델 ID는 도구에서 공개하지 않는다. 기관차 첫 시안의 역방향 화살표는 네이티브 편집 1회로 제거했다. 연대보증 체인의 연결고리는 지정한 2개보다 많지만 두 말의 동반 피격 의미가 명료해 채택했다. 프롬프트·원본 경로·수정/채택 기록·SHA-256은 content_trickcal/illustrations/manifest.json에 있다.

## 검증

- 전체 37개 제목과 설명이 점검 전후 동일함을 JSON 비교로 확인했다.
- 전체 37개가 대상별 고유 이미지에 연결되며 기물 진화에 다른 계열 그림이나 윷 도구 그림을 사용하지 않는다.
- tests/test_augment_art.gd를 전체 테스트 러너에 등록했다. 일반 도구/기물의 동명이인 구분, 교칙별 효과 이미지, 2장 패키지 전용 이미지 연결을 검사한다. 픽셀 안의 의미·개수는 생성 결과를 직접 보고 확인했다.
- 로컬 전체 323 tests / 25423 assertions / 0 failures. PAWN_ART_COVERAGE 27/27 및 AUGMENT_ART_COVERAGE 37/37.
- 원형 메달을 포함한 전체 37개 실제 카드 갤러리 5장 및 1366 × 768 인게임 선택 화면 2장 확인. 원본은 1254 × 1254 RGB, 신규 10종 런타임 최대 512px·무손실·밉맵.
- 기존 Windows WebRTC 미지원 조건을 다루는 테스트 진단과 인증서/종료 시 자원 경고가 발생한다. 새 스크립트 오류 없음.

## 전체 선택지 매핑

| ID | 표시 제목 | 선택 이미지 | 판정 |
|---|---|---|---|
| EVO_1_1 | [기물 진화] 윷: 윷말 | pawns/YUT.png | 수정/보강 |
| EVO_2_1 | [기물 진화] 체스: 폰 | pawns/CHESS_PAWN.png | 일치 확인 |
| EVO_2_2 | [기물 진화] 체스: 나이트 | pawns/CHESS_KNIGHT.png | 일치 확인 |
| EVO_2_3 | [기물 진화] 체스: 비숍 | pawns/CHESS_BISHOP.png | 일치 확인 |
| EVO_2_4 | [기물 진화] 체스: 룩 | pawns/CHESS_ROOK.png | 일치 확인 |
| EVO_3_1 | [기물 진화] 장기: 포 | pawns/JANGGI_PO.png | 일치 확인 |
| EVO_3_2 | [기물 진화] 장기: 차 | pawns/JANGGI_CHA.png | 일치 확인 |
| EVO_3_3 | [기물 진화] 장기: 마 | pawns/JANGGI_MA.png | 일치 확인 |
| EVO_3_4 | [기물 진화] 장기: 상 | pawns/JANGGI_SANG.png | 일치 확인 |
| EVO_4_1 | [기물 진화] 모노폴리: 미니카 | pawns/MONO_CAR.png | 일치 확인 |
| EVO_4_2 | [기물 진화] 모노폴리: 비행기 | pawns/MONO_PLANE.png | 일치 확인 |
| EVO_4_3 | [기물 진화] 모노폴리: 증기선 | pawns/MONO_SHIP.png | 일치 확인 |
| EVO_4_4 | [기물 진화] 모노폴리: 강아지 | pawns/MONO_DOG.png | 일치 확인 |
| EVO_5_1 | [기물 진화] 바둑: 흑돌 | pawns/BADUK_BLACK.png | 일치 확인 |
| EVO_5_2 | [기물 진화] 바둑: 백돌 | pawns/BADUK_WHITE.png | 일치 확인 |
| EVO_6_1 | [기물 진화] 쇼기: 보병 | pawns/SHOGI_FU.png | 일치 확인 |
| EVO_6_2 | [기물 진화] 쇼기: 비차 | pawns/SHOGI_HISHA.png | 일치 확인 |
| EVO_6_3 | [기물 진화] 쇼기: 각행 | pawns/SHOGI_KAKU.png | 일치 확인 |
| EVO_6_4 | [기물 진화] 쇼기: 계마 | pawns/SHOGI_KEIMA.png | 일치 확인 |
| TOOL_YUT | [판정 도구] 전통 박달나무 윷 | dice/DICE_YUT.png | 일치 확인 |
| TOOL_HOLDEM | [판정 도구] 텍사스 홀덤 딜러 | dice/DICE_POKER.png | 일치 확인 |
| TOOL_LIFE_ROULETTE | [판정 도구] 인생게임 회전 룰렛 | dice/DICE_ROULETTE.png | 일치 확인 |
| TOOL_CHINCHIRO | [판정 도구] 지하노역장 친치로 | dice/DICE_CHINCHIRO.png | 일치 확인 |
| TOOL_SLOT_777 | [판정 도구] 777 슬롯머신 | dice/DICE_SLOT.png | 일치 확인 |
| TOOL_REVOLVER | [판정 도구] 러시안 룰렛 리볼버 | dice/REVOLVER.png | 수정/보강 |
| TOOL_DICE_HWATU | [판정 도구] 화투 패 | dice/DICE_HWATU.png | 일치 확인 |
| TOOL_DICE_MAHJONG | [판정 도구] 리치 마작 만리장성 | dice/DICE_MAHJONG.png | 일치 확인 |
| TOOL_DICE_TAROT | [판정 도구] 점성술사의 타로 덱 | dice/DICE_TAROT.png | 일치 확인 |
| AUG_LAW_01 | [교칙 제정] 지름길 공사 중 | laws/LAW_01.png | 수정/보강 |
| AUG_LAW_02 | [교칙 제정] 사회적 거리두기 | laws/LAW_02.png | 수정/보강 |
| AUG_LAW_03 | [교칙 제정] 볼따구 평등법 | laws/LAW_03.png | 수정/보강 |
| AUG_LAW_04 | [교칙 제정] 청개구리 저주 | laws/LAW_04.png | 수정/보강 |
| AUG_LAW_05 | [교칙 제정] 폭주 기관차 | laws/LAW_05.png | 수정/보강 |
| AUG_LAW_06 | [교칙 제정] 과속 단속 | laws/LAW_06.png | 수정/보강 |
| AUG_LAW_07 | [교칙 제정] 강제 연대보증 | laws/LAW_07.png | 수정/보강 |
| AUG_LAW_08 | [교칙 제정] 결승선 문턱 | laws/LAW_08.png | 수정/보강 |
| CARD_PACKAGE | [카드 패키지] 생떼 카드 2장 | augments/CARD_PACKAGE.png | 수정/보강 |
