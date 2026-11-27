# File: res://scenes/tool_hand_gate.gd
# Class: class_name ToolHandGate
# Role: 선택부터 결과 공개까지 같은 소품을 유지하는 직접 조작 연출.
# 쿠키는 접시 위에서 개봉, 아이스크림은 포장 해제 후 제자리 섭취,
# 오미쿠지는 한 번 누를 때 3회 흔든 뒤 바로 뽑기, 마작은 3D 뒷면 패를 꺼내 함께 공개한다.
# 보상은 엔진이 이미 결정했으며 이 화면은 로컬 입력과 시각·음향만 담당한다.
class_name ToolHandGate
extends Control

signal interacted

const TOOLS: Array[StringName] = [&"DICE_MAHJONG", &"DICE_COOKIE", &"DICE_ICECREAM", &"DICE_OMIKUJI"]
const GOLD: Color = Color("ffd43b")
const INK: Color = Color("fff3bf")
const ROW_TILES: int = 13
const MAHJONG_PICKS: int = 3

var tool_id: StringName = &""
var tiles: Array[int] = []
var _picks: Array[int] = []
var _done_at: float = -1.0
var _clock: float = 0.0
var _prompt: Label = null
var _items: Array[Control] = []
var _shakes: int = 0
var _box: OmikujiView = null
var _column: Control = null
var _platter: CookiePlatterPick
var _icebox: IceboxPickArt
var _shake_tween: Tween
var selected_flavor := "strawberry"
var _details: Dictionary = {}
var _result_label: Label
var _mahjong: MahjongPick3D
var _revealed := false
var _result_caption := ""
var _table_dim: ColorRect
var _table_background: Panel



static func supports(id: StringName) -> bool:
	return TOOLS.has(id)


func setup(id: StringName, details: Dictionary) -> void:
	tool_id = id
	_details = details.duplicate()
	name = "ToolHandGate"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for tile: Variant in details.get("tiles", []):
		tiles.append(int(tile))
		MahjongFace.prepare(int(tile))  # 패를 꺼내는 순간 그림을 읽느라 멈칫하지 않게 미리 읽어 둔다
	if id == &"DICE_MAHJONG":
		MahjongFace.prepare(-1)
	var column := VBoxContainer.new()
	column.name = "GateColumn"
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_prompt = _label("", MobileSupport.text_px(20), INK)
	_prompt.name = "GatePrompt"
	column.add_child(_prompt)
	match tool_id:
		&"DICE_MAHJONG": _build_mahjong(column)
		&"DICE_COOKIE": _build_jar(column)
		&"DICE_ICECREAM": _build_icebox(column)
		_: _build_omikuji(column)
	var result_panel := PanelContainer.new()
	result_panel.name = "InPlaceResult"
	result_panel.custom_minimum_size = Vector2(600,60)
	result_panel.add_theme_stylebox_override("panel",_box_style(Color(.035,.07,.06,.94),Color("b8d27e"),12,2))
	result_panel.modulate.a = 0
	_result_label = _label("",22,Color("fff3bf"))
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.custom_minimum_size.x = 570
	result_panel.add_child(_result_label)
	column.add_child(result_panel)
	_refresh_prompt()
	_column = column
	if tool_id==&"DICE_MAHJONG":
		_table_dim=JudgmentTableStyle.backdrop(self)
		_table_background=Panel.new()
		_table_background.name="MahjongTablePanel"
		_table_background.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_table_background.add_theme_stylebox_override("panel",JudgmentTableStyle.surface())
		add_child(_table_background)
		move_child(_table_background,1)
		result_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		_prompt.add_theme_color_override("font_color",JudgmentTableStyle.EDGE)
	size = Vector2.ZERO
	set_process(true)


## 손으로 할 일을 다 했고, 잠깐 보여 준 뒤인가.
func complete() -> bool:
	if _done_at < 0: return false
	var duration := 4.0 if tool_id==&"DICE_COOKIE" else (4.2 if tool_id==&"DICE_ICECREAM" else (2.15 if tool_id==&"DICE_MAHJONG" else (OmikujiView.GREAT_TOTAL_TIME if _details.get("fortune")==&"great" else OmikujiView.TOTAL_TIME)-OmikujiView.DRAW_AT+.15))
	return _clock-_done_at>=duration

func set_result_caption(value: String) -> void:
	_result_caption=L10n.t(str(_details.get("message","")))+" · "+value if tool_id==&"DICE_COOKIE" else value

func revealed() -> bool:
	return _revealed

## 아직 손을 기다리는가.
func waiting() -> bool:
	return _done_at < 0.0


