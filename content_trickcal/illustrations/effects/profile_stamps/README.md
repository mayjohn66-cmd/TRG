# 프로필 상태 도장

내장 `image_gen`으로 실제 투명 배경을 써서 만들었다. 원본 PNG는 그대로 두고, 60~120px 초상 덮개와 웹 로딩 예산에 맞춰 스킵 표시는 256px, 밴 도장은 512px로 임포트한다. 원본 영역을 정규화해 임포트 크기가 바뀌어도 위치가 유지된다.

- `skip_painted.png`: 마른 붓 칠의 빨간 금지 표시, 따뜻한 상아색 가장자리와 투명한 틈.
- `ban_painted.png`: 낡은 느낌의 빨간 BANNED 고무 도장, 안쪽은 투명.
- `skip_ring_painted.png`: 두 상태가 함께일 때 쓰는, 스킵 표시에서 고리만 남긴 편집본.
- 두 상태가 함께 걸리면 원래 크기 스킵 고리가 가운데에 남고, BANNED 도장이 원래 대각선 획 대신 45도로 가운데를 가로지른다. 한쪽 상태가 끝나면 남은 도장이 혼자일 때의 배치로 돌아가고, 쾅 찍는 동작은 다시 하지 않는다.

화면 표현만 바뀌었다. 상태 기간·카드 제한·원래 도장 쾅 연출과 소리는 기존 상태와 갱신 경로가 그대로 관리한다.

## 최종 프롬프트 (생성 기록 원문)

같은 그림을 다시 만들 때 그대로 써야 하므로 영어 원문을 보존한다.


스킵 (내장 image_gen, transparent_background=true):

Use case: illustration-story. Asset type: one transparent painted status stamp overlay placed on top of a small chibi character portrait in a cozy cartoon board game. Primary request: a bold red SKIP / turn skipped prohibition mark, one rough hand-painted red circular ring crossed by one broad diagonal red brushstroke from upper left to lower right. The ring and diagonal must remain immediately readable as the familiar prohibition symbol at 60 pixels. Give the red paint tangible dry-brush ink texture, subtly uneven organic contours, tiny worn gaps and restrained darker red shading, with a very thin warm ivory edge for contrast over colorful portraits. The center spaces and every area outside the red mark are genuinely transparent so the character's face remains visible through it. Compact front-facing flat decal composition centered in a square with generous empty transparent padding; no perspective, no background or backing disc. Friendly cartoon game finish with simple bold shapes but clearly painted rather than mathematically perfect vector primitives. No letters, no text, no extra symbols, no character, no sparkles, no large splatters outside the main silhouette, no watermark. One mark only.

밴 (내장 image_gen, transparent_background=true):

Use case: illustration-story. Asset type: one transparent painted status stamp overlay for a chibi character portrait in a cozy cartoon board game. Primary request: a short wide red rubber-ink BAN stamp reading exactly "BANNED" in large chunky condensed block capitals, within a slightly uneven double rectangular red ink border. True worn rubber-stamp texture: tiny missing ink patches, organically rough edges, subtle dark crimson variation, hand-stamped illustrated quality rather than a clean geometric vector button. A very thin warm ivory contour immediately around the red letters and border keeps it legible over a colorful portrait. The rectangle interior between the letters and the border must be transparent, with no solid red or white plate behind the typography, so the character's face remains visible. Straight-on horizontal front-facing stamp, about 3:1 width to height, fully visible with ample transparent padding on every side; the game will tilt it later. Bold simple readable lettering at 75 pixels wide. Only this stamp, no hand or handle, no paper, no badge, no ribbons, no decorative objects, no character, no background, no large splatters or glow, no watermark. Text verbatim: BANNED.

고리만 남기기 편집 (내장 image_gen, transparent_background=true, 편집 대상: skip_painted.png):

Edit the attached transparent red painted prohibition symbol. Remove ONLY the entire diagonal slash from upper left to lower right, including its ivory edges and all slash fragments within the center. Keep one complete uninterrupted circular red ring, reconstructing the ring naturally at the two old slash junctions. Preserve the source's ring size, placement, thickness, rough dry-brush red paint, subtle crimson texture and thin warm ivory contour. The entire center of the ring must be genuinely transparent and completely empty, and the entire outside must stay transparent. No slash, no text, no letters, no additional symbols, no background, no backing disc, no glow. One circular ring only. This will be combined in the game with a separate BANNED text stamp placed across its center.
