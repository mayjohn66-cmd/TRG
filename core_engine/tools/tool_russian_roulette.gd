# File: res://core_engine/tools/tool_russian_roulette.gd
# Class: class_name ToolRussianRoulette
# Role: 러시안 룰렛 리볼버 - 빈 총이 나올 때마다 +3칸 누적(최대 15), 실탄 발사 시 누적 0칸 증발 + 턴 종료. 멈추면(cash_out) 누적치만큼 전진
class_name ToolRussianRoulette
extends BaseJudgmentTool

const CHAMBERS: int = 6
const STEPS_PER_EMPTY: int = 3
const MAX_STEPS: int = 15

var _loaded: bool = false
var _bullet_slot: int = 0
var _pulls: int = 0
var accumulated: int = 0


func _init() -> void:
	tool_id = &"REVOLVER"
	display_name = "러시안 룰렛 리볼버"


func has_pending_state() -> bool:
	return _loaded and accumulated > 0


## 실탄 위치(0~5번째 당김)를 지정해 탄창을 장전한다. 재현 가능한 판정/테스트용.
func load_chamber(bullet_slot: int) -> void:
	_bullet_slot = clampi(bullet_slot, 0, CHAMBERS - 1)
	_pulls = 0
	accumulated = 0
	_loaded = true


## 방아쇠를 한 번 당긴다. 장전되어 있지 않으면 RNG로 실탄 위치를 정해 장전한다.
func roll(rng: RandomNumberGenerator) -> RollResult:
	if not _loaded:
		load_chamber(rng.randi_range(0, CHAMBERS - 1))
	if _pulls == _bullet_slot:
		var lost: int = accumulated
		_reset()
		var fired: RollResult = RollResult.make(tool_id, 0, {"fired": true, "lost": lost})
		fired.ends_turn = true
		return fired
	_pulls += 1
	accumulated = mini(accumulated + STEPS_PER_EMPTY, MAX_STEPS)
	if accumulated >= MAX_STEPS:
		return _commit(false)
	var pending: RollResult = RollResult.make(tool_id, accumulated, {"fired": false, "accumulated": accumulated})
	pending.can_continue = true
	return pending


func cash_out() -> RollResult:
	if not has_pending_state():
		return null
	return _commit(true)


func _commit(voluntary: bool) -> RollResult:
	var total: int = accumulated
	_reset()
	return RollResult.make(tool_id, total, {"fired": false, "accumulated": total, "voluntary": voluntary})


func _reset() -> void:
	_loaded = false
	_pulls = 0
	accumulated = 0
