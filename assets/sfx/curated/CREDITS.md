# 고른 게임 효과음

여기서 쓰는 원본 녹음은 모두 **CC0 1.0**이다. 고쳐서 게임과 함께 다시 배포할 수 있다. 출처 표기는 자발적으로 남긴다.

| 제작자 | 원본 묶음 |
| --- | --- |
| Kenney | [UI Audio](https://kenney.nl/assets/ui-audio) |
| Kenney | [Interface Sounds](https://kenney.nl/assets/interface-sounds) — 공지 열기·닫기 |
| Kenney | [Digital Audio](https://kenney.nl/assets/digital-audio) — 새 도구·마법 신호 |
| Kenney | [Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds) — 광선·충전·바람 층 |
| Kenney | [Casino Audio](https://kenney.nl/assets/casino-audio) |
| Kenney | [Impact Sounds](https://kenney.nl/assets/impact-sounds) |
| Kenney | [Music Jingles](https://kenney.nl/assets/music-jingles) |
| Robin Lamb | [UI sound effects](https://opengameart.org/content/ui-sound-effects-button-clicks-user-feedback-notifications) |
| rubberduck | [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) |
| AntumDeluge | [Bicycle horn](https://opengameart.org/content/bicycle-horn) — 아이 장난감 플라스틱 나팔 |

라이선스: https://creativecommons.org/publicdomain/zero/1.0/

`manifest.json`에 파일마다 원래 이름·원본 URL·제작자·원본 해시·가공 방법·결과 해시를 적었다. Kenney 라이선스 안내문은 `licenses/`에 있다.

사건 34개에 모노 Vorbis 44.1kHz 39개, 모두 약 285KiB. 원래 무음은 잘라 내고, 가장자리는 페이드, 거친 극단은 필터로 줄이고, 최대 음량은 역할에 맞춰 조정했다. 마작 착지 두 개는 카지노 칩 녹음에서, 윷 던지기는 카드 부채 바스락 소리에서 만들고 착지에는 실제 나무 소리를 쓴다. 장난감 총은 빈 약실에 기계 스위치 소리, 깃발에 플라스틱 나팔을 쓴다. 실제 총기 발사 녹음은 쓰지 않는다.

생성된 `catalog.gd`가 옛 무작위 후보보다 먼저 쓰인다. `content_trickcal/audio/sfx/`의 사용자 파일은 여전히 그 사건의 소리 묶음 전체를 대신한다.

## 새 콘텐츠 소리 (2026-11-04)

다트·주식·강화 대장간·기억상실빔·양성자빔·오이 동작·구르는 몸·테마별 승리 도입·만화 결과 쪽을 위한 짧은 모노 Vorbis 40개. 원본은 Kenney CC0 Digital Audio, Sci-fi Sounds, Impact Sounds, Casino Audio, Interface Sounds다. `manifest.json`에 원본 해시·필터·측정한 음량을 적었고, 원본 라이선스 안내문은 `../licenses/`에 있다. 반복용 파일은 장면이 소유한 복사본을 쓰기 전까지 반복하지 않는 리소스로 둔다.

캐릭터 대사 녹음은 바뀌지 않았다. `voice_gains.gd`가 기존 고르기 대사 8개에 측정한 녹음별 재생 음량을 적용한다. 이 사용자 제공 캐릭터 녹음은 CC0 효과음 묶음과 별개다. 다시 만들려면 `tools/audio/curate_sfx.py`를 쓴다 (NumPy·FFmpeg 필요).

할리갈리는 Kenney의 `impactBell_heavy_000.ogg`(Impact Sounds, CC0)에서 만든 0.72초 `halli_bell_01.ogg`를 더한다. 작은 게임 종에 맞게 음을 올리고, 줄이고, 페이드하고, 음량을 맞췄다. 이 소리만 따로 다시 만들려면 `tools/audio/add_halli_bell.py`를 쓴다. 가공과 해시는 manifest에 있다.

## 연출 효과음 (2026-10-26)

사건 9개를 위한 모노 Vorbis 12개(24kHz, 약 68KiB): 레일 깔기, 기관차 칙칙폭폭·기적, 사슬 당기기·채우기, 빵집 문·소동, 습격 컷인 베기, 핀볼 금속 접촉. 기존 애니메이션·접촉 지점의 상관없는 일반 소리를 대신한다.

| 제작자 | 원본 | 녹음 |
| --- | --- | --- |
| rubberduck | [80 CC0 RPG SFX](https://opengameart.org/content/80-cc0-rpg-sfx) | chain_01/02, lock_03, blade_03, metal_01/03, wood_03 |
| Brian MacIntosh (BMacZero) | [Mechanical Sounds](https://opengameart.org/content/mechanical-sounds) | clank1, rattle1, squeakyclick1 |
| Joseph Sardin / Axeline T. | [Train whistle, foley #6](https://bigsoundbank.com/train-whistle-foley-6-s3320.html) | 기관차 기적 소리, 녹음 3320 |

세 원본 모두 이 녹음을 CC0로 명시해 공개했다. 안내문은 `licenses/Presentation-CC0.txt`에 있다. 이 추가분만 다시 만들려면 `tools/audio/add_presentation_sfx.py`를 쓴다. manifest에 원본·결과 해시, 자르기, 음 높이 변경, 필터, 페이드, 목표 음량을 적었다. 압축하지 않은 받은 파일은 게임 내보내기 밖에 둔다.
