# File: res://scenes/stage_yacht.gd
# Class: class_name YachtStage
# Role: 야추 다이스의 중앙 오픈 스테이지. 주사위 5개를 보여 주고, 클릭으로 [고정]을 토글한 뒤 [나머지 다시 굴리기]/[현재 족보로 이동 확정]을 누른다. 연출만 담당하며 판정은 엔진(ToolYacht)이 한다
#       1.3.1 주사위 케이스: 별도 창 대신 판 위에 놓인 전용 케이스. 초록 펠트 트레이·위쪽 고정 칸 5개·오른쪽 주사위 컵.
#       굴린 주사위는 컵에서 펠트로 쏟아지고, 누르면 위 고정 칸으로 올라간다 (다시 누르면 내려온다). MainBoard가 카드 시점(판 가운데 확대)으로 띄운다.
class_name YachtStage
extends Control

signal start_pressed
signal reroll_pressed(keep: Array)
signal confirm_pressed
signal roll_finished

const STAGE_SIZE: Vector2 = Vector2(640.0, 416.0)
## 케이스 (테두리·고정 칸 띠·펠트). 3D 주사위 화면은 케이스 안쪽에 겹친다.
const CASE_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 336.0)
const VIEW_AT: Vector2 = Vector2(32.0, 24.0)
const FELT_RECT: Rect2 = Rect2(22.0, 144.0, 596.0, 180.0)
const CUP_CENTER: Vector2 = Vector2(724.0, 174.0)
const CUP_RADIUS: float = 62.0
const ROLL_SECONDS: float = YachtRoll3D.TOTAL_TIME

