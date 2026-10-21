## A single wide casino reel: every ticket is one complete game, not three
## unrelated outcomes. It only reveals the game already chosen by the engine.
class_name DuelGameSlot
extends Control

signal finished

const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const BELL: Texture2D = preload("res://assets/ui/trickcal/slot/SLOT_BELL.png")
const POKER: Texture2D = preload("res://content_trickcal/illustrations/dice/DICE_POKER.png")
const GUN: Texture2D = preload("res://content_trickcal/illustrations/dice/REVOLVER.png")
const COLORS: Array[Color] = [Color("f28c98"), Color("e8b34f"), Color("56b8be"), Color("ef9868"), Color("a58ae5"), Color("7bad73")]
const GOLD := Color("ffdb79")
const ROW_HEIGHT: float = 76.0

var active := false
var settled := false
var selected_game := -1
var elapsed := 0.0
var reel_position := 0.0
var visited: Array[int] = []
var _end := 0.0
var _last_tick := -1

func _init() -> void:
	custom_minimum_size = Vector2(500, 218)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _ready() -> void:
	var reel := ReelWindow.new()
	reel.name = "ReelWindow"
	reel.owner_slot = self
	reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel.clip_contents = true
	add_child(reel)

func play(game_id: int) -> void:
	selected_game = clampi(game_id, 0, DuelRules.GAME_COUNT - 1)
	_end = float(DuelRules.GAME_COUNT * 5 + selected_game)
	elapsed = 0.0
	reel_position = 0.0
	_last_tick = -1
	visited.clear()
	settled = false
	active = true
	visible = true
	Sfx.play(&"slot_spin")
	queue_redraw()

func cancel() -> void:
	var was_active := active
	active = false
	visible = false
	if was_active:
		finished.emit()

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	var roll_time := DuelRules.ROULETTE_TIME - 0.16
	var progress := clampf(elapsed / roll_time, 0.0, 1.0)
	reel_position = _end * (1.0 - pow(1.0 - progress, 3.0))
	if elapsed >= roll_time:
		var settle := clampf((elapsed - roll_time) / 0.16, 0.0, 1.0)
		reel_position = _end + sin(settle * TAU) * 0.065 * (1.0 - settle)
	var ticket := int(floor(reel_position + 0.5))
	if ticket != _last_tick:
		_last_tick = ticket
		visited.append(posmod(ticket, DuelRules.GAME_COUNT))
		Sfx.play(&"roulette_tick")
	if elapsed >= DuelRules.ROULETTE_TIME:
		reel_position = _end
		active = false
		settled = true
		Sfx.play(&"slot_stop")
		finished.emit()
	queue_redraw()

func _box(rect: Rect2, fill: Color, edge: Color, radius: int = 12, width: int = 2, pen: CanvasItem = null) -> void:
	if pen == null:
		pen = self
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	pen.draw_style_box(style, rect)

func _text(text: String, at: Vector2, font_size: int, color: Color, width: float = -1.0, pen: CanvasItem = null) -> void:
	if pen == null:
		pen = self
	pen.draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

func _draw() -> void:
	if size.x < 20.0:
		return
	# The reel is clipped separately from its frame and lever.
	_box(Rect2(6, 6, size.x - 12, size.y - 12), Color("271d39"), Color("a9753d"), 20, 3)
	_box(Rect2(11, 11, size.x - 22, size.y - 22), Color("48304d"), GOLD, 16, 2)
	var window := Rect2(34, 27, size.x - 102, size.y - 54)
	_box(window.grow(4), Color("191624"), Color("b77d45"), 10, 3)
	var reel := get_node("ReelWindow") as ReelWindow
	reel.position = window.position
	reel.size = window.size
	reel.queue_redraw()
	# Lamps chase while spinning and all light together at the stop.
	for row: int in 2:
		for index: int in 15:
			var lit := settled or posmod(index + int(elapsed * 13.0) + row * 2, 4) < 2
			var at := Vector2(27.0 + index * (size.x - 54.0) / 14.0, 18.0 if row == 0 else size.y - 18.0)
			draw_circle(at, 3.1, GOLD if lit else Color("8c624a"))
			if lit:
				draw_circle(at + Vector2(-0.7, -0.7), 1.0, Color("fff7d6"))
	# A physical lever makes the slot machine read immediately.
	var lever_x := size.x - 35.0
	var pull := sin(clampf(elapsed / 0.28, 0.0, 1.0) * PI) * 35.0
	draw_circle(Vector2(lever_x, 132), 13, Color("a9753d"))
	draw_line(Vector2(lever_x, 132), Vector2(lever_x + 2, 58 + pull), Color("ded6c7"), 7, true)
	draw_circle(Vector2(lever_x + 2, 57 + pull), 13, Color("a13954"))
	draw_circle(Vector2(lever_x, 54 + pull), 9, Color("ee7782"))
	# Payline marks frame the winning ticket without crossing its title.
	var y := window.get_center().y
	draw_colored_polygon(PackedVector2Array([Vector2(19, y - 8), Vector2(31, y), Vector2(19, y + 8)]), GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(window.end.x + 14, y - 8), Vector2(window.end.x + 2, y), Vector2(window.end.x + 14, y + 8)]), GOLD)
	if settled:
		_box(Rect2(window.position.x - 2, y - ROW_HEIGHT / 2 - 2, window.size.x + 4, ROW_HEIGHT + 4), Color(1, 0.8, 0.3, 0.06), GOLD, 9, 3)

