# File: res://scenes/duel_arena.gd
# Class: class_name DuelArena
# Role: ACT_09 운명의 데스매치 결투장 (DuelArenaModal). 보드 한가운데에 열려 카지노 릴 종목 추첨 -> 종목 안내 -> 6종 초고속 미니게임
#       (묵찌빠 단두대 / 할리갈리 디럭스 / 병뚜껑 절벽 컬링 / 석양의 무법자 / 엘리아스 E카드 / 스피키 룰렛) -> 승패 공개 -> 결과를 보여 주고 닫히며 queue_free된다.
#       승패는 엔진(TurnManager·DuelRules)이 정한다. 이 화면은 로컬 자리의 입력(손·카드·누른 시각·게이지 값·구멍)만 value_chosen으로 내보내고 엔진 이벤트를 큐로 받아 연출한다.
class_name DuelArena
extends PanelContainer

## 로컬 자리가 값을 정했다 (MainBoard가 duel_pick 행동으로 보낸다).
signal value_chosen(player_id: int, value: int)
signal closed
## Emitted only once the casino reel has visibly stopped.
signal game_selected(game_id: int)

const SIZE: Vector2 = Vector2(560.0, 360.0)
const SKIN: Color = Color("f8d9a8")
const SKIN_EDGE: Color = Color("8a5a2b")
const GOLD: Color = Color("ffd43b")
const RED: Color = Color("ff6b6b")
const GREEN: Color = Color("8ce99a")
## 가위바위보·E카드에서 한 자리가 고르는 시간(초).
const PICK_SECONDS: float = 3.0
## 핫시트 순발력 게임 단축키: 신청자 A / 수비자 L (혼자면 스페이스도 된다).
const KEY_CHALLENGER: Key = KEY_A
const KEY_DEFENDER: Key = KEY_L

var board: MainBoard = null
var challenger: int = -1
var defender: int = -1
var game: int = DuelRules.Game.RPS
var setup_data: Dictionary = {}
## 이 화면에서 직접 입력할 수 있는 좌석 (AI 대전은 내 자리, 핫시트는 두 자리, 온라인은 내 자리).
var local_seats: Array[int] = []
## 공개 연출이 재생 중이다 (봇·보드는 이 동안 기다린다).
var animating: bool = true

var _queue: Array[Dictionary] = []
var _running: bool = false
var _opened: bool = false
var _closing: bool = false
var _step: StringName = &"idle"
## 미니게임 시계(초): 순발력 게임의 카드·신호 시각과 누른 시각은 이 시계 기준이다.
var _clock: float = -1.0
var _submitted: Dictionary = {}
var _pick_seat: int = -1
var _timer_left: float = 0.0
var _timer_total: float = 1.0
var _opened_holes: Array[int] = []
var _turn: int = -1
var _shown_cards: int = 0
var _signal_shown: int = 0

var _title: Label = null
var _vs: Label = null
var _game_label: Label = null
var _message: Label = null
var _stage: Control = null
var _buttons: HBoxContainer = null
var _bar: ProgressBar = null
var _drawing: StageDrawing = null
var _game_slot: DuelGameSlot = null
var _rps_stage: DuelRpsStage = null
var _halli_stage: DuelHalliStage = null
var _curling_stage: DuelCurlingStage = null
var _quickdraw_stage: DuelQuickdrawStage = null
var _ecard_stage: DuelEcardStage = null
var _pumpkin_stage: DuelPumpkinStage = null
var _intro_panel: PanelContainer
var _intro_headline: Label
var _intro_how: Label
var _intro_warning: Label
var _intro_ready := false
var _intro_elapsed := 0.0
const INTRO_HEADLINES: Array[String] = [
	"상대의 손을 이겨라!", "합이 5개일 때 종을 쳐라!", "절벽 직전에서 멈춰라!",
	"신호가 뜨면 먼저 쏴라!", "한 장으로 승부를 뒤집어라!", "호박을 터뜨리면 패배!",
]
const INTRO_HOW: Array[String] = [
	"3초 안에 바위 · 가위 · 보 중 하나를 고르세요.",
	"두 카드의 그림을 더해 5개가 되는 순간,\n[데스벨 치기!]를 누르세요.",
	"내 병뚜껑을 누르고 뒤로 당긴 뒤 놓으세요.\n번갈아 한 번씩, 절벽 가까이에 멈추면 승리합니다.",
	"[뽑아라!] 신호가 뜨면 [발사!]를 누르세요.\n진짜 신호에 더 빨리 반응하면 승리합니다.",
	"양쪽은 특수 카드 1장과 시민 4장으로 시작합니다.\n한 장씩 내고, 시민끼리 만나면 버린 뒤 다시 고르세요.",
	"호박에 연결된 버튼 다섯 개를 번갈아 누르세요.\n딱 하나의 버튼이 호박을 터뜨립니다!",
]
const INTRO_WARNINGS: Array[String] = [
	"같은 손이면 무승부! 다시 골라 승부를 냅니다.",
	"합이 5개가 아닐 때 누르면 반칙패!",
	"상대 병뚜껑을 밀어낼 수 있어요! 끝선을 넘으면 추락!",
	"트림은 가짜 신호! 신호보다 먼저 쏘면 반칙패!",
	"여왕 > 시민 > 반란군 > 여왕 · 사용한 카드는 다시 쓸 수 없어요!",
	"호박을 터뜨린 사람이 패배! 누른 버튼은 다시 쓸 수 없어요.",
]
var _hole_buttons: Array[Button] = []