## 3D 주사위 위의 입력 영역. 고정 테두리·태그와 굴리기 전 자리만 그린다.
class DieView extends Control:
	signal toggled
	var value: int = 0
	var kept: bool = false
	var rolling: bool = false
	var clickable: bool = false
	var _hover: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(96.0, 96.0)
		size = custom_minimum_size
		mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
		mouse_exited.connect(func() -> void: _hover = false; queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and clickable:
			accept_event()
			toggled.emit()

	func show_value(face: int) -> void:
		value = face
		queue_redraw()

	## 누를 수 있는 주사위에 손을 대면 주황 모서리 괄호 (글 없이 "고를 수 있다")
	func _draw() -> void:
		if not (clickable and _hover and value > 0):
			return
		var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var arm: float = 22.0
		var ink := Color("ff7a1a")
		for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var sx: float = 1.0 if corner.x <= rect.get_center().x else -1.0
			var sy: float = 1.0 if corner.y <= rect.get_center().y else -1.0
			draw_line(corner, corner + Vector2(arm * sx, 0), ink, 6.0)
			draw_line(corner, corner + Vector2(0, arm * sy), ink, 6.0)

	static func _box(color: Color, border: Color, width: int) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.border_color = border
		style.set_border_width_all(width)
		style.set_corner_radius_all(14)
		return style


var dice_views: Array[DieView] = []
var kept: Array[bool] = [false, false, false, false, false]
var dice: Array[int] = [0, 0, 0, 0, 0]
var rerolls_left: int = 0
var started: bool = false
var can_act: bool = false
## 굴러가는 연출 중인가 (이 동안은 입력을 받지 않는다).
var active: bool = false
var instant: bool = false

var _title: Label = null
var _status: Label = null
var _start_button: Button = null
var _reroll_button: Button = null
var _confirm_button: Button = null
var _result_text: String = ""  ## 확정된 뒤 상태 줄에 남겨 둘 결과 문구
var _dice_3d: YachtRoll3D
var _case_view: YachtCase3D
var _elapsed: float = 0.0
var _play_serial: int = 0
var _landed: bool = false


func _init() -> void:
	custom_minimum_size = STAGE_SIZE
	size = STAGE_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	_ensure_case.call_deferred()
	_title = _label("", 18, UiSkin.GREEN)  # 1.3.1: 케이스가 설명을 대신한다 (제목 없음)
	_title.visible = false
	add_child(_title)
	_dice_3d = YachtRoll3D.new()
	_dice_3d.position = VIEW_AT
	add_child(_dice_3d)
	for index: int in 5:
		var die := DieView.new()
		die.toggled.connect(_on_die_toggled.bind(index))
		add_child(die)
		dice_views.append(die)
	_status = _label("", 20, Color("fff3bf"))
	_status.add_theme_constant_override("outline_size", 5)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_status.position = Vector2(FELT_RECT.position.x, FELT_RECT.end.y - 34.0)
	_status.size = Vector2(FELT_RECT.size.x, 28.0)
	add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.position = Vector2(10.0, CASE_RECT.end.y + 24.0)
	buttons.size = Vector2(STAGE_SIZE.x - 20.0, 46.0)
	add_child(buttons)
	_start_button = _button("주사위 5개 굴리기", true, 340.0)
	_start_button.pressed.connect(func() -> void: start_pressed.emit())
	buttons.add_child(_start_button)
	_reroll_button = _button("나머지 다시 굴리기", false, 290.0)
	_reroll_button.pressed.connect(_on_reroll)
	buttons.add_child(_reroll_button)
	_confirm_button = _button("현재 족보로 이동 확정!", true, 290.0)
	_confirm_button.pressed.connect(func() -> void: confirm_pressed.emit())
	buttons.add_child(_confirm_button)
	_refresh()
	set_process(false)
	visibility_changed.connect(_on_visibility_changed)


## 주사위 케이스: 그림자 → 검은 테두리 → 고정 칸 5개 → 초록 펠트 → 오른쪽 주사위 컵 (3D 주사위는 이 위에 겹친다).
func _draw() -> void:
	pass # Case, recessed wells and hollow cup are rendered by YachtCase3D.

func _dice_3d_center(index: int, keep_row: bool) -> Vector2:
	return _dice_3d.die_center(index, keep_row)


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	_dice_3d.apply_time(_elapsed)
	if not _landed and _elapsed >= YachtRoll3D.ROLL_TIME * 0.62:
		_landed = true
		Sfx.play(&"thud")
	if _elapsed >= ROLL_SECONDS:
		dice.assign(_dice_3d.values)
		for view: DieView in dice_views:
			view.rolling = false
		active = false  # 고정한 주사위는 다시 굴린 뒤에도 그대로 고정 (플레이어가 직접 눌러야 풀린다)
		set_process(false)
		_refresh()
		roll_finished.emit()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel()
		if _dice_3d!=null: preload("res://scenes/web_3d_budget.gd").park(_dice_3d)
		if _case_view!=null: _case_view.set_active(false)
	elif _dice_3d != null and not active:
		_ensure_case()
		preload("res://scenes/web_3d_budget.gd").restore(_dice_3d)
		_case_view.set_active(true)
		_dice_3d.show_values(dice)


func _ensure_case() -> void:
	if _case_view==null and is_visible_in_tree():
		_case_view=YachtCase3D.new()
		add_child(_case_view)
		move_child(_case_view,0)


func cancel() -> void:
	_play_serial += 1
	if _dice_3d != null:
		_dice_3d.stop_rendering()
	set_process(false)
	if active:
		active = false
		for view: DieView in dice_views:
			view.rolling = false
		roll_finished.emit()


func _exit_tree() -> void:
	cancel()


func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, _action: bool, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	JudgmentTableStyle.button(button,width)
	return button


func _on_die_toggled(index: int) -> void:
	if not _can_toggle():
		return
	kept[index] = not kept[index]
	Sfx.play(&"toy_click",-9)
	_refresh()


func _can_toggle() -> bool:
	return can_act and started and rerolls_left > 0 and not active


func _on_reroll() -> void:
	if not (can_act and started and rerolls_left > 0 and not active):
		return
	reroll_pressed.emit(kept.duplicate())


## 파워 게이지를 붙일 굴리기 버튼들 ([주사위 5개 굴리기]·[나머지 다시 굴리기]).
func gauge_buttons() -> Array[Button]:
	return [_start_button, _reroll_button] as Array[Button]


## 스페이스 키: 처음이면 [주사위 5개 굴리기], 굴린 뒤면 고정하지 않은 주사위만 [다시 굴리기].
func roll_by_key() -> void:
	if not started:
		if can_act and not active:
			start_pressed.emit()
	else:
		_on_reroll()


## 엔진의 야추 상태에 화면을 맞춘다. tool이 null이면 초기 화면. acting은 지금 내가 조작할 차례인가.
func sync(tool: ToolYacht, acting: bool) -> void:
	can_act = acting
	if active:
		return  # 굴러가는 중에는 연출이 끝난 뒤 다시 맞춘다
	if tool != null and tool.has_pending_state():
		started = true
		rerolls_left = tool.rerolls_left
		dice.assign(tool.dice)
	elif not started and _result_text == "":
		dice = [0, 0, 0, 0, 0]
		rerolls_left = 0
	_refresh()


## 새 차례가 되면 지난 결과를 지우고 처음 화면으로 돌린다.
func reset() -> void:
	cancel()
	dice = [0, 0, 0, 0, 0]
	kept = [false, false, false, false, false]
	rerolls_left = 0
	started = false
	active = false
	_result_text = ""
	_refresh()


## 엔진 결과(RollResult.to_dict())를 굴러가는 연출로 보여 준다. 끝나면 돌아온다.
func play(result: Dictionary) -> void:
	cancel()
	var details: Dictionary = result["details"]
	var values: Array = details["dice"]
	var rolled: Array = details["rolled"]
	var confirmed: bool = bool(details.get("confirmed", false))
	if confirmed:
		if not instant: PresentationAudio.one_shot(self,&"good" if bool(result.get("reroll",false)) else &"card_pick",-8)
		started = false
		kept = [false, false, false, false, false]
		rerolls_left = int(details.get("rerolls_left", 0))
		dice.assign(values)
		_result_text = "%s → %d칸 이동!" % [details["label"], int(result["steps"])]
		_refresh()
		return
	_result_text = ""
	started = true
	rerolls_left = int(details["rerolls_left"])
	var wanted: Array[int] = []
	wanted.assign(values)
	if instant or not is_inside_tree():
		dice = wanted
		_refresh()
		return
	active = true
	if not rolled.is_empty(): PresentationAudio.one_shot(self,&"dice_roll",-8)
	_elapsed = 0.0
	_landed = rolled.is_empty()
	for index: int in 5:
		if rolled.has(index):
			dice_views[index].rolling = true
	_refresh()
	_dice_3d.begin(wanted, rolled)
	set_process(true)
	var serial: int = _play_serial
	await roll_finished
	if serial != _play_serial:
		return


func _refresh() -> void:
	if _status == null:
		return
	for index: int in 5:
		var view: DieView = dice_views[index]
		if not view.rolling:
			view.show_value(dice[index])
		view.kept = kept[index] and started
		view.clickable = _can_toggle()
		view.position = VIEW_AT + _dice_3d_center(index, view.kept) - view.size / 2.0  # 고정하면 위 고정 칸으로 (누르는 자리도 따라간다)
		view.visible = dice[index] > 0 or view.rolling
		view.queue_redraw()
	_dice_3d.set_kept(kept.map(func(value: bool) -> bool: return value and started))
	if not active:
		_dice_3d.show_values(dice)
		if not is_visible_in_tree():
			_dice_3d.stop_rendering()
	_start_button.visible = not started
	_start_button.disabled = not can_act or active
	_reroll_button.visible = started
	_confirm_button.visible = started
	_reroll_button.text = L10n.tf("다시 굴리기 (%d)", [rerolls_left])
	_reroll_button.disabled = not (can_act and rerolls_left > 0 and not active)
	_confirm_button.disabled = not (can_act and not active)
	if active:
		_status.text = ""
	elif started:
		var hand: Dictionary = ToolYacht.evaluate(dice)
		_status.text = "%s → %d칸%s" % [hand["label"], int(hand["steps"]), "  (+한 번 더!)" if hand["hand"] == &"yacht" else ""]
	elif not started and not active:
		_status.text = _result_text  # 굴리기 전에는 안내 글 없이 빈 케이스와 컵만
	queue_redraw()

