# 포춘쿠키 접시와 수북한 더미

- `cookie_platter_heaped.tscn`: 쿠키 선택용 3D 소품. 얕은 흰 접시와 높이·기울기가 제각각인 포춘쿠키 16개를 배치한다.
- `plate_runtime.scn`: 게임용 압축 접시 모델. 1,920개 삼각형, 텍스처 없는 단색 재질 2개.
- 쿠키는 기존 `../fortune-cookie-whole.glb` 하나를 16번 인스턴싱한다. 새 쿠키 메시·텍스처를 내보내거나 복제하지 않는다. `PickCookie_01`~`16`을 각각 꺼내기 대상으로 사용할 수 있다.
- 배치는 Blender의 중력·충돌로 정착시킨 뒤 고정했다. 임시 가이드는 최종 모델에서 제거했다. 게임에서 계속 물리 계산을 실행하지 않는다.
- 원본: `art_source/selection_props/cookie_platter_v1.blend`, `art_source/selection_props/cookie_platter_v1/ceramic_plate.glb`.
- 재현: `tools/art/build_cookie_platter_v1.py`로 모델과 배치를 만들고, `tools/art/preview_cookie_platter.gd`로 접시를 게임용 압축 SCN으로 변환·검증한다.
- 기존 과자통 3D 자산은 `art_source/selection_props/archive_tin_v2/`로 옮겨 게임용 자산에서 제외했다. 원래 포춘쿠키 파일과 깨짐 연출은 수정하지 않았다.
- 이 단계는 소품 교체다. 실제 쿠키 선택 조작은 다음 연결 작업에서 이 장면을 사용한다.