func setup(owner_board: MainBoard, challenger_id: int, defender_id: int, seats: Array[int], game_id: int = DuelRules.Game.RPS, game_setup: Dictionary = {}) -> void:
	board = owner_board
	challenger = challenger_id
	defender = defender_id
	local_seats = seats.duplicate()
	game = game_id
	setup_data = game_setup.duplicate(true)
	_turn = challenger
	name = "DuelArenaModal"
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = SIZE
	add_theme_stylebox_override("panel", board._style(Color(0.063, 0.086, 0.14, 0.97), GOLD, 5, 22, 26, 14))
	visible = false
	_build()


## 알림 카드가 끝난 뒤 결투장을 연다. 그때까지 도착한 이벤트는 큐에 쌓였다가 차례로 재생된다.
func open() -> void:
	if _opened:
		return
	_opened = true
	visible = true
	_place()
	if not get_viewport().size_changed.is_connected(_place):
		get_viewport().size_changed.connect(_place)
	var fitted_scale := scale
	modulate.a = 0.0
	scale = fitted_scale * 0.85
	pivot_offset = size / 2.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.tween_property(self, "scale", fitted_scale, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pump()
	await get_tree().process_frame
	if is_inside_tree() and not _closing:
		_place()


func push_event(kind: StringName, data: Dictionary) -> void:
	_queue.append({"kind": kind, "data": data})
	if _opened:
		_pump()


# ---------------------------------------------------------------------------
# 화면 구성
# ---------------------------------------------------------------------------

func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_title = board._make_label("일기토 데스매치", 24, GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color("3b2a00"))
	column.add_child(_title)
	_vs = board._make_label("%s  VS  %s" % [board._player_name(challenger), board._player_name(defender)], 16, Color("ced4da"))
	_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_vs)
	_game_label = board._make_label("종목 추첨 중...", 30, Color.WHITE)
	_game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_label.add_theme_constant_override("outline_size", 7)
	_game_label.add_theme_color_override("font_outline_color", Color("0b0e16"))
	column.add_child(_game_label)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(SIZE.x - 40.0, 150.0)
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_stage)
	_drawing = StageDrawing.new()
	_drawing.arena = self
	_drawing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_drawing)
	_rps_stage = DuelRpsStage.new()
	_rps_stage.arena = self
	_rps_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rps_stage.visible = false
	_stage.add_child(_rps_stage)
	_halli_stage = DuelHalliStage.new()
	_halli_stage.arena = self
	_halli_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_halli_stage.visible = false
	_stage.add_child(_halli_stage)
	_curling_stage = DuelCurlingStage.new()
	_curling_stage.arena = self
	_curling_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curling_stage.visible = false
	_curling_stage.shot_requested.connect(_curling_release)
	_stage.add_child(_curling_stage)
	_quickdraw_stage = DuelQuickdrawStage.new()
	_quickdraw_stage.arena = self
	_quickdraw_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quickdraw_stage.visible = false
	_stage.add_child(_quickdraw_stage)
	_ecard_stage = DuelEcardStage.new()
	_ecard_stage.arena = self
	_ecard_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ecard_stage.visible = false
	_stage.add_child(_ecard_stage)
	_pumpkin_stage = DuelPumpkinStage.new()
	_pumpkin_stage.arena = self
	_pumpkin_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pumpkin_stage.visible = false
	_stage.add_child(_pumpkin_stage)
	_game_slot = DuelGameSlot.new()
	_game_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_slot.visible = false
	_stage.add_child(_game_slot)
	_build_rule_intro()
	_message = board._make_label("", 18, Color.WHITE)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(SIZE.x - 40.0, 30.0)
	_message.add_theme_constant_override("outline_size", 5)
	_message.add_theme_color_override("font_outline_color", Color("0b0e16"))
	_message.visible = false
	column.add_child(_message)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(SIZE.x - 80.0, 10.0)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.visible = false
	_bar.add_theme_stylebox_override("background", board._style(Color("0b0e16"), Color("5c6b94"), 2, 8, 0, 0))
	_bar.add_theme_stylebox_override("fill", board._style(Color("fcc419"), Color("fff3bf"), 2, 6, 0, 0))
	column.add_child(_bar)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 10)
	column.add_child(_buttons)


func _build_rule_intro() -> void:
	_intro_panel = PanelContainer.new()
	_intro_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_panel.add_theme_stylebox_override("panel", board._style(Color("fff4dc"), Color("eac074"), 3, 18, 24, 18))
	_intro_panel.visible = false
	_stage.add_child(_intro_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_intro_panel.add_child(column)
	var heading := HBoxContainer.new()
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 8)
	column.add_child(heading)
	var icon := IntroIcon.new()
	icon.arena = self
	icon.custom_minimum_size = Vector2(80, 80)
	heading.add_child(icon)
	_intro_headline = board._make_label("", 30, Color("493951"))
	_intro_headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro_headline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(_intro_headline)
	_intro_how = board._make_label("", 24, Color("493951"))
	_intro_how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_intro_how)
	_intro_warning = board._make_label("", 20, Color("a84c4b"))
	_intro_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_intro_warning)
	for label: Label in [_intro_headline, _intro_how, _intro_warning]:
		label.add_theme_constant_override("outline_size", 0)


