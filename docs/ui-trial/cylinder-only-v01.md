# 약실 실린더 단독 3D 시제품

범위: 6약실 실린더, 한 발이 들어간 모습, 실린더 회전. 독립 미리보기 씬으로 확인한다.

- 반지름 1.03, 전체 두께 1.20, 약실 중심 반경 0.62.
- 실제 관통 약실 6개. 내부 반지름 0.215, 입구 모따기 반지름 0.235.
- 은색 몸체와 황동색 탄피는 별도 메시다. 탄피 1개는 실린더의 회전을 그대로 따른다.
- 회전 버튼: 1.65초 동안 4회전 후 감속 정지. 드래그: 실린더를 보는 각도 변경.

파일:

- `scenes/revolver_cylinder_preview.tscn`: 독립 미리보기. Godot에서 이 씬을 실행한다.
- `scenes/revolver_cylinder_3d.gd`: 모델 생성과 한 발 표시·회전.
- `assets/models/revolver/cylinder_v01.tscn`: 저장된 Godot 3D 모델.
- `assets/models/revolver/cylinder_v01.glb`: 같은 모델의 glTF 바이너리.
- `assets/models/revolver/cylinder_body_v01.res`: 실린더 본체 메시.

검증: 본체 3,224개 삼각형, 연결되지 않거나 중복 연결된 모서리 0개. 6개 약실 중심을 통과하는 광선은 본체와 충돌하지 않고, 외곽의 금속 면은 충돌한다. 저장된 메시와 GLB를 다시 읽었으며 실제 3D 렌더링에서 정면·측면·회전을 확인했다.
