## The roll clock moves a 3D coin while the printed ticket reveals the resolved cells.
class_name ScratchTicketView
extends Control

const SIZE := Vector2(420, 300)
const SCRATCH_START := 0.30
const SCRATCH_EACH := 0.52
const REVEAL_AT := SCRATCH_START + SCRATCH_EACH * 3.0
const TOTAL_TIME := REVEAL_AT + 0.75
const SCRATCH_STROKES_TIME := SCRATCH_EACH * 0.85
const TICKET_MESH: PackedScene = preload("res://assets/models/scratch_lottery/scratch_ticket.glb")
const COIN_MESH: PackedScene = preload("res://assets/models/scratch_lottery/scratch_coin.glb")
const FOIL_SHADER: Shader = preload("res://scenes/scratch_foil.gdshader")
const PRINT_EXTENT := Vector2(3.39, 2.28)

var settled := false
var _print_viewport: SubViewport
var _print: TicketPrint
var _coin: Node3D
var _ticket: Node3D
var _foils: Array[ColorRect] = []
## 직접 긁기 (1.3.1): 켜면 동전이 나오지 않고, 손가락·마우스로 문지른 만큼 은박이 벗겨진다 (scratch_at). 당첨 문양은 엔진이 정한 그대로다.
var manual: bool = false
var _manual: Array[float] = [0.0, 0.0, 0.0]
var _last_t: float = 0.0
var _rustle_msec: int = 0
## 화면(이 뷰) 좌표 → 복권 인쇄면 좌표 비율 (정사영 카메라 크기 3.2 = 화면 높이 300px, 인쇄면 3.39 단위 = 340px).
const VIEW_PER_PRINT: float = (300.0 / 3.20) * (PRINT_EXTENT.x / 340.0)


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(details: Dictionary) -> void:
	if _print_viewport == null:
		_build_stage()
	_print.winning = int(details.get("winning", 0))
	_print.cells = (details.get("cells", [0, 1, 2]) as Array).duplicate()
	_print.gold = (details.get("gold", [false, false, false]) as Array).duplicate()
	_manual = [0.0, 0.0, 0.0]
	apply_time(0.0)


static func caption(details: Dictionary, steps: int) -> String:
	return ToolScratchLottery.caption(details, steps)


func apply_time(t: float) -> void:
	settled = t >= REVEAL_AT
	_last_t = t
	if _print_viewport == null:
		return
	for i: int in ToolScratchLottery.CELLS:
		var progress := maxf(_scratched(t, i), _manual[i])
		var foil := _foils[i]
		foil.visible = progress < 1.0
		(foil.material as ShaderMaterial).set_shader_parameter("progress", progress)
	_print.roll_time = t
	_print.queue_redraw()
	_print_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_coin(t)
	# Small rise at entry, then the prop stays put so the suits can be read.
	_ticket.position.y = lerpf(-0.17, 0.0, smoothstep(0.0, 0.26, t))
	_ticket.rotation_degrees = Vector3(-10, -9, lerpf(-7.0, -2.0, smoothstep(0.0, 0.27, t)))


## 이 뷰 안의 한 점을 distance(px)만큼 문질렀다. 그 자리의 칸 은박이 그만큼 벗겨진다.
func scratch_at(view_point: Vector2, distance: float) -> void:
	if not manual:
		return
	var print_point: Vector2 = (view_point - SIZE * 0.5) / VIEW_PER_PRINT + TicketPrint.SIZE * 0.5
	for i: int in ToolScratchLottery.CELLS:
		if TicketPrint.cell_rect(i).grow(14.0).has_point(print_point) and _manual[i] < 1.0:
			_manual[i] = minf(1.0, _manual[i] + distance / (TicketPrint.cell_rect(i).size.y * 1.5))
			var now: int = Time.get_ticks_msec()
			if now - _rustle_msec > 140:
				_rustle_msec = now
				Sfx.play(&"ticket_rustle", -12.0)
	apply_time(_last_t)


## 세 칸을 다 긁었는가.
func manual_complete() -> bool:
	for value: float in _manual:
		if value < 1.0:
			return false
	return true


## 칸별로 벗겨진 정도 (테스트용).
func manual_progress() -> Array[float]:
	return _manual.duplicate()


static func _scratched(t: float, index: int) -> float:
	return clampf((t - SCRATCH_START - index * SCRATCH_EACH) / SCRATCH_STROKES_TIME, 0.0, 1.0)