class IntroIcon extends Control:
	var arena: DuelArena
	func _draw() -> void:
		draw_set_transform(size / 2.0, 0.0, Vector2.ONE * 1.4)
		arena._game_slot._icon(arena.game, Vector2.ZERO, self)


func _place() -> void:
	reset_size()
	position = board._board_center() - size / 2.0
	pivot_offset = size / 2.0
	var available := get_viewport_rect().size - Vector2(32, 32)
	var fit := minf(1.0, minf(available.x / maxf(size.x, 1.0), available.y / maxf(size.y, 1.0)))
	scale = Vector2.ONE * maxf(0.1, fit)


func _say(text: String, color: Color = Color.WHITE) -> void:
	_message.text = text
	_message.visible = not text.is_empty() and _step not in [&"roulette", &"selected", &"rules"]
	_message.add_theme_color_override("font_color", color)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * board._pace()).timeout


func _clear_buttons() -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()


func _add_button(text: String, callback: Callable, color: Color = Color("3b4766"), width: float = 150.0) -> Button:
	var button: Button = board._make_button(text, callback, 20, color, 12)
	button.custom_minimum_size = Vector2(width, 54)
	_buttons.add_child(button)
	return button


func _start_timer(seconds: float) -> void:
	_timer_total = maxf(seconds, 0.1)
	_timer_left = seconds
	_bar.value = 1.0
	_bar.visible = true


func _stop_timer() -> void:
	_timer_left = 0.0
	_bar.visible = false


func _seat_name(seat: int) -> String:
	return board._player_name(seat)


func _submit(seat: int, value: int) -> void:
	if _submitted.has(seat) or _closing or _step != &"play":
		return
	_submitted[seat] = value
	value_chosen.emit(seat, value)


func _local_open_seats() -> Array[int]:
	var seats: Array[int] = []
	for seat: int in [challenger, defender]:
		if local_seats.has(seat) and not _submitted.has(seat):
			seats.append(seat)
	return seats


# ---------------------------------------------------------------------------
# 시계: 순발력 게임의 카드·신호·게이지
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _opened or _closing:
		return
	if _step == &"rules":
		# Reading time is real time, including at 2x/3x game speed.
		_intro_elapsed += delta / maxf(Engine.time_scale, 0.01)
		if _intro_elapsed >= DuelRules.INTRO_TIME - 0.55:
			_confirm_intro()
	if _timer_left > 0.0:
		_timer_left -= delta
		_bar.value = clampf(_timer_left / _timer_total, 0.0, 1.0)
		if _timer_left <= 0.0:
			_timer_left = 0.0
			_bar.visible = false
			_on_local_timeout()
	if _clock < 0.0:
		return
	_clock += delta
	match game:
		DuelRules.Game.HALLI:
			var cards: Array = setup_data.get("cards", [])
			var dealt: int = mini(int(floor(_clock / float(setup_data.get("interval", DuelRules.HALLI_INTERVAL)))) + 1, cards.size())
			if dealt != _shown_cards:
				_shown_cards = dealt
			_halli_stage.sync_clock()
			_expire_reaction()
		DuelRules.Game.QUICKDRAW:
			_quickdraw_stage.sync_clock(_clock)
			_expire_reaction()


## 순발력 게임: 정답 순간이 지나고 창이 닫히면 안 누른 로컬 자리는 -1(못 누름)을 보낸다.
func _expire_reaction() -> void:
	if _step != &"play" or _clock < DuelRules.reaction_deadline(game, setup_data):
		return
	for seat: int in _local_open_seats():
		_submit(seat, -1)
	_clear_buttons()
	_step = &"waiting"
	_say("시간 끝! 판정 중...", Color("ced4da"))


func _on_local_timeout() -> void:
	match game:
		DuelRules.Game.RPS:
			if _pick_seat != -1:
				_choose(randi() % 3)
		DuelRules.Game.ECARD:
			if _pick_seat != -1:
				_choose(1 if DuelRules.ecard_count(setup_data, _pick_seat == challenger, 1) > 0 else 0)
		DuelRules.Game.CURLING:
			if _pick_seat != -1:
				_curling_release(DuelRules.CURLING_MAX)
		DuelRules.Game.BARREL:
			if local_seats.has(_turn) and _step == &"play":
				var free: Array[int] = []
				for hole: int in DuelRules.BARREL_HOLES:
					if not _opened_holes.has(hole):
						free.append(hole)
				if not free.is_empty():
					_pick_hole(free[randi() % free.size()])


