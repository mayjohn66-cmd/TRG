# 공통 "내 말도 위험" 경고 아이콘

`assets/board/decals/NPC_WARNING.png`를 스타일·색 참고로 삼아 내장 image_gen으로 만들었다. 고른 원본 PNG는 그대로이고 실제 투명 여백을 유지한다. 원본 경로·SHA-256·정규화된 자르기 영역은 `source.json`에 있다. 카드 UI에서 22/26/38/40px로 쓰므로 128px·밉맵·손실 압축으로 임포트한다.

`CardSkin.WarningIcon`이 같은 그림을 카드 모서리, 초증강 카드 모서리, 카드 상세의 주의 줄에 원래 비율로 맞춰 가운데에 그린다. 기존 대상 조건·주의 설명·마우스 필터·툴팁 글은 그대로다. 그림에 글자가 없어 언어와 상관없다. 보드의 NPC 경로 경고 그림은 따로 그대로 있다.

## 최종 프롬프트 (생성 기록 원문)

같은 그림을 다시 만들 때 그대로 써야 하므로 영어 원문을 보존한다. 내용: 둥근 빨간 삼각 경고 표지와 아주 굵은 상아색 느낌표 하나, 짙은 진홍 테두리와 보라·주황·남색·연초록 카드 위에서도 보이는 가는 상아색 바깥 선, 22px에서도 읽히게 단순하게.

Use case: illustration-story. Create ONE production transparent UI warning icon for the corner of cards and super-augment cards in a cute polished chibi fantasy board game. Reference image role: existing warning-symbol family and red/ivory palette; refine it for very small UI sizes. Keep the instantly familiar RED rounded triangular warning sign and one very bold IVORY exclamation mark. Broad substantial deep-crimson outer rim, restrained brighter warm-red inset face, one thin warm-ivory outside contour that stays visible on purple, orange, navy and pale-green card art. Large simple ivory exclamation with a thick tapered rounded upright and a separate large round dot; generous clear red space between mark and rim, absolutely legible at 22 pixels. Soft chunky toy-like painted/cartoon finish, subtle 3-tone cel-shading and one small edge highlight, mild ink texture, clean matte surface, no glossy glass, no elaborate detailing. Compact centered front-facing triangle, symmetric silhouette, slightly softened corners, no perspective or tilt. Opaque sign body; genuine transparent background outside. Complete icon fits with ample transparent padding; no cast shadow outside the silhouette, no glow, no sparkles, no particles, no decoration, no extra symbols, no text or letters beyond the single exclamation mark, no watermark. One icon only.
