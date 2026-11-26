# 규칙 도감 그림 v02

내장 `image_gen` 도구로 투명 배경을 써서 만들었다. 고른 원본 PNG는 Codex generated_images에서 수정 없이 복사했고, `manifest.json`에 해시·전체 프롬프트·원본 위치·투명 경계를 적었다.

## 심볼 역할

왕관·칼·일반 버튼·숫자뿐인 차례 기호를 상관없이 돌려 쓰던 자리를 독립 그림 14장으로 바꿨다. 기존 보드·기물 그림 6장은 실제로 맞는 개념에만 다시 쓴다. 기존 카드·기물·도구·증강 도감 그림은 실제 데이터에 그대로 연결된다.

중립 패널은 기존 색으로 물들인 9-slice 스킨으로 쓴다. 종이와 쪽 리본은 그림 텍스처다. 기술적인 자르기 마스크·선택 외곽선·표 선·글자·실시간 보드 경로 화살표는 배치·데이터와 정확히 맞춘다. 화면 표현만 바뀐다.

## 임포트·표시

아이콘: 엔진 제한 256px, 손실 압축 0.7, 밉맵. 패널 512px, 종이 768px, 리본 512px. 원본은 전체 해상도와 투명도를 유지한다. `scenes/rulebook_visuals.gd`의 정규화된 투명 영역이 임포트 크기와 상관없이 빈 여백을 뺀다.

## 검증 범위

도감 화면만 확인한다: 스크립트 구문 검사, 10개 장과 항목 상세의 실제 Godot 캡처, 넘기기 버튼, 항목 고르기, 스크롤, 키보드 장 넘기기, 닫기. CI 표식 `[check:rulebook-art]`은 게임 전체 테스트 없이 도감 구문 검사와 웹 내보내기만 고른다.

## 그림별 내용

| 그림 | 내용 |
|---|---|
| finish | 3단 시상대, 가운데 가장 높은 단에 큰 금 트로피, 아래 상아색 두 단, 바닥에 초록 월계수 (완주·순위, 왕관 없음) |
| play_card | 산호빨강 문양이 있는 상아색 카드 한 장을 둥근 장갑 손이 아래 모서리에서 잡고, 작은 청록 앞쪽 휘두름 (카드 한 장 내기, 덱·공격 아님) |
| roll | 큰 검은 눈이 박힌 두툼한 상아색 주사위 하나와 아래 작은 초록 굴림 곡선 |
| choose_pawn | 산호·파랑·초록 둥근 말 셋과 가운데 파란 말 위의 큰 상아색 손가락 (말 고르기) |
| resolve | 크림·초록 칸 위의 큰 금색 체크 표시와 작은 주황 정산 반짝임 (차례 정산, 트로피 아님) |
| bonus | 상아색 앞코와 짧은 금주황 불꽃을 단 작은 청록 장난감 로켓, 오른쪽 위로 금색 꼬리 (보너스 전진) |
| augment_round | 초록·파랑·산호 강화 카드 세 장을 부채꼴로 펼치고 가운데 위에 작은 금 결정 (셋 중 하나 고르기, 왕관 없음) |
| tempo | 금 틀에 짙은 빨강 모래의 짧은 모래시계와 뒤로 솟는 산호색 불꽃 두 줄기 (시간 가속, 시계·숫자 없음) |
| attack | 굵은 은색 칼이 대각선으로 가로지르는 산호빨강 카드 (공격 카드, 방패 없음) |
| defense | 청록 가운데·금 테두리의 큰 방패 뒤 코발트 카드, 작은 화살이 왼쪽으로 튕김 (방어, 칼 없음) |
| trap_card | 둥글고 무해해 보이는 은색 덫 뒤의 보라 카드 (물음표·눈·가시 없음, 숨은 카드와 구분) |
| lawbook | 표지에 금색 저울이 돋을새김된 닫힌 에메랄드 가죽 법전과 상아색 책갈피 |
| supply | 상아색 카드 두 장과 금 코르크 초록 병이 든 열린 꿀색 보급 상자 (책·선물 리본 없음) |
| super | 금 번개를 가르는 큰 보라 결정과 아래 작은 기울어진 상아색 주사위 (하이리스크 하이리턴, 책·왕관 없음) |
| panel·paper·ribbon | 중립 패널 바탕·종이 질감·쪽 리본 |

## 프롬프트 (생성 기록 원문)

아래는 이미지 생성 도구에 넣은 프롬프트 원문이다. 같은 그림을 다시 만들거나 비교할 때 그대로 써야 하므로 영어 원문을 보존한다. 뜻은 위 표에 정리했다.


### finish

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: A small three-step winners' podium with ONE large golden trophy on the highest center step and two lower ivory steps. Green laurel at the base, very simple, communicates finish and ranking. No crowns.

### play_card

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: ONE warm ivory playing card with a coral-red face emblem, held at the lower corner by a simple rounded ivory mitten hand, a small teal forward swoosh. Communicates playing one card, not a deck or attack.

### roll

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: ONE chunky ivory six-sided die with large dark round pips, one tiny green curved rolling swoosh underneath. Clear single-die silhouette.