func _input(event: InputEvent) -> void:
	if game == DuelRules.Game.CURLING and _opened and not _closing and _step == &"play" and _pick_seat != -1:
		if _curling_stage.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if _closing or _step != &"play" or not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	if game == DuelRules.Game.BARREL:
		var hole := int((event as InputEventKey).keycode) - KEY_1
		if hole >= 0 and hole < 5:
			_pick_hole(hole)
			get_viewport().set_input_as_handled()
		return
	if game != DuelRules.Game.HALLI and game != DuelRules.Game.QUICKDRAW:
		return
	var key: Key = (event as InputEventKey).keycode
	var seat: int = -1
	if key == KEY_CHALLENGER and local_seats.has(challenger):
		seat = challenger
	elif key == KEY_DEFENDER and local_seats.has(defender):
		seat = defender
	elif key == KEY_SPACE and local_seats.size() == 1:
		seat = local_seats[0]
	if seat != -1:
		_press(seat)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# 이벤트 재생 큐
# ---------------------------------------------------------------------------

func _pump() -> void:
	if _running or _closing:
		return
	_running = true
	while not _queue.is_empty() and not _closing:
		var item: Dictionary = _queue.pop_front()
		await _play(item["kind"], item["data"])
		if not is_inside_tree():
			return
	_running = false


func _play(kind: StringName, data: Dictionary) -> void:
	match kind:
		&"duel_started":
			await _play_roulette()
			if is_inside_tree() and not _closing:
				await _begin_game()
		&"duel_pick_in":
			if game == DuelRules.Game.CURLING and data.has("value"):
				await _play_curling_shot(int(data["player_id"]), int(data["value"]))
			elif game == DuelRules.Game.RPS:
				_rps_stage.mark_ready(int(data["player_id"]))
			elif game == DuelRules.Game.ECARD:
				_ecard_stage.mark_ready(int(data["player_id"]))
			elif game == DuelRules.Game.BARREL and data.has("hole"):
				await _play_barrel_stab(data)
			elif game not in [DuelRules.Game.HALLI, DuelRules.Game.QUICKDRAW] and not local_seats.has(int(data["player_id"])):
				_say("%s 입력 완료!" % _seat_name(int(data["player_id"])), Color("ced4da"))
		&"duel_revealed":
			await _play_reveal(data)
		&"duel_resolved":
			await _play_resolved(data)


## Reel -> locked ticket -> separate large instructions -> live inputs.
## Reading can finish with the start button or a bounded real-time fallback;
## the engine deadline reserves the entire introduction for every peer.
func _play_roulette() -> void:
	_step = &"roulette"
	animating = true
	_clock = -1.0
	_stop_timer()
	_clear_buttons()
	_drawing.visible = false
	_stage.custom_minimum_size.y = 218.0
	_game_label.text = "대결 종목 추첨"
	_game_label.add_theme_color_override("font_color", GOLD)
	_say("", Color.WHITE)
	_game_slot.play(game)
	await get_tree().process_frame
	_place()
	await _game_slot.finished
	if not is_inside_tree() or _closing:
		return
	_step = &"selected"
	_game_label.text = "오늘의 대결!"
	_say("", GOLD)
	game_selected.emit(game)
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree() or _closing:
		return
	_step = &"rules"
	_game_slot.visible = false
	_game_label.text = DuelRules.game_name(game)
	_say("", Color.WHITE)
	_intro_headline.text = INTRO_HEADLINES[game]
	_intro_how.text = INTRO_HOW[game]
	_intro_warning.text = INTRO_WARNINGS[game]
	_intro_panel.visible = true
	custom_minimum_size.x = 700.0
	_stage.custom_minimum_size.y = 246.0
	_intro_elapsed = 0.0
	_intro_ready = false
	var start := _add_button("대결 시작" if not local_seats.is_empty() else "대결 보기", _confirm_intro, Color("b57c30"), 260.0)
	start.custom_minimum_size.y = 64.0
	start.add_theme_font_size_override("font_size", 25)
	await get_tree().process_frame
	_place()
	while not _intro_ready and is_inside_tree() and not _closing:
		await get_tree().process_frame
	if not is_inside_tree() or _closing:
		return
	_intro_panel.visible = false
	_clear_buttons()
	_drawing.visible = true
	custom_minimum_size = SIZE
	_stage.custom_minimum_size.y = 150.0
	animating = false
	await get_tree().process_frame
	_place()


func _confirm_intro() -> void:
	if _step != &"rules" or _closing or _intro_ready:
		return
	_intro_ready = true
	Sfx.play(&"ui_click")
	for child: Node in _buttons.get_children():
		(child as Button).disabled = true


