# 카드 일러스트 공통 제작 기준

사용자 피드백: 제작이 진행될수록 배경이 화려해져 캐릭터가 묻혔다. 앞으로 카드 삽화의 기본은 **캐릭터와 핵심 동작을 먼저 읽을 수 있는 단순한 배경**이다.

- 배경은 단색 또는 매우 옅은 두 색 그라데이션. 밝고 낮은 대비의 넓은 여백을 둔다.
- 마을·건물·숲·실내 장식·원경·세밀한 바닥 무늬를 넣지 않는다. 복잡한 풍경을 흐리게 처리하는 방식도 피한다.
- 캐릭터와 효과에 꼭 필요한 소품만 그린다. 바나나, 소환 덩굴, 포탈, 타로, 택배, 클로버 등은 핵심 소품이다.
- 바닥·수면·바위는 위치와 행동을 설명하는 최소 형태만. 호수 장면은 단순한 수면 띠와 바위 하나로 충분하다.
- 효과선·반짝임은 소수의 굵고 단순한 형태만 쓰고, 얼굴이나 주요 소품을 가리지 않는다. 빛 입자·꽃·낙엽·보케를 화면 전체에 흩뿌리지 않는다.
- 3등신 치비, 큰 볼, 네 손가락 또는 단순한 주먹 손, 기존 캐릭터 외형과 읽기 쉬운 동작을 유지한다.
- 실제 손패 크기 140×220에서 얼굴·핵심 소품이 가장 먼저 보이는지 확인한다. 캐릭터보다 배경이 먼저 눈에 띄면 단순화한다.

공통 프롬프트 핵심:

> Character-first simple game-card illustration. Nearly flat pale pastel background or extremely gentle two-color gradient, large quiet negative space, no detailed environment or blurred scenery. Only the character, essential action props, minimal contextual ground/water, and a few broad action accents. Clean silhouettes readable at tiny card size.

`simple-background-v5` 적용: ACT_08, ACT_13, TRP_06, TRP_07, TRP_08, TRP_C02, TRP_C03, TRP_C04. 이미 단순한 효과선 배경인 ACT_09와 ACT_15는 이번 교체 대상에 포함하지 않았다. 기존 캐릭터·구도·동작을 입력 이미지로 고정해 내장 이미지 생성 도구에서 배경을 편집했다.

교체 전 PNG/임포트, 새 원본, 프롬프트, 해시, 실제 카드 UI 및 비교 검수는 작업 폴더 `outputs/cards-simple-bg-v05/`에 보관한다. 원본 PNG는 생성 결과 그대로 복사하고 기존 임포트 설정과 UID를 유지한다.
