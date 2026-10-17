# File: res://scenes/hub_kit.gd
# Class: class_name HubKit
# Role: 시작 메뉴·대기방의 "마을 허브" 부품 모음. 원본 게임의 로비처럼 아래쪽 둥근 초록 메뉴 버튼 줄, 왼쪽 위 프로필 띠, 오른쪽 위 둥근 아이콘 버튼, 말풍선 팁 띠, 축제 등불 장식, 캐릭터 자리 카드를 모두 코드로 직접 그린다 (원작 그림은 쓰지 않는다)
class_name HubKit
extends RefCounted

const GREEN: Color = Color("86d94f")
const GREEN_EDGE: Color = Color("3f9a2b")
const GREEN_DARK: Color = Color("2c7a1f")
const GREEN_LIGHT: Color = Color("c4f08c")
const CREAM: Color = Color("fff6d6")
const INK: Color = Color("1f5a2a")
const GOLD: Color = Color("ffd34e")
const NAV_SIZE: Vector2 = Vector2(150.0, 156.0)


## 둥근 단색 글자 윤곽이 있는 라벨 (버튼 글씨·로고용).
static func outlined(text: String, size_px: int, color: Color = Color.WHITE, outline: Color = GREEN_DARK, outline_px: int = 6) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size_px)
	item.add_theme_color_override("font_color", color)
	item.add_theme_color_override("font_outline_color", outline)
	item.add_theme_constant_override("outline_size", outline_px)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item


# ---------------------------------------------------------------------------
# 아이콘: 폰트에 이모지가 없어서 도형으로 직접 그린다
# ---------------------------------------------------------------------------

