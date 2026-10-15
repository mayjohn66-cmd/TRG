# File: res://core_engine/board/board_layout.gd
# Class: class_name BoardLayout
# Role: 타일 번호 -> 0~1 정규화 평면 좌표(우하단 0번에서 반시계). 화면 렌더링과 흑돌 알까기 필살기의 직선 충돌 판정이 같은 좌표계를 쓴다
class_name BoardLayout
extends RefCounted


## 타일 번호 -> 0~1 정규화 좌표. 출발선(0번)은 우하단에서 시작해 반시계 방향으로 돈다: 0 우하단 -> 5 우상단 -> 10 좌상단 -> 15 좌하단 -> 다시 0.
## 지름길 1은 5(우상단)->20,21,22(중앙),23,24->15(좌하단), 지름길 2는 10(좌상단)->25,26,22,27,28->0(우하단).
static func tile_norm(index: int) -> Vector2:
	if index <= 5:
		return Vector2(1.0, 1.0 - index / 5.0)
	if index <= 10:
		return Vector2(1.0 - (index - 5) / 5.0, 0.0)
	if index <= 15:
		return Vector2(0.0, (index - 10) / 5.0)
	if index <= 19:
		return Vector2((index - 15) / 5.0, 1.0)
	match index:
		20: return Vector2(5.0 / 6.0, 1.0 / 6.0)
		21: return Vector2(4.0 / 6.0, 2.0 / 6.0)
		22: return Vector2(0.5, 0.5)
		23: return Vector2(2.0 / 6.0, 4.0 / 6.0)
		24: return Vector2(1.0 / 6.0, 5.0 / 6.0)
		25: return Vector2(1.0 / 6.0, 1.0 / 6.0)
		26: return Vector2(2.0 / 6.0, 2.0 / 6.0)
		27: return Vector2(4.0 / 6.0, 4.0 / 6.0)
		28: return Vector2(5.0 / 6.0, 5.0 / 6.0)
	return Vector2(0.5, 0.5)


## 좌표에서 가장 가까운 타일 번호 (출발선 0번 제외: 알까기로 날아간 돌은 1~28번 중 한 곳에 안착한다).
static func nearest_tile(point: Vector2) -> int:
	var best: int = 1
	var best_distance: float = INF
	for index: int in range(1, GameEnums.TILE_COUNT):
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
