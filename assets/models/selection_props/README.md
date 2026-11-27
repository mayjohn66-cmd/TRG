# 직접 선택 소품 — 3D 자산 준비

포춘쿠키 선택 소품은 **`../fortune_cookie/platter_v1/cookie_platter_heaped.tscn`**으로 교체했다. 얕은 접시와 기존 모델을 공유하는 쿠키 16개를 쌓아 둔다. 아래 과자통은 `art_source/selection_props/archive_tin_v2/`에 보관하며 게임용 자산에서 제외했다. 아이스크림 선택 소품은 2D `assets/fx/judgment/icebox_2d/`를 사용한다.

다음 표는 이전 `v2/` 3D 시안 기록이다. Blender 5.2.4 LTS에서 제작·재열기·GLB 구조 검증을 했다.

| 파일 | 구성 |
|---|---|
| `cookie_tin_open.glb` | 민트색 금속 과자통, 크림색 안쪽, 황동 테두리, 열린 뚜껑 |
| `cookie_tin_filled.glb` | 같은 통 + 기존 포춘쿠키 5개 (`PickCookie_01`~`05`) |
| `icebox_open.glb` | 파란 아이스박스, 단열 내벽, 열린 뚜껑·손잡이·잠금쇠 |
| `icebox_stocked.glb` | 같은 박스 + 얼음 40개 + 포장 아이스크림 12개 (`PickWrapped_01`~`12`) |
| `wrapped_strawberry_chocolate.glb` | 딸기 문양의 분홍 포장 |
| `wrapped_chocolate.glb` | 초콜릿 문양의 갈색 포장 |
| `wrapped_mint_chocolate.glb` | 민트 잎 문양의 민트색 포장 |
| `icecream_strawberry_chocolate.glb` | 딸기 아이스크림·초콜릿 코팅·얇은 나무 막대 |
| `icecream_chocolate.glb` | 초콜릿 아이스크림·초코 코팅·밀크초코 줄무늬 |
| `icecream_mint_chocolate.glb` | 민트 아이스크림·초콜릿 칩 |

- 뚜껑은 `CookieLidPivot`·`IceboxLidPivot`을 기준으로 움직인다. 쿠키·포장 아이스크림·얼음은 실제 개별 3D 오브젝트로 분리되어 있다.
- 원본: `art_source/selection_props/selection_props_v2.blend`. 원본 폴더는 `.gdignore`로 게임 임포트에서 제외한다. v1은 같은 폴더의 `archive_v1/`에 보관한다.
- 재현 스크립트: `tools/art/build_selection_props_v2.py`. 원래 포춘쿠키 GLB는 읽기 전용으로 가져오며 원본 해시를 검증한다.
- 검증: `tools/art/check_selection_props_v2.py`(저장 원본 재열기·유한 좌표·재질·UV·개수·GLB 검사), `tools/art/check_selection_props.gd`(Godot 로딩).
- 2D 연출에서도 같은 외형을 쓸 수 있도록 `assets/fx/judgment/icecream_variants/v1/`에 3종 투명 렌더를 저장한다. 별도 얼음 레이어도 같은 3D 얼음을 렌더한 투명 이미지다.
- 이 자산에는 과자통·아이스박스의 생성 그림을 사용하지 않았다. 물체의 두께·안쪽·뚜껑·포장지는 모두 메시다.
