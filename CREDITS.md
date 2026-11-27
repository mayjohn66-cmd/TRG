# 크레딧 (외부 소재 출처 및 라이선스)

프로젝트에 사용된 서체, 효과음, 배경 음악, 캐릭터 보이스, 아바타 이미지의 출처와 라이선스 안내다.

---

## 1. 서체 · 아이콘 글리프 (Fonts & Glyphs)

모든 글꼴은 외부 웹폰트 호출이나 사용자 기기 설치 글꼴에 의존하지 않도록 프로젝트 내부(`assets/fonts/`)에 포함해 배포하며, 각 폴더에 라이선스 전문(`OFL.txt`)과 변경·서브셋 명세(`*-NOTICE.md`)를 함께 보관한다.

| 파일 / 자산 | 원본 서체 및 제작자 | 용도 | 라이선스 |
|---|---|---|---|
| `assets/fonts/ONE-Mobile-POP.otf` (`game_ui_font.tres`) | **ONE 모바일 POP체** — ㈜원스토어 ([공식 안내](https://www.onestorecorp.com/sv/fordev_font/)) | 한국어·영어 기본 UI, 카드, 제목 서체 (원본 무수정 포함) | 원스토어 무료 배포 라이선스 (폰트 단독 유상 판매 금지) |
| `assets/fonts/TRGGothic-Bold.ttf` (`game_small_font.tres`) | **나눔고딕 Bold** — NAVER Corp. | 13px 이하 소형 라벨·액션 로그·패드 안내용 한글 서브셋 (예약 글꼴명 규정에 따라 `TRG Gothic`으로 개명) | SIL Open Font License 1.1 (`assets/fonts/OFL.txt`) |
| `assets/fonts/NanumGothic-Regular.ttf` | **나눔고딕 Regular** — NAVER Corp. | 기본·소형 UI 서체에 없는 문자용 보조 폴백 글꼴 | SIL Open Font License 1.1 (`assets/fonts/OFL.txt`) |
| `assets/fonts/MochiyPopOne-Regular.ttf` | **Mochiy Pop One** — Fontworks Inc. / The Mochiy Pop Project Authors (Google Fonts) | 일본어(`日本語`) 선택 시 전역 기본 서체 (가나·기호·JIS 제1수준 한자 약 3,600자 서브셋) | SIL Open Font License 1.1 (`assets/fonts/OFL.txt`) |
| `assets/fonts/mahjong/TRG-Mahjong-Glyphs.ttf` | **Noto Sans JP** — Google / Adobe ([GitHub](https://github.com/google/fonts/tree/main/ofl/notosansjp)) | 리치 마작 판정 도구의 패 표면 한자(`一~九·萬·發·中`) 전용 초경량 서브셋 | SIL Open Font License 1.1 (`assets/fonts/mahjong/OFL.txt`) |
| `assets/fonts/result/*.ttf` · `assets/fonts/victory/*.ttf` | Google Fonts 배포 오픈소스 서체 (`Bangers`, `Black Han Sans`, `Jua`, `DotGothic16`, `Gugi`, `Song Myung`, `Orbitron`, `Goldman`, `Bebas Neue` 등) | 만화 컷 결과창·완주(`FINISH!`)·특수 승리 피날레 연출 문구 전용 서브셋 (`sources.json`에 원본 해시 기록) | SIL Open Font License 1.1 (각 폴더 `*-OFL.txt`) |
| `assets/ui/trickcal/emoji/*.png` · 법전 아이콘 일부 | **Noto Color Emoji** — Google | 인게임 텍스트 내 그림 이모지(`EmojiText`) 및 초기 법전 문양 생성 | SIL Open Font License 1.1 |

---

## 2. 효과음 · 배경 음악 (Audio)

| 파일 | 출처 | 제작자 / 권리자 | 라이선스 |
|---|---|---|---|
| `assets/sfx/*.ogg` (`ui_click`, `hop`, `slam`, `launch`, `thud`, `dice_*`, `card_*`, `augment_*`, `law*`, `good`, `bad` 등) | Kenney **Casino Audio**, **Interface Sounds**, **Impact Sounds**, **Digital Audio** (https://kenney.nl) | Kenney Vleugels (Kenney.nl) | CC0 1.0 (`assets/sfx/licenses/`) |
| `assets/sfx/curated/*.ogg` (`rocket`, `launch`, `dash`, `shot`, `charge`, `good`, `warp`, `trap_set`, `slam` 재선정·가공) | Kenney **Sci-fi Sounds**, **Digital Audio**, **Interface Sounds**, **Impact Sounds**, **RPG Audio** (`manifest.json` 및 `tools/audio/retune_sfx.py` 기록) | Kenney Vleugels (Kenney.nl) | CC0 1.0 (`assets/sfx/curated/licenses/`) |
| `assets/sfx/curated/*.ogg` (`launch` 바람음, `shot`, `warp`, `yut_toss`, `promote`) | OpenGameArt: qubodup *"Swish - bamboo stick weapon swhoshes"*, Ogrebane *"Teleport Spell"*, rubberduck *"25 CC0 bang / firework SFX"*, wobbleboxx *"Level up, power up, Coin get"* | 각 원제작자 | CC0 1.0 (`assets/sfx/curated/licenses/OpenGameArt-CC0.txt`) |
| `assets/bgm/lobby_daylife.ogg` — *DayLife* | EPIDGames 공식 영상 [트릭컬 BGM 맛보기 10탄 - 로비화면 테마](https://www.youtube.com/watch?v=pfsosJ1xPqk) 반복 구간 | Warak / EPIDGames | 원작 음원 (저작권은 원권리자에게 있음) |
| `assets/bgm/battle_monatium_night.ogg` — *모나티엄의 밤 (Monatium Night)* | EPIDGames 공식 영상 [트릭컬 BGM 맛보기 8탄 - 모나티엄의 밤](https://www.youtube.com/watch?v=8Y-wY2kZmZ0) 반복 구간 | Warak / EPIDGames | 원작 음원 (저작권은 원권리자에게 있음) |

---

## 3. 캐릭터 상황별 보이스 (Character Voices)

원작은 EPIDGames의 《트릭컬 리바이브》이며, Trickcal Wiki에 정리된 한국어 대사 항목을 참고해 Godot 재생용 Ogg Vorbis(`24 kHz` 모노)로 변환했다. 공격 컷인은 등장·스테이지 진입 대사, 피격 사출은 퇴장 대사, 필살기는 스킬 강화 대사를 사용한다. 음성과 실연에 대한 모든 권리는 원권리자 및 성우에게 있다.

| 아바타 (캐릭터) | 장면 파일 (`content_trickcal/avatars/<id>/`) | 참고 위키 | 원본 대사 및 음원 |
|---|---|---|---|
| **avatar_01 (에르핀)** | `opening_voice.ogg` | [erpin](https://wiki.cheeky.tsuncloud.com/korea/apostles/erpin) | [Erpin_Spawn1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/erpin/voice_erpin_spawn1/Voice_Erpin_Spawn1.ogg) · 등장 대사 1 |
| 〃 | `attack_voice.ogg` | [erpin](https://wiki.cheeky.tsuncloud.com/korea/apostles/erpin) | [Erpin_Spawn2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/erpin/voice_erpin_spawn2/Voice_Erpin_Spawn2.ogg) · 등장 대사 2 |
| 〃 | `hit_voice.ogg` | [erpin](https://wiki.cheeky.tsuncloud.com/korea/apostles/erpin) | [Erpin_Die2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/erpin/voice_erpin_die2/Voice_Erpin_Die2.ogg) · 퇴장 대사 2 |
| 〃 | `skill_voice.ogg` | [erpin](https://wiki.cheeky.tsuncloud.com/korea/apostles/erpin) | [Erpin_HeroSkill](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/erpin/voice_erpin_heroskill/Voice_Erpin_HeroSkill.ogg) · 스킬 강화 |
| 〃 | `augment_voice.ogg` | [erpin](https://wiki.cheeky.tsuncloud.com/korea/apostles/erpin) | [Erpin_LevelUp](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/erpin/voice_erpin_levelup/Voice_Erpin_LevelUp.ogg) · 레벨업 |
| 〃 | `victory_voice.ogg` | [erpin](https://wiki.cheeky.tsuncloud.com/korea/apostles/erpin) | [Erpin_Victory1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/erpin/voice_erpin_victory1/Voice_Erpin_Victory1.ogg) · 승리 대사 1 |
| 〃 | `special_victory_voice.ogg` | [erpin](https://wiki.cheeky.tsuncloud.com/korea/apostles/erpin) | [Erpin_Victory2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/erpin/voice_erpin_victory2/Voice_Erpin_Victory2.ogg) · 승리 대사 2 |
| **avatar_02 (버터)** | `opening_voice.ogg` | [butter](https://wiki.cheeky.tsuncloud.com/korea/apostles/butter) | [Butter_Spawn1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/butter/voice_butter_spawn1/Voice_Butter_Spawn1.ogg) · 등장 대사 1 |
| 〃 | `attack_voice.ogg` | [butter](https://wiki.cheeky.tsuncloud.com/korea/apostles/butter) | [Butter_Spawn2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/butter/voice_butter_spawn2/Voice_Butter_Spawn2.ogg) · 등장 대사 2 |
| 〃 | `hit_voice.ogg` | [butter](https://wiki.cheeky.tsuncloud.com/korea/apostles/butter) | [Butter_Die2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/butter/voice_butter_die2/Voice_Butter_Die2.ogg) · 퇴장 대사 2 |
| 〃 | `skill_voice.ogg` | [butter](https://wiki.cheeky.tsuncloud.com/korea/apostles/butter) | [Butter_HeroSkill](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/butter/voice_butter_heroskill/Voice_Butter_HeroSkill.ogg) · 스킬 강화 |
| 〃 | `augment_voice.ogg` | [butter](https://wiki.cheeky.tsuncloud.com/korea/apostles/butter) | [Butter_DeckSetting2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/butter/voice_butter_decksetting2/Voice_Butter_DeckSetting2.ogg) · 덱편성 2 |
| 〃 | `victory_voice.ogg` | [butter](https://wiki.cheeky.tsuncloud.com/korea/apostles/butter) | [Butter_Victory2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/butter/voice_butter_victory2/Voice_Butter_Victory2.ogg) · 승리 대사 2 |
| 〃 | `special_victory_voice.ogg` | [butter](https://wiki.cheeky.tsuncloud.com/korea/apostles/butter) | [Butter_Victory1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/butter/voice_butter_victory1/Voice_Butter_Victory1.ogg) · 승리 대사 1 |
| **avatar_03 (엘레나)** | `opening_voice.ogg` | [elena](https://wiki.cheeky.tsuncloud.com/korea/apostles/elena) | [Elena_Spawn1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/elena/voice_elena_spawn1/Voice_Elena_Spawn1.ogg) · 등장 대사 1 |
| 〃 | `attack_voice.ogg` | [elena](https://wiki.cheeky.tsuncloud.com/korea/apostles/elena) | [Elena_Stage](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/elena/voice_elena_stage/Voice_Elena_Stage.ogg) · 스테이지 진입 |
| 〃 | `hit_voice.ogg` | [elena](https://wiki.cheeky.tsuncloud.com/korea/apostles/elena) | [Elena_Die2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/elena/voice_elena_die2/Voice_Elena_Die2.ogg) · 퇴장 대사 2 |
| 〃 | `skill_voice.ogg` | [elena](https://wiki.cheeky.tsuncloud.com/korea/apostles/elena) | [Elena_HeroSkill](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/elena/voice_elena_heroskill/Voice_Elena_HeroSkill.ogg) · 스킬 강화 |
| 〃 | `augment_voice.ogg` | [elena](https://wiki.cheeky.tsuncloud.com/korea/apostles/elena) | [Elena_DeckSetting1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/elena/voice_elena_decksetting1/Voice_Elena_DeckSetting1.ogg) · 덱편성 1 |
| 〃 | `victory_voice.ogg` | [elena](https://wiki.cheeky.tsuncloud.com/korea/apostles/elena) | [Elena_Victory1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/elena/voice_elena_victory1/Voice_Elena_Victory1.ogg) · 승리 대사 1 |
| 〃 | `special_victory_voice.ogg` | [elena](https://wiki.cheeky.tsuncloud.com/korea/apostles/elena) | [Elena_Victory2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/elena/voice_elena_victory2/Voice_Elena_Victory2.ogg) · 승리 대사 2 |
| **avatar_04 (실라)** | `opening_voice.ogg` | [sylla](https://wiki.cheeky.tsuncloud.com/korea/apostles/sylla) | [Sylla_Spawn2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/sylla/voice_sylla_spawn2/Voice_Sylla_Spawn2.ogg) · 등장 대사 2 |
| 〃 | `attack_voice.ogg` | [sylla](https://wiki.cheeky.tsuncloud.com/korea/apostles/sylla) | [Sylla_Stage](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/sylla/voice_sylla_stage/Voice_Sylla_Stage.ogg) · 스테이지 진입 |
| 〃 | `hit_voice.ogg` | [sylla](https://wiki.cheeky.tsuncloud.com/korea/apostles/sylla) | [Sylla_Die2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/sylla/voice_sylla_die2/Voice_Sylla_Die2.ogg) · 퇴장 대사 2 |
| 〃 | `skill_voice.ogg` | [sylla](https://wiki.cheeky.tsuncloud.com/korea/apostles/sylla) | [Sylla_HeroSkill](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/sylla/voice_sylla_heroskill/Voice_Sylla_HeroSkill.ogg) · 스킬 강화 |
| 〃 | `augment_voice.ogg` | [sylla](https://wiki.cheeky.tsuncloud.com/korea/apostles/sylla) | [Sylla_DeckSetting1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/sylla/voice_sylla_decksetting1/Voice_Sylla_DeckSetting1.ogg) · 덱편성 1 |
| 〃 | `victory_voice.ogg` | [sylla](https://wiki.cheeky.tsuncloud.com/korea/apostles/sylla) | [Sylla_Victory2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/sylla/voice_sylla_victory2/Voice_Sylla_Victory2.ogg) · 승리 대사 2 |
| 〃 | `special_victory_voice.ogg` | [sylla](https://wiki.cheeky.tsuncloud.com/korea/apostles/sylla) | [Sylla_Victory1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/sylla/voice_sylla_victory1/Voice_Sylla_Victory1.ogg) · 승리 대사 1 |
| **avatar_05 (셰이디)** | `opening_voice.ogg` | [shady](https://wiki.cheeky.tsuncloud.com/korea/apostles/shady) | [Shady_Spawn1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/shady/voice_shady_spawn1/Voice_Shady_Spawn1.ogg) · 등장 대사 1 |
| 〃 | `attack_voice.ogg` | [shady](https://wiki.cheeky.tsuncloud.com/korea/apostles/shady) | [Shady_Stage](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/shady/voice_shady_stage/Voice_Shady_Stage.ogg) · 스테이지 진입 |
| 〃 | `hit_voice.ogg` | [shady](https://wiki.cheeky.tsuncloud.com/korea/apostles/shady) | [Shady_Die1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/shady/voice_shady_die1/Voice_Shady_Die1.ogg) · 퇴장 대사 1 |
| 〃 | `skill_voice.ogg` | [shady](https://wiki.cheeky.tsuncloud.com/korea/apostles/shady) | [Shady_HeroSkill](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/shady/voice_shady_heroskill/Voice_Shady_HeroSkill.ogg) · 스킬 강화 |
| 〃 | `augment_voice.ogg` | [shady](https://wiki.cheeky.tsuncloud.com/korea/apostles/shady) | [Shady_LevelUp](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/shady/voice_shady_levelup/Voice_Shady_LevelUp.ogg) · 레벨업 |
| 〃 | `victory_voice.ogg` | [shady](https://wiki.cheeky.tsuncloud.com/korea/apostles/shady) | [Shady_Victory1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/shady/voice_shady_victory1/Voice_Shady_Victory1.ogg) · 승리 대사 1 |
| 〃 | `special_victory_voice.ogg` | [shady](https://wiki.cheeky.tsuncloud.com/korea/apostles/shady) | [Shady_Victory2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/shady/voice_shady_victory2/Voice_Shady_Victory2.ogg) · 승리 대사 2 |
| **avatar_06 (다야)** | `opening_voice.ogg` | [daya](https://wiki.cheeky.tsuncloud.com/korea/apostles/daya) | [Daya_Spawn1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/daya/voice_daya_spawn1/Voice_Daya_Spawn1.ogg) · 등장 대사 1 |
| 〃 | `attack_voice.ogg` | [daya](https://wiki.cheeky.tsuncloud.com/korea/apostles/daya) | [Daya_Stage](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/daya/voice_daya_stage/Voice_Daya_Stage.ogg) · 스테이지 진입 |
| 〃 | `hit_voice.ogg` | [daya](https://wiki.cheeky.tsuncloud.com/korea/apostles/daya) | [Daya_Die2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/daya/voice_daya_die2/Voice_Daya_Die2.ogg) · 퇴장 대사 2 |
| 〃 | `skill_voice.ogg` | [daya](https://wiki.cheeky.tsuncloud.com/korea/apostles/daya) | [Daya_HeroSkill](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/daya/voice_daya_heroskill/Voice_Daya_HeroSkill.ogg) · 스킬 강화 |
| 〃 | `augment_voice.ogg` | [daya](https://wiki.cheeky.tsuncloud.com/korea/apostles/daya) | [Daya_LevelUp](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/daya/voice_daya_levelup/Voice_Daya_LevelUp.ogg) · 레벨업 |
| 〃 | `victory_voice.ogg` | [daya](https://wiki.cheeky.tsuncloud.com/korea/apostles/daya) | [Daya_Victory1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/daya/voice_daya_victory1/Voice_Daya_Victory1.ogg) · 승리 대사 1 |
| 〃 | `special_victory_voice.ogg` | [daya](https://wiki.cheeky.tsuncloud.com/korea/apostles/daya) | [Daya_Victory2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/daya/voice_daya_victory2/Voice_Daya_Victory2.ogg) · 승리 대사 2 |
| **avatar_07 (벨리타)** | `opening_voice.ogg` | [belita](https://wiki.cheeky.tsuncloud.com/korea/apostles/belita) | [Belita_Spawn2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/belita/voice_belita_spawn2/Voice_Belita_Spawn2.ogg) · 등장 대사 2 |
| 〃 | `attack_voice.ogg` | [belita](https://wiki.cheeky.tsuncloud.com/korea/apostles/belita) | [Belita_Stage](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/belita/voice_belita_stage/Voice_Belita_Stage.ogg) · 스테이지 진입 |
| 〃 | `hit_voice.ogg` | [belita](https://wiki.cheeky.tsuncloud.com/korea/apostles/belita) | [Belita_Die2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/belita/voice_belita_die2/Voice_Belita_Die2.ogg) · 퇴장 대사 2 |
| 〃 | `skill_voice.ogg` | [belita](https://wiki.cheeky.tsuncloud.com/korea/apostles/belita) | [Belita_HeroSkill](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/belita/voice_belita_heroskill/Voice_Belita_HeroSkill.ogg) · 스킬 강화 |
| 〃 | `augment_voice.ogg` | [belita](https://wiki.cheeky.tsuncloud.com/korea/apostles/belita) | [Belita_DeckSetting1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/belita/voice_belita_decksetting1/Voice_Belita_DeckSetting1.ogg) · 덱편성 1 |
| 〃 | `victory_voice.ogg` | [belita](https://wiki.cheeky.tsuncloud.com/korea/apostles/belita) | [Belita_Victory1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/belita/voice_belita_victory1/Voice_Belita_Victory1.ogg) · 승리 대사 1 |
| 〃 | `special_victory_voice.ogg` | [belita](https://wiki.cheeky.tsuncloud.com/korea/apostles/belita) | [Belita_Victory2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/belita/voice_belita_victory2/Voice_Belita_Victory2.ogg) · 승리 대사 2 |
| **avatar_08 (죠안)** | `opening_voice.ogg` | [joanne](https://wiki.cheeky.tsuncloud.com/korea/apostles/joanne) | [Joanne_Spawn1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/joanne/voice_joanne_spawn1/Voice_Joanne_Spawn1.ogg) · 등장 대사 1 |
| 〃 | `attack_voice.ogg` | [joanne](https://wiki.cheeky.tsuncloud.com/korea/apostles/joanne) | [Joanne_Stage](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/joanne/voice_joanne_stage/Voice_Joanne_Stage.ogg) · 스테이지 진입 |
| 〃 | `hit_voice.ogg` | [joanne](https://wiki.cheeky.tsuncloud.com/korea/apostles/joanne) | [Joanne_Die1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/joanne/voice_joanne_die1/Voice_Joanne_Die1.ogg) · 퇴장 대사 1 |
| 〃 | `skill_voice.ogg` | [joanne](https://wiki.cheeky.tsuncloud.com/korea/apostles/joanne) | [Joanne_HeroSkill](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/joanne/voice_joanne_heroskill/Voice_Joanne_HeroSkill.ogg) · 스킬 강화 |
| 〃 | `augment_voice.ogg` | [joanne](https://wiki.cheeky.tsuncloud.com/korea/apostles/joanne) | [Joanne_Equipment](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/joanne/voice_joanne_equipment/Voice_Joanne_Equipment.ogg) · 장비 |
| 〃 | `victory_voice.ogg` | [joanne](https://wiki.cheeky.tsuncloud.com/korea/apostles/joanne) | [Joanne_Victory1](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/joanne/voice_joanne_victory1/Voice_Joanne_Victory1.ogg) · 승리 대사 1 |
| 〃 | `special_victory_voice.ogg` | [joanne](https://wiki.cheeky.tsuncloud.com/korea/apostles/joanne) | [Joanne_Victory2](https://cheeky.tsuncloud.com/deploy/com.epidgames.trickcalrevive/audio/audio/kor/voice/hero/joanne/voice_joanne_victory2/Voice_Joanne_Victory2.ogg) · 승리 대사 2 |

---

## 4. 아바타 이미지

| 폴더 | 캐릭터 | 출처 및 제작 방식 |
|---|---|---|
| `content_trickcal/avatars/avatar_01` ~ `avatar_08` | 에르핀, 버터, 엘레나, 실라, 셰이디, 다야, 벨리타, 죠안 | 《트릭컬 리바이브》(EPIDGames)의 정식 공개 캐릭터를 기반으로 구성. 팬 제작 스파인 뷰어(`viewer.dclnslde.com`) 재생 화면에서 감정별 프레임(`idle·happy·angry·surprised·sad·cheer`, 10fps)과 로비 대기 동작(`idle_hq` 1024px WebP / 저화질 `idle_lq` 640px WebP, 아바타별 개별 `.pck` 분리 로드)을 추출해 사용하며, 추출 설정과 해시는 각 폴더 `README.md` 및 `manifest.json`에 기록했다. 원작 캐릭터의 저작권은 원작 제작사에 있다. |

---

## 5. 비공식 팬 제작 안내

- 이 게임은 원작 《트릭컬 리바이브》의 제작사(EPIDGames)와 무관한 **비공식 팬 제작 게임**이며 공식 저작물이 아니다.
- 개인이 **비영리 목적**으로 **무료 배포**하는 2차 창작물이며, 광고·후원·유료 판매 등 일체의 수익 활동을 하지 않는다.
- 원작의 공식 회사 로고 및 게임 타이틀 로고 리소스는 사용하지 않는다.
- 아바타에 사용되는 원작 캐릭터의 권리는 원작 제작사(EPIDGames)에 있으며, 원작의 2차 창작 가이드라인 범위 안에서 **정식 공개된 사도만** 사용한다(미공개 데이터 미사용).
- 원권리자의 삭제·중단 요청이 있을 경우 즉시 배포를 중단하거나 해당 리소스를 제거한다(`content_trickcal/avatars/` 폴더 제거 시 기본 도형 아바타 폴백으로 동작하도록 분리 설계됨).
