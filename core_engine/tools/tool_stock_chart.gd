# File: res://core_engine/tools/tool_stock_chart.gd
# Class: class_name ToolStockChart
# Role: 엘리아스 주식 차트 (v1.1) - 주가(기본 6칸)가 매 굴림 오르내리고 그만큼 전진. 드물게 상한가(즉시 20칸) 또는 상장폐지(이동 0칸 + 선두 말 사출 + 턴 종료)
class_name ToolStockChart
extends BaseJudgmentTool

const BASE_PRICE: int = 6
const MIN_PRICE: int = 1
const MAX_PRICE: int = 12
## 상한가 칸 수와 확률(%) / 상장폐지 확률(%).
const LIMIT_UP_STEPS: int = 20
const LIMIT_UP_CHANCE: int = 6
const DELIST_CHANCE: int = 6
## 등락폭과 가중치 (합 100). 너무 오르거나 내리면 기준가 쪽으로 1 당긴다.
const DELTAS: Array[int] = [-3, -2, -1, 0, 1, 2, 3]
const DELTA_WEIGHTS: Array[int] = [8, 14, 18, 20, 18, 14, 8]
const PULL_BACK_FROM: int = 4
## 차트에 남겨 두는 최근 주가 수.
const HISTORY_SIZE: int = 4

const EVENT_NONE: StringName = &""
const EVENT_LIMIT_UP: StringName = &"limit_up"
const EVENT_DELISTED: StringName = &"delisted"

## 지금 주가 (= 다음 굴림의 기준). 판마다 기본값에서 시작해 굴릴 때마다 오르내린다.
var price: int = BASE_PRICE
var history: Array[int] = [BASE_PRICE]


func _init() -> void:
	tool_id = &"DICE_STOCK"
	display_name = "엘리아스 주식 차트"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var event_roll: int = rng.randi_range(0, 99)
	var before: int = price
	var event: StringName = event_for(event_roll)
	if event == EVENT_LIMIT_UP:
		_push_price(MAX_PRICE)  # 차트는 천장을 뚫는다
		price = BASE_PRICE
		return RollResult.make(tool_id, LIMIT_UP_STEPS, {"event": EVENT_LIMIT_UP, "before": before, "price": MAX_PRICE, "delta": MAX_PRICE - before, "history": history.duplicate()})
	if event == EVENT_DELISTED:
		_push_price(0)
		price = BASE_PRICE
		var crash: RollResult = RollResult.make(tool_id, 0, {"event": EVENT_DELISTED, "before": before, "price": 0, "delta": -before, "history": history.duplicate(), "eject_leader": true})
		crash.ends_turn = true
		return crash
	var delta: int = next_delta(price, rng.randi_range(0, 99))
	price = clampi(price + delta, MIN_PRICE, MAX_PRICE)
	_push_price(price)
	return RollResult.make(tool_id, price, {"event": EVENT_NONE, "before": before, "price": price, "delta": delta, "history": history.duplicate()})


## 0~99 값 → 사건 (상한가 / 상장폐지 / 보통 등락).
static func event_for(event_roll: int) -> StringName:
	if event_roll < LIMIT_UP_CHANCE:
		return EVENT_LIMIT_UP
	if event_roll < LIMIT_UP_CHANCE + DELIST_CHANCE:
		return EVENT_DELISTED
	return EVENT_NONE


## 지금 주가와 0~99 값 → 등락폭. 기준가에서 PULL_BACK_FROM 이상 벗어나 있으면 기준가 쪽으로 1 당긴다.
static func next_delta(current: int, delta_roll: int) -> int:
	var acc: int = 0
	var delta: int = 0
	for index: int in DELTA_WEIGHTS.size():
		acc += DELTA_WEIGHTS[index]
		if delta_roll < acc:
			delta = DELTAS[index]
			break
	if current - BASE_PRICE >= PULL_BACK_FROM:
		delta -= 1
	elif BASE_PRICE - current >= PULL_BACK_FROM:
		delta += 1
	return delta


func _push_price(value: int) -> void:
	history.append(value)
	while history.size() > HISTORY_SIZE:
		history.pop_front()