class Icon extends Control:
	var kind: StringName = &"star"
	var ink: Color = Color("2c7a1f")
	var accent: Color = Color("ffd34e")

	var pulse: bool = false
	var _clock: float = 0.0

	func _init(icon_kind: StringName = &"star", ink_color: Color = Color("2c7a1f"), accent_color: Color = Color("ffd34e")) -> void:
		kind = icon_kind
		ink = ink_color
		accent = accent_color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	## 켜면 숨 쉬듯 깜빡인다 (대기 중 표시).
	func start_pulse() -> void:
		pulse = true
		set_process(true)

	func _process(delta: float) -> void:
		_clock += delta
		modulate.a = 0.65 + 0.35 * sin(_clock * 2.6)

	func _line(points: PackedVector2Array, width: float, color: Color) -> void:
		draw_polyline(points, color, width, true)
		draw_circle(points[0], width / 2.0, color)
		draw_circle(points[points.size() - 1], width / 2.0, color)

	func _draw() -> void:
		var k: float = minf(size.x, size.y) / 64.0
		draw_set_transform(size / 2.0, 0.0, Vector2(k, k))
		match kind:
			&"sword":
				_line(PackedVector2Array([Vector2(-18, 18), Vector2(16, -16)]), 8.0, ink)
				_line(PackedVector2Array([Vector2(-18, 18), Vector2(16, -16)]), 3.5, Color.WHITE)
				_line(PackedVector2Array([Vector2(-10, 4), Vector2(-2, 12)]), 7.0, accent)
				_line(PackedVector2Array([Vector2(-20, 20), Vector2(-14, 14)]), 8.0, ink)
				draw_circle(Vector2(18, -18), 5.0, accent)
			&"dice":
				var box := StyleBoxFlat.new()
				box.bg_color = Color.WHITE
				box.border_color = ink
				box.set_border_width_all(4)
				box.set_corner_radius_all(9)
				draw_style_box(box, Rect2(-20, -20, 40, 40))
				for spot: Vector2 in [Vector2(-9, -9), Vector2(9, -9), Vector2(0, 0), Vector2(-9, 9), Vector2(9, 9)]:
					draw_circle(spot, 3.6, accent if spot == Vector2.ZERO else ink)
			&"key":
				draw_arc(Vector2(-10, -8), 11.0, 0.0, TAU, 28, ink, 7.0, true)
				draw_circle(Vector2(-10, -8), 4.0, accent)
				_line(PackedVector2Array([Vector2(-2, 0), Vector2(18, 20)]), 7.0, ink)
				_line(PackedVector2Array([Vector2(10, 12), Vector2(17, 5)]), 6.0, ink)
				_line(PackedVector2Array([Vector2(15, 17), Vector2(21, 11)]), 6.0, ink)
			&"face":
				draw_circle(Vector2.ZERO, 22.0, ink)
				draw_circle(Vector2.ZERO, 17.5, accent)
				draw_circle(Vector2(-7, -3), 3.2, ink)
				draw_circle(Vector2(7, -3), 3.2, ink)
				draw_arc(Vector2(0, 3), 9.0, 0.35, PI - 0.35, 14, ink, 3.5, true)
			&"book":
				var left := PackedVector2Array([Vector2(0, -16), Vector2(-22, -12), Vector2(-22, 16), Vector2(0, 20)])
				var right := PackedVector2Array([Vector2(0, -16), Vector2(22, -12), Vector2(22, 16), Vector2(0, 20)])
				draw_colored_polygon(left, accent)
				draw_colored_polygon(right, Color.WHITE)
				draw_polyline(PackedVector2Array([left[0], left[1], left[2], left[3], right[2], right[1], right[0], left[3]]), ink, 3.5, true)
				for row: int in 3:
					_line(PackedVector2Array([Vector2(5, -7 + row * 8), Vector2(16, -5 + row * 8)]), 2.6, ink)
			&"gear":
				for index: int in 8:
					var angle: float = float(index) * TAU / 8.0
					_line(PackedVector2Array([Vector2(cos(angle), sin(angle)) * 14.0, Vector2(cos(angle), sin(angle)) * 22.0]), 8.0, ink)
				draw_circle(Vector2.ZERO, 17.0, ink)
				draw_circle(Vector2.ZERO, 7.0, accent)
			&"crown":
				draw_colored_polygon(PackedVector2Array([Vector2(-18, 12), Vector2(-20, -10), Vector2(-9, 0), Vector2(0, -16), Vector2(9, 0), Vector2(20, -10), Vector2(18, 12)]), accent)
				draw_polyline(PackedVector2Array([Vector2(-18, 12), Vector2(-20, -10), Vector2(-9, 0), Vector2(0, -16), Vector2(9, 0), Vector2(20, -10), Vector2(18, 12), Vector2(-18, 12)]), ink, 3.0, true)
			&"play":
				draw_colored_polygon(PackedVector2Array([Vector2(-12, -18), Vector2(20, 0), Vector2(-12, 18)]), accent)
				draw_polyline(PackedVector2Array([Vector2(-12, -18), Vector2(20, 0), Vector2(-12, 18), Vector2(-12, -18)]), ink, 3.5, true)
			&"next":
				_line(PackedVector2Array([Vector2(-14, -12), Vector2(-2, 0), Vector2(-14, 12)]), 6.0, ink)
				_line(PackedVector2Array([Vector2(2, -12), Vector2(14, 0), Vector2(2, 12)]), 6.0, ink)
			&"leaf":
				draw_colored_polygon(PackedVector2Array([Vector2(-20, 16), Vector2(-14, -8), Vector2(2, -22), Vector2(20, -20), Vector2(16, 2), Vector2(2, 16)]), accent)
				_line(PackedVector2Array([Vector2(-18, 18), Vector2(10, -10)]), 3.5, ink)
			&"back":
				_line(PackedVector2Array([Vector2(10, -20), Vector2(-10, 0), Vector2(10, 20)]), 11.0, ink)
			&"forward":
				_line(PackedVector2Array([Vector2(-10, -20), Vector2(10, 0), Vector2(-10, 20)]), 11.0, ink)
			&"grid":
				for gx: int in 3:
					for gy: int in 3:
						var cell := Rect2(Vector2(-21 + gx * 15, -21 + gy * 15), Vector2(12, 12))
						draw_rect(cell, accent if (gx + gy) % 2 == 0 else Color.WHITE)
						draw_rect(cell, ink, false, 2.5)
			&"hourglass":
				draw_colored_polygon(PackedVector2Array([Vector2(-14, -18), Vector2(14, -18), Vector2(0, 0)]), accent)
				draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(14, 18), Vector2(-14, 18)]), accent.darkened(0.15))
				draw_polyline(PackedVector2Array([Vector2(-16, -20), Vector2(16, -20), Vector2(0, 0), Vector2(16, 20), Vector2(-16, 20), Vector2(0, 0), Vector2(-16, -20)]), ink, 3.5, true)
			_:
				draw_circle(Vector2.ZERO, 14.0, accent)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------------------
