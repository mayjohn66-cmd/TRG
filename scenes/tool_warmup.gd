# File: res://scenes/tool_warmup.gd
# Class: class_name ToolWarmup
# Role: 판정 도구 3D 화면 미리 그려 두기 (1.3.1, 게임 도중 멈칫 방지).
#       도구를 바꾸는 첫 시점은 4라운드 증강이다. 그 전(판 시작 ~ 3라운드)에 화면이 한가할 때마다 3D 도구 화면을 하나씩 만들어
#       보드 밑에 아주 작게·거의 투명하게 몇 프레임 그린다 (셰이더 준비·모델·텍스처를 그래픽 메모리에 올리기).
#       그린 화면은 갱신을 멈춘 채 판이 끝날 때까지 들고 있다가(모델·텍스처가 내려가지 않게) clear()로 지운다.
#       결과·난수와는 상관없다 (그림만).
class_name ToolWarmup
extends Control

## 하나를 다 그렸다 (테스트용).
signal warmed(tool_id: StringName)

## 미리 그릴 도구 (3D·무거운 그림을 쓰는 것). 기본 주사위·친치로는 판 시작부터 쓰므로 뺀다.
const ORDER: Array[StringName] = [
	&"YUT", &"SLOT_777", &"LIFE_ROULETTE", &"REVOLVER", &"DICE_MAHJONG", &"DICE_YACHT",
	&"DICE_DARTS", &"DICE_CAPSULE", &"DICE_PIRATE", &"DICE_COOKIE", &"DICE_SCRATCH",
]
## 하나를 몇 프레임 그리나.
const RENDER_FRAMES: int = 3
## 하나를 그린 뒤 다음 것까지 쉬는 시간 (초). 한 번에 몰아 그려 멈칫하지 않게 나눈다.
const GAP: float = 0.7

## 지금 그려도 되는가 (MainBoard가 연출·알림 중이 아닐 때만 참을 준다). 비어 있으면 늘 참.
var can_step: Callable = Callable()
## 다 그린 화면을 실제 연출에 넘긴다 (tool_id, view) -> 받았으면 true (RollPresenter.adopt_view). 넘긴 화면은 연출이 맡는다.
var adopt: Callable = Callable()
var _queue: Array[StringName] = []
var _kept: Dictionary = {}
var _current: Control = null
var _frames_left: int = 0
var _cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()
var _handed: Dictionary = {}


func _init() -> void:
	name = "ToolWarmup"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1, 1, 1, 0.02)  # 보드 밑에서 거의 보이지 않게 (완전히 투명하면 그리기를 건너뛴다)
	scale = Vector2.ONE * 0.04
	set_process(false)


## 판이 시작될 때 부른다. 이미 그려 둔 것은 다시 그리지 않는다.
func start() -> void:
	_rng.seed = 7
	_queue = []
	for id: StringName in ORDER:
		if not _kept.has(id) and not _handed.has(id):
			_queue.append(id)
	_cooldown = GAP
	set_process(not _queue.is_empty())


## 판이 끝나면 부른다: 들고 있던 화면을 모두 지운다.
func clear() -> void:
	_queue.clear()
	_current = null
	for view: Variant in _kept.values():
		if is_instance_valid(view):
			(view as Node).queue_free()
	_kept.clear()
	_handed.clear()
	set_process(false)


func warmed_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in _kept.keys() + _handed.keys():
		ids.append(id)
	return ids


func pending() -> int:
	return _queue.size() + (1 if _current != null else 0)


func _process(delta: float) -> void:
	if _current != null:
		_frames_left -= 1
		if _frames_left > 0:
			return
		_freeze(_current)
		var done_id: StringName = StringName(_current.get_meta("tool_id", &""))
		if adopt.is_valid() and bool(adopt.call(done_id, _current)):
			_kept.erase(done_id)
			_handed[done_id] = true
		warmed.emit(done_id)
		_current = null
		_cooldown = GAP
		return
	if _queue.is_empty():
		set_process(false)
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if can_step.is_valid() and not bool(can_step.call()):
		return
	var id: StringName = _queue.pop_front()
	var view: Control = _make(id)
	if view == null:
		return
	view.set_meta("tool_id", id)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_pose(id, view)
	for viewport: Node in view.find_children("*", "SubViewport", true, false):
		(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_kept[id] = view
	_current = view
	_frames_left = RENDER_FRAMES


func _freeze(view: Control) -> void:
	for viewport: Node in view.find_children("*", "SubViewport", true, false):
		(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.visible = false  # 모델·텍스처는 들고 있되 더 그리지 않는다


func _make(id: StringName) -> Control:
	match id:
		&"YUT": return YutThrow3D.new()
		&"SLOT_777": return SlotMachine3D.new()
		&"LIFE_ROULETTE": return RouletteSpin3D.new()
		&"REVOLVER": return ToyFlagGun3D.new()
		&"DICE_MAHJONG": return MahjongSlam3D.new()
		&"DICE_YACHT": return YachtRoll3D.new()
		&"DICE_DARTS": return DartBoardView.new()
		&"DICE_CAPSULE": return CapsuleGachaView.new()
		&"DICE_PIRATE": return PirateBarrelView.new()
		&"DICE_COOKIE": return FortuneCookieView.new()
		&"DICE_SCRATCH": return ScratchTicketView.new()
	return null


## 연출 중간 한 장면을 잡아 실제로 쓰는 모델·재질이 모두 그려지게 한다.
func _pose(id: StringName, view: Control) -> void:
	match id:
		&"YUT": (view as YutThrow3D).begin(3, 0.5)
		&"SLOT_777": (view as SlotMachine3D).begin([1, 3, 5], 0.5)
		&"LIFE_ROULETTE": (view as RouletteSpin3D).begin(5, 0.5)
		&"REVOLVER": (view as ToyFlagGun3D).begin(true, 4, 0)
		&"DICE_MAHJONG": (view as MahjongSlam3D).begin([0, 9, 27])
		&"DICE_YACHT": (view as YachtRoll3D).begin([1, 2, 3, 4, 5], [0, 1, 2, 3, 4])
		_:
			var tool: BaseJudgmentTool = ToolRegistry.create(id)
			view.call("begin", tool.roll(_rng).details if tool != null else {})
	if view.has_method("apply_time"):
		view.call("apply_time", 0.6)