## 오래 손대지 않으면 남은 것을 저절로 고른다.
func auto_finish() -> void:
	match tool_id:
		&"DICE_MAHJONG":
			var index: int = 0
			while _picks.size() < MAHJONG_PICKS and index < _items.size():
				if not _picks.has(index):
					pick(index)
				index += 1
		&"DICE_OMIKUJI":
			draw()
		_:
			pick(_items.size() / 2)
	# 자동 선택도 동일한 제자리 공개 과정을 끝까지 보여 준다.


## 스페이스 키: 마작은 다음 패, 오미쿠지는 뽑기, 쿠키·아이스크림은 가운데 것을 고른다.
func key_press() -> void:
	match tool_id:
		&"DICE_MAHJONG":
			for index: int in _items.size():
				if not _picks.has(index):
					pick(index)
					return
		&"DICE_OMIKUJI":
			draw()
		_:
			pick(_items.size() / 2)


## 자리 하나를 고른다 (마작 패 / 쿠키 / 아이스크림). 터치·클릭과 테스트가 같은 길을 쓴다.
func pick(index: int) -> void:
	if _done_at >= 0.0 or index < 0 or index >= _items.size() or _picks.has(index):
		return
	_picks.append(index)
	interacted.emit()
	var item: Control = _items[index]
	match tool_id:
		&"DICE_MAHJONG":
			Sfx.play(&"toy_click", -6.0)
			item.modulate.a = 0.0  # 줄에서 빠진 자리는 빈칸으로 남는다
			_mahjong.pick(index)
			if _picks.size() >= MAHJONG_PICKS:
				_finish()
		_:
			Sfx.play(&"card_pick", -5.0)
			if _platter != null:
				_platter.take(index,global_position)
			elif _icebox != null:
				selected_flavor = _icebox.flavor_at(index)
				_icebox.focus_point=global_position-_icebox.global_position
				_icebox.take(index)
			_finish()
	_refresh_prompt()


## 오미쿠지 통을 흔든다 (연출만, 몇 번이든).
func shake() -> void:
	if _done_at >= 0.0 or _box == null:
		return
	_shakes += 1
	interacted.emit()
	if _shake_tween != null and _shake_tween.is_valid(): _shake_tween.kill()
	_shake_tween=create_tween()
	_shake_tween.tween_method(func(progress: float) -> void:
		_box.manual_swing=sin(progress*TAU*3)*sin(progress*PI)
		_box.queue_redraw(),0.0,1.0,.9)
	for offset: float in [0.0,.3,.6]:
		var timer:=get_tree().create_timer(offset+.01)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self) and waiting(): Sfx.play(&"yut_clack",-8)
		)

	_refresh_prompt()


## 오미쿠지 막대를 뽑는다.
func draw() -> void:
	if _done_at >= 0.0:
		return
	if _shake_tween != null and _shake_tween.is_valid(): _shake_tween.kill()
	_box.manual_swing=0
	Sfx.play(&"omikuji_draw", -6.0)
	interacted.emit()
	_finish()
	_refresh_prompt()


func shake_count() -> int:
	return _shakes


func picks() -> Array[int]:
	return _picks.duplicate()


func item_count() -> int:
	return _items.size()


func _process(delta: float) -> void:
	_clock += delta
	if _done_at>=0:
		var elapsed:=_clock-_done_at
		var reveal_at:=1.75
		if _platter!=null: _platter.open_at(elapsed)
		elif _icebox!=null: reveal_at=2.3
		elif _mahjong!=null:
			if elapsed>=.45: _mahjong.reveal(clampf((elapsed-.45)/.5,0,1))
			reveal_at=1.0
		elif _box!=null:
			_box.apply_time(OmikujiView.DRAW_AT+elapsed)
			reveal_at=OmikujiView.REVEAL_AT-OmikujiView.DRAW_AT
		if elapsed>=reveal_at and not _revealed:
			_revealed=true
			_result_label.text=_result_caption
			_result_label.get_parent().modulate.a=1
			Sfx.play(&"card_pick",-6)
			_prompt.modulate.a=0

	if _column != null and _clock < 0.25:
		_column.reset_size()
		_column.position = -_column.size * 0.5  # 글자·그림 크기가 정해진 뒤 가운데에 둔다 (처음 몇 프레임만: 매 프레임 다시 재지 않는다)
	if _table_background!=null:
		JudgmentTableStyle.layout_backdrop(self,_table_dim)
		_table_background.position=_column.position-Vector2.ONE*JudgmentTableStyle.PADDING
		_table_background.size=_column.size+Vector2.ONE*JudgmentTableStyle.PADDING*2


func _finish() -> void:
	if _done_at < 0.0:
		_done_at = _clock
		for button: Node in find_children("*","Button",true,false): button.disabled=true