# 부품
# ---------------------------------------------------------------------------

## 아래쪽 메뉴 버튼 한 개: 위로 솟은 동그란 아이콘 + 아래 초록 알약 + 글자. 올리면 통통 커지고 누르면 눌린다.
static func nav_button(node_name: String, icon_kind: StringName, text: String, callback: Callable, tone: StringName = &"green") -> Button:
	var palette: Array = {
		&"green": [GREEN, GREEN_EDGE, GREEN_DARK],
		&"blue": [Color("7cc7f0"), Color("2f7fb8"), Color("1d5a8a")],
		&"pink": [Color("f5a0c0"), Color("c2457a"), Color("8f2d58")],
		&"gold": [Color("ffd66b"), Color("c98a14"), Color("8a5a0a")],
	}.get(tone, [GREEN, GREEN_EDGE, GREEN_DARK]) as Array
	var fill: Color = palette[0]
	var edge: Color = palette[1]
	var dark: Color = palette[2]
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = NAV_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.pivot_offset = NAV_SIZE / 2.0
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var body := Panel.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.position = Vector2(0, 62)
	body.size = Vector2(NAV_SIZE.x, NAV_SIZE.y - 62.0)
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = fill
	body_style.border_color = edge
	body_style.set_border_width_all(4)
	body_style.border_width_bottom = 8
	body_style.set_corner_radius_all(30)
	body_style.shadow_color = Color(0, 0, 0, 0.25)
	body_style.shadow_size = 6
	body_style.shadow_offset = Vector2(0, 4)
	body.add_theme_stylebox_override("panel", body_style)
	button.add_child(body)
	var shine := Panel.new()
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.position = Vector2(14, 70)
	shine.size = Vector2(NAV_SIZE.x - 28.0, 12)
	var shine_style := StyleBoxFlat.new()
	shine_style.bg_color = Color(1, 1, 1, 0.35)
	shine_style.set_corner_radius_all(6)
	shine.add_theme_stylebox_override("panel", shine_style)
	button.add_child(shine)
	var disc := Panel.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.position = Vector2((NAV_SIZE.x - 84.0) / 2.0, 2)
	disc.size = Vector2(84, 84)
	var disc_style := StyleBoxFlat.new()
	disc_style.bg_color = CREAM
	disc_style.border_color = edge
	disc_style.set_border_width_all(5)
	disc_style.set_corner_radius_all(42)
	disc_style.shadow_color = Color(0, 0, 0, 0.2)
	disc_style.shadow_size = 4
	disc.add_theme_stylebox_override("panel", disc_style)
	button.add_child(disc)
	var icon := Icon.new(icon_kind, dark, GOLD)
	icon.position = Vector2(14, 14)
	icon.size = Vector2(56, 56)
	disc.add_child(icon)
	var title := outlined(text, 24, Color.WHITE, dark, 7)
	title.name = "CardTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 92)
	title.size = Vector2(NAV_SIZE.x, 40)
	button.add_child(title)
	button.mouse_entered.connect(func() -> void: _bounce(button, 1.07))
	button.mouse_exited.connect(func() -> void: _bounce(button, 1.0))
	button.button_down.connect(func() -> void: _bounce(button, 0.94, 0.06))
	button.button_up.connect(func() -> void: _bounce(button, 1.07 if button.is_hovered() else 1.0, 0.1))
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


