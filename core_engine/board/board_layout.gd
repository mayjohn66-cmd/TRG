# File: res://core_engine/board/board_layout.gd
# Class: class_name BoardLayout
# Role: 타일 번호 -> 0~1 정규화 평면 좌표(우하단 0번에서 반시계). 화면 렌더링과 흑돌 알까기 필살기의 직선 충돌 판정이 같은 좌표계를 쓴다
class_name BoardLayout
extends RefCounted


## 타일 번호 -> 0~1 정규화 좌표. 출발선(0번)은 우하단에서 시작해 반시계 방향으로 한 변 BoardSpec.side칸씩 돈다:
## 0 우하단 -> 한 변 우상단 -> 두 변 좌상단 -> 세 변 좌하단 -> 다시 0. 가운데는 타일이 없는 넓은 빈 무대다.
## 코너 타일이 크기 때문에 한 변의 일반 타일은 코너에서 이만큼(변 길이의 비율) 떨어진 곳에서 시작해 균등하게 놓인다.
const CORNER_REACH: float = 0.17


## 한 변 위의 위치(0~1): 0번째와 마지막 번째는 코너, 그 사이 일반 타일은 코너 여유를 두고 균등 배치.
static func _along(k: int, step: int) -> float:
	if k <= 0:
		return 0.0
	if k >= step:
		return 1.0
	if step < 3:
		return float(k) / float(step)
	return CORNER_REACH + (1.0 - 2.0 * CORNER_REACH) * float(k - 1) / float(step - 2)


static func tile_norm(index: int) -> Vector2:
	var step: int = BoardSpec.side
	if index <= step:
		return Vector2(1.0, 1.0 - _along(index, step))
	if index <= step * 2:
		return Vector2(1.0 - _along(index - step, step), 0.0)
	if index <= step * 3:
		return Vector2(0.0, _along(index - step * 2, step))
	return Vector2(_along(index - step * 3, step), 1.0)


## 좌표에서 가장 가까운 타일 번호 (출발선 0번 제외: 알까기로 날아간 돌은 1~23번 중 한 곳에 안착한다).
static func nearest_tile(point: Vector2) -> int:
	var best: int = 1
	var best_distance: float = INF
	for index: int in range(1, BoardSpec.tile_count):
		var distance: float = tile_norm(index).distance_to(point)
		if distance < best_distance - 0.000001:
			best_distance = distance
			best = index
	return best


## 점 p에서 선분 a-b까지의 최단 거리.
static func distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var length_sq: float = ab.length_squared()
	if length_sq <= 0.0000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
