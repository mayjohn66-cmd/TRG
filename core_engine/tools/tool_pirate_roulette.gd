# File: res://core_engine/tools/tool_pirate_roulette.gd
# Class: class_name ToolPirateRoulette
# Role: 해적 룰렛 (신규 판정 도구) - 해적이 든 통의 구멍 8개에 칼을 하나씩 꽂는다. 꽂을 때마다 +2칸 누적, 해적이 튀어나오면 누적 0칸 + 턴 종료.
#       멈추면(cash_out) 누적한 칸만큼 전진. 해적 구멍은 8개 중 하나라 7번 모두 무사하면 14칸으로 자동 확정된다. (러시안 룰렛 리볼버와 같은 연속 시도형)
class_name ToolPirateRoulette
extends BaseJudgmentTool

const HOLES: int = 8
const STEPS_PER_SWORD: int = 2
const MAX_STEPS: int = STEPS_PER_SWORD * (HOLES - 1)

var _armed: bool = false
## 몇 번째로 꽂는 칼에서 해적이 튀어나오는가 (0부터).
var _pirate_slot: int = 0
var swords: int = 0
var accumulated: int = 0
## 칼을 꽂은 구멍 번호 (연출용, 꽂은 순서대로). 어느 구멍이 해적인지와는 상관없이 순서만 정해 둔다.
var holes: Array[int] = []
var _order: Array[int] = []
## 플레이어가 고른 구멍 (1.3.1 구멍을 눌러 꽂기, -1 = 정해진 순서대로). 해적이 튀어나오는 차례(몇 번째 칼)와는 상관없다 - 칼이 꽂히는 자리만 바뀐다.
var _preferred: int = -1


func prefer_hole(hole: int) -> void:
	_preferred = hole


func _init() -> void:
	tool_id = &"DICE_PIRATE"
	display_name = "해적 룰렛"


func has_pending_state() -> bool:
	return _armed and accumulated > 0


## 해적 구멍(몇 번째 칼에서 튀어나오는지)과 꽂는 구멍 순서를 정한다. 재현 가능한 판정/테스트용.
func arm(pirate_slot: int, order: Array[int] = []) -> void:
	_pirate_slot = clampi(pirate_slot, 0, HOLES - 1)
	swords = 0
	accumulated = 0
	holes.clear()
	_order = order.duplicate()
	if _order.size() != HOLES:
		_order.clear()
		for index: int in HOLES:
			_order.append(index)
	_armed = true


## 칼을 하나 꽂는다. 통이 준비되지 않았으면 RNG로 해적 구멍과 꽂는 순서를 정한다.
func roll(rng: RandomNumberGenerator) -> RollResult:
	if not _armed:
		var order: Array[int] = sample_distinct(rng, HOLES, HOLES)
		arm(rng.randi_range(0, HOLES - 1), order)
	if _preferred >= 0 and _preferred < HOLES and not holes.has(_preferred):
		var at: int = _order.find(_preferred)
		if at > swords:
			_order[at] = _order[swords]
			_order[swords] = _preferred
	_preferred = -1
	var hole: int = _order[swords]
	holes.append(hole)
	if swords == _pirate_slot:
		var lost: int = accumulated
		var stuck: Array[int] = holes.duplicate()
		_reset()
		var popped: RollResult = RollResult.make(tool_id, 0, {"popped": true, "lost": lost, "swords": stuck.size(), "holes": stuck})
		popped.ends_turn = true
		return popped
	swords += 1
	accumulated = mini(accumulated + STEPS_PER_SWORD, MAX_STEPS)
	if swords >= HOLES - 1:
		return _commit(false)
	var pending: RollResult = RollResult.make(tool_id, accumulated, {"popped": false, "accumulated": accumulated, "swords": swords, "holes": holes.duplicate()})
	pending.can_continue = true
	return pending


func cash_out() -> RollResult:
	if not has_pending_state():
		return null
	return _commit(true)


func _commit(voluntary: bool) -> RollResult:
	var total: int = accumulated
	var stuck: Array[int] = holes.duplicate()
	_reset()
	return RollResult.make(tool_id, total, {"popped": false, "accumulated": total, "swords": stuck.size(), "holes": stuck, "voluntary": voluntary, "full": stuck.size() >= HOLES - 1})


func _reset() -> void:
	_armed = false
	swords = 0
	accumulated = 0
	holes.clear()


static func caption(details: Dictionary, steps: int, can_continue: bool = false) -> String:
	if bool(details.get("popped", false)):
		return "해적이 튀어나왔다! 누적 %d칸 사라짐, 턴 종료" % int(details.get("lost", 0))
	if bool(details.get("full", false)):
		return "칼 7개 모두 무사! %d칸 확정" % steps
	if can_continue:
		return "푹! 칼 %d개 · 누적 %d칸" % [int(details.get("swords", 0)), steps]
	return "멈추고 %d칸 이동 확정" % steps