func _refresh_prompt() -> void:
	match tool_id:
		&"DICE_MAHJONG":
			_prompt.text = L10n.tf("패를 골라 꺼내세요 (%d / %d)", [_picks.size(), MAHJONG_PICKS])
		&"DICE_COOKIE":
			_prompt.text = L10n.t("접시에서 쿠키를 하나 집으세요")
		&"DICE_ICECREAM":
			_prompt.text = L10n.t("아이스크림을 하나 꺼내세요")
		_:
			_prompt.text = L10n.t("통을 흔들고 뽑으세요") if _shakes == 0 else L10n.tf("흔들흔들… %d번 흔들었어요", [_shakes])


# ---------------------------------------------------------------------------
# 장면 만들기
# ---------------------------------------------------------------------------

## 마작: 3D 뒷면 패를 꺼내 놓은 뒤 셋을 함께 뒤집는다.
func _build_mahjong(column: VBoxContainer) -> void:
	_mahjong=MahjongPick3D.new()
	_mahjong.values=tiles if tiles.size()==3 else [0,1,2]
	_mahjong.custom_minimum_size=Vector2(600,312)
	_mahjong.size=_mahjong.custom_minimum_size
	_mahjong.selected.connect(pick)
	column.add_child(_mahjong)
	for index: int in ROW_TILES:
		var marker:=Control.new()
		marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_mahjong.add_child(marker)
		_items.append(marker)


## Lightweight native 3D platter using the existing cookie mesh.
func _build_jar(column: VBoxContainer) -> void:
	_platter = CookiePlatterPick.new()
	_platter.name = "CookiePlatter"
	_platter.custom_minimum_size = CookiePlatterPick.EXTENT
	_platter.selected.connect(pick)
	_platter.ready.connect(func() -> void: _platter.prepare_message(str(_details.get("message",""))), CONNECT_ONE_SHOT)
	column.add_child(_platter)
	for index: int in 16:
		var marker := Control.new()
		marker.name = "GateItem%d" % index
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_platter.add_child(marker)
		_items.append(marker)


## Layered painted icebox: independent wrappers, occluding ice and front rim.
func _build_icebox(column: VBoxContainer) -> void:
	_icebox = IceboxPickArt.new()
	_icebox.name = "IceboxSelection"
	_icebox.interactive = true
	_icebox.prepare_result(_details)
	_icebox.custom_minimum_size = Vector2(480, 350)
	_icebox.size = _icebox.custom_minimum_size
	_icebox.selected.connect(pick)
	column.add_child(_icebox)
	if _icebox.is_node_ready():
		_register_packets()
	else:
		_icebox.ready.connect(_register_packets, CONNECT_ONE_SHOT)

func _register_packets() -> void:
	for packet: TextureRect in _icebox.packets:
		_items.append(packet)


## 오미쿠지: 육각 나무 통과 [흔들기]·[뽑기] 버튼.
func _build_omikuji(column: VBoxContainer) -> void:
	var stage := CenterContainer.new()
	stage.custom_minimum_size = Vector2(240, 200)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage)
	stage.custom_minimum_size = Vector2(OmikujiView.SIZE.x * 0.8, OmikujiView.SIZE.y * 0.8)
	var holder := Control.new()
	holder.custom_minimum_size = stage.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(holder)
	var view := OmikujiView.new()
	view.name = "OmikujiBox"
	view.scale = Vector2.ONE * 0.8
	view.pivot_offset = Vector2(OmikujiView.SIZE.x * 0.5, OmikujiView.SIZE.y * 0.85)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(view)
	view.manual_mode = true
	view.begin(_details)
	view.apply_time(OmikujiView.DRAW_AT)  # 연출 첫 장면: 통이 자리 잡은 뒤, 흔들기 전
	_box = view
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	var shake_button := _button("ShakeButton", L10n.t("흔들기"), Color("e67700"))
	shake_button.pressed.connect(shake)
	buttons.add_child(shake_button)
	var draw_button := _button("DrawButton", L10n.t("뽑기"), Color("2b8a3e"))
	draw_button.pressed.connect(draw)
	buttons.add_child(draw_button)


func _button(node_name: String, text: String, tone: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(120, 48)
	button.add_theme_font_size_override("font_size", MobileSupport.text_px(20))
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		var style := _box_style(tone.lightened(0.12 if state_name == "hover" else 0.0), tone.darkened(0.4), 12, 3)
		if state_name == "focus":
			style.draw_center = false
		button.add_theme_stylebox_override(state_name, style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 4)
	return button


static func _box_style(fill: Color, edge: Color, radius: int, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(8)
	return style


func _label(text: String, px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


