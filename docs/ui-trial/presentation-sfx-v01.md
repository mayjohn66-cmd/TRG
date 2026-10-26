# 추가 연출 전용 효과음 (2026-10-26)

다운로드한 CC0 녹음으로 9개 이벤트(12개 Ogg, 합계 69,840 bytes)를 추가했다.
원본 ZIP/WAV는 게임 폴더 밖에 보관하고, 게임에는 24 kHz 모노 Vorbis만 넣는다.

| 연출 | 연결 순간 | 새 이벤트 |
| --- | --- | --- |
| 폭주 기관차 | 레일 착지 / 출발 / 가속되는 구동 박자 | `rail_lay`, `train_whistle`, `train_chug` |
| 강제 연대책임 | 사슬이 뻗기 시작 / 중앙 자물쇠 결속 | `chain_pull`, `chain_lock` |
| 에르핀의 빵집 털이 | 문 진입 / 안에서 네 번 소동 | `bakery_door`, `bakery_rummage` |
| 도적단 대습격 | 눈 컷인의 충격 프레임 | `cutin_slash` |
| 핀볼 | 실제 궤도의 범퍼 접촉 | `pinball_hit` |

기존 애니메이션 시점, 배속, 물리, 보상은 그대로 사용한다. 레일·사슬·소동의
복수 녹음은 기존 연속 중복 방지 경로를 따른다. 반복 박자는 작게, 결속·컷인은
상대적으로 또렷하게 보정했다. 공통 재생 풀은 빈 재생기를 먼저 사용해 긴
기적을 짧은 구동음이 순번만으로 끊지 않게 했다. 전체·효과음 음소거와 사용자
음원 우선순위도 기존 경로를 사용한다.

원본 출처·이용 조건은 `assets/sfx/curated/CREDITS.md` 및
`licenses/Presentation-CC0.txt`, 개별 원본/결과 SHA-256과 편집값은
`manifest.json`에 기록했다. 재생성은
`python tools/audio/add_presentation_sfx.py <원본 폴더> <ffmpeg>`로 한다.

검증은 이번 효과음과 이를 연결한 연출에 한정했다.

- `sfx_assets_test.gd`: 62개 이벤트 스트림·변형·사용자 덮어쓰기 정상.
- `sfx_playback_test.gd`: 네이티브 Dummy 오디오 믹서에서 새 이벤트 9종 모두
  실제 PCM 출력 확인. 측정 peak 0.16~0.52로 무음/클리핑 없음. 24회 구동음 중
  기적 유지, 전체/효과음 음소거도 확인했다.
- `ui_train_test.gd`, `ui_bond_test.gd`, `ui_bakery_test.gd`,
  `ui_raid_test.gd`: 각각 기존의 해당 연출 전용 검사 통과.
- 네이티브 핀볼 한 번의 궤도 재생에서 `pinball_hit` 호출과 지정 포켓 도착 확인.
- 배포 범위 `presentation-sfx`는 위 연출과 음원 검사만 실행하고, 내보낸 PCK의
  스트림 로드와 기존 40 MiB 최초 다운로드 예산도 확인한다.

네이티브 믹서 검사는 헤드리스가 아닌 환경에서
`godot --path . --audio-driver Dummy --rendering-method gl_compatibility -s res://tests/sfx_playback_test.gd`
로 실행한다. 개인 저장값을 건드리지 않도록 APPDATA/LOCALAPPDATA를 별도 작업
폴더로 지정했다. 이 환경의 기존 루트 인증서 경고와 연출 검사 종료 시
렌더러 자원 경고는 오디오 실패로 분류하지 않았다. 실제 귀로 듣는 음색 선호와
기기별 최종 음량은 이 PCM 검사만으로 판단할 수 없다.
