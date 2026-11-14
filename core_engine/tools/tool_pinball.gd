# File: res://core_engine/tools/tool_pinball.gd
# Class: class_name ToolPinball
# Role: 클래식 구슬 핀볼 - 발사대에서 쏜 쇠구슬이 못(Peg)에 튕기며 내려와 하단 7개 구멍 중 하나에 들어간다. 들어간 구멍의 숫자(1~10)만큼 전진. 구멍은 호스트 RNG가 정하고 발사 세기·구슬 궤적은 연출일 뿐이다
class_name ToolPinball
extends BaseJudgmentTool

## 하단 구멍의 숫자 (왼쪽부터). 가운데 ★10은 드물다.
const HOLES: Array[int] = [2, 4, 6, 10, 5, 3, 1]
## 구멍이 걸릴 가중치 (HOLES와 같은 순서). 합 100.
const WEIGHTS: Array[int] = [14, 16, 14, 8, 16, 16, 16]


func _init() -> void:
	tool_id = &"DICE_PINBALL"
	display_name = "클래식 구슬 핀볼"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var hole: int = pick_hole(rng.randi_range(0, 99))
	# 구슬이 못에 튕기는 좌우 순서 (연출 전용): 구멍 쪽으로 이어지도록 호스트 RNG에서 뽑아 모든 화면이 똑같이 보게 한다.
	var bounces: Array[int] = []
	for i: int in 6:
		bounces.append(rng.randi_range(0, 1))
	return RollResult.make(tool_id, HOLES[hole], {"hole": hole, "value": HOLES[hole], "bounces": bounces})


## 0~99 값을 가중치에 따라 구멍 번호(0~6)로 바꾼다.
static func pick_hole(roll_value: int) -> int:
	var acc: int = 0
	for index: int in WEIGHTS.size():
		acc += WEIGHTS[index]
		if roll_value < acc:
			return index
	return WEIGHTS.size() - 1
