# 도적단 대습격 "SHING" 컷인 시안

방식: 내장 image_gen, 캐릭터 참고 생성. 승인된 시안을 그대로 가져와 습격 컷인에 쓴다.

참고 그림: `content_trickcal/illustrations/pawns/NPC_ROBBER.png`

## 프롬프트 (생성 기록 원문)

같은 그림을 다시 만들 때 그대로 써야 하므로 영어 원문을 보존한다. 내용: 초증강 [도적단 대습격]의 "SHING!" 정지 장면을 16:9 한 장으로. 기존 보라 두건 치비 도적(검은 눈가면, 작은 금 자루)의 가면 쓴 눈을 대각선 띠에 크게 잡고, 오른쪽 아래에서 커다란 보라 장갑 손이 훔친 카드 세 장을 앞으로 내민다. 빨강·검정·상아 대비의 괴도물 컷인 느낌, 배경은 아주 단순하게, 글자·로고 없음.

Use case: stylized-concept. Create ONE wide 16:9 game cut-in illustration concept for the Korean cute board game's "Bandit Mass Raid" super augment, the exact instantaneous SHING! / critical reveal freeze-frame. Reference image role: character identity reference ONLY. Use the supplied existing purple-hooded chibi robber: dark muted purple pointed hood and cloak, beige round cheeky face, black domino eye mask, two ivory eyes, small gold loot sack. Preserve its cute squat toy-like character identity, not an adult human.

Art direction: Persona 5-inspired phantom-thief attack cut-in energy, aggressive red / near-black / warm ivory graphic contrast, sharp diagonal torn-paper composition, bold thick black ink contours, huge clean flat cel-shadow shapes, sparse coarse screenprint grain. Dramatic extreme close-up of this robber's masked eyes and hood filling a long diagonal eye-panel from left to right across the middle. Eyes suddenly narrow with mischievous triumphant determination; one sharp ivory four-point SHING gleam flashes at the mask edge. Lower right, a single oversized purple mitten hand sweeps THREE stolen playing cards toward the viewer, cards clear and simple, tiny gold pouch peeking beside it. Main eye close-up is the dominant focal point, cards secondary; one character only, coherent anatomy, no fingers visible on mitten.

Make the background VERY SIMPLE: one flat scarlet field, one large near-black slanted slab behind the eye panel, only two or three ivory razor-shaped impact accents. Clear negative space and instantly readable silhouette. Editorial Japanese heist comic finish with cute comedic chibi attitude, not photorealistic, no scenery, no complex background, no particle cloud, no gradient glow, no UI, no typography, no letters, no words, no logo, no Persona characters, no watermark. A finished single illustration, not a mockup sheet or multiple options.

## 게임 적용

승인된 원본 그림은 그대로다. 1024px·밉맵·손실 압축으로 임포트한다. `RaidCutin`은 길고 좁은 대각선 띠로 가면 쓴 눈만 보여 주고, 띠 끝은 빨강, 가장자리는 거칠게 찢긴 흰색이다. 눈보다 먼저 흰 붓 찢김이 지나간다. 나갈 때는 흰 잉크가 오른쪽에서 왼쪽으로 눈을 지우며 띠가 오므라들고, 잠깐 흰 조각이 남는다. 띠 밖은 24%만 어둡게 해 보드가 잘 보인다. 보통 속도에서 1.05초이고, 덮개가 사라진 뒤에야 보상이 들어온다. 초기화하면 덮개가 그 주인 `RaidStage`와 함께 해제된다. 예전의 전체 그림 패널과 맞물려 갈라지는 퇴장은 바꿨다.