### choose_pawn

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: THREE small round pawns in coral, blue and green; ONE large simple ivory pointer hand hovering over the blue center pawn, communicates choosing a piece. Rounded mitten-like finger, very simple hand anatomy.

### resolve

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: ONE cream/green board tile with ONE large golden checkmark seated on it and a small orange settlement sparkle of four broad rays. Communicates resolving a turn, not winning a trophy.

### bonus

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: ONE small teal toy rocket with an ivory nose and a short golden-orange exhaust flame, pointing diagonally upper right. One broad gold motion trail, communicates bonus forward movement.

### augment_round

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: A fan of exactly THREE different ivory-backed upgrade cards in green, blue and coral, with ONE small gold faceted crystal hovering above the center card. Simple, communicates choosing one upgrade out of three. No crown.

### tempo

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: ONE short hourglass with gold frame and dark red sand, with TWO simple broad coral flame tongues rising behind it. Communicates time speeding up, no clock face or numbers.

### attack

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: ONE coral-red playing card with a single short chunky silver sword crossing it diagonally, blade toward upper right. Simple bold attack-card emblem, no shield or extra weapons.

### defense

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: ONE cobalt-blue playing card behind a large chunky ivory/silver shield with a teal center and broad gold rim. A tiny blunt incoming arrow bounces off to the left, communicates defense. No sword.

### trap_card

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: ONE purple playing card partly behind ONE open cartoon spring-jaw trap, rounded harmless-looking chunky silver jaws and gold center trigger. Distinct from a hidden question-mark card; no eye, no question mark, no spikes outside the silhouette.

### lawbook

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: ONE closed emerald-green leather lawbook with a large embossed golden balance-scale symbol on its cover and a warm-ivory bookmark. Simple broad gold page edge, straight-on three-quarter book icon, no cards beside it.

### supply

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: ONE open honey-brown supply crate containing TWO simple ivory cards and ONE small green refill bottle with a gold cork. Cohesive compact silhouette, communicates general resupply, no book or gift ribbon.

### super

Use case: illustration-story. ONE transparent standalone UI symbol for a cozy chibi board-game rulebook. Match the supplied reference's simple rounded chunky silhouette, thick clean dark-brown/forest outline, warm ivory/gold accents and restrained 3-tone matte cartoon shading. Broad simple shapes instantly readable at 40px and attractive at 132px. Front-facing or slight top-down object, no extreme perspective. All objects form ONE compact centered emblem with generous transparent margin. Genuine transparent background outside the objects. No backing disc, no outer badge frame, no scenery, no tiny intricate decoration, no text, no letters, no numerals, no logo, no watermark, no glow, no particle field. Primary subject: ONE large purple faceted crystal splitting a golden lightning bolt, with ONE small tilted ivory die at its base. Clear high-risk high-reward special-upgrade symbol, one bold coral accent, no book, no crown.

### panel

Use case: productivity-visual. ONE production UI nine-slice panel texture for a simple cozy cartoon game rulebook. A flat front-facing perfectly rectangular SQUARE white/very pale ivory matte paper panel, a simple medium neutral-gray thin rounded rim with a slightly darker clean outside edge, subtle broad inner bevel and very faint paper grain. Small softly rounded corners, perfectly STRAIGHT parallel horizontal and vertical edges, NO inward bow or curved sides, no perspective. White center occupies 85% of the square and is perfectly empty for live text; only gentle uniform off-white texture, no gradients crossing center. Neutral white and gray palette because game code will tint it mint, beige, leather brown or pastel. Tiny restrained baked shadow hugging bottom rim, no outside cast shadow. Entire panel within transparent margins and genuine transparent exterior. No symbols, no ornaments, no screws, no corner flourishes, no line pattern, no writing, no text, no watermark. Single centered square panel only.

### paper

Use case: productivity-visual. ONE square front-facing cream notebook-paper UI sheet for a cozy chibi board-game encyclopedia. Flat pale warm ivory #fbf4df paper with very faint tan horizontal ruled lines, evenly spaced and subtle enough for black text readability; leave the upper 15% blank for a live heading. Small rounded corners, perfectly straight flat edges, tiny folded lower-right corner in pale beige, no ripped edges, no bending or bowed sides. Very restrained matte paper grain, broad empty clean writing space, simple icon-like game UI finish, no elaborate decoration. No book spine, no leather frame, no clips, no drawings, no letters, no text, no watermark. Whole square paper sheet centered with generous genuine transparent margins outside; paper itself opaque.

### ribbon

Use case: productivity-visual. ONE simple horizontal ORANGE page-number ribbon UI sprite, about 4.4:1 width to height, for a cozy cartoon board-game encyclopedia. A flat broad rectangular warm-orange #f08a3c center banner with perfectly straight parallel top and bottom edges, narrow gold-peach highlight along the upper edge and darker burnt-orange lower edge. Two SHORT folded fishtail ends extend sideways behind it with simple notches. Symmetric, front-facing, matte 3-tone painted cartoon finish with subtle paper/fabric grain. The central 75% is completely EMPTY for live page numbers. Restrained chunky dark-brown contour, no elaborate curls, no inward bow, no perspective, no shiny gems, no symbols, no words, no numbers, no text, no watermark. Entire ribbon centered with generous genuine transparent margins outside the silhouette.
