# File: res://scenes/tool_hand_gate.gd
# Class: class_name ToolHandGate
# Role: 판정 도구를 손으로 다루는 첫 장면 (1.3.1). 결과는 굴릴 때 엔진이 이미 정했고, 이 장면은 그 결과를 "내 손으로" 꺼내는 연출이다.
#       RollPresenter가 내 화면에서 내가 굴린 결과를 보여 주기 전에 띄운다 (남이 굴린 것·컴퓨터·온라인 상대는 띄우지 않는다).
#       - 마작: 리치 마작처럼 1열로 붙은 뒷면 패 중 3개를 고르면, 고를 때마다 탁 꺼내 세워 앞면(굴린 패)을 보여 준다.
#       - 포츈쿠키: 뚜껑 열린 과자통에서 쿠키 하나를 집는다.
#       - 아이스크림: 아이스박스에 꽂힌 아이스크림 하나를 위로 꺼낸다.
#       - 오미쿠지: [흔들기]로 통을 흔들고(몇 번이든), [뽑기]를 누르면 막대가 나온다.
#       다 하면 complete()가 true가 되고, 오래 손대지 않으면 RollPresenter가 auto_finish()로 마저 끝낸다.
class_name ToolHandGate
extends Control

const TOOLS: Array[StringName] = [&"DICE_MAHJONG", &"DICE_COOKIE", &"DICE_ICECREAM", &"DICE_OMIKUJI"]
const GOLD: Color = Color("ffd43b")
const INK: Color = Color("fff3bf")
const ROW_TILES: int = 13
const ROW_TILE: Vector2 = Vector2(30, 44)
const STAND_TILE: Vector2 = Vector2(66, 96)
const MAHJONG_PICKS: int = 3
## 다 고른 뒤 결과로 넘어가기 전 잠깐 보여 주는 시간.
const LINGER: float = 0.55

var tool_id: StringName = &""
var tiles: Array[int] = []
var _picks: Array[int] = []
var _done_at: float = -1.0
var _auto: bool = false
var _clock: float = 0.0
var _prompt: Label = null
var _items: Array[Control] = []
var _stand_row: HBoxContainer = null
var _shakes: int = 0
var _box: Control = null
var _column: Control = null


static func supports(id: StringName) -> bool:
	return TOOLS.has(id)


func setup(id: StringName, details: Dictionary) -> void:
	tool_id = id
	name = "ToolHandGate"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for tile: Variant in details.get("tiles", []):
		tiles.append(int(tile))
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
	_refresh_prompt()
	_column = column
	size = Vector2.ZERO
	set_process(true)