func _begin_game() -> void:
	if game == DuelRules.Game.RPS:
		custom_minimum_size.x = 700.0
		_stage.custom_minimum_size.y = 250.0
		_drawing.visible = false
		_rps_stage.visible = true
		_rps_stage.reset_round()
		_place.call_deferred()
	elif game == DuelRules.Game.ECARD:
		custom_minimum_size.x = 820.0
		_stage.custom_minimum_size.y = 290.0
		_drawing.visible = false
		_ecard_stage.visible = true
		_ecard_stage.reset_round()
		_place.call_deferred()
	elif game == DuelRules.Game.HALLI:
		custom_minimum_size.x = 740.0
		_stage.custom_minimum_size.y = 300.0
		_drawing.visible = false
		_halli_stage.visible = true
		_place.call_deferred()
	elif game == DuelRules.Game.CURLING:
		custom_minimum_size.x = 860.0
		_stage.custom_minimum_size.y = 360.0
		_drawing.visible = false
		_curling_stage.visible = true
		_curling_stage.reset_table()
		_place.call_deferred()
	elif game == DuelRules.Game.BARREL:
		custom_minimum_size.x = 740.0
		_stage.custom_minimum_size.y = 380.0
		_drawing.visible = false
		_pumpkin_stage.visible = true
		_place.call_deferred()
	elif game == DuelRules.Game.QUICKDRAW:
		custom_minimum_size.x = 860.0
		_stage.custom_minimum_size.y = 330.0
		_drawing.visible = false
		_quickdraw_stage.visible = true
		_step = &"preparing"
		animating = true
		_clock = -1.0
		_stop_timer()
		_clear_buttons()
		_say("")
		_quickdraw_stage.prepare()
		_place.call_deferred()
		await _quickdraw_stage.prepared
		if not is_inside_tree() or _closing:
			return
		animating = false
	_step = &"play"
	_say("", Color.WHITE)
	match game:
		DuelRules.Game.RPS, DuelRules.Game.ECARD:
			_next_pick_seat()
		DuelRules.Game.CURLING:
			_begin_curling_pick()
		DuelRules.Game.HALLI, DuelRules.Game.QUICKDRAW:
			_begin_reaction()
		DuelRules.Game.BARREL:
			_begin_barrel()
	_drawing.queue_redraw()


## 한 자리씩 고르는 게임(가위바위보·E카드·컬링): 핫시트라면 다음 로컬 자리가 이어서 고른다.
func _next_pick_seat() -> void:
	_clear_buttons()
	_pick_seat = -1
	var open: Array[int] = _local_open_seats()
	if open.is_empty():
		_step = &"waiting"
		_say("" if game in [DuelRules.Game.RPS, DuelRules.Game.ECARD] else ("컴퓨터끼리 결투 중..." if local_seats.is_empty() else "상대를 기다리는 중..."), Color("ced4da"))
		return
	_pick_seat = open[0]
	_vs.text = "%s 차례" % _seat_name(_pick_seat)
	_say("", Color.WHITE)
	match game:
		DuelRules.Game.RPS:
			for hand: int in 3:
				_buttons.add_child(_rps_stage.make_choice(hand, _choose.bind(hand)))
			_start_timer(PICK_SECONDS)
		DuelRules.Game.ECARD:
			for value: int in DuelRules.ecard_choices(setup_data, _pick_seat == challenger):
				_buttons.add_child(_ecard_stage.make_choice(value, _pick_seat, _choose.bind(value)))
			_start_timer(PICK_SECONDS * 2.0)


func _choose(value: int) -> void:
	if _pick_seat == -1 or _step != &"play" or _submitted.has(_pick_seat):
		return
	var seat: int = _pick_seat
	if game == DuelRules.Game.ECARD:
		if not DuelRules.ecard_choices(setup_data, seat == challenger).has(value):
			return
		_pick_seat = -1
		_ecard_stage.mark_ready(seat)
		_clear_buttons()
	if game == DuelRules.Game.RPS:
		_pick_seat = -1
		_rps_stage.mark_ready(seat)
		_clear_buttons()
	_stop_timer()
	Sfx.play(&"ui_click")
	_submit(seat, value)
	_drawing.queue_redraw()
	await get_tree().create_timer(0.15).timeout
	if is_inside_tree() and _step == &"play":
		_next_pick_seat()


func _curling_stop() -> void:
	# Keyboard/button fallback uses the same aimed impulse as a pointer release.
	_curling_stage.fire()


func _begin_curling_pick() -> void:
	_step = &"play"
	_clock = 0.0
	_clear_buttons()
	_pick_seat = _turn if local_seats.has(_turn) and not _submitted.has(_turn) else -1
	_vs.text = "%s 차례" % _seat_name(_turn)
	_say("")
	_curling_stage.begin_aim(0 if _turn == challenger else 1, _pick_seat != -1)
	if _pick_seat != -1:
		_add_button("튕기기 [Space]", _curling_stop, Color("c92a2a"), 230.0)
		_start_timer(DuelRules.TIME_CURLING - 2.0)
		_bar.visible = false  # The countdown must not resemble the removed power gauge.
	animating = false
	_place.call_deferred()


func _curling_release(value: int) -> void:
	if _pick_seat == -1 or _step != &"play" or not local_seats.has(_pick_seat) or _submitted.has(_pick_seat):
		return
	var seat := _pick_seat
	_pick_seat = -1
	_stop_timer()
	_clear_buttons()
	_submit(seat, value)
	_step = &"waiting"


func _play_curling_shot(seat: int, value: int) -> void:
	animating = true
	_step = &"waiting"
	_pick_seat = -1
	_clock = -1.0
	_stop_timer()
	_clear_buttons()
	_say("")
	_vs.text = "%s 투구" % _seat_name(seat)
	_curling_stage.play_shot(0 if seat == challenger else 1, value)
	await _curling_stage.settled
	if not is_inside_tree() or _closing:
		return
	if seat == challenger:
		_turn = defender
		_begin_curling_pick()
	else:
		animating = false


