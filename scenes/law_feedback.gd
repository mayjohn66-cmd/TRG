## 특수 승리 법전 시각 피드백 (1.01): 글을 읽지 않아도 "차오른다 → 한 걸음 남았다 → 그래서 끝났다"를 보이게 한다.
## - 보드 위(이 노드의 _draw, MainBoard 좌표): 하극상 [1위 타겟] 과녁, 식권 빵집 황금 테두리, 포위망 후보 칸 점멸·완성 레이저, 카이지 불꽃 궤적
## - 화면 위(screen 레이어): 기록이 오른 자리에서 법전 슬롯으로 날아가 꽂히는 황금 구슬 + 머리 위 카운트 배너, 초전도체 콤보 배너, 리치 사이렌 배너
## 시뮬레이션·RNG는 건드리지 않고 GameState를 읽기만 한다.
class_name LawFeedback
extends Node2D

const ICON_ROOT: String = "res://assets/fx/law_fx/%s.png"
const GOLD: Color = Color("ffd43b")
const TARGET_RED: Color = Color("ff3b3b")
## 기록 키 -> [아이콘, 배너 문구(%d 현재, %d 목표), 법전 ID]
const GAIN_STYLE: Dictionary = {
	&"kills": ["sword", "투기장 처치 +1! (%d/%d)", "LAW_01"],
	&"bakery": ["croissant", "식권 스탬프 획득! (%d/%d)", "LAW_02"],
	&"ejected": ["anger", "동네북 분노 충전! (%d/%d)", "LAW_06"],
	&"underdog": ["horse", "하극상 처치 +1! (%d/%d)", "LAW_08"],
}
const ORB_SECONDS: float = 0.62
const POPUP_SECONDS: float = 1.7
const FLAME_SECONDS: float = 1.3
## 비상 배너의 y (위쪽 메뉴 줄 바로 아래: 언어·배속·메뉴 버튼을 가리지 않게).
const SIREN_TOP: float = 52.0

var board: MainBoard = null
## 화면 좌표로 그리는 레이어 (구슬·배너). MainBoard가 만들어 넘긴다.
var screen: CanvasLayer = null
var _clock: float = 0.0
var _bakery_tiles: Array[int] = []
var _flames: Array[Dictionary] = []
## 이미 알린 리치 (법전ID:플레이어:값) — 같은 상태로 사이렌을 다시 울리지 않는다.
var _reach_seen: Dictionary = {}


func setup(main_board: MainBoard, screen_layer: CanvasLayer) -> void:
	board = main_board
	screen = screen_layer
	name = "LawFeedback"  # 말 레이어 바로 다음 자식이라 말 위·UI 창 아래에 그린다 (z_index를 올리면 드래프트 창 위로 뚫고 나온다)


func _process(delta: float) -> void:
	_clock += delta
	if not _flames.is_empty():
		_flames = _flames.filter(func(flame: Dictionary) -> bool: return _clock - float(flame["born"]) < FLAME_SECONDS)
	queue_redraw()


static func icon(icon_name: String) -> Texture2D:
	return TextureCache.fetch(ICON_ROOT % icon_name)


func _state() -> GameState:
	return board.state if board != null else null


func _tile_radius() -> float:
	return maxf(board._tile_center(1).distance_to(board._tile_center(2)) * 0.48, 14.0)


## MainBoard 좌표 → 화면(캔버스) 좌표.
func to_screen(point: Vector2) -> Vector2:
	return board.get_global_transform_with_canvas() * point


# ---------------------------------------------------------------------------
# 보드 위 상시 마커
# ---------------------------------------------------------------------------

func _draw() -> void:
	var state: GameState = _state()
	if state == null or board.manager == null or board.manager.is_game_over:
		return
	var radius: float = _tile_radius()
	var pulse: float = 0.5 + 0.5 * sin(_clock * TAU * 1.1)
	if state.rulebook.has_law("LAW_02"):
		_draw_bakery_goals(state, radius, pulse)
	if state.rulebook.has_law("LAW_05"):
		_draw_siege(state, radius, pulse)
	if state.rulebook.has_law("LAW_08"):
		_draw_leader_targets(state, radius, pulse)
	_draw_flames(radius)


