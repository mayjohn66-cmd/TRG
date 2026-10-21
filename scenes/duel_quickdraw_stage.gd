## Two approved toy revolvers; the arena clock and engine alone decide the winner.
class_name DuelQuickdrawStage
extends Control

signal prepared

const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const GOLD := Color("ffdc79")
var arena: DuelArena
var guns: Array[ToyFlagGun3D] = []
var strikes: Dictionary = {}
var pending: Dictionary = {}
var shot_ages: Dictionary = {}
var result: Dictionary = {}
var preparing := false
var active := false
var elapsed := 0.0
var clock := -1.0
var cue := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_guns)

func prepare() -> void:
	if guns.is_empty():
		for index: int in 2:
			var gun := ToyFlagGun3D.new()
			gun.custom_minimum_size = Vector2.ZERO
			gun.flip_h = index == 0
			add_child(gun)
			gun.render_view.size = Vector2i(600, 360)
			guns.append(gun)
	_layout_guns()
	preparing = true
	active = true
	elapsed = 0.0
	clock = -1.0
	strikes.clear()
	pending.clear()
	shot_ages.clear()
	result.clear()
	for index: int in 2:
		guns[index].sound_enabled = index == 0
		guns[index].begin_preparation()
	queue_redraw()

func _layout_guns() -> void:
	for index: int in guns.size():
		guns[index].position = Vector2(size.x * float(index) / 2.0 - size.x * 0.025, 44)
		guns[index].size = Vector2(size.x * 0.55, size.y - 78)

func start_reaction() -> void:
	clock = 0.0
	cue = 0
	queue_redraw()

func sync_clock(at: float) -> void:
	if not active or preparing or not result.is_empty():
		return
	clock = at
	var next := 0
	var fake := float(arena.setup_data.get("fake", -1.0))
	if clock >= float(arena.setup_data["signal"]):
		next = 2
	elif fake >= 0.0 and clock >= fake and clock < fake + 0.35:
		next = 1
	if next != cue:
		cue = next
		if cue == 2:
			Sfx.play(&"slam", -5.0)
	for seat: int in pending.keys():
		var ms := int(pending[seat])
		if ms >= 0 and float(ms) / 1000.0 <= clock:
			fire(seat, ms)
			pending.erase(seat)
	queue_redraw()

func queue_picks(picks: Dictionary) -> void:
	pending = picks.duplicate()
	sync_clock(maxf(clock, 0.0))

func fire(seat: int, milliseconds: int) -> void:
	if not active or preparing or milliseconds < 0 or strikes.has(seat):
		return
	var index := 0 if seat == arena.challenger else 1
	strikes[seat] = milliseconds
	shot_ages[index] = 0.0
	guns[index].begin(true, 0)
	queue_redraw()

func shots_finished() -> bool:
	for age: float in shot_ages.values():
		if age < ToyFlagGun3D.FLAG_TOTAL_TIME:
			return false
	return true

func show_result(data: Dictionary) -> void:
	result = data.duplicate(true)
	queue_redraw()

func cancel() -> void:
	active = false
	for gun: ToyFlagGun3D in guns:
		gun.stop_rendering()
	if preparing:
		preparing = false
		prepared.emit()

func _process(delta: float) -> void:
	if not active:
		return
	if preparing:
		elapsed += delta
		for gun: ToyFlagGun3D in guns:
			gun.apply_preparation(elapsed)
		if elapsed >= ToyFlagGun3D.PREP_TIME:
			preparing = false
			for gun: ToyFlagGun3D in guns:
				gun.show_side()
				gun.render_view.render_target_update_mode = SubViewport.UPDATE_ONCE
				gun.sound_enabled = true
			prepared.emit()
		queue_redraw()
	for index: int in shot_ages.keys():
		var old := float(shot_ages[index])
		shot_ages[index] = old + delta
		if old < ToyFlagGun3D.FLAG_TOTAL_TIME:
			guns[index].apply_time(float(shot_ages[index]))
			if float(shot_ages[index]) >= ToyFlagGun3D.FLAG_TOTAL_TIME:
				guns[index].stop_rendering()

func _text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var pos := center - Vector2(FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0, 0)
	draw_string_outline(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 7, Color("352b38"))
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("765242")
	background.border_color = Color("c99b67")
	background.set_border_width_all(2)
	background.set_corner_radius_all(18)
	draw_style_box(background, Rect2(Vector2.ZERO, size))
	draw_circle(Vector2(size.x / 2, 110), 47, Color("edb86b", 0.22))
	for index: int in 5:
		var y := size.y - 40.0 + float(index) * 8.0
		draw_line(Vector2(20, y), Vector2(size.x - 20, y), Color("e2b578", 0.08), 2)
	for index: int in 2:
		var seat := arena.challenger if index == 0 else arena.defender
		var x := size.x * (0.25 if index == 0 else 0.75)
		var color := Color("ffb4a8") if index == 0 else Color("a8d9ff")
		_text(arena._seat_name(seat), Vector2(x, 32), 22, color)
		if not result.is_empty():
			var ms := int((result["picks"] as Dictionary).get(seat, -1))
			var mark := roundi(float(arena.setup_data["signal"]) * 1000.0)
			_text(DuelRules.reaction_text(ms, mark), Vector2(x, size.y - 14), 21, color)
	var title := "장전 중..." if elapsed < 1.30 else "실린더 회전!"
	var color := GOLD
	if not preparing:
		title = "· · ·"
		if cue == 1:
			title = "트림!"
			color = Color("c5b6a9")
		elif cue == 2:
			title = "뽑아라!"
			color = Color("ffce69")
	if not result.is_empty():
		title = "%s 승리!" % arena._seat_name(int(result["winner"]))
		if result["decided_by"] == &"foul": title = "부정출발!"
		elif result["decided_by"] == &"nobody": title = "시간 초과!"
	_text(title, Vector2(size.x / 2, 92), 32 if result.is_empty() else 28, color)