## 손으로 할 일을 다 했고, 잠깐 보여 준 뒤인가.
func complete() -> bool:
	return _done_at >= 0.0 and (_auto or _clock - _done_at >= LINGER)


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
	_auto = true  # 저절로 끝낼 때는 기다리지 않는다


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
	var item: Control = _items[index]
	match tool_id:
		&"DICE_MAHJONG":
			Sfx.play(&"toy_click", -6.0)
			item.modulate.a = 0.0  # 줄에서 빠진 자리는 빈칸으로 남는다
			_stand_row.add_child(_standing_tile(tiles[_picks.size() - 1] if _picks.size() - 1 < tiles.size() else 0))
			if _picks.size() >= MAHJONG_PICKS:
				_finish()
		_:
			Sfx.play(&"card_pick", -5.0)
			var tween: Tween = create_tween()
			tween.tween_property(item, "position:y", item.position.y - (70.0 if tool_id == &"DICE_ICECREAM" else 36.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(item, "scale", Vector2.ONE * 1.18, 0.22)
			for other: Control in _items:
				if other != item:
					other.modulate = Color(0.6, 0.6, 0.65)
			_finish()
	_refresh_prompt()


## 오미쿠지 통을 흔든다 (연출만, 몇 번이든).
func shake() -> void:
	if _done_at >= 0.0 or _box == null:
		return
	_shakes += 1
	Sfx.play(&"yut_clack", -8.0)
	var tween: Tween = create_tween()
	for angle: float in [-0.22, 0.2, -0.14, 0.1, 0.0]:
		tween.tween_property(_box, "rotation", angle, 0.06)
	_refresh_prompt()


## 오미쿠지 막대를 뽑는다.
func draw() -> void:
	if _done_at >= 0.0:
		return
	Sfx.play(&"omikuji_draw", -6.0)
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
	if _column != null:
		_column.reset_size()
		_column.position = -_column.size * 0.5  # 글자·그림 크기가 정해진 뒤 가운데에 둔다


func _finish() -> void:
	if _done_at < 0.0:
		_done_at = _clock


func _refresh_prompt() -> void:
	match tool_id:
		&"DICE_MAHJONG":
			_prompt.text = L10n.tf("패를 골라 꺼내세요 (%d / %d)", [_picks.size(), MAHJONG_PICKS])
		&"DICE_COOKIE":
			_prompt.text = L10n.t("과자통에서 쿠키를 하나 집으세요")
		&"DICE_ICECREAM":
			_prompt.text = L10n.t("아이스크림을 하나 꺼내세요")
		_:
			_prompt.text = L10n.t("통을 흔들고 뽑으세요") if _shakes == 0 else L10n.tf("흔들흔들… %d번 흔들었어요", [_shakes])


# ---------------------------------------------------------------------------
# 장면 만들기
# ---------------------------------------------------------------------------

## 마작: 리치 마작처럼 뒷면 패를 1열로 붙여 놓고, 그 위에 꺼낸 패를 세운다.
func _build_mahjong(column: VBoxContainer) -> void:
	_stand_row = HBoxContainer.new()
	_stand_row.name = "StandRow"
	_stand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stand_row.add_theme_constant_override("separation", 12)
	_stand_row.custom_minimum_size = Vector2(0, STAND_TILE.y + 8)
	_stand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_stand_row)
	var felt := PanelContainer.new()
	felt.add_theme_stylebox_override("panel", _box_style(Color("2f6b45"), Color("173d27"), 14))
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(felt)
	var row := HBoxContainer.new()
	row.name = "TileRow"
	row.add_theme_constant_override("separation", 1)  # 따닥따닥 붙어 있다
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.add_child(row)
	var tile_size: Vector2 = ROW_TILE * (1.35 if MobileSupport.touch_mode() else 1.0)
	for index: int in ROW_TILES:
		var holder := Control.new()
		holder.name = "RowTile%d" % index
		holder.custom_minimum_size = tile_size
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		holder.add_child(_face(-1, tile_size))
		_connect_pick(holder, index)
		row.add_child(holder)
		_items.append(holder)


## 고른 패: 앞면을 보이게 세워 둔다 (굴린 패를 고른 순서대로).
func _standing_tile(tile: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = STAND_TILE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Panel.new()
	frame.size = STAND_TILE + Vector2(6, 10)
	frame.position = Vector2(-3, -3)
	frame.add_theme_stylebox_override("panel", _box_style(Color("fff5dc"), Color("2f6b45"), 8, 3))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)
	holder.add_child(_face(tile, STAND_TILE))
	holder.scale = Vector2(0.6, 0.6)
	holder.pivot_offset = STAND_TILE * 0.5
	var tween: Tween = holder.create_tween()
	tween.tween_property(holder, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return holder


func _face(tile: int, extent: Vector2) -> Control:
	var face := MahjongFace.new()
	face.back = tile < 0
	face.tile_id = maxi(tile, 0)
	face.size = Vector2(MahjongFace.FACE_SIZE)
	face.scale = extent / Vector2(MahjongFace.FACE_SIZE)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return face


## 포츈쿠키: 뚜껑이 열린 유리 과자통 안에 쿠키가 담겨 있다.
func _build_jar(column: VBoxContainer) -> void:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(340, 230)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage)
	var lid := Panel.new()
	lid.add_theme_stylebox_override("panel", _box_style(Color("e8a87c"), Color("8c5a2b"), 12, 3))
	lid.size = Vector2(120, 26)
	lid.position = Vector2(222, 18)
	lid.rotation = 0.5
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(lid)
	var jar := Panel.new()
	jar.add_theme_stylebox_override("panel", _box_style(Color(0.85, 0.93, 1.0, 0.35), Color("a5d8ff"), 26, 4))
	jar.size = Vector2(250, 170)
	jar.position = Vector2(30, 52)
	jar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(jar)
	var rim := Panel.new()
	rim.add_theme_stylebox_override("panel", _box_style(Color("d0ebff"), Color("74c0fc"), 8, 3))
	rim.size = Vector2(266, 18)
	rim.position = Vector2(22, 44)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(rim)
	var spots: Array[Vector2] = [Vector2(50, 128), Vector2(120, 138), Vector2(190, 126), Vector2(84, 82), Vector2(158, 86)]
	_add_treats(stage, "cookie", spots, Vector2(76, 60))


## 아이스크림: 아이스박스 위로 막대 아이스크림들이 꽂혀 있다.
func _build_icebox(column: VBoxContainer) -> void:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(360, 240)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage)
	var spots: Array[Vector2] = []
	for index: int in 5:
		spots.append(Vector2(40 + index * 62, 30 + (index % 2) * 10))
	_add_treats(stage, "icecream", spots, Vector2(54, 120))
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", _box_style(Color("4dabf7"), Color("1864ab"), 14, 4))
	box.size = Vector2(340, 118)
	box.position = Vector2(10, 118)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(box)  # 박스가 아이스크림 아랫부분을 가린다 (꽂혀 있는 모습)
	var frost := ColorRect.new()
	frost.color = Color(1, 1, 1, 0.55)
	frost.size = Vector2(320, 10)
	frost.position = Vector2(20, 124)
	frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(frost)
	var label := _label(L10n.t("ICE BOX"), 22, Color("e7f5ff"))
	label.position = Vector2(10, 170)
	label.size = Vector2(340, 30)
	stage.add_child(label)