## 봉인된 에르핀의 식권: 빵집 칸에 황금 테두리 + 크루아상 배지.
func _draw_bakery_goals(state: GameState, radius: float, pulse: float) -> void:
	if _bakery_tiles.is_empty():
		for index: int in BoardSpec.tile_count:
			if state.board.get_tile(index).tile_type == TileNode.TileType.BAKERY:
				_bakery_tiles.append(index)
	var croissant: Texture2D = icon("croissant")
	for index: int in _bakery_tiles:
		var center: Vector2 = board._tile_center(index)
		draw_arc(center, radius * (1.05 + 0.08 * pulse), 0.0, TAU, 40, Color(GOLD, 0.55 + 0.4 * pulse), 4.0, true)
		draw_arc(center, radius * (1.25 + 0.1 * pulse), 0.0, TAU, 40, Color(GOLD, 0.25 * (1.0 - pulse)), 2.0, true)
		if croissant != null:
			var side: float = radius * 0.95
			draw_texture_rect(croissant, Rect2(center + Vector2(radius * 0.35, -radius * 1.35), Vector2(side, side)), false)
		_draw_tag(center + Vector2(0, radius * 1.75), "[식권 목표]", GOLD)


## 다크호스의 하극상: 지금 1위인 사람의 보드 위 말 머리 위에 붉은 과녁.
func _draw_leader_targets(state: GameState, radius: float, pulse: float) -> void:
	var leader: int = state.race_leader(-1)
	if leader == -1:
		return
	var target: Texture2D = icon("target")
	for pawn: PlayerPawn in state.pawns_of(leader):
		if pawn.is_finished or not pawn.has_left_start or pawn.carrier != null:
			continue
		var view: Node2D = board._pawn_views.get(pawn.entity_id)
		if view == null or not view.visible:
			continue
		var head: Vector2 = view.position + Vector2(0, -radius * 1.55)
		draw_arc(view.position, radius * (0.9 + 0.12 * pulse), 0.0, TAU, 36, Color(TARGET_RED, 0.75), 3.0, true)
		for k: int in 4:
			var dir: Vector2 = Vector2.from_angle(TAU * float(k) / 4.0 + _clock * 0.8)
			draw_line(view.position + dir * radius * 0.7, view.position + dir * radius * 1.15, Color(TARGET_RED, 0.9), 3.0, true)
		if target != null:
			var side: float = radius * (1.0 + 0.12 * pulse)
			draw_texture_rect(target, Rect2(head - Vector2(side, side) * 0.5, Vector2(side, side)), false)
		_draw_tag(head + Vector2(0, -radius * 0.75), "[1위 타겟]", TARGET_RED)


## 사도 포위망 후보 칸: 한 칸만 더 벌리면 완성되는 사람(지금 화면의 나)이 갈 수 있는 칸을 점멸한다.
static func siege_candidate_tiles(state: GameState, player_id: int) -> Array[int]:
	var law_goal: int = SpecialVictory.goal_of(state, "LAW_05")
	var counted: Array[int] = VictoryLaw.spread_pawn_ids(state, player_id)
	if counted.size() != law_goal - 1 or state.is_graduated(player_id):
		return []
	var taken: Array[int] = []
	for pawn_id: int in counted:
		taken.append(state.get_pawn(pawn_id).current_tile_idx)
	var result: Array[int] = []
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.is_finished or counted.has(pawn.entity_id) or pawn.carrier != null:
			continue
		var from: int = pawn.current_tile_idx if pawn.has_left_start else 0
		for step: int in range(1, 7):
			var tile: int = (from + step) % BoardSpec.tile_count
			if tile == GameEnums.GOAL_TILE or result.has(tile):
				continue
			if taken.all(func(other: int) -> bool: return absi(other - tile) >= VictoryLaw.SPREAD_GAP):
				result.append(tile)
	return result