static func _bounce(node: Control, target: float, seconds: float = 0.12) -> void:
	if not node.is_inside_tree():
		return
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * target, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 동그란 캐릭터 판: 아바타 그림이 있으면 그것을, 없으면 색 원 위에 동글 웃는 얼굴을 그린다. 반환 Control의 크기는 diameter x diameter.
static func avatar_disc(id: StringName, color: Color, diameter: float, ring: Color = Color.WHITE, ring_px: int = 6) -> Control:
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(diameter, diameter)
	holder.size = Vector2(diameter, diameter)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc := StyleBoxFlat.new()
	disc.bg_color = color.lightened(0.45)
	disc.border_color = ring
	disc.set_border_width_all(ring_px)
	disc.set_corner_radius_all(int(diameter / 2.0))
	disc.shadow_color = Color(0, 0, 0, 0.22)
	disc.shadow_size = maxi(3, int(diameter / 30.0))
	holder.add_theme_stylebox_override("panel", disc)
	if AvatarSlot.has_assets(id):
		var avatar := AvatarSlot.new()
		avatar.setup(1, color, Vector2(diameter, diameter) - Vector2.ONE * ring_px * 2.0)
		avatar.set_character(id)
		avatar.position = Vector2.ONE * ring_px
		var mask := StyleBoxFlat.new()
		mask.bg_color = color.lightened(0.5)
		mask.set_corner_radius_all(int((diameter - ring_px * 2.0) / 2.0))
		avatar.add_theme_stylebox_override("panel", mask)
		holder.add_child(avatar)
	else:
		var face := Icon.new(&"face", color.darkened(0.45), Color.WHITE.lerp(color, 0.25))
		face.position = Vector2.ONE * diameter * 0.12
		face.size = Vector2.ONE * diameter * 0.76
		holder.add_child(face)
	return holder


## 오른쪽 대결 선택 카드(가로로 긴 큰 버튼): 왼쪽 동그란 아이콘, 큰 제목(CardTitle), 작은 설명(CardSub), 오른쪽 화살표. 올리면 통통 커진다.
static func mode_card(node_name: String, icon_kind: StringName, title_text: String, sub_text: String, callback: Callable, tone: StringName = &"green") -> Button:
	var palette: Array = {
		&"green": [Color("86d94f"), Color("3f9a2b"), Color("2c7a1f")],
		&"blue": [Color("7cc7f0"), Color("2f7fb8"), Color("1d5a8a")],
		&"pink": [Color("f5a0c0"), Color("c2457a"), Color("8f2d58")],
	}.get(tone, [GREEN, GREEN_EDGE, GREEN_DARK]) as Array
	var fill: Color = palette[0]
	var edge: Color = palette[1]
	var dark: Color = palette[2]
	var size := Vector2(640.0, 124.0)
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.pivot_offset = size / 2.0
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = Color.WHITE
	normal.set_border_width_all(5)
	normal.border_width_bottom = 9
	normal.set_corner_radius_all(40)
	normal.shadow_color = Color(edge, 0.8)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 4)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = fill.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = fill.darkened(0.1)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var disc := Panel.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.position = Vector2(22, 18)
	disc.size = Vector2(82, 82)
	var disc_style := StyleBoxFlat.new()
	disc_style.bg_color = CREAM
	disc_style.border_color = edge
	disc_style.set_border_width_all(5)
	disc_style.set_corner_radius_all(41)
	disc.add_theme_stylebox_override("panel", disc_style)
	button.add_child(disc)
	var icon := Icon.new(icon_kind, dark, GOLD)
	icon.position = Vector2(12, 12)
	icon.size = Vector2(58, 58)
	disc.add_child(icon)
	var title := outlined(title_text, 44, Color.WHITE, dark, 9)
	title.name = "CardTitle"
	title.position = Vector2(126, 8)
	title.size = Vector2(440, 62)
	button.add_child(title)
	var sub := outlined(sub_text, 19, Color("fffbe6"), dark, 5)
	sub.name = "CardSub"
	sub.position = Vector2(128, 72)
	sub.size = Vector2(450, 28)
	button.add_child(sub)
	var arrow := Icon.new(&"next", Color.WHITE, GOLD)
	arrow.position = Vector2(576, 38)
	arrow.size = Vector2(44, 44)
	button.add_child(arrow)
	button.mouse_entered.connect(func() -> void: _bounce(button, 1.03))
	button.mouse_exited.connect(func() -> void: _bounce(button, 1.0))
	button.button_down.connect(func() -> void: _bounce(button, 0.97, 0.06))
	button.button_up.connect(func() -> void: _bounce(button, 1.03 if button.is_hovered() else 1.0, 0.1))
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


