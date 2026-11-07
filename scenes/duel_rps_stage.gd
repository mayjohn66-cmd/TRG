## Presentation only. The engine supplies both hands and the winner.
class_name DuelRpsStage
extends Control

signal finished

const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const ART_DIR := "res://assets/ui/trickcal/duel/rps/"
const THROW_AT: float = 0.90
const FINISH_AT: float = 2.05
const GOLD := Color("ffdc79")
const INK := Color("493951")

var arena: DuelArena
var art: Array[Texture2D] = []
var ready_seats: Array[int] = []
var revealed: Dictionary = {}
var active := false
var elapsed := 0.0
var mode: StringName = &"choose"
var winner := -1
var _pending: Dictionary = {}
var _beat := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for filename: String in ["rock.png", "scissors.png", "paper.png"]:
		var texture := load(ART_DIR + filename) as Texture2D
		art.append(texture)

func reset_round() -> void:
	ready_seats.clear()
	revealed.clear()
	_pending.clear()
	active = false
	elapsed = 0.0
	winner = -1
	mode = &"choose"
	queue_redraw()

func mark_ready(seat: int) -> void:
	if not ready_seats.has(seat):
		ready_seats.append(seat)
	queue_redraw()

func play_reveal(picks: Dictionary, result_winner: int) -> void:
	_pending = picks.duplicate()
	revealed.clear()
	winner = result_winner
	elapsed = 0.0
	_beat = -1
	mode = &"windup"
	active = true
	queue_redraw()

func cancel() -> void:
	var was_active := active
	active = false
	_pending.clear()
	if was_active:
		finished.emit()

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if elapsed < THROW_AT:
		var beat := mini(int(elapsed / 0.30), 2)
		if beat != _beat:
			_beat = beat
			Sfx.play(&"hop", -7.0)
	elif revealed.is_empty():
		# Both sprites change in the same frame; no first-hand preview.
		revealed = _pending.duplicate()
		mode = &"result"
		Sfx.play(&"card_impact")
		if arena != null and arena.board != null:
			arena.board.screen_shake(3.0, 0.12)
	if elapsed >= FINISH_AT:
		active = false
		finished.emit()
	queue_redraw()

func make_choice(hand: int, callback: Callable) -> Button:
	var button := arena.board._make_button("", callback, 20, Color("3b4766"), 12)
	button.name = ["RockChoice", "ScissorsChoice", "PaperChoice"][hand]
	button.tooltip_text = DuelRules.HAND_NAMES[hand]
	button.custom_minimum_size = Vector2(146, 108)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 10
	column.offset_right = -10
	column.offset_top = 7
	column.offset_bottom = -7
	column.add_theme_constant_override("separation", 0)
	button.add_child(column)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = art[hand]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(64, 64)
	column.add_child(icon)
	var label := arena.board._make_label(DuelRules.HAND_NAMES[hand], 22, INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 0)
	column.add_child(label)
	return button

func _text(text: String, center: Vector2, px: int, color: Color) -> void:
	text = L10n.t(text)
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(FONT, center + Vector2(-width / 2, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func _draw() -> void:
	if arena == null or art.size() != 3:
		return
	var y := size.y * 0.49
	var thrown := not revealed.is_empty()
	var reveal_age := maxf(elapsed - THROW_AT, 0.0)
	var pop := 1.0 + sin(clampf(reveal_age / 0.22, 0.0, 1.0) * PI) * 0.16 if thrown else 1.0
	for seat: int in [arena.challenger, arena.defender]:
		var left := seat == arena.challenger
		var x := size.x * (0.24 if left else 0.76)
		var center := Vector2(x, y)
		var color: Color = MainBoard.PLAYER_COLORS.get(seat, Color.WHITE)
		var won := thrown and winner == seat
		var lost := thrown and winner != -1 and winner != seat
		PaintedFx.stamp(self,PaintedFx.SMOKE,center+Vector2(0,42),Vector2(140,38),Color(0.10,0.08,0.13,0.35))
		PaintedFx.stamp(self,PaintedFx.IMPACT,center,Vector2(153,146),Color(color,0.16 if not lost else 0.05))
		draw_arc(center, 72, 0, TAU, 64, GOLD if won else Color(color, 0.65), 4 if won else 2, true)
		if won:
			var shine := 1-smoothstep(0.15,0.85,reveal_age)
			PaintedFx.stamp(self,PaintedFx.IMPACT,center,Vector2.ONE*(164+reveal_age*18),Color(GOLD,shine*0.75),0.14)
			for ray: int in 6:
				var angle := float(ray)*2.39996+0.3
				var at := center+Vector2.from_angle(angle)*(78+reveal_age*16)
				PaintedFx.stamp(self,PaintedFx.FLECK,at,Vector2(10,5)*(0.8+0.2*sin(ray*3.1)),Color(GOLD,shine*0.8),angle)
		var hand := int(revealed.get(seat, DuelRules.Hand.ROCK)) if thrown else DuelRules.Hand.ROCK
		var bob := -sin(fmod(elapsed, 0.30) / 0.30 * PI) * 14.0 if mode == &"windup" else 0.0
		var tilt := (-0.08 if left else 0.08) * (0.7 if thrown else 1.0)
		var factor := pop * (0.92 if lost else 1.0)
		draw_set_transform(center + Vector2(0, bob), tilt, Vector2.ONE * factor)
		draw_texture_rect(art[hand], Rect2(-78, -78, 156, 156), false, Color(0.66, 0.64, 0.70, 1) if lost else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		_text(arena._seat_name(seat), Vector2(x, size.y - 18), 20, color.lightened(0.2))
		var status := DuelRules.HAND_NAMES[hand] if thrown else ("선택 완료" if ready_seats.has(seat) else "선택 중")
		_text(status, Vector2(x, y + 91), 18, GOLD if won or (not thrown and ready_seats.has(seat)) else Color("d0ced9"))
	if mode == &"windup":
		_text(["가위", "바위", "보!"][mini(int(elapsed / 0.30), 2)], Vector2(size.x / 2, y), 34, GOLD)
	elif thrown:
		_text("무승부!" if winner == -1 else "승리!", Vector2(size.x / 2, y - 7), 29, GOLD)
		if winner == -1:
			_text("다시!", Vector2(size.x / 2, y + 27), 20, Color("e4dfed"))
		else:
			var direction := -1.0 if winner == arena.challenger else 1.0
			draw_colored_polygon(PackedVector2Array([Vector2(size.x / 2 + direction * 28, y + 20), Vector2(size.x / 2 + direction * 46, y + 27), Vector2(size.x / 2 + direction * 28, y + 34)]), GOLD)
	else:
		_text("VS", Vector2(size.x / 2, y), 32, GOLD)