func _add_treats(stage: Control, kind: String, spots: Array[Vector2], extent: Vector2) -> void:
	for index: int in spots.size():
		var item := Treat.new()
		item.name = "GateItem%d" % index
		item.kind = kind
		item.flavor = index
		item.size = extent
		item.position = spots[index]
		item.pivot_offset = extent * 0.5
		item.rotation = ([-0.12, 0.08, -0.04, 0.14, -0.1][index % 5] as float) * (0.4 if kind == "icecream" else 1.0)
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_connect_pick(item, index)
		stage.add_child(item)
		_items.append(item)


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
	view.begin({})
	view.apply_time(0.22)  # 연출 첫 장면: 통이 자리 잡은 뒤, 흔들기 전
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


func _connect_pick(item: Control, index: int) -> void:
	item.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		var drag: InputEventMouseMotion = event as InputEventMouseMotion
		var pressed: bool = (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or (touch != null and touch.pressed)
		# 아이스크림은 위로 쓱 끌어 꺼내도 된다
		var pulled: bool = drag != null and tool_id == &"DICE_ICECREAM" and (drag.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and drag.relative.y < -2.0
		if pressed or pulled:
			item.accept_event()
			pick(index))


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
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 과자통의 포츈쿠키 / 아이스박스의 막대 아이스크림 (직접 그린다).
class Treat extends Control:
	var kind: String = "cookie"
	var flavor: int = 0

	func _draw() -> void:
		if kind == "cookie":
			var c: Vector2 = size * 0.5
			var shell: PackedVector2Array = []
			for step: int in 25:
				var angle: float = PI + PI * float(step) / 24.0
				shell.append(c + Vector2(cos(angle) * size.x * 0.46, sin(angle) * size.y * 0.62 + size.y * 0.18))
			shell.append(c + Vector2(size.x * 0.18, size.y * 0.30))
			shell.append(c + Vector2(0, size.y * 0.12))
			shell.append(c + Vector2(-size.x * 0.18, size.y * 0.30))
			draw_colored_polygon(shell, Color("f2a541"))
			shell.append(shell[0])
			draw_polyline(shell, Color("a0581c"), 3.0, true)
			draw_line(c + Vector2(-size.x * 0.06, -size.y * 0.26), c + Vector2(0, size.y * 0.1), Color("c9772a"), 3.0, true)
			return
		var tones: Array[Color] = [Color("ff8fab"), Color("ffd43b"), Color("8ce99a"), Color("74c0fc"), Color("b197fc")]
		var stick := Rect2(size.x * 0.4, size.y * 0.62, size.x * 0.2, size.y * 0.38)
		draw_rect(stick, Color("e3b778"))
		var bar := Rect2(0, 0, size.x, size.y * 0.68)
		draw_style_box(_rounded(tones[flavor % tones.size()]), bar)
		draw_style_box(_rounded(Color("7b4a2a")), Rect2(0, 0, size.x, size.y * 0.24))

	func _rounded(fill: Color) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.set_corner_radius_all(int(size.x * 0.42))
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		return style