## 오른쪽 위의 둥근 아이콘 버튼 (설정·규칙).
static func round_button(node_name: String, icon_kind: StringName, callback: Callable, diameter: float = 60.0) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.focus_mode = Control.FOCUS_NONE
	button.pivot_offset = Vector2(diameter, diameter) / 2.0
	var normal := StyleBoxFlat.new()
	normal.bg_color = GREEN
	normal.border_color = Color.WHITE
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(int(diameter / 2.0))
	normal.shadow_color = Color(GREEN_EDGE, 0.8)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0, 3)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = GREEN.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = GREEN.darkened(0.12)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := Icon.new(icon_kind, Color.WHITE, GOLD)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 11
	icon.offset_top = 11
	icon.offset_right = -11
	icon.offset_bottom = -11
	button.add_child(icon)
	button.mouse_entered.connect(func() -> void: _bounce(button, 1.1))
	button.mouse_exited.connect(func() -> void: _bounce(button, 1.0))
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


## 왼쪽 위 프로필 띠: 둥근 아바타 + 초록 이름표 + 작은 직함. 눌러서 아바타 설정으로 간다. 반환: {"root", "name", "title", "avatar"}
static func profile_capsule(player_name: String, title_text: String, avatar_id: StringName, color: Color, callback: Callable) -> Dictionary:
	var root := Button.new()
	root.name = "ProfileCapsule"
	root.flat = true
	root.focus_mode = Control.FOCUS_NONE
	root.custom_minimum_size = Vector2(330, 92)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		root.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2(44, 14)
	plate.size = Vector2(286, 64)
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color("2fa63a")
	plate_style.border_color = Color("1f7a2a")
	plate_style.set_border_width_all(3)
	plate_style.set_corner_radius_all(20)
	plate_style.shadow_color = Color(0, 0, 0, 0.22)
	plate_style.shadow_size = 5
	plate.add_theme_stylebox_override("panel", plate_style)
	root.add_child(plate)
	var name_label := outlined(player_name, 24, Color.WHITE, Color("17591f"), 5)
	name_label.name = "ProfileName"
	name_label.position = Vector2(60, 4)
	name_label.size = Vector2(210, 34)
	name_label.clip_text = true
	plate.add_child(name_label)
	var title := outlined(title_text, 15, Color("d8ffc0"), Color("17591f"), 4)
	title.name = "ProfileTitle"
	title.position = Vector2(60, 36)
	title.size = Vector2(210, 22)
	plate.add_child(title)
	var avatar: Control = avatar_disc(avatar_id, color, 76.0, Color("2fa63a"), 4)
	avatar.position = Vector2(8, 8)
	root.add_child(avatar)
	if callback.is_valid():
		root.pressed.connect(callback)
	return {"root": root, "name": name_label, "title": title, "avatar": avatar}


