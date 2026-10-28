# 결과 표찰 이미지 보강

큰 사각 패널 안의 글 목록을 개별 결과 표찰로 교체했다. 기존 크림색·올리브 테두리를 유지하고, 최신 결과에만 옅은 녹색(성공), 황금색(재굴림), 붉은색(실패)을 입힌다. 공개된 새 결과만 0.2초 동안 살짝 커지며 나타나고, 이전 결과는 재생하지 않는다. 멈추기·확정은 새 표찰을 추가하지 않는다.

상단에는 해당 도구 이미지와 횟수를 작게 배치한다. 이미지 가장자리는 기존 UI 마스크로 둥글게 맞춘다. 하단의 누적 이동·턴 종료도 같은 표찰 재질을 쓴다. 기록 위치는 조금 올려 왼쪽 로그와 간격을 확보한다. 결과 판정·공개 시점·턴 분리 규칙은 기존과 같다.

## 생성 자산

- 방식: 내장 image_gen 도구. 새 이미지 1회 생성, 재생성 없음.
- 프로젝트 경로: `assets/ui/trickcal/roll_history_v01/result_plaque.webp`
- 2100×749 RGBA. 생성 PNG의 픽셀과 알파를 유지한 무손실 WebP 포맷 변환, 700,426바이트.
- 생성 원본은 Codex generated_images에 보존한다. 엔진에서만 투명 여백을 제외한 (9,167,2080,412) 영역을 사용하고, 323×64 공유 텍스처 한 장으로 축소해 9-slice로 표시한다.
- QA: 중앙 글자 영역이 비어 있고, 직선 테두리·둥근 모서리·알파를 확인했다. 프레임 바깥의 희미한 잔여 알파는 런타임 영역에 포함하지 않는다. 한·영·일, 모바일 두 크기와 PC에서 결과·실패·긴 카드 기록을 캡처해 확인한다.

## 생성 프롬프트

Create one production game UI asset: a single blank horizontal result plaque, straight front view, width-to-height ratio about 4.6:1, centered and occupying almost the entire canvas with only 3% transparent padding. This is for a friendly Korean fantasy board game. Simple, soft, hand-painted mobile game UI: warm ivory enamel / smooth cream paper surface, restrained sage-olive outer ink contour, a very fine warm tan inner rim, gently rounded corners and a tiny soft edge highlight giving a tactile sticker feel. Flat straight top, bottom and sides, no inward curves, no perspective, no skew. Large uncluttered blank center for runtime text. Thin rim; the center must stay light and readable. Subtle painted material variation, clean readable silhouette at a small display size. Absolutely NO text, letters, numbers, symbols, icons, illustrations, badges, stars, sparkles, ribbons, ornamental leaves or extra objects. NO cast shadow outside the plaque. Transparent background, actual alpha outside the plaque, no checkered background. Exactly one isolated horizontal plaque, not a sheet or mockup.
