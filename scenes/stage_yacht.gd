# File: res://scenes/stage_yacht.gd
# Class: class_name YachtStage
# Role: 야추 다이스의 중앙 오픈 스테이지. 주사위 5개를 보여 주고, 클릭으로 [고정]을 토글한 뒤 [나머지 다시 굴리기]/[현재 족보로 이동 확정]을 누른다. 연출만 담당하며 판정은 엔진(ToolYacht)이 한다
class_name YachtStage
extends Control

signal start_pressed
signal reroll_pressed(keep: Array)
signal confirm_pressed
signal roll_finished

const STAGE_SIZE: Vector2 = Vector2(620.0, 270.0)
const ROLL_SECONDS: float = YachtRoll3D.TOTAL_TIME

## 3D 주사위 위의 입력 영역. 고정 테두리·태그와 굴리기 전 자리만 그린다.
class DieView extends Control:
	signal toggled
	var value: int = 0
	var kept: bool = false
	var rolling: bool = false
	var clickable: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(96.0, 120.0)
		size = custom_minimum_size

	func _gui_input(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and clickable:
			accept_event()
			toggled.emit()

	func show_value(face: int) -> void:
		value = face
		queue_redraw()

	func _draw() -> void:
		var side: float = 92.0
		var origin := Vector2(2.0, 4.0)
		var body := Rect2(origin, Vector2(side, side))
		if value <= 0 and not rolling:
			draw_style_box(UiSkin.panel("inset", 0.0), body)
			draw_string(ThemeDB.fallback_font, origin + Vector2(side / 2.0 - 12.0, side / 2.0 + 14.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UiSkin.SOFT)
		if kept:
			draw_style_box(_box(Color.TRANSPARENT, UiSkin.GREEN, 3), body)
			var tag := Rect2(Vector2(origin.x + 6.0, origin.y + side + 4.0), Vector2(side - 12.0, 20.0))
			var tag_style: StyleBoxFlat = _box(Color("eaf4ce"), UiSkin.GREEN, 2)
			tag_style.set_corner_radius_all(8)
			draw_style_box(tag_style, tag)
			draw_string(ThemeDB.fallback_font, tag.position + Vector2(0.0, 15.0), L10n.t("고정"), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 14, UiSkin.INK)

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
var _elapsed: float = 0.0
var _play_serial: int = 0
var _landed: bool = false


func _init() -> void:
	custom_minimum_size = STAGE_SIZE
	size = STAGE_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiSkin.panel("panel", 12.0))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_title = _label("야추 다이스", 18, UiSkin.GREEN)
	_title.position = Vector2(0.0, 10.0)
	_title.size = Vector2(STAGE_SIZE.x, 26.0)
	add_child(_title)
	_dice_3d = YachtRoll3D.new()
	_dice_3d.position = Vector2(22.0, 24.0)
	add_child(_dice_3d)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.position = Vector2((STAGE_SIZE.x - (96.0 * 5.0 + 14.0 * 4.0)) / 2.0, 44.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for index: int in 5:
		var die := DieView.new()
		die.toggled.connect(_on_die_toggled.bind(index))
		row.add_child(die)
		dice_views.append(die)
	_status = _label("", 20, UiSkin.INK)
	_status.position = Vector2(0.0, 176.0)
	_status.size = Vector2(STAGE_SIZE.x, 28.0)
	add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.position = Vector2(10.0, 212.0)
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
	elif _dice_3d != null and not active:
		_dice_3d.show_values(dice)


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


func _button(text: String, action: bool, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 44.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	UiSkin.button(button, action, 10.0, 6.0)
	return button


func _on_die_toggled(index: int) -> void:
	if not _can_toggle():
		return
	kept[index] = not kept[index]
	_refresh()


func _can_toggle() -> bool:
	return can_act and started and rerolls_left > 0 and not active


func _on_reroll() -> void:
	if not (can_act and started and rerolls_left > 0 and not active):
		return
	reroll_pressed.emit(kept.duplicate())


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
		view.queue_redraw()
	if not active:
		_dice_3d.show_values(dice)
		if not is_visible_in_tree():
			_dice_3d.stop_rendering()
	_start_button.visible = not started
	_start_button.disabled = not can_act or active
	_reroll_button.visible = started
	_confirm_button.visible = started
	_reroll_button.text = "나머지 다시 굴리기 (남은 횟수: %d)" % rerolls_left
	_reroll_button.disabled = not (can_act and rerolls_left > 0 and not active)
	_confirm_button.disabled = not (can_act and not active)
	if active:
		_status.text = "주사위 굴리는 중…"
	elif started:
		var hand: Dictionary = ToolYacht.evaluate(dice)
		_status.text = "현재 족보: %s → %d칸%s" % [hand["label"], int(hand["steps"]), "  (+한 번 더!)" if hand["hand"] == &"yacht" else ""]
	elif not started and not active:
		_status.text = _result_text if _result_text != "" else "주사위 5개를 굴려 족보를 만드세요 (유지할 주사위는 클릭해 고정)"
	_title.text = "야추 다이스 - 고정할 주사위를 클릭하세요" if started and can_act and rerolls_left > 0 else "야추 다이스"
