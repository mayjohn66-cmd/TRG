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
| `launch` | 잡힌 말이 날아감 | whoosh, swoosh, card-slide, slide |
| `thud` | 출발선에 쿵 떨어짐 | thud, chips-handle, place |
| `dice_roll` | 주사위 굴림 | dice-shake, die-throw, dice-throw, dice |
| `dice_result` | 주사위 결과 확정 | dice-throw, die-throw, dice |
| `card_pick` | 카드 집어 듦 | card-fan, card-slide, card-shove |
| `card_throw` | 카드 던짐 | card-shove, card-slide, whoosh |
| `card_impact` | 카드 발동 임팩트 | card-place, impact, thud |
| `augment_show` | 증강 카드 등장 | card-fan, card-shuffle, shuffle |
| `augment_pick` | 증강 선택 | card-place, select, click |
| `law` | 새 교칙 찍힘 | impact, stamp, thud, chips-collide |
| `law_drop` | 오래된 교칙 밀려남 | whoosh, slide |
| `promote` | 승급 반짝임 | sparkle, magic, chime, powerup |
| `charge` | 돌진 차징 | charge, whoosh |
| `dash` | 초고속 돌진·발사 | dash, whoosh, swoosh, shot |
| `shot` | 총알 발사 | shot, gun, laser |
| `good` | 좋은 일 (나이스/골인) | win, coin, chime, success |
| `bad` | 나쁜 일 (억까/으악) | lose, fail, buzz, error |
| `game_start` | GAME START 배너 | start, fanfare, impact |
| `win` | 승리 | win, fanfare, victory |

## 출처 표기
쓴 파일의 출처와 라이선스는 저장소 루트 `CREDITS.md`에 적어 주세요 (CC0는 표기 의무가 없지만 기록해 둡니다).

## 현재 들어 있는 소리
Kenney(CC0)의 Casino Audio / Interface Sounds / Impact Sounds / Digital Audio에서 골라 이벤트 이름으로 바꿔 넣었습니다 (`<이벤트>_01.ogg` ...). 같은 이벤트에 파일이 여러 개면 무작위로 재생됩니다. 이벤트 이름 뒤에는 번호만 올 수 있어서(`law_01`은 `law`, `law_drop_01`은 `law_drop`) 이름이 겹치는 이벤트가 섞이지 않습니다. 바꾸고 싶으면 같은 이름으로 덮어쓰면 됩니다.