func _draw_siege(state: GameState, radius: float, pulse: float) -> void:
	var viewer: int = board._law_view_player()
	if viewer != -1:
		var blink: float = 0.5 + 0.5 * sin(_clock * TAU * 2.2)
		for tile: int in siege_candidate_tiles(state, viewer):
			var center: Vector2 = board._tile_center(tile)
			draw_circle(center, radius * 1.05, Color(Color("9c36b5"), 0.35 + 0.4 * blink))
			draw_arc(center, radius * 1.05, 0.0, TAU, 32, Color(Color("f3d9fa"), 0.6 + 0.4 * blink), 4.0, true)
			draw_arc(center, radius * (1.3 + 0.2 * blink), 0.0, TAU, 32, Color(Color("e599f7"), 0.5 * (1.0 - blink)), 2.0, true)
	# 완성된 포위망(경보 중이거나 조건을 채운 사람): 세어지는 말을 레이저로 잇는다
	var goal: int = SpecialVictory.goal_of(state, "LAW_05")
	for player_id: int in state.player_ids:
		if state.is_graduated(player_id):
			continue
		var counted: Array[int] = VictoryLaw.spread_pawn_ids(state, player_id)
		if counted.size() < goal and not state.siege_armed.has(player_id):
			continue
		var points: PackedVector2Array = PackedVector2Array()
		for pawn_id: int in counted:
			var view: Node2D = board._pawn_views.get(pawn_id)
			if view != null:
				points.append(view.position)
		if points.size() < 2:
			continue
		points.append(points[0])
		var color: Color = MainBoard.PLAYER_COLORS.get(player_id, Color.WHITE)
		draw_polyline(points, Color(color.lightened(0.2), 0.35 + 0.3 * pulse), 12.0, true)
		draw_polyline(points, Color(Color.WHITE, 0.85), 3.0, true)
		# 레이저를 따라 흐르는 빛 알갱이
		for i: int in points.size() - 1:
			var along: float = fposmod(_clock * 1.4 + float(i) * 0.33, 1.0)
			draw_circle(points[i].lerp(points[i + 1], along), 5.0, Color(1, 1, 1, 0.9))
		for point: Vector2 in points:
			draw_arc(point, radius * (0.8 + 0.15 * pulse), 0.0, TAU, 28, Color(color.lightened(0.3), 0.9), 3.0, true)


## 보드 위 작은 글자 꼬리표 (테두리 글씨, 지금 언어로).
func _draw_tag(center: Vector2, text: String, color: Color) -> void:
	var font: Font = board.get_theme_default_font()
	if font == null:
		return
	var shown: String = L10n.t(text)
	var size: int = 15
	var width: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(center.x - width * 0.5, center.y)
	draw_string_outline(font, at, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.05, 0.02, 0.0, 0.9))
	draw_string(font, at, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color.lightened(0.2))


func _draw_flames(radius: float) -> void:
	for flame: Dictionary in _flames:
		var age: float = (_clock - float(flame["born"])) / FLAME_SECONDS
		var center: Vector2 = flame["pos"]
		var fade: float = 1.0 - age
		var rise: Vector2 = Vector2(0, -radius * 0.6 * age)
		draw_circle(center + rise, radius * 0.55 * fade, Color(Color("ff6b00"), 0.55 * fade))
		draw_circle(center + rise * 1.3, radius * 0.32 * fade, Color(Color("ffd43b"), 0.8 * fade))


# ---------------------------------------------------------------------------
# 기록이 오른 순간: 황금 구슬 + 머리 위 카운트 배너
# ---------------------------------------------------------------------------

## 기록 키의 법전이 오른 순간을 보여 준다. tile = 일이 일어난 칸 (-1이면 그 사람의 가장 앞선 말 자리).
## 띄운 머리 위 배너를 돌려준다 (기록 키가 연출 대상이 아니면 null).
func show_gain(player_id: int, key: StringName, value: int, tile: int) -> Control:
	var style: Array = GAIN_STYLE.get(key, [])
	if style.is_empty() or screen == null:
		return null
	var state: GameState = _state()
	var goal: int = SpecialVictory.goal_of(state, String(style[2]))
	var from: Vector2 = _cause_point(player_id, tile)
	var color: Color = MainBoard.PLAYER_COLORS.get(player_id, GOLD)
	var banner: Control = popup(from, String(style[0]), String(style[1]) % [mini(value, goal), goal], color)
	fly_orb(from, String(style[2]))
	return banner


func _cause_point(player_id: int, tile: int) -> Vector2:
	if tile >= 0:
		return board._tile_center(tile)
	var state: GameState = _state()
	var best: PlayerPawn = null
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.has_left_start and not pawn.is_finished and (best == null or state.pawn_progress_distance(pawn) < state.pawn_progress_distance(best)):
			best = pawn
	return board._tile_center(best.current_tile_idx if best != null else 0)