## 말풍선 띠(원본의 퀘스트 안내 줄처럼): 둥근 아바타 점 + 팁 글자 + 다음 팁 버튼. 반환: {"root", "label", "next"}
static func tip_bar(first_text: String, on_next: Callable) -> Dictionary:
	var root := PanelContainer.new()
	root.name = "TipBar"
	root.custom_minimum_size = Vector2(560, 56)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.border_color = Color("e3efc6")
	style.set_border_width_all(3)
	style.set_corner_radius_all(28)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 5
	style.set_content_margin_all(8)
	root.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(38, 38)
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color("ffe48a")
	dot_style.border_color = Color("e0b23a")
	dot_style.set_border_width_all(3)
	dot_style.set_corner_radius_all(19)
	dot.add_theme_stylebox_override("panel", dot_style)
	var dot_icon := Icon.new(&"hourglass", Color("8a5a0a"), Color("fff3bf"))
	dot_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	dot_icon.offset_left = 6
	dot_icon.offset_top = 6
	dot_icon.offset_right = -6
	dot_icon.offset_bottom = -6
	dot.add_child(dot_icon)
	row.add_child(dot)
	var text := Label.new()
	text.name = "TipText"
	text.text = first_text
	text.add_theme_font_size_override("font_size", 17)
	text.add_theme_color_override("font_color", Color("2f4a2a"))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(430, 0)
	text.max_lines_visible = 2
	row.add_child(text)
	var next := Button.new()
	next.name = "TipNext"
	next.custom_minimum_size = Vector2(54, 38)
	next.focus_mode = Control.FOCUS_NONE
	var next_style := StyleBoxFlat.new()
	next_style.bg_color = Color("d6ecb0")
	next_style.border_color = Color("9fca62")
	next_style.set_border_width_all(2)
	next_style.set_corner_radius_all(19)
	next.add_theme_stylebox_override("normal", next_style)
	var next_hover: StyleBoxFlat = next_style.duplicate()
	next_hover.bg_color = Color("e4f5c8")
	next.add_theme_stylebox_override("hover", next_hover)
	next.add_theme_stylebox_override("pressed", next_style)
	next.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var next_icon := Icon.new(&"next", Color("5a8a2a"), GOLD)
	next_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	next_icon.offset_left = 12
	next_icon.offset_top = 7
	next_icon.offset_right = -12
	next_icon.offset_bottom = -7
	next.add_child(next_icon)
	if on_next.is_valid():
		next.pressed.connect(on_next)
	row.add_child(next)
	return {"root": root, "label": text, "next": next}


## 크고 노란 로고 판: 위 작은 글자 + 큰 제목 + 아래 부제.
static func logo(small_text: String, big_text: String, sub_text: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "HubLogo"
	column.add_theme_constant_override("separation", -4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var small: Label = outlined(small_text, 30, Color.WHITE, GREEN_DARK, 9)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(small)
	var big: Label = outlined(big_text, 84, GOLD, GREEN_DARK, 16)
	big.name = "Logo"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.28))
	big.add_theme_constant_override("shadow_offset_y", 5)
	column.add_child(big)
	var sub: Label = outlined(sub_text, 24, Color.WHITE, Color("2c7a1f"), 7)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	return column


## 마을 축제 장식: 왼쪽 위의 따뜻한 햇살과 위쪽에 늘어진 줄 등불. 클릭을 막지 않는다.
class FestivalDecor extends Control:
	const LANTERN_COLORS: Array[Color] = [Color("ff6b5e"), Color("ffb347"), Color("5fb3ff"), Color("ffd34e"), Color("ff6b5e"), Color("7ad87a")]
	var _t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var glow_center := Vector2(w * 0.16, h * 0.04)
		for layer: int in 6:
			draw_circle(glow_center, (6 - layer) * 74.0, Color(1.0, 0.93, 0.62, 0.05))
		for line: int in 2:
			_garland(w, h, 8.0 + line * 40.0, 22.0 + line * 12.0, line)

	func _garland(w: float, h: float, y0: float, sag: float, seed_shift: int) -> void:
		var points := PackedVector2Array()
		var steps: int = 40
		var x0: float = -20.0
		var x1: float = w + 20.0
		for index: int in steps + 1:
			var u: float = float(index) / steps
			points.append(Vector2(lerpf(x0, x1, u), y0 + sin(u * PI) * sag))
		draw_polyline(points, Color(0.42, 0.3, 0.2, 0.75), 2.0, true)
		var count: int = 9
		for index: int in count:
			var u: float = (float(index) + 0.5 + 0.2 * seed_shift) / count
			if u >= 1.0:
				continue
			var base := Vector2(lerpf(x0, x1, u), y0 + sin(u * PI) * sag)
			var sway: float = sin(_t * 1.3 + float(index) * 1.7 + seed_shift) * 3.0
			var color: Color = LANTERN_COLORS[(index + seed_shift * 2) % LANTERN_COLORS.size()]
			draw_line(base, base + Vector2(sway * 0.4, 10), Color(0.42, 0.3, 0.2, 0.75), 2.0)
			var top: Vector2 = base + Vector2(sway * 0.4, 10)
			var box := StyleBoxFlat.new()
			box.bg_color = Color(color, 0.92)
			box.border_color = Color(1, 1, 1, 0.55)
			box.set_border_width_all(2)
			box.set_corner_radius_all(12)
			box.shadow_color = Color(color, 0.35)
			box.shadow_size = 10
			draw_style_box(box, Rect2(top + Vector2(-14 + sway, 0), Vector2(28, 40)))
			draw_line(top + Vector2(-14 + sway, 9), top + Vector2(14 + sway, 9), Color(1, 1, 1, 0.45), 2.0)
			draw_line(top + Vector2(-14 + sway, 30), top + Vector2(14 + sway, 30), Color(1, 1, 1, 0.45), 2.0)


