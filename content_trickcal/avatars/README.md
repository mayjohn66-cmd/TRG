# 아바타 에셋 (사도 Spine 캐릭터 자리)

게임 화면의 좌석 프로필(`AvatarSlot`)이 읽는 폴더입니다. 캐릭터마다 폴더 하나를 만듭니다.

```
content_trickcal/avatars/
  default/            <- 캐릭터 id (없으면 자리표시자 P1~P4 + 감정 이름만 보임)
    frames.tres       <- (권장) SpriteFrames 스프라이트 시트. 애니메이션 이름 = 감정
    portrait.png      <- (대체) 정지 이미지 한 장. 감정은 튕김/떨림 연출로만 보임
```

- `frames.tres` 애니메이션 이름: `idle`(기본, 필수) / `happy` / `angry` / `surprised` / `sad` / `cheer`. 없는 감정은 `idle`로 대신합니다.
- 칸 크기: 일반 프로필 84x84, 위쪽(맞은편) 한 줄 프로필 48x48. 이미지는 칸 높이에 맞춰 줄어들며 가운데 정렬됩니다. 권장 원본은 256x256 이상, 배경 투명.
- 캐릭터 지정은 `AvatarSlot.set_character(&"캐릭터id")`. 지금은 모든 좌석이 `default`를 씁니다(로비에서 캐릭터를 고르는 기능은 다음 단계).
- 반응이 일어나는 때: 말이 잡힘(피해자 angry / 잡은 쪽 happy), 완주(cheer), 설치물 발동(surprised), 카드 사용(happy), 게임 종료(승자 cheer / 나머지 sad).
- Spine 런타임을 직접 쓰려면 `AvatarSlot.use_frames()` 대신 같은 칸(`_stage`) 안에 Spine 노드를 넣는 확장을 추가하면 됩니다. 웹 내보내기 지원 여부를 먼저 확인하세요.
- **주의:** 원본 게임에서 가져온 에셋은 개발사 2차 창작 가이드라인을 확인하기 전에는 이 저장소(공개 저장소이고 웹으로 배포됨)에 올리지 마세요.
