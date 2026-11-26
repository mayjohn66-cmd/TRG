# 빵집 털이 연출 그림

`bakery_storefront.png`와 `flour_puff.png`는 내장 `image_gen`으로 만들었고 생성된 투명도를 유지한다. 원래 출력 파일은 사용자의 generated_images 폴더에 남아 있다.

`erpin_move.png`는 뷰어의 전용 `minimi/minimierpin` 모델의 이동(Move) 애니메이션 14프레임을 투명 여백과 함께 50% 크기로 묶은 것이다. `erpin_idle.png`는 원래 대기(Idle) 첫 프레임이다. 출처: https://viewer.dclnslde.com/ → 미니미 → 에르핀. 프레임 배치와 출처는 `source.json`에 있다. 그림을 다시 그리지 않았다.

`bread_haul_three.png`는 빵 정확히 세 개(시골빵·둥근 빵·크루아상)를 담은 그림 소품 하나로, 내장 `image_gen`으로 만들고 실제 투명도를 가진다. 에르핀은 원래 이동 애니메이션의 위아래 움직임에 맞춰 이 빵 더미를 통째로 들고 간다. 예전 보드 아이콘 빵은 이 장면에서 더 이상 쓰지 않는다. 원본은 1536×1024로 보관하고, 54px 폭 소품과 웹 첫 로딩 예산에 맞춰 게임 텍스처는 512px로 제한한다. 정규화한 원본 좌표 덕분에 어느 크기에서나 위치가 유지된다.

장면 순서: 다가가기 → 가운데 어두운 문으로 들어가기 → 안에서 밀가루와 함께 네 번 쿵쾅 → 빵 세 개를 들고 탈출. 옮겨지는 말 위로 78% 어두운 배경을 깔고, 가게와 에르핀은 그 앞에 둔다. 카드 지급은 탈출 뒤에 시작하고 실제로 예약된 보상 작업을 그대로 쓴다.

## 최종 프롬프트 (생성 기록 원문)

같은 그림을 다시 만들 때 그대로 써야 하므로 영어 원문을 보존한다.


빵 세 개 소품 (내장 image_gen, transparent_background=true):

Use case: illustration-story. Asset type: one transparent carried-loot prop sprite for a cute chibi bakery game animation. Primary request: exactly THREE freshly baked breads held together in a small compact stack, with no hands or character: one chunky oblong golden country loaf with three pale score marks, one plump round bread roll with a cross-shaped score, and one buttery curved croissant. The two loaves sit side by side at the bottom, the croissant rests lightly across their upper edges. All three individual silhouettes must be clearly distinguishable and countable. Full colored hand-painted cartoon illustration, warm golden crust, soft cream highlights, restrained brown outlines, soft volume and appetizing baked texture, same cozy fantasy bakery aesthetic as a chibi game. Front three-quarter view, compact horizontal composition suitable for a small character carrying this pile in front of their chest. Richly shaped bread objects rather than flat UI icon glyphs. Keep the forms simple enough to read at 50 pixels wide. One isolated prop only. True transparent background and generous transparent padding on every side. No basket, bag, plate, table, floor, character, hands, badge, circular backing, letters, numbers, text, sparkles or watermark. Exactly three bread pieces and no additional crumbs shaped like bread.

빵집 가게 (내장 image_gen, transparent_background=true):

Use case: illustration-story. Asset type: transparent game sprite, isolated cozy fantasy bakery storefront for a cute chibi board game. Primary request: one small inviting bakery, readable simple silhouette, hand-painted clean cartoon illustration with warm brown outlines, cream stucco, honey wood trim, rounded terracotta roof, a small sign displaying only a thick loaf-of-bread pictogram (no lettering), one side display window with three chunky breads. Straight-on front elevation with a very slight view of the roof top, no ground plane or surrounding scenery. CRITICAL: in the lower middle of the facade there is one very large OPEN arched doorway, pitch-dark empty interior; the doorway opening spans approximately horizontal 43%-64% and vertical 52%-92% of the building's full bounds, touching the doorstep. No door leaf blocking it, no people inside or outside. The doorway must be a simple clean dark shape so a separately animated small character can walk into it. A short visible wooden doorstep. Bold friendly forms, restrained details, no ornate decoration. Entire building fully within the image with transparent padding on all sides; genuine transparent background. The building fills most of a square image. No environment, no text, no letters, no watermark, no characters, no explosion or effects.

밀가루 연기 (내장 image_gen, transparent_background=true):

Use case: illustration-story. Asset type: transparent 2D game VFX sprite, one isolated flour dust puff for a cute bakery slapstick animation. A single compact irregular cloud of white flour with a few tiny detached dust wisps, hand painted soft warm ivory and pale beige shaded folds, readable bold organic silhouette, restrained texture, fluffy and soft edges but clearly visible on a green game board. Side view, no ground or background, no hard geometric circles, no explosion flames, no objects, no characters, no text, no symbols. Fill the center of a square image with generous transparent padding. True transparent background.