## 머리 위 플로팅 배너: 아이콘 + 문구가 톡 튀어 올랐다가 떠오르며 사라진다.
func popup(board_point: Vector2, icon_name: String, text: String, color: Color, font_px: int = 18) -> Control:
	var banner := _make_banner(icon_name, text, color, font_px)
	screen.add_child(banner)
	banner.reset_size()
	var anchor: Vector2 = to_screen(board_point) + Vector2(-banner.size.x * 0.5, -banner.size.y - _tile_radius() * 1.4)
	var view: Vector2 = get_viewport_rect().size
	anchor.x = clampf(anchor.x, 8.0, view.x - banner.size.x - 8.0)
	anchor.y = maxf(anchor.y, 8.0)
	banner.position = anchor
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2.ONE * 0.3
	var pace: float = board._motion_pace()
	var tween: Tween = banner.create_tween()
	tween.tween_property(banner, "scale", Vector2.ONE * 1.12, 0.16 * pace).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.1 * pace)
	tween.tween_interval(0.9 * pace)
	tween.tween_property(banner, "position:y", anchor.y - 26.0, 0.5 * pace)
	tween.parallel().tween_property(banner, "modulate:a", 0.0, 0.5 * pace)
	tween.tween_callback(banner.queue_free)
	return banner


func _make_banner(icon_name: String, text: String, color: Color, font_px: int) -> PanelContainer:
	var banner := PanelContainer.new()
	banner.name = "LawGainBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = MainBoard._style(Color(0.08, 0.06, 0.02, 0.9), color.lightened(0.25), 3, 12, 6, 8)
	box.content_margin_left = 10
	box.content_margin_right = 14
	banner.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(row)
	var picture := TextureRect.new()
	picture.texture = icon(icon_name)
	picture.custom_minimum_size = Vector2(font_px + 12, font_px + 12)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var label: Label = MainBoard._make_label(text, font_px, Color("fff3bf"))
	label.name = "LawGainText"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color("2b1d00"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return banner


## 황금 구슬: 일이 일어난 자리에서 그 법전의 슬롯으로 휘어 날아가 꽂히고, 슬롯이 번쩍인다.
func fly_orb(board_point: Vector2, law_id: String) -> void:
	var slot: Control = board.law_slot_for(law_id)
	if slot == null:
		return
	var from: Vector2 = to_screen(board_point)
	var to: Vector2 = slot.get_global_rect().get_center()
	var orb := LawOrb.new()
	screen.add_child(orb)
	orb.position = from
	var bend: Vector2 = (from + to) * 0.5 + Vector2(0, -minf(from.distance_to(to) * 0.35, 220.0))
	var pace: float = board._motion_pace()
	var tween: Tween = orb.create_tween()
	tween.tween_method(func(t: float) -> void:
		orb.position = from.lerp(bend, t).lerp(bend.lerp(to, t), t)
		orb.trail_push(), 0.0, 1.0, ORB_SECONDS * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_flash_slot(slot)
		orb.queue_free())


func _flash_slot(slot: Control) -> void:
	if not is_instance_valid(slot):
		return
	slot.pivot_offset = slot.size * 0.5
	var pace: float = board._motion_pace()
	var tween: Tween = slot.create_tween()
	tween.tween_property(slot, "scale", Vector2.ONE * 1.08, 0.08 * pace)
	tween.parallel().tween_property(slot, "modulate", Color(1.6, 1.4, 0.7), 0.08 * pace)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.2 * pace)
	tween.parallel().tween_property(slot, "modulate", Color.WHITE, 0.25 * pace)


## 초전도체 무한 동력: 화면 가운데 콤보 배너.
func show_chain(player_id: int, chain: int, goal: int) -> void:
	if screen == null:
		return
	var color: Color = MainBoard.PLAYER_COLORS.get(player_id, GOLD)
	var banner := _make_banner("bolt", "초전도체 %d연속 가속 중!" % chain, Color("74c0fc") if chain < goal else GOLD, 30)
	banner.name = "LawChainBanner"
	screen.add_child(banner)
	banner.reset_size()
	var view: Vector2 = get_viewport_rect().size
	banner.position = Vector2((view.x - banner.size.x) * 0.5, view.y * 0.24)
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2.ONE * 2.0
	banner.modulate = Color(color.lightened(0.5), 0.0)
	var pace: float = board._motion_pace()
	var tween: Tween = banner.create_tween()
	tween.tween_property(banner, "scale", Vector2.ONE, 0.18 * pace).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(banner, "modulate", Color.WHITE, 0.12 * pace)
	tween.tween_interval(0.85 * pace)
	tween.tween_property(banner, "modulate:a", 0.0, 0.3 * pace)
	tween.tween_callback(banner.queue_free)
	fly_orb(to_screen_inverse(Vector2(view.x * 0.5, view.y * 0.3)), "LAW_07")


