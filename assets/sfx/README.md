# 효과음 폴더

여기에 `.wav` / `.ogg` / `.mp3` 파일을 넣으면 게임이 자동으로 찾아 재생합니다. 코드 수정은 필요 없습니다.
파일이 없으면 해당 소리는 조용히 건너뜁니다.

## 파일 이름 규칙
1. **이벤트 이름으로 시작**하면 가장 우선 (`hop_01.wav`, `hop_02.wav` 처럼 여러 개면 무작위 재생).
2. 아니면 파일 이름에 아래 **키워드**가 들어 있으면 연결됩니다 (예: Kenney Casino Audio의 `card-slide-1.ogg`, `dice-throw-2.ogg`).
3. 하위 폴더는 자유롭게 써도 됩니다.
- 짧은 효과음은 WAV 또는 OGG, 길이 2초 안팎 권장.
- 배경음은 `assets/bgm/<이름>.ogg` (루프 가능한 OGG 권장).

## 이벤트 목록
| 이벤트 | 쓰이는 순간 | 파일 이름 키워드 |
|---|---|---|
| `ui_click` | 버튼 클릭 | click, button, select, tap |
| `hop` | 말 점프 착지 (톡) | chip-lay, chips-stack, card-place, place |
| `slam` | 내리찍기 (잡을 때 쾅) | impact, thud, slam, chips-collide |
| `launch` | 장외 홈런·점프 코너 비행 | whoosh, swoosh, phase-jump, slide |
| `rocket` | 🔥 리벤지 부스터 로켓 출격 | rocket, thruster |
| `warp` | 옷장 포탈 워프 | warp, portal, phaser-down |
| `trap_set` | 은신 함정 설치 | trap-set, latch |
| `thud` | 출발선에 쿵 떨어짐 | thud, chips-handle, place |
| `dice_roll` | 주사위 계열(주사위·윷·친치로·마작·화투·타로) 굴림 | dice-throw, die-throw, dice |
| `roll_other` | 그 밖의 판정 도구(슬롯·홀덤·룰렛·리볼버) 굴림 | dice-shake, shake |
| `card_get` | 카드 획득·드로우 | card-place, card-fan |
| `card_pick` | 카드 집어 듦 | card-fan, card-slide, card-shove |
| `card_throw` | 카드 던짐 | card-shove, card-slide, whoosh |
| `card_impact` | 카드 발동 임팩트 | card-place, impact, thud |
| `turn_start` | [OO 차례] 배너 | turn-start |
| `round_start` | [N라운드 시작!] 배너 | round-start |
| `review_open` / `review_confirm` | 증강 확인 창 열림 / [확인] 누름 | review-open, review-confirm |
| `attack_alert` | 공격 카드 발동! 경보 | attack-alert |
| `trap_hidden` | 비밀 함정 설치 알림 | trap-hidden |
| `build_hotel` / `build_mine` | 호텔 건물 / 필살기 지뢰가 솟아오름 | build-hotel, build-mine |
| `revenge_ignite` | 리벤지 부스터 점화 | revenge-ignite |
| `tempo_warning` | 템포 업 경고 | tempo-warning |
| `emote_pop` | 이모트 말풍선 | emote-pop |
| `timer_tick` / `timeout` | 제한 시간 5초 전 째깍 / 시간 초과·강제 턴 패스 | timer-tick, timeout |
| `graduate` | 순위 확정(졸업) | graduate |
| `podium` | 결과 시상대 | podium |
| `augment_show` | 증강 카드 등장 | card-fan, card-shuffle, shuffle |
| `augment_pick` | 증강 선택 | card-place, select, click |
| `law` | 새 교칙 찍힘 | impact, stamp, thud, chips-collide |
| `law_drop` | 오래된 교칙 밀려남 | whoosh, slide |
| `promote` | 승급 반짝임 | sparkle, magic, chime, powerup |
| `charge` | 돌진 차징 | charge, whoosh |
| `dash` | ⚡ 부스터 발판·처치 컷인 돌진 | dash, whoosh, swoosh, shot |
| `shot` | 뱅! 장난감 총 발사 | shot, gun, laser |
| `good` | 좋은 일 (나이스/골인) | win, coin, chime, success |
| `bad` | 나쁜 일 (억까/으악) | lose, fail, buzz, error |
| `game_start` | GAME START 배너 | start, fanfare, impact |
| `win` | 승리 | win, fanfare, victory |

## 출처 표기
쓴 파일의 출처와 라이선스는 저장소 루트 `CREDITS.md`에 적어 주세요 (CC0는 표기 의무가 없지만 기록해 둡니다).

## 현재 들어 있는 소리
Kenney(CC0)의 Casino Audio / Interface Sounds / Impact Sounds / Digital Audio에서 골라 이벤트 이름으로 바꿔 넣었습니다 (`<이벤트>_01.ogg` ...). 같은 이벤트에 파일이 여러 개면 무작위로 재생됩니다. 이벤트 이름 뒤에는 번호만 올 수 있어서(`law_01`은 `law`, `law_drop_01`은 `law_drop`) 이름이 겹치는 이벤트가 섞이지 않습니다. 바꾸고 싶으면 같은 이름으로 덮어쓰면 됩니다.


## 파일이 없어도 소리가 나는 합성음
소리 파일이 없는 이벤트는 코드(`Sfx.synth`)가 짧은 PCM 파형을 직접 만들어 재생합니다 (클릭 팝, 차징, 틱, 점프 슬라이드, 타격음, 경보, 팡파르 등).
파일을 넣으면 합성음 대신 그 파일이 재생됩니다. `res://content_trickcal/audio/sfx/`(배경음은 `.../audio/bgm/`)에 넣어도 똑같이 찾으며, 같은 이름이면 그 폴더의 파일이 우선입니다.
기획서 이름으로 넣어도 됩니다: `pawn_step`(=hop), `pawn_capture`(=slam), `card_slam`(=card_impact), `trap_trigger`(=trap), `skill_ult`(=promote), `law_enact`(=law), `fanfare_win`(=win), `dice_charge`(=charge).


## 2차 재선정 (tools/audio/retune_sfx.py)
화면에서 일어나는 일과 소리 재질이 어긋난 것(날아가는 말에 종이 미끄러지는 소리, 총에 스프링 소리, 포탈에 1.75초 차임, 발판에 "딩")을
Kenney CC0 팩(Sci-fi / Digital / Interface / Impact / RPG)에서 다시 골랐습니다. 고른 기준은 측정한 특징(길이·첫 타격까지 시간·밝기·높낮이 변화·잡음 비율)입니다.
이어서 모든 효과음을 4단계 음량(호버 -36 / 자잘한 소리 -30 / 강조 -25 / 큰 순간 -21 dB RMS)으로 맞췄습니다.
원본 팩을 받아 `python tools/audio/retune_sfx.py <팩 폴더> ffmpeg`로 다시 만들 수 있고, 가공 기록은 `curated/manifest.json`에 남습니다.

## 3차 재선정 (OpenGameArt CC0 추가)
- 장외 홈런(`launch`): 나무 "딱" + 대나무 "휙" 두 소리를 겹쳐 방망이로 쳐 날리는 느낌
- 뱅!(`shot`): 장난감 레이저 대신 짧은 화약총 한 방
- 옷장 포탈(`warp`): 순간이동 주문 소리
- 윷 던짐(`yut_toss`): 종이 부채 소리 대신 대나무 휘두르는 소리 2종 (번갈아 재생)
- 슬롯 릴(`slot_spin`): 스프링 대신 톱니 딸깍
- 승급(`promote`): 긴 차임 대신 0.6초 레벨 업 상승음