## 대기방의 캐릭터 자리 카드 한 장(원본의 파티 편성 칸처럼 세로로 길다): 위 왕관, 큰 동그란 캐릭터, 이름표, 상태 줄, 아래 버튼 칸.
## 반환: {"root", "avatar", "name", "state", "actions"(버튼을 담는 VBox), "crown"}
static func seat_card(seat: int, color: Color, empty: bool, avatar_id: StringName = &"default") -> Dictionary:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(172, 250)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.55) if empty else Color(1, 1, 1, 0.94)
	style.border_color = Color(color, 0.55 if empty else 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(26)
	style.shadow_color = Color(0, 0, 0, 0.14 if empty else 0.22)
	style.shadow_size = 6
	style.set_content_margin_all(10)
	root.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(column)
	var crown_row := Control.new()
	crown_row.custom_minimum_size = Vector2(0, 22)
	column.add_child(crown_row)
	var badge := outlined("P%d" % seat, 17, Color.WHITE, color.darkened(0.35), 5)
	badge.position = Vector2(2, -2)
	crown_row.add_child(badge)
	var crown := Icon.new(&"crown", Color("8a5a0a"), GOLD)
	crown.position = Vector2(118, -4)
	crown.size = Vector2(30, 26)
	crown.visible = false
	crown_row.add_child(crown)
	var avatar_holder := CenterContainer.new()
	column.add_child(avatar_holder)
	var avatar: Control
	if empty:
		avatar = Panel.new()
		avatar.custom_minimum_size = Vector2(108, 108)
		var hollow := StyleBoxFlat.new()
		hollow.bg_color = Color(color, 0.10)
		hollow.border_color = Color(color, 0.5)
		hollow.set_border_width_all(4)
		hollow.set_corner_radius_all(54)
		avatar.add_theme_stylebox_override("panel", hollow)
		var wait := Icon.new(&"hourglass", Color(color, 0.7), Color(color, 0.35))
		wait.position = Vector2(30, 28)
		wait.size = Vector2(48, 52)
		wait.start_pulse()
		avatar.add_child(wait)
	else:
		avatar = avatar_disc(avatar_id, color, 108.0, color, 5)
	avatar_holder.add_child(avatar)
	var name_plate := PanelContainer.new()
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = color.darkened(0.1) if not empty else Color("9db7a8")
	plate_style.set_corner_radius_all(14)
	plate_style.set_content_margin_all(3)
	name_plate.add_theme_stylebox_override("panel", plate_style)
	column.add_child(name_plate)
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(140, 0)
	name_plate.add_child(name_label)
	var state_label := Label.new()
	state_label.add_theme_font_size_override("font_size", 14)
	state_label.add_theme_color_override("font_color", Color("3d6b5c"))
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(state_label)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)
	return {"root": root, "avatar": avatar, "name": name_label, "state": state_label, "actions": actions, "crown": crown}
