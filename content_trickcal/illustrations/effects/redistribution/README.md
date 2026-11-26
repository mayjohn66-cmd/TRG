# 공산주의 재분배 연출 그림

내장 image_gen으로 실제 투명 배경을 써서 만들었다. 원본 PNG는 그대로 복사했고, 정규화한 원본 영역 덕분에 Godot 임포트로 줄여도 위치가 유지된다. 도장은 512px, 카드 뒷면과 교환 문장은 256px·밉맵·손실 압축으로 임포트한다. 출처와 해시는 `source.json`에 있다.

- `stamp.png`: 읽기 쉬운 빨간 한글 "재분배" 고무 도장. 기존 시작 쾅 연출에 쓴다.
- `card_back.png`: 남색 바탕에 따뜻한 금색 옛 열쇠가 그려진 카드 뒷면. 이 효과에서 모으는 카드 껍데기에만 쓴다.
- `exchange.png`: 가운데가 투명한 금색 원형 화살표 두 개. 모은 카드 더미 아래와 엔진이 정한 도착 칸에 투영한다. 원래 모으기·똑같이 나누기·섞기·돌려주기 단계와 엔진 재분배는 그대로다.
- 동심 도형 틀 대신 부드러운 빨간 경보 음영을 쓴다. 다른 증강이나 공통 카드 뒷면은 바뀌지 않았다.

## 언어별 도장

도장이 나타날 때 `L10n.current_lang`으로 고른다. 한국어는 `stamp.png`(재분배), 영어는 `stamp_en.png`(REDISTRIBUTE), 일본어는 `stamp_ja.png`(再分配). 영어는 폭 330px, 한국어·일본어는 270px이고 모두 원본 비율과 원래 쾅 시간을 유지한다. 모르는 언어 코드는 한국어로. 영어·일본어판은 `stamp.png`에서 내장 image_gen으로 편집해 실제 투명도를 유지하고, 둘 다 512px로 임포트한다.

## 최종 프롬프트 (생성 기록 원문)

같은 그림을 다시 만들 때 그대로 써야 하므로 영어 원문을 보존한다.

### 도장

Use case: illustration-story. Create ONE transparent game VFX sprite: a bold Korean red rubber-ink stamp reading exactly "재분배", three clear Korean syllables in one horizontal line, large chunky confident Hangul brush/block lettering. One irregular double rectangular red ink border, subtly tilted ink impression but front-facing artwork. Distressed hand-printed ink texture with restrained worn gaps and a thin warm ivory contour around the red letters and border, matching a cute polished fantasy board game. Extremely readable at 220 pixels wide. Genuine transparency outside and inside between the letters and frame, no paper, no solid backing plate. Short wide approximately 2.5:1 composition, whole stamp centered with ample transparent margins. Only the red stamp, no political symbols, no stars, no hammer/sickle, no characters, no extra words or decorative objects, no watermark. Exact text: 재분배.

### 카드 뒷면

Use case: illustration-story. ONE production-ready transparent sprite of a fantasy board-game playing card BACK, flat straight-on portrait rectangle with width-to-height 84:118. Match a cozy chibi board game: deep navy blue #18263f enamel/leather face, substantial warm ivory paper edge, simple broad warm gold double frame with softly rounded corners, ONE large ornate but very readable golden antique KEY upright in the center (bow at top, shaft downward, teeth at lower right). A few restrained painted highlights, delicate ink grain and gently worn gold embossing so it feels illustrated rather than a geometric placeholder. Bold clean dark brown contours, 3-tone cel shading, simple uncluttered composition; no elaborate filigree, no scattered particles, no glow. This is ONE FLAT card back, not a stack, no perspective or tilt, no hand, no shadow outside, no desk, no text, no letters, no number, no watermark. The ivory card body is opaque. Genuine transparent background outside the card, ample transparent margin, all four corners visible.

### 교환 문장

Use case: illustration-story. ONE isolated transparent fantasy board-game redistribution floor seal. Exactly TWO broad chunky warm GOLD curved arrows chasing each other around one OPEN EMPTY circular center, clockwise circular exchange / shuffle symbol. Friendly substantial hand-painted cartoon finish, ivory bevel highlights, rich ochre side shading, restrained rough ink grain, thick dark brown edges, very simple instantly readable shape at 40 pixels. Both arrows together form one balanced almost-complete ring with two short clear arrowhead gaps. Flat orthographic TOP-DOWN view, perfect circular arrangement, no perspective, no plate or backing disc, no extra outer frame, no scene or ground. The whole center and outside are GENUINELY TRANSPARENT. Generous transparent margins around the complete ring. Only the two gold circular arrows, no cards, no text, no letters, no numbers, no sparkles, no particles, no glow, no watermark. Cohesive with warm ivory/gold toy UI in a cute chibi board game.

### 영어 도장 편집

Edit the attached transparent Korean rubber stamp into an ENGLISH localization. Replace the three Korean syllables with exactly "REDISTRIBUTE" in one line of large bold condensed uppercase Latin stamp lettering. Correct spelling: R E D I S T R I B U T E. Preserve the distressed crimson/red rubber-ink texture, worn tiny transparent ink gaps, thin warm ivory contour around lettering and the rough double rectangular border. Widen the border naturally if needed to fit the longer word clearly, about 4:1 width to height. Large simple readable lettering at 320 pixels wide, no decorative flourishes. Genuine transparency outside and inside between letters and frame; no paper or solid backing. Only this stamp, ample transparent margin, no Korean characters remaining, no extra words, no watermark. Exact text: REDISTRIBUTE.

### 일본어 도장 편집

Edit the attached transparent Korean rubber stamp into a JAPANESE localization. Replace all Korean lettering with exactly the three Japanese kanji "再分配" in one horizontal line, large bold clear brush/block stamp lettering. Use Japanese glyph forms, not Hangul. Preserve the same distressed crimson/red rubber-ink texture, tiny worn transparent ink gaps, thin warm ivory contour around lettering, and rough double rectangular border. Preserve the short-wide 2.5:1 composition, centered and entirely visible with ample transparent margins. Readable at 270 pixels wide. Genuine transparency outside and inside between letters and frame, no paper or solid backing. Only this stamp, no extra symbols, no Korean letters, no other words or watermark. Exact text: 再分配.
