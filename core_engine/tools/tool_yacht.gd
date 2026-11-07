# File: res://core_engine/tools/tool_yacht.gd
# Class: class_name ToolYacht
# Role: 야추 다이스 - 주사위 5개를 굴린 뒤, 마음에 드는 주사위를 고정(Keep)하고 나머지를 최대 2번 다시 굴려 족보를 맞춘다. 확정(cash_out)하면 족보 칸수만큼 전진 (야추는 12칸 + 한 번 더)
class_name ToolYacht
extends BaseJudgmentTool

const DICE_COUNT: int = 5
const MAX_REROLLS: int = 2
const STEPS_TRIPLE: int = 5
const STEPS_SMALL_OR_FULL: int = 7
const STEPS_FOUR_OR_LARGE: int = 9
const STEPS_YACHT: int = 12

var dice: Array[int] = []
var rerolls_left: int = 0
var _started: bool = false
## 다음 다시 굴리기에서 고정할 주사위 (TurnManager가 굴림 행동의 keep 인자로 넣어 준다).
var _keep: Array[bool] = []


func _init() -> void:
	tool_id = &"DICE_YACHT"
	display_name = "야추 다이스"


func has_pending_state() -> bool:
	return _started


## 다음 다시 굴리기에서 고정할 주사위 표시를 정한다 (5개 bool). 길이가 맞지 않으면 모두 고정 안 함.
func set_keep(mask: Array) -> void:
	_keep = []
	for index: int in DICE_COUNT:
		_keep.append(index < mask.size() and bool(mask[index]))


## 첫 굴림이면 5개를 모두 굴리고(남은 다시 굴리기 2회), 이미 진행 중이면 고정하지 않은 주사위만 다시 굴린다. 다시 굴릴 횟수가 없으면 현재 족보로 확정한다.
func roll(rng: RandomNumberGenerator) -> RollResult:
	if not _started:
		dice = []
		for i: int in DICE_COUNT:
			dice.append(rng.randi_range(1, 6))
		_started = true
		rerolls_left = MAX_REROLLS
		_keep = []
		return _pending([0, 1, 2, 3, 4])
	if rerolls_left <= 0:
		return _commit(false)
	var rolled: Array[int] = []
	for index: int in DICE_COUNT:
		if index < _keep.size() and _keep[index]:
			continue
		dice[index] = rng.randi_range(1, 6)
		rolled.append(index)
	rerolls_left -= 1
	var kept_before: Array[bool] = _keep.duplicate()
	_keep = []
	return _pending(rolled, kept_before)


func cash_out() -> RollResult:
	if not _started:
		return null
	return _commit(true)


func _pending(rolled: Array[int], kept: Array[bool] = []) -> RollResult:
	var hand: Dictionary = evaluate(dice)
	var pending: RollResult = RollResult.make(tool_id, int(hand["steps"]), {
		"dice": dice.duplicate(), "rolled": rolled, "kept": kept, "rerolls_left": rerolls_left,
		"hand": hand["hand"], "label": hand["label"], "preview_steps": int(hand["steps"]), "confirmed": false,
	})
	pending.can_continue = true
	return pending


func _commit(voluntary: bool) -> RollResult:
	var hand: Dictionary = evaluate(dice)
	var result: RollResult = RollResult.make(tool_id, int(hand["steps"]), {
		"dice": dice.duplicate(), "rolled": [], "kept": [], "rerolls_left": rerolls_left,
		"hand": hand["hand"], "label": hand["label"], "preview_steps": int(hand["steps"]), "confirmed": true, "voluntary": voluntary,
	})
	result.reroll = hand["hand"] == &"yacht"
	_reset()
	return result


func _reset() -> void:
	_started = false
	dice = []
	rerolls_left = 0
	_keep = []


## 5개 눈금의 족보와 이동 칸수. 야추 > 포카드·라지 스트레이트 > 스몰 스트레이트·풀하우스 > 트리플 > 찬스(가장 높은 눈금의 절반 올림).
static func evaluate(values: Array) -> Dictionary:
	var counts: Dictionary = {}
	var highest: int = 0
	for value: Variant in values:
		var face: int = int(value)
		counts[face] = int(counts.get(face, 0)) + 1
		highest = maxi(highest, face)
	var sizes: Array[int] = []
	for face: Variant in counts.keys():
		sizes.append(int(counts[face]))
	sizes.sort()
	sizes.reverse()
	var most: int = sizes[0] if not sizes.is_empty() else 0
	var distinct: Array[int] = []
	for face: Variant in counts.keys():
		distinct.append(int(face))
	distinct.sort()
	var run: int = _longest_run(distinct)
	if most == DICE_COUNT:
		return {"hand": &"yacht", "label": "★ 야추!", "steps": STEPS_YACHT}
	if most == 4:
		return {"hand": &"four", "label": "포카드", "steps": STEPS_FOUR_OR_LARGE}
	if run >= 5:
		return {"hand": &"large_straight", "label": "라지 스트레이트", "steps": STEPS_FOUR_OR_LARGE}
	if most == 3 and sizes.size() > 1 and sizes[1] == 2:
		return {"hand": &"full_house", "label": "풀하우스", "steps": STEPS_SMALL_OR_FULL}
	if run >= 4:
		return {"hand": &"small_straight", "label": "스몰 스트레이트", "steps": STEPS_SMALL_OR_FULL}
	if most == 3:
		return {"hand": &"triple", "label": "트리플", "steps": STEPS_TRIPLE}
	return {"hand": &"chance", "label": "노페어 (찬스)", "steps": (highest + 1) / 2}


static func _longest_run(sorted_faces: Array[int]) -> int:
	var best: int = 0
	var current: int = 0
	var previous: int = -10
	for face: int in sorted_faces:
		current = current + 1 if face == previous + 1 else 1
		previous = face
		best = maxi(best, current)
	return best
