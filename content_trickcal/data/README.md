# 밸런스 표 (CSV) 사용법

엑셀·구글 스프레드시트·메모장으로 열어서 고친 뒤 저장(UTF-8, CSV)하면 다음 실행부터 바로 반영됩니다. 웹 배포는 `git push`만 하면 이 파일들이 함께 패키징됩니다.

| 파일 | 내용 |
|---|---|
| `augments_table.csv` | 모든 증강 + 규칙 수치(`RULE_*`) |
| `dice_table.csv` | 판정 도구 13종 |
| `cards_table.csv` | 생떼 카드 32종 |
| `ui_strings.csv` | 화면 문구 (key, ko, en, ja) - 다국어 대비 |
| `translations.csv` | 코드에 있는 한국어 문구의 영어·일본어 (ko, en, ja) - 영어·일본어 화면이 그릴 때 번역 |

> 쉼표가 들어간 칸은 큰따옴표로 감쌉니다(엑셀이 알아서 해 줍니다). 줄바꿈은 칸 안에 `\n`이라고 적습니다. 비워 둔 칸은 코드 기본값을 씁니다.

## augments_table.csv
| 열 | 설명 |
|---|---|
| `id` | 증강 ID (바꾸지 마세요) |
| `enabled` | `TRUE`/`FALSE`. FALSE면 드래프트에 나오지 않습니다 |
| `category` | `PAWN`(기물) `DICE`(판정 도구) `LAW`(교칙) `CARD`(카드 패키지) `CHAOS`(초증강) `UTIL`(범용 보급) `RULE`(규칙 수치 행, 드래프트 아님) |
| `tier` | 카드 테두리: `NORMAL` / `GOLD`(금빛) / `PRISMA`(보라 후광+금 테두리, 초증강) / `HOLO`(크리스탈 청록+무지개 후광, 법전 전용 희귀) |
| `weight` | 등장 가중치(기본 100, 초증강 50). 0이면 제외. 한 계열 안에서는 비율대로, 계열 사이에서는 평균 가중치 비율대로 뽑힙니다 |
| `min_round` | 이 라운드부터 등장 |
| `title` `subtitle` `desc` `spec_preview` | 카드 제목 / 위쪽 계열 표시 / 효과 설명 / 족보·공식 요약. `{p1}` `{p2}`는 아래 param 값으로 바뀝니다. `DICE` 행의 spec_preview를 비우면 dice_table의 `spec_table`을 씁니다 |
| `param_1` `param_2` | 실제 게임 수치 (아래 표) |
| `target_ref` | 연결 대상 ID (`DICE`=도구 ID, `LAW`=교칙 ID, `CARD`=카드 종류 `COUNTER`/`TRAP`/`TRAP_CORNER`/`INSTANT`/`SUMMON`, `+`로 이으면 param_1·param_2장씩) |
| `icon_file` | 아이콘 파일. `content_trickcal/illustrations/` 아래 상대 경로 또는 `res://` 전체 경로 |

새 행 추가: `DICE`(target_ref=도구 ID)·`LAW`(target_ref=교칙 ID)·`CARD`(카드 패키지, param_1=장수, target_ref=카드 종류) 행은 새 id로 추가하면 새 증강이 됩니다. 기물·초증강은 로직이 필요해 새로 만들 수 없습니다.

### param이 바꾸는 수치
| id | param_1 | param_2 |
|---|---|---|
| `CARD_PACKAGE`(및 새 CARD 행) | 받는 카드 수 | (target_ref가 `A+B`면 B 종류 장수) |
| `UTIL_01` 랜덤 변이 물약 | 변이 뒤 전진 칸 | |
| `UTIL_03` 필살기 리필 주사 | 받는 카드 수 | |
| `AUG_LAW_01`~`08` 특수 승리 교칙 | 목표 수치 (처치 6 · 손패 5 · 설치물 5 · 한방 16칸 · 포위망 4 · 사출 8 · 연속 굴림 4 · 다크호스 3) | |
| `SUPER_01` 판 뒤집기 | 완주 확률(%) | |
| `SUPER_03` 악마의 계약 | 영구 가속 칸 | |
| `SUPER_02` 재분배 | 다시 나눠 주는 카드 수 | |
| `SUPER_04` 지뢰밭 | 지뢰 개수 | 함정 카드 수 |
| `SUPER_05` 도적단 | 도적떼(왼쪽 줄) 수 | 팩맨(오른쪽 줄) 수 |
| `SUPER_06` 도박사 | 이동 배수 | 이 눈금 이하면 과열 |
| `SUPER_08` 빵집 털이 | 받는 카드 수 | |
| `SUPER_09` 저격수 | 내 말 전진 칸 | |
| `SUPER_10` 아우토반 니트로 | 추가 칸 | 홀수라도 가속하는 최소 눈금 |
| `SUPER_11` 폭주 기관차 | (수치 없음: 무작위 한 변을 기관차가 쓸고 지나간다) | |
| `EVO_7_2` 루도 복수자 | 리벤지 부스터 발동 시 추가 전진 칸 (기본 4) | |
| `RULE_REVENGE_BOOST` 🔥 | 복수 부스터 칸 | |
| `RULE_DASH_PAD` ⚡ | 발판 추가 전진 칸 | |
| `RULE_LEAPFROG` 🏃 | 말 하나당 칸 | 한 번에 최대 칸 |