func _build_stage() -> void:
	var stage := SubViewport.new()
	stage.name = "ScratchTicketStage"
	stage.size = Vector2i(SIZE) * 2
	stage.own_world_3d = true
	stage.transparent_bg = true
	stage.msaa_3d = Viewport.MSAA_2X
	stage.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(stage)
	var display := TextureRect.new()
	display.texture = stage.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.size = SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)

	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("e9e5f5")
	world.environment.ambient_light_energy = 0.82
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -31, 0)
	key.light_color = Color("fff0d4")
	key.light_energy = 1.15
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-4, 57, 0)
	fill.light_color = Color("d3d8ff")
	fill.light_energy = 0.62
	stage.add_child(fill)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.20
	camera.position = Vector3(0, 0.015, 6.0)
	stage.add_child(camera)
	camera.current = true
	_ticket = TICKET_MESH.instantiate() as Node3D
	stage.add_child(_ticket)
	_build_print()
	_coin = COIN_MESH.instantiate() as Node3D
	_ticket.add_child(_coin)


func _build_print() -> void:
	_print_viewport = SubViewport.new()
	_print_viewport.name = "LotteryPrint"
	_print_viewport.size = Vector2i(TicketPrint.SIZE) * 2
	_print_viewport.disable_3d = true
	add_child(_print_viewport)
	_print = TicketPrint.new()
	_print.scale = Vector2.ONE * 2.0
	_print_viewport.add_child(_print)
	for index: int in ToolScratchLottery.CELLS:
		var cell := TicketPrint.cell_rect(index)
		var foil := ColorRect.new()
		foil.position = cell.position
		foil.size = cell.size
		var material := ShaderMaterial.new()
		material.shader = FOIL_SHADER
		foil.material = material
		_print.add_child(foil)
		_foils.append(foil)

	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_texture = _print_viewport.get_texture()
	var plane := QuadMesh.new()
	plane.size = PRINT_EXTENT
	var face := MeshInstance3D.new()
	face.mesh = plane
	face.material_override = ink
	face.position.z = 0.032
	_ticket.add_child(face)


static func _coin_track(index: int, progress: float) -> Vector2:
	var cell := TicketPrint.cell_rect(index)
	return Vector2(cell.get_center().x - cos(progress * TAU * 1.5) * cell.size.x * 0.37,
		cell.position.y + progress * cell.size.y)


func _update_coin(t: float) -> void:
	var stroke_time := t - SCRATCH_START
	var index := clampi(floori(stroke_time / SCRATCH_EACH), 0, ToolScratchLottery.CELLS - 1)
	var progress := _scratched(t, index)
	var at := _coin_track(index, progress)
	var lift := 0.0
	if stroke_time < 0.0:
		var entry := smoothstep(0.02, SCRATCH_START, t)
		at += Vector2(-39.0, -42.0) * (1.0 - entry)
		lift = 0.22 * (1.0 - entry)
	elif progress == 1.0 and index < ToolScratchLottery.CELLS - 1:
		var elapsed := stroke_time - index * SCRATCH_EACH
		var hop := smoothstep(SCRATCH_STROKES_TIME, SCRATCH_EACH, elapsed)
		at = at.lerp(_coin_track(index + 1, 0.0), hop)
		lift = sin(hop * PI) * 0.16
	elif progress == 1.0:
		var departure := smoothstep(REVEAL_AT - 0.08, REVEAL_AT + 0.21, t)
		at += Vector2(32.0, 24.0) * departure
		lift = departure * 0.24
	var uv := at / TicketPrint.SIZE - Vector2(0.5, 0.5)
	_coin.visible = t < REVEAL_AT + 0.21 and not manual
	_coin.position = Vector3(uv.x * PRINT_EXTENT.x, -uv.y * PRINT_EXTENT.y + 0.045, 0.125 + lift)
	_coin.rotation_degrees = Vector3(-36.0, 18.0 * sin(progress * TAU * 1.5), -19.0 + progress * 38.0)


