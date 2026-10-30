# File: res://scenes/font_sizes.gd
# Class: class_name FontSizes
# Role: 글자 크기 표준 사다리. 글꼴은 크기마다 글리프(한글·일본어 수천 자)를 따로 구워 텍스처에 쌓으므로,
#       글자 맞추기(1px씩 줄이며 재기)나 제각각인 크기가 쌓이면 웹 메모리가 불어난다. 작은 글자는 1px 단위,
#       큰 글자는 굵은 간격만 쓴다. 크기 변화 연출은 font_size 대신 노드의 scale 트윈으로 한다.
class_name FontSizes
extends RefCounted

const LADDER: Array[int] = [6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 22, 24, 26, 28, 32, 36, 40, 44, 48, 56, 64, 72, 96, 120]


## px 이하에서 가장 큰 표준 크기 (줄이는 쪽으로 맞춰 칸을 넘지 않게).
static func snap(px: int) -> int:
	if px <= LADDER[0]:
		return maxi(px, 1)
	var result: int = LADDER[0]
	for size: int in LADDER:
		if size > px:
			break
		result = size
	return result


## 글자 맞추기에서 재 볼 크기들: start_px부터 min_px까지 표준 크기만 큰 것부터.
static func steps(start_px: int, min_px: int) -> Array[int]:
	var result: Array[int] = []
	for index: int in range(LADDER.size() - 1, -1, -1):
		var size: int = LADDER[index]
		if size <= start_px and size >= min_px:
			result.append(size)
	if result.is_empty() or result.back() != snap(min_px):
		result.append(snap(min_px))
	return result


## px 바로 아래 표준 크기.
static func next_down(px: int) -> int:
	return snap(px - 1)