`RULE_*` 행은 `enabled=FALSE`로 그 기믹 자체를 끌 수 있습니다. 특수 승리 교칙(`LAW`)과 초증강(`CHAOS`) 행은 7라운드(세 번째 드래프트)부터 나옵니다 (`min_round` 7). 첫 드래프트(1라운드)는 기물 진화(`PAWN`)만, 두 번째(4라운드)는 판정 도구(`DICE`)·카드(`CARD`)·기물 진화만 제시합니다 (`AugmentRegistry.DRAFT_FOCUS`, 그 계열에 받을 수 있는 증강이 모자라면 다른 계열로 채움).

## dice_table.csv
`enabled`(FALSE면 교체 증강에서 빠짐, 기본 주사위 D6는 제외) · `name`(도구 이름) · `desc`(도구 카드 한 줄) · `spec_table`(족보표 문구) · `min_step`/`max_step`(이동 칸을 이 범위로 맞춤. 0칸·턴 종료 결과는 건드리지 않음, 비우면 제한 없음) · `jackpot_step`(그 도구의 최고 결과 칸 수를 이 값으로 교체, 상한과 무관. 윷·홀덤·슬롯·화투·마작·야추·블랙잭·핀볼만 지원) · `icon_file`(`illustrations/dice/` 아래).

## cards_table.csv
`enabled`(FALSE면 덱과 카드 패키지에서 빠짐) · `type`(COUNTER/INSTANT/TRAP/TRAP_CORNER/SUMMON, 표시용) · `name` · `parody_quote`(툴팁에 나오는 출처 문구) · `desc`(카드 확대 설명, `{p1}`) · `param_1`(수치: 싸이크론 전진 `CNT_05`, 우노 +4 폭탄 이동 보너스 `ACT_03`, 로켓 `ACT_04`, 결투 승자 전진 `ACT_09`, 빠루 범위 `ACT_10`, 알고리즘 밴 턴 `ACT_14`, 나락 최소 눈금 `TRP_02`, 지뢰 반경 `TRP_03`, 도미노 연쇄 반경 `TRP_05`, 바나나 미끄러짐 `TRP_06`, 무인도 유지 턴 `TRP_C01`, 소원빌기 점프 칸 `TRP_C02`, 지나가는 상인 유지 턴 `TRP_C03`, 물의 세례 끌어오기 범위 `TRP_C04`) · `param_2`(덱에 들어가는 장수) · `icon_file`(`assets/cards/` 아래).

## 번역 열 (다국어 대비)
세 표 끝의 `*_en` / `*_ja` 열(증강 `title`·`subtitle`·`desc`·`spec_preview`, 도구 `name`·`desc`·`spec_table`, 카드 `name`·`parody_quote`·`desc`)에 번역을 적으면 그 언어일 때 그 값을 씁니다. 비워 두면 한국어 열을 씁니다. 화면 버튼·알림 문구는 `ui_strings.csv`의 `en`·`ja` 열에 적습니다 (`{p1}`·`%s` 같은 자리 표시는 그대로 두세요).
영어·일본어는 원문(한국어)을 그대로 두고 화면에 그릴 때 번역합니다. 언어마다 표의 `*_en`/`*_ja` 열·`ui_strings.csv`의 `en`/`ja` 열·`translations.csv`의 `en`/`ja` 열(코드 문구, `%d라운드 시작!` 같은 형식 틀은 틀 그대로 적고 `%`·`{p1}` 순서를 지킵니다)가 한 사전이 됩니다. 코드에 새 한국어 문구를 넣고 `translations.csv`에 영어·일본어를 안 넣으면 `tests/test_l10n.gd`가 알려 줍니다.

## 주의
- 온라인 대전은 모든 참가자가 같은 CSV로 빌드된 같은 버전을 써야 합니다 (값이 다르면 시뮬레이션이 어긋납니다).
- 값이 잘못되면(글자 등) 그 칸은 비어 있는 것처럼 코드 기본값을 씁니다. 파일 전체가 없어도 게임은 기본값으로 돕니다.