func _icon(game_id: int, at: Vector2, pen: CanvasItem = null) -> void:
	if pen == null:
		pen = self
	pen.draw_circle(at, 25, COLORS[game_id].darkened(0.15))
	pen.draw_circle(at, 22, COLORS[game_id].lightened(0.64))
	match game_id:
		DuelRules.Game.HALLI:
			pen.draw_texture_rect(BELL, Rect2(at - Vector2(26, 26), Vector2(52, 52)), false)
		DuelRules.Game.ECARD:
			pen.draw_texture_rect(POKER, Rect2(at - Vector2(24, 24), Vector2(48, 48)), false)
		DuelRules.Game.QUICKDRAW:
			pen.draw_texture_rect(GUN, Rect2(at - Vector2(27, 27), Vector2(54, 54)), false)
		DuelRules.Game.RPS:
			# Scissors: simple, legible game symbol rather than a tiny character.
			pen.draw_line(at + Vector2(-10, 12), at + Vector2(12, -15), Color("66526e"), 6, true)
			pen.draw_line(at + Vector2(9, 12), at + Vector2(-11, -15), Color("66526e"), 6, true)
			for side: float in [-1.0, 1.0]:
				pen.draw_arc(at + Vector2(side * 10, 12), 7, 0, TAU, 20, Color("d76585"), 5, true)
			pen.draw_circle(at, 3, GOLD)
		DuelRules.Game.CURLING:
			for index: int in 12:
				var angle := float(index) * TAU / 12.0
				pen.draw_line(at + Vector2.from_angle(angle) * 15, at + Vector2.from_angle(angle) * 19, Color("347e8e"), 4, true)
			pen.draw_circle(at, 16, Color("429da8"))
			pen.draw_circle(at, 11, Color("b7e4dd"))
			pen.draw_arc(at, 11, 0, TAU, 24, Color("286d80"), 2, true)
		DuelRules.Game.BARREL:
			_box(Rect2(at - Vector2(15, 18), Vector2(30, 37)), Color("b47c49"), Color("6f4d39"), 8, 2, pen)
			for offset_y: int in [-10, 10]:
				pen.draw_line(at + Vector2(-14, offset_y), at + Vector2(14, offset_y), Color("e6c274"), 4)
			for offset_x: int in [-8, 0, 8]:
				pen.draw_circle(at + Vector2(offset_x, 1), 2.4, Color("503b35"))

class ReelWindow extends Control:
	var owner_slot: DuelGameSlot
	func _draw() -> void:
		var s := owner_slot
		draw_rect(Rect2(Vector2.ZERO, size), Color("151422"))
		var nearest := int(floor(s.reel_position))
		for index: int in range(nearest - 2, nearest + 4):
			var offset := (float(index) - s.reel_position) * ROW_HEIGHT
			var rect := Rect2(6, size.y / 2 + offset - ROW_HEIGHT / 2 + 3, size.x - 12, ROW_HEIGHT - 6)
			if rect.end.y < 0 or rect.position.y > size.y:
				continue
			var id := posmod(index, DuelRules.GAME_COUNT)
			var fade := clampf(1.0 - absf(offset) / ROW_HEIGHT * 0.50, 0.32, 1.0)
			var fill := Color("fff4dc").darkened((1.0 - fade) * 0.3)
			s._box(rect, fill, COLORS[id].darkened(0.1), 9, 2, self)
			s._icon(id, Vector2(40, rect.get_center().y), self)
			var font_size := 25
			while FONT.get_string_size(DuelRules.game_name(id), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x - 83 and font_size > 16:
				font_size -= 1
			s._text(DuelRules.game_name(id), Vector2(76, rect.get_center().y + float(font_size) * 0.35), font_size, Color("493951"), -1.0, self)
		# Shade edges to suggest the curvature of a drum.
		for index: int in 12:
			var alpha := 0.55 * (1.0 - float(index) / 12.0)
			draw_rect(Rect2(0, float(index) * 2, size.x, 2), Color(0.06, 0.04, 0.10, alpha))
			draw_rect(Rect2(0, size.y - float(index + 1) * 2, size.x, 2), Color(0.06, 0.04, 0.10, alpha))