## 순발력 게임(할리갈리·석양의 무법자): 시계를 0부터 돌리고 로컬 자리마다 누를 버튼을 연다.
func _begin_reaction() -> void:
	_clear_buttons()
	_clock = 0.0
	_shown_cards = 0
	_signal_shown = 0
	if game == DuelRules.Game.HALLI:
		_halli_stage.start()
	if game == DuelRules.Game.QUICKDRAW:
		_quickdraw_stage.start_reaction()
		_game_label.text = DuelRules.game_name(game)
		_game_label.add_theme_color_override("font_color", Color.WHITE)
	var label: String = "데스벨 치기!" if game == DuelRules.Game.HALLI else "발사!"
	var seats: Array[int] = _local_open_seats()
	for seat: int in seats:
		var key_hint: String = ""
		if seats.size() > 1:
			key_hint = " [%s]" % ("A" if seat == challenger else "L")
		if seats.size() == 1:
			key_hint = " [Space]"
		var button := _add_button(("%s%s" % [label, key_hint]) if seats.size() == 1 else "%s\n%s%s" % [_seat_name(seat), label, key_hint], _press.bind(seat), Color("c92a2a"), 240.0 if seats.size() == 1 else 230.0)
		if game in [DuelRules.Game.HALLI, DuelRules.Game.QUICKDRAW]:
			button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	if seats.is_empty():
		_say("컴퓨터끼리 결투 중..." if local_seats.is_empty() else "상대를 기다리는 중...", Color("ced4da"))
	else:
		_say("", Color.WHITE)


func _press(seat: int) -> void:
	if _step != &"play" or _submitted.has(seat) or _clock < 0.0 or not local_seats.has(seat):
		return
	var pressed_ms: int = int(round(_clock * 1000.0))
	if game == DuelRules.Game.HALLI:
		_halli_stage.strike(seat, pressed_ms)
	if game == DuelRules.Game.QUICKDRAW:
		_quickdraw_stage.fire(seat, pressed_ms)
	_submit(seat, pressed_ms)
	var mark_ms: int = int(round(DuelRules.reaction_mark(game, setup_data) * 1000.0))
	if game not in [DuelRules.Game.HALLI, DuelRules.Game.QUICKDRAW]:
		_say("%s: %s" % [_seat_name(seat), DuelRules.reaction_text(pressed_ms, mark_ms)], RED if pressed_ms < mark_ms else GREEN)
	for child: Node in _buttons.get_children():
		if (child as Button).text.contains(_seat_name(seat)) or local_seats.size() == 1:
			(child as Button).disabled = true


## 스피키 룰렛: 연결된 버튼 5개. 자기 차례인 로컬 자리만 누른다.
func _begin_barrel() -> void:
	_clear_buttons()
	_hole_buttons.assign(_pumpkin_stage.buttons)
	_refresh_barrel_turn()


func _refresh_barrel_turn() -> void:
	var mine: bool = local_seats.has(_turn)
	_pumpkin_stage.refresh(mine)
	_vs.text = "%s 차례" % _seat_name(_turn)
	_say("")
	if mine: _start_timer(DuelRules.TIME_BARREL_PICK * 0.75)
	else: _stop_timer()


func _pick_hole(hole: int) -> void:
	if _step != &"play" or not local_seats.has(_turn) or hole < 0 or hole >= 5 or _opened_holes.has(hole):
		return
	_step = &"waiting"
	_stop_timer()
	_pumpkin_stage.mark_pending(hole)
	value_chosen.emit(_turn, hole)


func _play_barrel_stab(data: Dictionary) -> void:
	var hole: int = int(data["hole"])
	var seat: int = int(data["player_id"])
	if _opened_holes.has(hole): return
	_opened_holes.append(hole)
	_step = &"waiting"
	animating = true
	_stop_timer()
	_pumpkin_stage.play_press(hole, bool(data["bomb"]))
	await _pumpkin_stage.finished
	if not is_inside_tree() or _closing: return
	if bool(data["bomb"]): return
	_turn = defender if seat == challenger else challenger
	_step = &"play"
	animating = false
	_refresh_barrel_turn()


# ---------------------------------------------------------------------------
# 공개와 결과
# ---------------------------------------------------------------------------

## 보드 연출(사출·전진)이 기다려야 하는가: 결투장이 열린 뒤 승패 공개가 끝날 때까지는 보드가 결과를 먼저 보여 주면 안 된다.
func holds_board() -> bool:
	if not _opened or _closing:
		return false
	return animating or _queue_has(&"duel_revealed")


func _queue_has(kind: StringName) -> bool:
	for item: Dictionary in _queue:
		if item["kind"] == kind:
			return true
	return false


