# 증강 원형 메달 — v0.2

제작·적용 완료: 교칙·카드 패키지 2종, 기물 계열 6종, 판정 도구 9종, 총 17종.
아래 대표 경로에 PNG가 들어 있다. 개별 ID 이미지를 추가하면 대표 이미지보다 먼저 표시된다.
웹에서는 파일 추가 후 새 빌드·배포가 필요하다. 기본 D6 이미지는 별도 제작하지 않아 기존 `6`을 유지한다.

## 표시 규격

- 입력: 1:1 정사각형 PNG, 불투명한 어두운 배경, 중앙 집중형 오브젝트. 설명 문구 없음. 룰렛 `7`·슬롯 `777`은 요청한 식별 숫자로 예외 허용.
- 현재 생성 원본의 실제 크기와 SHA-256: `manifest.json` 참조.
- 원본 PNG는 1254×1254로 보존. Godot 런타임 텍스처는 크기 제한 512px·무손실 압축·밉맵 사용으로 통일해 110px 메달과 48px HUD 표시 비용을 줄인다.
- 증강 카드: 260×390px. 메달 전체 150×150px, 디스크 외경 120px.
- 네온 링 두께 5px, 안쪽 이미지 110×110px, 디스크 기준 좌표 (5, 5).
- 원형 셰이더: UV 중심 (0.5, 0.5), 반지름 0.5. 화면 미분으로 약 1px 경계 안티앨리어싱.
- 이미지 비율 유지. 외곽 사각 모서리는 알파 마스킹하고, 링은 이미지 위에 별도 렌더링.
- 원본 속 중요 오브젝트는 중심에서 반지름 40% 안에 배치하는 것을 권장. UI 자체 링은 원본에 그리지 않는다.
- 카테고리 링: 기물 `#20C997`, 판정 도구 `#9775FA`, 교칙 `#FFD43B`, 카드 패키지 `#FF6B6B`.
- 기물 대표 6종: 어두운 청록 배경·청록 후광. 판정 도구 9종: 어두운 남보라 배경·보라 후광.
- 장기·쇼기·마작의 글자 문양은 큰 도형 문양으로 단순화했다. 홀덤은 같은 무늬 카드 5장과 칩으로 표시한다.
- 우측 판정 도구 HUD: 기존 48×48px 슬롯 안에 동일한 원형 이미지 사용.
- 이미지와 글자는 동시에 표시하지 않는다. 이미지가 전혀 없을 때 기존 약어 유지.

## 우선순위

1. 개별 대상 이미지 (기물 세부 타입 / 교칙 ID / 도구 런타임 ID).
2. 개별 증강 ID 이미지 `augments/<증강 ID>.png` (기물·교칙·카드 패키지).
3. 아래 계열·카테고리 대표 이미지.
4. 기존 글자 약어.

예: `pawns/CHESS_KNIGHT.png` → `augments/EVO_2_2.png` → `pawns/PAWN_CHESS.png` → `나`.
예: `laws/LAW_03.png` → `augments/AUG_LAW_03.png` → `augments/AUG_LAW.png` → `법`.
예: `augments/CARD_PACKAGE.png` → `augments/AUG_CARD_PACK.png` → `J`.

누락 경로는 경고 없이 건너뛰며, 임포트된 Texture2D만 사용한다. 게임 규칙 데이터는 바꾸지 않는다.

## 계열 대표 파일

| 계열 | 대표 경로 |
|---|---|
| 체스 | `pawns/PAWN_CHESS.png` |
| 장기 | `pawns/PAWN_JANGGI.png` |
| 윷놀이 | `pawns/PAWN_YUT.png` |
| 모노폴리 | `pawns/PAWN_MONO.png` |
| 바둑 | `pawns/PAWN_BADUK.png` |
| 쇼기 | `pawns/PAWN_SHOGI.png` |

세부 기물 파일명은 `GameEnums.PawnSubType`의 키와 일치시킨다.
예: `CHESS_KNIGHT`, `JANGGI_CHA`, `MONO_CAR`, `BADUK_BLACK`, `SHOGI_FU`.

## 판정 도구 공용 파일

| 런타임 ID (개별 파일명) | 대표 경로 |
|---|---|
| `YUT` | `dice/DICE_YUT.png` |
| `LIFE_ROULETTE` | `dice/DICE_ROULETTE.png` |
| `HOLDEM` | `dice/DICE_POKER.png` |
| `SLOT_777` | `dice/DICE_SLOT.png` |
| `REVOLVER` | `dice/DICE_RUSSIAN.png` |
| `CHINCHIRO` | `dice/DICE_CHINCHIRO.png` |
| `DICE_HWATU` | `dice/DICE_HWATU.png` |
| `DICE_MAHJONG` | `dice/DICE_MAHJONG.png` |
| `DICE_TAROT` | `dice/DICE_TAROT.png` |

각 행은 먼저 `dice/<런타임 ID>.png`, 없으면 대표 경로를 찾는다.
기본 주사위는 선택적으로 `dice/D6.png` → `dice/DICE_D6.png` → 기존 `6`.
대표 이름과 런타임 ID가 같은 경우 중복 검색하지 않는다.

## 생성 기록

도구: 네이티브 `image_gen.imagegen`. 실제 모델 식별자는 도구가 공개하지 않아 기록하지 않았다.
전체 프롬프트·원본 경로·파일 해시는 `manifest.json`에 기록한다.
생성 원본은 별도 보존하고 래스터 재가공 없이 복사했다. 게임에서만 원형 마스킹한다.
