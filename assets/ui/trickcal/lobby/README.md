# 대기실 좌석 아이콘

2026-10-26, 기본 내장 `image_gen` 도구로 새 원본 2개를 생성했다.
기존 좌석 색상과 둥근 패널을 유지하면서 얇은 도형 모래시계와 왕관을 교체한다.

- `UI_LOBBY_WAIT.png`: 투명 배경의 모래시계 배지 원본. 192px, WebP 품질 0.8,
  밉맵으로 임포트하며 화면에서는 108px 안에 표시한다.
- `UI_LOBBY_CROWN.png`: 투명 배경의 방장 왕관 원본. 64px로 임포트하며 기존
  30×26px 영역 안에 비율을 유지해 표시한다.
- `wait_palette.gdshader`: 배지의 푸른 부분만 좌석 색상으로 바꾼다. 금빛 모래와
  크림색 목재는 유지한다. 대기 표시는 약한 밝기 변화만 사용한다.
- `seat_icon.gd`: 위 그림을 실제 좌석 칸에 표시한다. 이름표·버튼·입장 처리는
  기존 UI가 담당한다.

웹에서는 기존 리소스 다운로드 큐를 통해 `avatars/ui_lobby.pck`를 대기방에서
필요할 때 받는다. 생성한 원본 PNG는 수정하지 않고 보존하며, 첫 로딩 본체에는
이 폴더를 포함하지 않는다. 편집기와 데스크톱은 로컬 원본을 바로 사용한다.

## 생성 프롬프트

### 모래시계 배지

Create a single production game UI icon, an empty-player-seat waiting medallion for a cute Korean chibi board game lobby. One isolated round pale-blue enamel medallion, softly hand-painted, with a thick simple rounded blue rim, creamy ivory inset, and one chunky toy hourglass centered inside. The hourglass has two rounded warm ivory wooden caps and short sturdy side supports, clear softly blue glass and a small amount of golden sand visibly trickling from the upper chamber to the lower chamber. Strong compact silhouette, easy to read when the entire medallion is just 112 pixels across. Flat 2D game illustration with subtle volume, rounded dark desaturated blue-gray outlines and just one soft highlight; restrained cream, pale sky blue, warm honey sand palette. All blue areas should share the same hue, which the game will recolor per player. Round outer silhouette fills 92% of the square, centered with even transparent padding. No text, no letters, no numbers, no face, no character, no sparkles, no flowers, no decorative filigree, no banner, no rectangular panel, no checkerboard background. This is a simple finished illustrated icon, not a geometric line drawing and not a photorealistic 3D render. Genuine transparent background.

### 방장 왕관

Create a single production game UI icon: a tiny friendly golden host crown for a cute Korean chibi board-game lobby. Front view of a squat wide crown, just three plump rounded points topped with small round knobs, a thick rounded base band, and one simple honey-orange center accent. Very clear compact chunky silhouette, reads instantly at only 26 pixels wide. Flat 2D hand-painted game icon with rounded warm brown outlines, restrained buttery gold and honey-orange shading, a small creamy highlight, very slight pillowy volume. Simple, modest, cheerful, polished, matching a cream-and-mint lobby UI. Object fills 90% of a square with even transparent padding. No text, no letters, no glow, no floating sparkles, no ornate engraving, no red velvet interior, no wings, no extra icons, no badge circle, no card, no background, no watermark. Not a thin line symbol, not photorealistic. Genuine transparent background.