func _play_reveal(data: Dictionary) -> void:
	if game == DuelRules.Game.BARREL:
		_step = &"reveal"
		animating = true
		_stop_timer()
		var loser: int = defender if int(data["winner"]) == challenger else challenger
		_pumpkin_stage.show_result(_seat_name(loser))
		await _wait(1.0)
		if is_inside_tree() and not _closing: animating = false
		return
	if game == DuelRules.Game.ECARD:
		await _play_ecard_reveal(data)
		return
	if game == DuelRules.Game.QUICKDRAW:
		await _play_quickdraw_reveal(data)
		return
	if game == DuelRules.Game.CURLING:
		animating = true
		_step = &"reveal"
		_clock = -1.0
		_clear_buttons()
		_stop_timer()
		_curling_stage.show_result(int(data["winner"]))
		_vs.text = "%s  VS  %s" % [_seat_name(challenger), _seat_name(defender)]
		_say("둘 다 추락! 신청자 판정승" if data["decided_by"] == &"both_fell" else "")
		Sfx.play(&"good", -5.0)
		await get_tree().create_timer(1.20).timeout
		if is_inside_tree() and not _closing:
			animating = false
		return
	if game == DuelRules.Game.RPS:
		await _play_rps_reveal(data)
		return
	if game == DuelRules.Game.HALLI:
		await _play_halli_reveal(data)
		return
	animating = true
	var picks: Dictionary = data["picks"]
	# 순발력 게임: 봇이 먼저 냈어도 화면의 카드·신호가 그 순간까지 다 나온 다음 공개한다.
	if game == DuelRules.Game.HALLI or game == DuelRules.Game.QUICKDRAW:
		var until: float = DuelRules.reaction_mark(game, setup_data) + 0.4
		for seat: int in [challenger, defender]:
			var pressed: int = int(picks.get(seat, -1))
			if pressed >= 0:
				until = minf(until, float(pressed) / 1000.0 + 0.2)
		if _clock < 0.0:
			_clock = 0.0
		while _clock >= 0.0 and _clock < until and is_inside_tree() and not _closing:
			await get_tree().process_frame
	_clock = -1.0
	_step = &"reveal"
	_stop_timer()
	_clear_buttons()
	_drawing.reveal = picks
	_drawing.queue_redraw()
	if not is_inside_tree():
		return
	var winner: int = int(data["winner"])
	board.screen_shake(7.0, 0.25)
	board._impact_ring(global_position + size / 2.0, GOLD, 60.0)
	Sfx.play(&"slam")
	var detail: String = str(data.get("detail", ""))
	if winner == -1:
		_say("무승부 %s! 재대결!" % detail, Color("ffe066"))
		await _wait(1.0)
		_submitted.clear()
		_drawing.reveal = {}
		_drawing.queue_redraw()
		animating = false
		if is_inside_tree() and not _closing:
			_step = &"play"
			_next_pick_seat()
		return
	var suffix: String = ""
	match data["decided_by"]:
		&"foul": suffix = " (상대 반칙!)"
		&"fall": suffix = " (상대 추락!)"
		&"both_fell": suffix = " (둘 다 추락, 신청자 판정승)"
		&"nobody": suffix = " (아무도 못 눌러 신청자 판정승)"
		&"upset": suffix = " 하극상!"
	_say("%s  →  %s 승리!%s" % [detail, _seat_name(winner), suffix], GOLD)
	_vs.text = "%s  VS  %s" % [board._player_name(challenger), board._player_name(defender)]
	await _wait(1.1)
	animating = false


func _play_rps_reveal(data: Dictionary) -> void:
	animating = true
	_step = &"reveal"
	_pick_seat = -1
	_stop_timer()
	_clear_buttons()
	_say("", Color.WHITE)
	_vs.text = "%s  VS  %s" % [_seat_name(challenger), _seat_name(defender)]
	_rps_stage.play_reveal(data["picks"], int(data["winner"]))
	await _rps_stage.finished
	if not is_inside_tree() or _closing:
		return
	if int(data["winner"]) == -1:
		_submitted.clear()
		_rps_stage.reset_round()
		_step = &"play"
		_next_pick_seat()
	animating = false


func _play_halli_reveal(data: Dictionary) -> void:
	animating = true
	var at := DuelRules.reaction_deadline(game, setup_data)
	for seat: int in [challenger, defender]:
		var pressed := int((data["picks"] as Dictionary).get(seat, -1))
		if pressed >= 0:
			at = minf(at, float(pressed) / 1000.0)
	# Early network/bot outcomes wait for the same card boundary humans see.
	# Timeout may already have stopped input, but its clock keeps advancing.
	while _clock >= 0.0 and _clock < at and is_inside_tree() and not _closing:
		await get_tree().process_frame
	if not is_inside_tree() or _closing:
		return
	_clock = -1.0
	_step = &"reveal"
	_stop_timer()
	_clear_buttons()
	_say("")
	_halli_stage.show_result(data, at)
	await get_tree().create_timer(1.35).timeout
	if is_inside_tree() and not _closing:
		animating = false


func _play_ecard_reveal(data: Dictionary) -> void:
	animating = true
	_step = &"reveal"
	_pick_seat = -1
	_stop_timer()
	_clear_buttons()
	_say("")
	_vs.text = "%s  VS  %s" % [_seat_name(challenger), _seat_name(defender)]
	_ecard_stage.play_reveal(data)
	await _ecard_stage.finished
	if not is_inside_tree() or _closing:
		return
	if int(data["winner"]) == -1:
		_submitted.clear()
		_ecard_stage.reset_round()
		_step = &"play"
		_next_pick_seat()
	animating = false