## 화면 좌표 → MainBoard 좌표 (fly_orb가 보드 좌표를 받는다).
func to_screen_inverse(point: Vector2) -> Vector2:
	return board.get_global_transform_with_canvas().affine_inverse() * point


## 카이지의 한방 역전법: 지나온 칸마다 불꽃을 남기고 도착한 말 위에 폭주 미터.
func show_kaiji(player_id: int, steps: int, goal: int, path: Array) -> void:
	for index: int in path.size():
		_flames.append({"pos": board._tile_center(int(path[index])), "born": _clock + float(index) * 0.035})
	var land: Vector2 = board._tile_center(int(path.back())) if not path.is_empty() else Vector2.ZERO
	var color: Color = GOLD if steps >= goal else MainBoard.PLAYER_COLORS.get(player_id, GOLD)
	popup(land, "rocket", "한 턴 %d칸 폭주! (목표: %d칸)" % [steps, goal], color, 20)
	fly_orb(land, "LAW_04")


# ---------------------------------------------------------------------------
# 리치 사이렌
# ---------------------------------------------------------------------------

## 지금 한 걸음 남은 [법전ID, 플레이어] 목록 (새로 생긴 것만 돌려준다: 같은 값으로 다시 울리지 않는다).
func new_reaches() -> Array[Array]:
	var state: GameState = _state()
	var fresh: Array[Array] = []
	var alive: Dictionary = {}
	for law: LawResource in state.rulebook.active_laws_queue:
		if not law is VictoryLaw:
			continue
		for player_id: int in state.player_ids:
			if SpecialVictory.is_reach(state, law as VictoryLaw, player_id):
				var key: String = "%s:%d:%d" % [law.law_id, player_id, (law as VictoryLaw).progress(state, player_id)]
				alive[key] = true
				if not _reach_seen.has(key):
					fresh.append([law, player_id])
	_reach_seen = alive
	return fresh


## 화면 위쪽 가운데 비상 배너 (막지 않는다). 사이렌 아이콘이 양쪽에서 번쩍인다.
func show_siren(text: String) -> Control:
	if screen == null:
		return null
	var banner := PanelContainer.new()
	banner.name = "LawSirenBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = MainBoard._style(Color(0.45, 0.02, 0.02, 0.93), GOLD, 3, 12, 8, 10)
	banner.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(row)
	var sirens: Array[TextureRect] = []
	for side: int in 2:
		var picture := TextureRect.new()
		picture.texture = icon("siren")
		picture.custom_minimum_size = Vector2(34, 34)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sirens.append(picture)
	row.add_child(sirens[0])
	var label: Label = MainBoard._make_label(text, 20, Color("fff3bf"))
	label.name = "LawSirenText"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color("3b0000"))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	row.add_child(sirens[1])
	screen.add_child(banner)
	banner.reset_size()
	var view: Vector2 = get_viewport_rect().size
	banner.position = Vector2((view.x - banner.size.x) * 0.5, -banner.size.y)
	var pace: float = board._motion_pace()
	var tween: Tween = banner.create_tween()
	tween.tween_property(banner, "position:y", SIREN_TOP, 0.22 * pace).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i: int in 6:
		tween.tween_property(box, "bg_color", Color(0.75, 0.05, 0.05, 0.95), 0.18 * pace)
		tween.tween_property(box, "bg_color", Color(0.35, 0.02, 0.02, 0.93), 0.18 * pace)
	tween.tween_property(banner, "modulate:a", 0.0, 0.35 * pace)
	tween.tween_callback(banner.queue_free)
	for picture: TextureRect in sirens:
		picture.pivot_offset = Vector2(17, 17)
		var spin: Tween = picture.create_tween().set_loops(8)
		spin.tween_property(picture, "modulate", Color(1.6, 0.6, 0.6), 0.15 * pace)
		spin.tween_property(picture, "modulate", Color.WHITE, 0.15 * pace)
	return banner


## 황금 구슬 (꼬리가 따라오는 빛).
class LawOrb:
	extends Node2D
	var _trail: Array[Vector2] = []

	func trail_push() -> void:
		_trail.append(position)
		if _trail.size() > 10:
			_trail.pop_front()
		queue_redraw()

	func _draw() -> void:
		for i: int in _trail.size():
			var t: float = float(i + 1) / float(_trail.size())
			draw_circle(_trail[i] - position, 3.0 + 7.0 * t, Color(1.0, 0.82, 0.25, 0.35 * t))
		draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.85, 0.3, 0.35))
		draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.92, 0.55, 0.95))
		draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
