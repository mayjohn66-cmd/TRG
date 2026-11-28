# 초증강 엘리아스 마블 — AI 협업 전달사항 · 작업 지시판 (AI Handoff Board)

> **역할:** 기획 담당(사용자 · 기획 AI)이 개발·아트·QA 등 **다른 AI 에이전트(예: Claude Code 등)에게 전달할 필수 규칙과 작업 지시사항**을 기록·인계하는 공식 게시판이다.
> **단일 기준서 위치:** `docs` 브랜치 (`https://github.com/mayjohn66-cmd/TRG/tree/docs`)

> [!IMPORTANT]
> **다른 AI 에이전트 작업 시작 전 필독**
> 코드를 수정하거나 새 에셋을 추가하기 전에 아래 **`1절` 공통 절대 수칙**과 **`2절` 진행 대기 전달사항**을 먼저 확인하라. 기획서에 없는 수치·UI 치수·폴리곤 상한·규칙을 임의로 추정해 적용하지 말고, 불명확한 항목은 작업 전 기획 담당(사용자)에게 확인한다.

---

## 목차

1. [모든 AI 공통 절대 수칙 (임의 변경 금지)](#1-모든-ai-공통-절대-수칙-임의-변경-금지)
2. [현재 전달사항 · 작업 대기 목록 (Active)](#2-현재-전달사항--작업-대기-목록-active)
3. [신규 전달사항 작성 양식 (복사용 템플릿)](#3-신규-전달사항-작성-양식-복사용-템플릿)
4. [완료된 전달사항 아카이브 (Done)](#4-완료된-전달사항-아카이브-done)

---

## 1. 모든 AI 공통 절대 수칙 (임의 변경 금지)

| 번호 | 절대 수칙 | 세부 기준 및 참조 문서 |
|---|---|---|
| **1** | **4브랜치 역할 준수** | `docs`(기획서 · AI 인계 문서 전용 · 배포 없음) / `dev`(현재 버전 개발 · 실시간 패치 · 푸시 시 자동 테스트 후 `web` 배포) / `next`(다음 버전 패치 · 신규 기능 개발 · 미배포) / `web`(자동 빌드 산출물 · 수동 수정 금지). 기획 변경은 `docs`가 최신 기준이며, 다른 AI에게 전달할 내용은 반드시 이 문서에 기록한다 *(사용자 지시 `2026-11-28`)* |
| **2** | **전 구간 시각·청각 비침범 불변식** | 도구·특수 발판(자판기·가마솥·상점·정령·워프·발판)·이동·처치·중립 기물·템포 업·배너 등 **모든 연출은 화면 퇴장과 사운드가 끝날 때까지 `await`**한 뒤 다음 스텝(효과음·봇 차례 포함)을 시작한다. Fire-and-forget 조기 반환 금지 ([`EDGE_CASE_SPEC.md` 2.1절](EDGE_CASE_SPEC.md#21-단일-fifo-연출-대기열과-비침범-불변식)) |
| **3** | **3D 모델 폴리곤 · 저용량 상한** | 런타임 상한: **S급 `≤ 1,500 tris / 30 KB` · M급 `≤ 3,500 tris / 80 KB` · L급 `≤ 6,500 tris (최대 8,000) / 200 KB`** · 전체 번들 `≤ 150,000 tris / 4.0 MiB` · 텍스처 `≤ 512px`. **원본 `.glb` 직접 참조 금지**(`optimized/vN/` 압축 `.scn`/`.res`만 참조), `SubViewport ≤ 1.5×` · `MSAA_2X` 상한 · 비활성 `32×32` 파킹 ([`Visual_Asset_Guide_Draft.md` 6절](visual/Visual_Asset_Guide_Draft.md#6-3d-모델링-폴리곤-수--저용량-운영-상한-규격-131-전수-계측)) |
| **4** | **UI 버튼 크기 · 배치 좌표 고정** | 기준 해상도 **`1366 × 768`**(`SAFE_MARGIN = 12px`)의 지정 좌표·크기, 모바일 최소 버튼 높이 **`48px`**(메뉴·리롤 `64px`), `FontSizes.LADDER` 폰트 사다리를 임의로 바꾸지 않는다 ([`Visual_Asset_Guide_Draft.md` 7절](visual/Visual_Asset_Guide_Draft.md#7-화면별-ui-버튼-크기--배치-좌표-고정-규격-1366768)) |
| **5** | **확정 아트 · 카드 용어 · 검증 게이트** | 생떼 카드는 4대 분류(`방어·발동·함정·소환`)와 통일 용어 규약([`GDD_TDD_Master.md` 4.4절](GDD_TDD_Master.md#44-생떼-카드-52종--기본-덱-89장-통일-명세))을 따르고, 확정 아트 5건([`Visual_Asset_Guide_Draft.md` 6.3절](visual/Visual_Asset_Guide_Draft.md#63-사용자-확정-3d--아트-회귀-방지-고정-사항-131-인계-확정))을 임의로 되돌리지 않는다. 작업 완료 전 `lowpoly_models_test` · `ui_web_3d_budget_test` · `ui_overlap_audit` 통과 필수 |
| **6** | **연출 물리 인과 (장식 소품 금지)** | 화면의 3D 소품(야추 컵·핀볼 손잡이·다트 과녁·캡슐 레버·가마솥 등)은 정지 배경 장식이 아니라 결과물을 실제로 내보내는 작동 주체로 구현한다. 도구 21종·특수 발판·컷신의 동작과 금지 안티패턴은 [`PRESENTATION_SPEC.md`](PRESENTATION_SPEC.md)를 따른다 |

---

## 2. 현재 전달사항 · 작업 대기 목록 (Active)

> 상태 표기: `대기(TODO)` · `진행중(IN_PROGRESS)` · `검토요청(REVIEW)` · `보류(HOLD)`

### 한눈에 보는 대기 목록

| ID | 우선순위 | 상태 | 대상 역할 | 대상 브랜치 | 요약 |
|---|---|---|---|---|---|
| **`HANDOFF-015`** | `P1` | `대기(TODO)` | 개발 · 아트 AI | **`dev`** | 정령산 `LAW_02` 특수 승리 **「정령 원기옥 (`SPIRIT BOMB!`)」** 패러디 개편(구 `정령산 순례` 교체) 및 전용 2D 원기옥 컷신·아이콘·SFX 구현 |
| **`HANDOFF-012`** | `P1` | `검토요청(REVIEW)` | 개발 · 아트 AI | **`dev`** | 규칙 도감 UI/UX 종합 개선 10건 (`UI-01 ~ UI-10`: 카드 5필터, 상세 팝업 전체 암전·닫기 구분, 백업 팝업 대비·닫기, 특수 칸 미니보드 잘림 해소 등) |
| **`HANDOFF-014`** | `P2` | `대기(TODO)` | QA · 개발 AI | **`dev`** | 전역 UI 겹침 감사(`tests/ui_overlap_audit.gd`)의 구 첫 증강 fixture를 현행 4R 드래프트 기준으로 갱신 |
| **`HANDOFF-003`** | `P2` | `보류(기획 대기)` | 개발 · 3D 아트 AI | `next` | `1.4` 마스터 기획 초안([`V1_4_UPDATE_PLAN.md`](V1_4_UPDATE_PLAN.md) — 유령 늪·도구 14종·기물 16종·특수 승리 10종·카드 23종·증강 8종) 사용자 패러디·최종 선별 확정 전 선구현 금지 |

---

### `[HANDOFF-015]` 정령산 `LAW_02` 특수 승리 「정령 원기옥 (`SPIRIT BOMB!`)」 패러디 개편 및 전용 컷신·아이콘 구현

- **대상 역할 / 브랜치:** 개발 · 2D 아트 AI (`core_engine/board/board_catalog.gd` · `scenes/spirit_bomb_stage.gd` · `scenes/law_victory_prelude.gd` · `scenes/presentation_audio.gd` · `scenes/sfx.gd` · `scenes/victory_title_geometry_data.gd` · `assets/ui/illustrations/laws/LAW_02_SPIRIT_BOMB.png` · `content_trickcal/data/translations.csv`) / **`dev` (1.3.x 실시간 개선)**
- **우선순위 / 상태:** `보통(P1)` / `대기(TODO)`
- **전달 내용 (사용자 확정 `2026-11-28`):**
  - 기존 정령산 `LAW_02` 임시 명칭(**`정령산 순례`** / `SPIRIT PILGRIMAGE` · 에르핀 식권 6장 연출 재사용)을 폐기하고, **《드래곤볼》 원기옥 (`Spirit Bomb` = 정령 + 원기옥 이중 패러디)**으로 전면 개편한다.
  - **1. `BoardCatalog` 텍스트 · 테마 · 번역 갱신:**
    - `SHOP_KINDS[&"spirit"]`: `law_tag = "[기운 목표]"`, `visit_stamp = "정령의 기운 모음! (%d/%d)"`
    - `spirit_mountain` → `law_variants["LAW_02"]`:
      - `name`: `"정령 원기옥"` · `condition`: `"정령 칸에 {p1}회 멈춤"` *(목표 `6회`, `bakery` 키·땅 정령 정차 집계 유지)*
      - `card_title`: `ko: "[특수 승리] 정령 원기옥"`, `en: "[Special Win] Spirit Bomb"`, `ja: "[特殊勝利] 精霊元気玉"`
      - `win_reason`: `"정령들아, 나에게 힘을 조금만 나눠줘! — 특대 정령 원기옥 완성!"`
      - `result_phrase`: `"SPIRIT BOMB!"` · `geometry_key`: `"LAW_02:S"`
      - `icon`: `"laws/LAW_02_SPIRIT_BOMB.png"` · `stage`: `&"spirit_bomb"`
      - `theme`: `{"font": "bungee", "headline": "SPIRIT BOMB!", "lines": "SPIRIT\nBOMB!", "ink": "0b2533", "accent": "2cc7c2", "tilt": -0.055}`
      - `paper`: `"e3f6f7"` · `comic_title`: `{"upper": "aef5ff", "lower": "ffffff", "shadow": "126b7a"}`
    - `victory_title_geometry_data.gd`의 `"LAW_02:S"` 글자 윤곽 데이터를 `SPIRIT\nBOMB!`로 재생성하고 `translations.csv`에 한·영·일 신규 문구를 동시 추가한다.
  - **2. 전용 도입 무대 구현 (`scenes/spirit_bomb_stage.gd`, `LawVictoryPrelude.STAGES[&"spirit_bomb"]`):**
    - `bad_carrot_stage.gd` · `monatium_cash_stage.gd`와 동일한 **결정론적 Seekable 2D 무대**(`setup(focus, source_view)` + `seek(time, view)` + `_draw()` · 내부 `Timer`/`randf()` 금지).
    - **타이밍 상수:** `COUNT = 6` · `GATHER_START = 0.22` · `GATHER_INTERVAL = 0.23` · `ORB_FLIGHT = 0.26` · `DROP_START_AT = 1.88` · **`IMPACT_AT = 2.26`** · **`INTRO_SECONDS = 2.86`** · `FADE_SECONDS = 0.40` · `DIM_TARGET = 0.78` · `DIM_RAMP_END = 0.85`.
    - **3단계 시각 시퀀스:** ① `0.22~1.63s`: 6방향에서 4원소 색(`불 #ff7a3d · 물 #38bdf8 · 땅 #c89b54 · 바람 #52e5b7`) 정령 빛방울 6묶음이 상단(`focus - 165px`)으로 곡선 흡입, 매 합류마다 구체 반지름 6단계(`22→136px`) 탄성 팽창 + 바닥 그림자 확대 → ② `1.63~2.26s`: 하늘·청록 이중 오라 + 6갈래 결정론 전기 아크 맥동 후 `1.88s`부터 `ease_in` 수직 투하 → ③ `2.26~2.86s`: 중앙 백색·시안 섬광 링 + 방사형 충격파 + 4원소 불티 확산 → `SPIRIT BOMB!` 만화 타이틀 핸드오프.
  - **3. 효과음 큐 (`presentation_audio.gd` · `sfx.gd`):**
    - `0.22 + i * 0.23s` (`i = 0..5`): 합성음 `spirit_orb_gather` · `1.88s`: `dash (-4.0 dB)` · `2.26s`: `hero_impact (-3.0 dB)` + 합성음 `spirit_bomb_burst`.
  - **4. 전용 아이콘 (`assets/ui/illustrations/laws/LAW_02_SPIRIT_BOMB.png`):**
    - `≤ 512×512` PNG(문자 없음), 정령산 밤하늘 위 거대 청록·하늘빛 원기옥 구체에 불·물·땅·바람 4색 정령 빛방울이 빨려 드는 구도.
- **반드시 지킬 제약:**
  - `golden_ticket_stage.gd` 폴백 및 구 `정령산 순례` / `SPIRIT PILGRIMAGE` 문자열 잔존 금지
  - 3D 모델 추가 없음(순수 2D Seekable + `≤ 512px` 아이콘 1장), 전체 비침범 `await` 및 `1x`/`3x` 배속 일관성 유지
- **참조 기획서:** [`PRESENTATION_SPEC.md` 5.1절](PRESENTATION_SPEC.md#51-law_02-보드별-전용-승리-컷신--정령산-정령-원기옥-spirit-bomb-확정-규격) · [`GDD_TDD_Master.md` 4.0절·4.3절](GDD_TDD_Master.md#40-테마-보드판-4종과-전용-기믹)
- **완료 기준 (검증):**
  - 정령산 `LAW_02` 승리 컷신 `seek()` 프레임/도감 미리보기 확인(구 `식권`·`SPIRIT PILGRIMAGE` 미노출)
  - 단위 테스트 · `test_augment_art` · `ui_rulebook_scroll_test` · `ui_text_fit` (한·영·일) 통과

---

### `[HANDOFF-012]` 규칙 도감(`scenes/rulebook.gd`) UI · UX 종합 개선 10건 (`UI-01 ~ UI-10`)

- **대상 역할 / 브랜치:** 개발 · UI 아트 AI (`scenes/rulebook.gd` · `assets/ui/trickcal/board_preview/{classic,monatium}.webp` · `content_trickcal/data/translations.csv`) / **`dev` (1.3.x 실시간 패치)**
- **우선순위 / 상태:** `보통(P1)` / `검토요청(REVIEW)`
- **전달 내용 (실서비스 시각 검수 + 사용자 승인 `2026-11-28`):**
  - 상세 치수·색상·동작은 [`RULEBOOK_SPEC.md` 4절](RULEBOOK_SPEC.md#4-규칙-도감-ui--ux-종합-개선-확정-규격-10건-handoff-012) 및 [`Visual_Asset_Guide_Draft.md` 7.5절](visual/Visual_Asset_Guide_Draft.md#75-규칙-도감-rulebook--1366--768-고정-스테이지)의 **`UI-01 ~ UI-10`** 규격을 그대로 구현한다.
  - **P0 (탐색·조작 최우선):**
    - `UI-01`: `[도감] → [카드]` 상단에 5개 분류 필터 알약 탭 신설 (`전체` · `방어(#4C6EF5)` · `발동(#D98B2B)` · `함정(#8E4AA8)` · `소환(#2F9A85)`, 장수 동적 집계, 상세 팝업 `[◀ 이전]`/`[다음 ▶]`도 필터 목록 내 순환)
    - `UI-02`: 상세 팝업 암전 막(`_popup_dim`)을 도감 전체 화면(`PRESET_FULL_RECT`, `alpha = 0.65`)으로 확장 + 바깥 클릭 닫기 + 하단 `[닫기]` 버튼 색상 분리(`#5f4630`, 흰 글씨) + 우상단 `[×]` 닫기 버튼(`44×44`) 추가
    - `UI-03`: `[기록 백업/복구]` 팝업 `_code_field`에 밝은 `LobbyTheme.input_field()` 스킨(`#EEFFA8` / `#1B4D3E`) 적용 + 우상단 `[×]` 버튼(`36×36`) 및 바깥 클릭 자동 닫기
  - **P1 (잘림·가독성):**
    - `UI-04`: `[기본 규칙] → [특수 칸]` 좌측 노트 `MiniBoard`를 `276×276`으로 축소해 초기 화면에서 `0번 출발선`까지 스크롤 없이 100% 노출 *(보드 상세 팝업 `320×320` 유지)*
    - `UI-05`: `EntryDetailScroll`·`CatalogScroll`을 `SCROLL_MODE_AUTO`로 전환해 불필요한 스크롤바 제거 + 짧은 상세 팝업(본문 높이 55% 미만) 세로 중앙 균형 배치
    - `UI-06`: 도감 스크롤 하단 `margin_bottom = 18px` 확보 및 `풀 파워`·`보드연성진` 끝줄 잘림 해소 + `BoardVariantButton`을 단순 `(→)` 대신 `보드 1/4 ▶` 칩 라벨(또는 상세 팝업 내 보드 전환 탭)로 직관화
    - `UI-07`: `[잡기]` 우측 방어 타일 5종 중 세부 4종 아이콘 차별화 (기존 에셋 조합 재사용, 추가 용량 `0 KB`)
  - **P2 (균형·폴리싱):**
    - `UI-08`: 좌측 챕터 버튼 열 `(28, 136)` · 각 `196×60`(`sep 7px`), 하단 `N / 11` 리본 `y = 716, H = 40` 안착, 우상단 메달 경계 여백 확보(상세 팝업 `[×]` 충돌 회피)
    - `UI-09`: `classic.webp` · `monatium.webp` 보드 미리보기(`640×400`)를 중앙 `[굴리기]` HUD 없는 클린 캡처로 통일
    - `UI-10`: `[한 턴]` `① 카드` 설명 간결화(`"굴리기 전에 카드 1장 · 필살기 사용 (안 써도 돼요)"`) 및 하단 `꿀팁` 상자 초기 잘림 해소
- **반드시 지킬 제약:**
  - 한국어 신규·수정 문구(필터 탭명·`보드 1/4` 등)는 `translations.csv` 영·일 동시 추가
  - 터치 모드 버튼 최소 높이 `48px`(필터 `44px` + `TOUCH_SLOP 26px`) 및 `FontSizes.LADDER` 준수
- **참조 기획서:** [`RULEBOOK_SPEC.md` 4절](RULEBOOK_SPEC.md#4-규칙-도감-ui--ux-종합-개선-확정-규격-10건-handoff-012) · [`Visual_Asset_Guide_Draft.md` 7.5절](visual/Visual_Asset_Guide_Draft.md#75-규칙-도감-rulebook--1366--768-고정-스테이지)
- **완료 기준 (검증):**
  - `tests/ui_overlap_audit.gd` (한·영·일 PC/터치 넘침 0건) 및 규칙 도감 화면 테스트 통과
  - 카드 필터 5종 전환·상세 팝업 전체 암전/닫기·백업 팝업 닫기·`특수 칸` 미니보드 무잘림 확인
- **작업 AI 완료 보고 (2026-11-28, 개발 AI):**
  - 커밋 `7ab52c5b` / `dev` (개발 기록 `7.140`) / 단위 879개 · `ui_text_fit` · `ui_overlap_audit` · `ui_rulebook_scroll_test`(1180개, 필터·암전·[×]·백업 닫기·미니보드·꿀팁 확인 추가) 포함 전체 로컬 CI 통과
  - `UI-01`: 필터 장수는 **카드 종류 수**(전체 52)로 표기했다 (덱 장수 합계는 89라 격자 52칸과 맞지 않음). 필터 상태는 도감을 닫기 전까지 유지된다
  - `UI-02`: 상세 팝업의 메달은 `[×]` 자리와 겹쳐 **숨김** 처리
  - `UI-05` 원인: 두 스크롤은 이미 `SCROLL_MODE_AUTO`였고 짧은 팝업엔 스크롤바가 뜨지 않았다. 보이던 스크롤바는 기본 규칙 노트의 실제 넘침(한 턴 536/457px, 특수 칸 764/457px). 짧은 팝업 기준 55%는 노트 **종이 안쪽 높이** 대비로 잡았다 (상세 큰 그림이 288px라 스크롤 칸 대비로는 조건이 성립하지 않음)
  - `UI-06`: `풀 파워`·`보드연성진` 글은 카드 안에 다 들어가 있었고 격자 끝에 붙어 잘려 보인 것 → 끝 여백 18px로 해소
  - `UI-09`: `belatien.webp`에도 `[로그 펼치기]` 조각·카드 더미가 찍혀 있어 classic·monatium과 함께 3종 재캡처 (HUD·굴리기 버튼·카드 더미 없음, 640×400)
  - `UI-10`: 문구는 노트 폭상 2줄로 줄바꿈된다 (고아 한 단어 줄은 없어짐). 큰 그림 132→108px·표/요점 간격 압축으로 `꿀팁`까지 첫 화면(457/457px)

---

### `[HANDOFF-003]` 1.4 차기 버전 마스터 기획 초안 구현 대기 안내

- **대상 역할 / 브랜치:** 개발 · 3D 아트 AI / `next` *(확정 전 선구현 금지)*
- **우선순위 / 상태:** `낮음(P2)` / `보류(HOLD — 사용자 패러디 · 최종 선별 확정 대기)`
- **전달 내용:**
  - `1.4.x` 업데이트 전체 초안(**신규 보드판 「유령 늪」**, 기존 검토 도구 `노래방 점수판`·`후쿠비키` 포함 **판정 도구 14종**, **신규 기물 4계열 16종**, **특수 승리 10종+변형 1종**, **생떼 카드 23종**, **증강 8종**)이 [`V1_4_UPDATE_PLAN.md`](V1_4_UPDATE_PLAN.md)에 전수 밸런스 조정 초안으로 작성되었다.
  - 사용자가 `[패러디 슬롯]`(특수 승리·카드·증강 최종 명칭 및 대사)과 Phase 1 우선 투입 항목을 확정해 별도 `HANDOFF`로 착수 지시를 내리기 전까지 코드·에셋을 선구현하지 않는다.
  - 확정 후 구현 시 반드시 `next` 브랜치에서 `ReleaseGate("1.4.0")` 버전 잠금을 걸고, **기물 S급(`≤ 1,500 tris / 30 KB`) · 도구 S~L급(`≤ 6,500 tris / 200 KB`, `optimized/vN/` 변환, `SubViewport ≤ 1.5×`, `MSAA_2X`, 비활성 `32×32` 파킹)**과 **전체 번들 `≤ 150,000 tris / 4.0 MiB`**, **카드 `GDD 4.4` 통일 용어 규격**, **UI 고정 좌표 규격**을 준수한다.
- **참조 기획서:** [`V1_4_UPDATE_PLAN.md`](V1_4_UPDATE_PLAN.md) · [`Visual_Asset_Guide_Draft.md` 6절·7절](visual/Visual_Asset_Guide_Draft.md#6-3d-모델링-폴리곤-수--저용량-운영-상한-규격-131-전수-계측) · [`GDD_TDD_Master.md` 4.4절](GDD_TDD_Master.md#44-생떼-카드-52종--기본-덱-89장-통일-명세)

---

### `[HANDOFF-014]` 전역 UI 겹침 감사의 오래된 첫 증강 fixture 갱신

- **대상 역할 / 브랜치:** QA · 개발 AI / `dev`
- **우선순위 / 상태:** `낮음(P2)` / `대기(TODO)`
- **전달 내용:**
  - 도감 이미지 복원 중 `tests/ui_overlap_audit.gd`를 실행했으나, `_session()`이 옛 첫 라운드 증강 창을 기다린 후 없는 `_draft_overlay`를 `_scan()`에 넘겨 `_collect`/`_collect_buttons`의 `get_children()`에서 null 오류가 발생했다(현행 `dev` 기반, 도감 복원과 무관한 게임 보드 fixture).
  - 감사 도구의 증강 진입 과정을 현행 4R 첫 드래프트/오프닝·큐 대기에 맞춰 갱신한 뒤 다시 검사한다. null 검사로 아무 화면도 보지 않고 성공 처리하지 않는다. 이번 아트 수정에서는 이 전역 감사가 통과했다고 보고하지 않는다.
  - 도감 전용 `ui_rulebook_scroll_test.gd`는 최신 HANDOFF-012 UI와 아트 복원을 함께 적용한 상태에서 한·영·일/PC/터치 포함 **1,241개** 검사를 통과했다.
- **참조:** `tests/ui_overlap_audit.gd::_session`, `_scan`, `_collect`, `_collect_buttons`
- **완료 기준 (검증):** 실제 증강 창이 열린 상태를 단언하고, `SCRIPT ERROR` 없이 전역 감사를 완료하여 결과/남은 겹침을 보고한다.

---

## 3. 신규 전달사항 작성 양식 (복사용 템플릿)

새 전달사항을 추가할 때는 아래 블록을 복사해 `2절` 하단에 이어 붙이고, 상단 **한눈에 보는 대기 목록** 표에도 1줄을 추가한다.

```markdown
### `[HANDOFF-NNN]` 작업 제목

- **대상 역할 / 브랜치:** 개발 AI / 아트 AI / QA AI · `dev` 또는 `next`
- **우선순위 / 상태:** `높음(P0)` / `보통(P1)` / `낮음(P2)` · `대기(TODO)`
- **전달 내용:**
  - 무엇을 왜 바꾸는지 핵심 요구사항 작성
  - 예외 조건이나 기존 동작 유지 범위 명시
- **반드시 지킬 제약:**
  - (예: 3D 모델 등급 상한, UI 버튼 고정 크기/좌표, 연출 비침범 `await`, RNG 결정성 유지 등)
- **참조 기획서:** [`GDD_TDD_Master.md`](GDD_TDD_Master.md) / [`EDGE_CASE_SPEC.md`](EDGE_CASE_SPEC.md) / [`PRESENTATION_SPEC.md`](PRESENTATION_SPEC.md) / [`RULEBOOK_SPEC.md`](RULEBOOK_SPEC.md) / [`Visual_Asset_Guide_Draft.md`](visual/Visual_Asset_Guide_Draft.md)
- **완료 기준 (검증):**
  - 통과해야 할 테스트 스크립트 및 확인 시나리오
- **작업 AI 완료 보고 (완료 시 기록):**
  - 커밋 해시 / 브랜치 / 실행한 테스트 결과 / 특이사항
```

---

## 4. 완료된 전달사항 아카이브 (Done)

> 구현 및 검증이 끝난 전달사항은 `2절`에서 아래 표로 옮겨 이력을 남긴다. (표 행 사이에 빈 줄을 넣지 않는다.)

| ID | 완료일 | 대상 브랜치 | 요약 | 반영 커밋 · 검증 결과 |
|---|---|---|---|---|
| **`[HANDOFF-001]`** 특수 발판 연출 중 템포 업 경고음 침범 수정 | 2026-11-28 | `dev` · `docs` | 빵집·자판기·가마솥·정령 칸·코너 버프·부스터 발판 연출 스텝이 자기 창·배지·카드·파편 퇴장까지 `await`하도록 수정. 정령산 다음 판 디버그 판 준비 오류 동시 수정 | `dev`: `6d671f34` · `6b17c18f` / `ui_round_sequence_test::_tempo_after_pad`(6종 발판) · 단위 877개 통과 |
| **`[HANDOFF-002]`** 생떼 카드 52종 인게임 도감·툴팁 문구 통일화 | 2026-11-28 | `dev` · `docs` | 카드 20장 설명·손패 1줄 요약 4종을 `GDD_TDD_Master.md` `4.4절` 통일 용어로 정렬(`소각` 용어 시험 반영, `기억상실빔`은 엔진 기준 `모든 말`로 GDD까지 일치시킴) | `dev`: `762e58b` · `3eac44d` (개발 기록 `7.139`) / `test_card_descriptions_follow_the_glossary` · `ui_overlap_audit` 통과 |
| **`[HANDOFF-004]`** AI 터보 턴 배율 기획서 `0.75배` 고정 | 2026-11-28 | `docs` | 사용자 결정에 따라 실제 코드(`TURBO_PACE_SCALE = 0.75`)에 맞춰 `GDD_TDD_Master.md` `4.6절` 및 `EDGE_CASE_SPEC.md` `2.5절`의 구 `0.35배` 표기를 `0.75배`로 통일 | `docs`: `1247600` |
| **`[HANDOFF-005]`** 처치 장면 리벤지 `+N` · `방어!` 배지 예외 확정 | 2026-11-28 | `docs` | 사용자 결정: 처치 템포 유지를 위해 `_revenge_charged_popup`(`0.12초`) · `_show_defended`(`0.45초`) 2종만 비차단 부가 배지 예외로 `EDGE_CASE_SPEC.md` `2.1절`·`PRESENTATION_SPEC.md`에 명문화 | `docs`: `361d904` |
| **`[HANDOFF-006]`** 개별 범위 CI 시험 3종 `1.3.1` 현행화 | 2026-11-28 | `dev` | `ui_blackjack_compact_test` · `ui_roll_history_test` · `ui_profile_aura_test`를 `1.3.1` 화면 사양에 맞게 정비 완료 | `dev`: `c3af7af` · `3eac44d` (개발 기록 `7.139`) |
| **`[HANDOFF-007]`** TRPG·풀 파워 아이콘 및 확정 아트 통합 인계 | 2026-11-28 | `dev` · `docs` | TRPG 4기물(`TRPG_*_V02.png`), 풀 파워(`AUG_UTIL_FULL_POWER_V02.png`), 다트 숫자 고정, 결과 숫자 `Bangers`, 야추 빈 컵 분리, 핀볼 측면 손잡이 유지 사양을 `Visual_Asset_Guide_Draft.md` `6.3절`에 영구 고정 | `dev`: `1c584e11`~`6d557ee5` / `docs`: `1247600` · `test_pawn_art` 290개 · `test_augment_art` 316개 통과 |
| **`[HANDOFF-008]`** 야추 다이스 컵 쏟기 연출 교정 | 2026-11-28 | `dev` · `docs` | `YachtCase3D.split_model`로 케이스에서 컵을 분리해 `YachtRoll3D`에서 흔들기(`0.34초`) → 펠트 쪽 `72°` 기울이기(`0.46초`) → `cup_mouth` 입구에서 주사위 쏟기 → 바로 서기 구현 (추가 삼각형 0) | `dev`: `949b6c4` · `3eac44d` (개발 기록 `7.139`) |
| **`[HANDOFF-009]`** 규칙 도감(`rulebook.gd`) 텍스트 오기·누락 10건 교정 | 2026-11-28 | `dev` · `docs` | `RULEBOOK_SPEC.md` `3절` 10건 교정 완료 및 도감 요약 배너 `2.2절` 문구 반영, 법전 판정 `_law_judgement` 분기 적용 | `dev`: `0cfd6bb` · `3eac44d` (개발 기록 `7.139`) |
| **`[HANDOFF-010]`** 지하노역장 친치로 카이지 4·5·6 3주사위 + 쇼벤 리워크 | 2026-11-28 | `dev` · `docs` | 카이지 사기 주사위(`[4,4,5,5,6,6]`) 3개 + `1/6` 쇼벤(`0칸+턴 종료`) · 4/5/6의 눈 · 시고로(8) · 아라시(10) · `★666`(12+한번더) 엔진·3D 그릇 3주사위·쇼벤 이탈·도구 카드·번역 완료 | `dev`: `020f344` · `3eac44d` (개발 기록 `7.139`) / 27조합·27,000회 분포·3D 그릇·연출기 시험 통과 |
| **`[HANDOFF-011]`** 오미쿠지 2버튼 조작 서술 정정 | 2026-11-28 | `docs` | 사용자 결정(현행 2버튼 코드 유지)에 따라 `PRESENTATION_SPEC.md` `2.2절` 오미쿠지 서술을 `[흔들기](반복) + [뽑기]` 2버튼 방식으로 정정 | `docs`: `8eb241b` |
| **`[HANDOFF-013]`** 기존 규칙 도감 v04 이미지 누락 복원 | 2026-11-28 | `dev` | 이전 `trg-v13-card-art` 로컬에만 남아 있던 승인 PNG 15종·생성 기록·정규화 크롭을 `assets/ui/trickcal/rulebook/v04/`에 복원해 `rulebook_visuals.gd`의 공용 경로로 연결. 장 버튼·목록·상세·보드별 설명이 같은 아이콘을 사용하며, 함정 칸의 예전 실전용 그림을 도감용 그림으로 교체. 중복된 구형 preload 제거. 동시 반영된 HANDOFF-012(`7ab52c5b`)를 통합하면서 CNT_01 만능 방어·필터·팝업·보드 미리보기 등 최신 UI를 보존. 원본 픽셀·게임 규칙 변경 없음. | 복원 `20581c07` · 통합 `33167afd` / `ui_rulebook_scroll_test`: **1241 checks**, 실제 OpenGL 도감 캡처·아이콘 33개 연결 확인, `lowpoly_models_test`: 42종, `ui_web_3d_budget_test`: 135개 통과. 전역 `ui_overlap_audit`는 HANDOFF-014로 별도 인계. HANDOFF-012 전체 완료/리뷰 상태를 이 작업으로 변경하지 않음 |