class TicketPrint extends Control:
	const SIZE := Vector2(340, 230)
	const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
	const INK := Color("352641")
	const WINE := Color("503451")
	const BRASS := Color("c79d64")
	const PAPER := Color("f3e2bc")
	const SUIT_DARK := Color("292336")
	const SUIT_RED := Color("ae354d")
	var winning := 0
	var cells: Array = [0, 1, 2]
	var gold: Array = [false, false, false]
	var roll_time := 0.0
	var _cream := _box(PAPER, Color("a78669"), 1, 5)
	var _head := _box(WINE, BRASS, 1, 7)
	var _normal := _box(Color("fff5dc"), Color("9d8676"), 2, 9)
	var _golden := _box(Color("ffdf86"), Color("bc8737"), 2, 9)


	static func cell_rect(index: int) -> Rect2:
		return Rect2(25.0 + index * 100.0, 85.0, 90.0, 106.0)


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), INK)
		draw_rect(Rect2(Vector2(3, 3), SIZE - Vector2(6, 6)), BRASS, false, 1.0)
		draw_style_box(_cream, Rect2(Vector2(7, 7), SIZE - Vector2(14, 14)))
		for i: int in 34:
			var x := 11.0 + i * 9.5
			draw_line(Vector2(x, 11), Vector2(x, 218), Color(0.48, 0.32, 0.3, 0.07), 1.0)
		draw_style_box(_head, Rect2(15, 15, 310, 58))
		_text(L10n.t("당첨 문양"), Vector2(107, 43), 22, Color("ffedcc"))
		draw_line(Vector2(199, 24), Vector2(199, 62), BRASS, 1.0)
		draw_circle(Vector2(251, 44), 21.0, BRASS, true, -1.0, true)
		draw_circle(Vector2(251, 44), 19.2, Color("ffefcf"), true, -1.0, true)
		_text(ToolScratchLottery.SUITS[winning], Vector2(251, 42), 34, _suit_color(winning))
		for index: int in ToolScratchLottery.CELLS:
			var cell := cell_rect(index)
			var is_gold := bool(gold[index])
			var suit := int(cells[index])
			var progress := ScratchTicketView._scratched(roll_time, index)
			draw_style_box(_golden if is_gold else _normal, cell)
			_text(ToolScratchLottery.SUITS[suit], cell.get_center(), 61,
				Color("8b4f12") if is_gold else _suit_color(suit))
			if is_gold:
				_text("★", cell.position + Vector2(cell.size.x - 14, 14), 16, Color("ad6e25"))
			if progress > 0.0 and progress < 1.0:
				_draw_foil_chips(cell, progress, index)
			if roll_time >= ScratchTicketView.REVEAL_AT and suit == winning:
				var fade := smoothstep(ScratchTicketView.REVEAL_AT, ScratchTicketView.REVEAL_AT + 0.18, roll_time)
				var ring := Color("ab6719") if is_gold else Color("427b57")
				draw_style_box(_box(Color.TRANSPARENT, Color(ring, fade), 3, 9), cell.grow(3))
		for direction: float in [-1.0, 1.0]:
			var side_x := 170.0 + direction * 104.0
			draw_line(Vector2(side_x - 47, 207), Vector2(side_x + 47, 207), Color("a58469"), 0.8)
			_text("◆", Vector2(170.0 + direction * 20.0, 207.0), 11, WINE)
		_text("♠", Vector2(170, 207), 16, WINE)


	func _draw_foil_chips(cell: Rect2, progress: float, index: int) -> void:
		for i: int in 7:
			var phase := fposmod(progress * 3.0 + i * 0.173, 1.0)
			var x := cell.position.x + cell.size.x * (0.13 + fposmod(i * 0.378 + index * 0.194, 0.76))
			var y := cell.position.y + cell.size.y * progress - 4.0 - phase * 18.0
			if y < cell.position.y:
				continue
			var sliver := Color("85899a") if i % 2 == 0 else Color("fff8ea")
			draw_line(Vector2(x, y), Vector2(x + 1.0 + i % 3, y - 2.0),
				Color(sliver, 0.82 * (1.0 - phase)), 1.35, true)


	static func _suit_color(suit: int) -> Color:
		return SUIT_RED if suit == 1 or suit == 2 else SUIT_DARK


	static func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = border
		box.set_border_width_all(width)
		box.set_corner_radius_all(radius)
		return box


	func _text(value: String, center: Vector2, px: int, color: Color) -> void:
		var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at := center + Vector2(-width * 0.5, (FONT.get_ascent(px) - FONT.get_descent(px)) * 0.5)
		draw_string(FONT, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