func _play_quickdraw_reveal(data: Dictionary) -> void:
	animating = true
	var deadline := DuelRules.reaction_deadline(game, setup_data)
	var at := 0.0
	var any_shot := false
	for value: int in (data["picks"] as Dictionary).values():
		if value >= 0:
			at = maxf(at, minf(float(value) / 1000.0, deadline))
			any_shot = true
	if not any_shot:
		at = deadline
	_quickdraw_stage.queue_picks(data["picks"])
	while _clock >= 0.0 and _clock < at and is_inside_tree() and not _closing:
		await get_tree().process_frame
	if not is_inside_tree() or _closing:
		return
	_clock = -1.0
	_step = &"reveal"
	_stop_timer()
	_clear_buttons()
	_say("")
	while not _quickdraw_stage.shots_finished() and is_inside_tree() and not _closing:
		await get_tree().process_frame
	if not is_inside_tree() or _closing:
		return
	_quickdraw_stage.show_result(data)
	await get_tree().create_timer(1.10).timeout
	if is_inside_tree() and not _closing:
		animating = false


func _play_resolved(data: Dictionary) -> void:
	var winner: int = int(data["winner"])
	var loser: int = int(data["loser"])
	_stop_timer()
	_step = &"result"
	var advance: int = int(data.get("advance", DuelRules.winner_advance()))
	if int(data["pawn_id"]) == -1:
		_say("날려 버릴 말이 없어 결투가 끝났습니다", Color("ced4da"))
	elif local_seats.has(winner) and not local_seats.has(loser):
		_say("결투 승리! 상대 선두 말 장외 사출, 내 말 +%d칸!" % advance, GREEN)
	elif local_seats.has(loser) and not local_seats.has(winner):
		_say("결투 패배! 내 선두 말이 출발선으로 날아갑니다!", RED)
	else:
		_say("%s 선두 말 장외 사출! %s +%d칸" % [_seat_name(loser), _seat_name(winner), advance], Color("ffe066"))
	await _wait(1.2)
	close_now()


## 결투장을 닫는다: 페이드아웃 뒤 closed를 알리고 곧바로 queue_free한다 (연출 노드가 남지 않게).
func close_now() -> void:
	if _closing:
		return
	_closing = true
	animating = false
	_clock = -1.0
	_game_slot.cancel()
	_rps_stage.cancel()
	_halli_stage.cancel()
	_curling_stage.cancel()
	_quickdraw_stage.cancel()
	_ecard_stage.cancel()
	_pumpkin_stage.cancel()
	_stop_timer()
	_clear_buttons()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.25)
	tween.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())


# ---------------------------------------------------------------------------
# 무대 그림: 종목마다 가운데 무대를 코드로 그린다 (이모지 글꼴에 기대지 않는다)
# ---------------------------------------------------------------------------

class StageDrawing extends Control:
	var arena: DuelArena = null
	## 공개된 값 {player_id: value}. 비어 있으면 아직 가려 둔다.
	var reveal: Dictionary = {}
	var popped: bool = false
	func _draw() -> void:
		if arena == null or arena._step == &"roulette" or arena._step == &"idle":
			return
		match arena.game:
			DuelRules.Game.QUICKDRAW: _draw_cowboys()

	func _seat_x(seat: int) -> float:
		return size.x * (0.25 if seat == arena.challenger else 0.75)

	func _name_at(seat: int, y: float) -> void:
		var font: Font = ThemeDB.fallback_font
		var text: String = arena._seat_name(seat)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2(_seat_x(seat) - width / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MainBoard.PLAYER_COLORS.get(seat, Color.WHITE))

	func _center_text(text: String, at: Vector2, font_size: int, color: Color) -> void:
		var font: Font = ThemeDB.fallback_font
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(at.x - width / 2.0, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	func _draw_cowboys() -> void:
		for seat: int in [arena.challenger, arena.defender]:
			var x: float = _seat_x(seat)
			var base := Vector2(x, size.y - 30.0)
			draw_line(base, base + Vector2(0, -60), Color("8a5a2b"), 10.0)
			draw_circle(base + Vector2(0, -74), 16.0, SKIN)
			draw_rect(Rect2(base + Vector2(-26, -98), Vector2(52, 10)), Color("5c3d2e"))
			draw_rect(Rect2(base + Vector2(-14, -116), Vector2(28, 20)), Color("5c3d2e"))
			if reveal.has(seat):
				var mark_ms: int = int(round(DuelRules.reaction_mark(arena.game, arena.setup_data) * 1000.0))
				var pressed: int = int(reveal[seat])
				var side: float = -1.0 if seat == arena.challenger else 1.0
				_center_text(DuelRules.reaction_text(pressed, mark_ms), base + Vector2(side * 78.0, -54.0), 18, Color("adb5bd") if pressed < 0 else (RED if pressed < mark_ms else GREEN))
			_name_at(seat, size.y - 4.0)
		draw_circle(Vector2(size.x / 2.0, 34.0), 22.0, Color("ff922b"))  # 석양
