# File: res://scenes/super_fx.gd
# Class: class_name SuperFX
# Role: 초증강 전용 보드 연출. 로그를 읽지 않아도 보드만 보고 "이 초증강 때문에 이렇게 됐구나"를 알 수 있게, 초증강마다 고유한 장면을 보여 준다.
#       엔진은 증강을 고르는 순간 이미 결과를 정했다. MainBoard가 그 사이 엔진이 낸 변화(움직인 말·지뢰 칸·빼앗긴 카드·묶인 말·질주 길)를
#       기록해 넘기면(play의 changes), 여기서 그 결과를 연출로 보여 준다. 말 그림은 연출이 끝날 때까지 제자리에 붙잡혀 있다.
#       외부 그림 없이 Line2D·Polygon2D·CPUParticles2D·Tween·modulate로만 그린다. 초증강 하나는 0.8~1.2초 안팎.
#       폭주 기관차(SUPER_11)는 RunawayTrainStage가 따로 보여 준다.
class_name SuperFX
extends RefCounted

const GOLD: Color = Color("ffd43b")
const RED: Color = Color("ff3b30")
const DEVIL_RED: Color = Color("c2255c")
const DEVIL_PURPLE: Color = Color("7b2cbf")
const NEON: Color = Color("3bc9db")
const NEON_HOT: Color = Color("f783ac")
const CHAIN: Color = Color("ff4d4d")
const BREAD: Color = Color("d9a05b")

var board: MainBoard
var _generation: int = 0


func _init(owner: MainBoard) -> void:
	board = owner


## 이 초증강이 연출을 갖고 있는가 (폭주 기관차는 기관차 무대가 맡는다).
static func handles(effect: StringName) -> bool:
	return effect in [SuperAugments.FLIP, SuperAugments.REDISTRIBUTE, SuperAugments.DEVIL, SuperAugments.MINEFIELD, SuperAugments.RAID,
		SuperAugments.GAMBLER, SuperAugments.CASTLING, SuperAugments.BAKERY, SuperAugments.SNIPER, SuperAugments.NITRO, SuperAugments.GUARANTEE]


## 초증강 하나의 연출을 재생하고 끝날 때까지 기다린다. changes: [{"kind": "teleport"|"start"|"finish"|"place"|"steal"|"bond"|"nitro"|"castle", ...}]
func play(effect: StringName, player_id: int, changes: Array) -> void:
	_generation = board._fx_generation
	_title(effect, player_id)
	match effect:
		SuperAugments.FLIP: await _flip(player_id, changes)
		SuperAugments.REDISTRIBUTE: await _redistribute(player_id, changes)
		SuperAugments.DEVIL: await _devil(player_id, changes)
		SuperAugments.MINEFIELD: await _minefield(player_id, changes)
		SuperAugments.RAID: await _raid(player_id, changes)
		SuperAugments.GAMBLER: await _gambler(player_id)
		SuperAugments.CASTLING: await _castling(changes)
		SuperAugments.BAKERY: await _bakery(player_id, changes)
		SuperAugments.SNIPER: await _sniper(player_id, changes)
		SuperAugments.NITRO: await _nitro(changes)
		SuperAugments.GUARANTEE: await _guarantee(changes)


# ---------------------------------------------------------------------------
# 1. 판 뒤집기: 스포트라이트 → 코인 토스 → 성공(황금 로켓으로 결승) / 실패(붉은 낙뢰 → 출발선으로)
# ---------------------------------------------------------------------------

func _flip(player_id: int, changes: Array) -> void:
	var finished: Dictionary = _first(changes, "finish")
	var sent: Dictionary = _first(changes, "start")
	var success: bool = not finished.is_empty()
	var pawn_id: int = int(finished.get("pawn", sent.get("pawn", -1)))
	var view: Node2D = _view(pawn_id)
	if view == null:
		return
	var at: Vector2 = view.position
	_spotlight(at, Color(1.0, 0.97, 0.75))
	Sfx.play(&"charge")
	await _wait(0.25)
	# 보드 한가운데에서 거대한 코인이 빙글빙글 돌며 튀어 오른다
	var center: Vector2 = _local(board._board_center())
	var coin := Node2D.new()
	coin.position = center
	coin.z_index = 40
	var rim := Polygon2D.new()
	rim.polygon = _circle(40.0, 32)
	rim.color = Color("b8860b")
	coin.add_child(rim)
	var face := Polygon2D.new()
	face.polygon = _circle(33.0, 32)
	face.color = GOLD
	coin.add_child(face)
	var mark: Label = _label("?", 38, Color("7a5200"))
	coin.add_child(mark)
	_center_label(mark)
	_layer().add_child(coin)
	Sfx.play(&"toy_click")
	var spin: Tween = coin.create_tween()
	spin.tween_method(func(t: float) -> void:
		coin.position = center + Vector2(0.0, -150.0 * sin(t * PI))
		coin.scale = Vector2(cos(t * TAU * 3.0), 1.0) * (1.0 + 0.35 * sin(t * PI)), 0.0, 1.0, 0.55)
	await _wait(0.55)
	if not _alive():
		coin.queue_free()
		return
	coin.scale = Vector2.ONE * 1.15
	face.color = GOLD if success else Color("ff8787")
	mark.text = "★" if success else "X"
	mark.add_theme_color_override("font_color", Color("7a5200") if success else Color("7d0a0a"))
	Sfx.play(&"good" if success else &"bad")
	_fade_out(coin, 0.25, 0.35)
	var pawn: PlayerPawn = board.state.get_pawn(pawn_id)
	if success:
		# 황금빛으로 터지며 결승선으로 로켓처럼 직행
		board._burst_shards(at, GOLD, 22)
		_ring(at, GOLD, 70.0, 5.0, 0.35)
		Sfx.play(&"rocket")
		var goal: Vector2 = board._pawn_position(pawn) if pawn != null else board._tile_center(GameEnums.GOAL_TILE)
		await _rocket(view, goal, 0.42, GOLD)
		_ring(goal, GOLD, 60.0, 5.0, 0.3)
		board._floating_badge(_screen(goal) + Vector2(0, -40), "완주!", GOLD, 34)
		await _wait(0.15)
	else:
		# 붉은 낙뢰가 내리꽂히고 출발선으로 튕겨 난다
		_bolt(at + Vector2(randf_range(-30, 30), -280.0), at, RED)
		_flash(at, Color(1.0, 0.85, 0.85), 60.0)
		view.modulate = Color(2.0, 0.6, 0.6)
		view.create_tween().tween_property(view, "modulate", Color.WHITE, 0.3)
		board.screen_shake(11.0, 0.25)
		Sfx.play(&"slam")
		await _wait(0.2)
		await _eject_now(pawn_id, player_id)


# ---------------------------------------------------------------------------
# 2. 공산주의 재분배: 붉은 사이렌 → '재분배' 도장 쾅 → 모든 말이 꼴찌 자리로 끌려감 → 손패가 가운데로 모였다 흩어짐(덱 연출)
# ---------------------------------------------------------------------------

func _redistribute(_player_id: int, changes: Array) -> void:
	var siren := Siren.new()
	siren.z_index = 70
	board.add_child(siren)
	siren.size = board.size
	var blink: Tween = siren.create_tween()
	for i: int in 2:
		blink.tween_property(siren, "modulate:a", 1.0, 0.09)
		blink.tween_property(siren, "modulate:a", 0.15, 0.13)
	blink.tween_property(siren, "modulate:a", 0.0, 0.15)
	blink.tween_callback(siren.queue_free)
	siren.modulate.a = 0.0
	Sfx.play(&"attack_alert")
	await _wait(0.18)
	_stamp("재분배", RED)
	await _wait(0.22)
	if not _alive():
		return
	# 모든 말이 동시에 꼴찌의 자리로 휙 끌려간다
	var moved: int = 0
	for change: Dictionary in changes:
		if change["kind"] != "teleport":
			continue
		var pawn: PlayerPawn = board.state.get_pawn(int(change["pawn"]))
		var view: Node2D = _view(int(change["pawn"]))
		if pawn == null or view == null:
			continue
		var target: Vector2 = board._pawn_position(pawn)
		_pull_line(view.position, target, RED)
		board._glide(view, target, board._depth_scale(0.0), {"dur": 0.42, "arc": 36.0, "pace_cap": 1.0, "land_tile": pawn.current_tile_idx})
		board._fx_hints.erase(pawn.entity_id)
		moved += 1
	if moved > 0:
		Sfx.play(&"warp")
	# 네 사람의 손패가 가운데로 빨려 들어간다 (다시 나눠 주는 건 덱에서 날아가는 카드가 보여 준다)
	var center: Vector2 = board._board_center()
	for player_id: int in board.state.active_players(board.state.player_ids):
		var from: Vector2 = board._profile_center(player_id)
		if not from.is_finite():
			continue
		for i: int in 2:
			_card_back_flight(from, center, 0.3, i * 0.06, true)
	await _wait(0.5)
	if _alive():
		_ring(_local(center), RED, 80.0, 6.0, 0.3)
		board.screen_shake(5.0, 0.15)
	await _wait(0.12)


# ---------------------------------------------------------------------------
# 3. 악마의 계약: 완주한 말이 검붉은 오라에 휩싸여 출발선으로 끌려 나옴 → 프로필·주사위 UI에 영구 불꽃 테두리
# ---------------------------------------------------------------------------

func _devil(player_id: int, changes: Array) -> void:
	var sent: Dictionary = _first(changes, "start")
	var pawn_id: int = int(sent.get("pawn", -1))
	var view: Node2D = _view(pawn_id)
	var goal: Vector2 = board._tile_center(GameEnums.GOAL_TILE) + Vector2(0.0, 38.0)
	_aura(goal, 0.6)
	Sfx.play(&"revenge_ignite")
	if view != null:
		board._kill_fx(view)
		view.visible = true
		view.position = goal
		view.modulate = Color(1.6, 0.35, 0.55)
		var drag: Tween = view.create_tween()
		drag.tween_property(view, "position", goal + Vector2(0.0, -40.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drag.tween_property(view, "position", board._tile_center(GameEnums.GOAL_TILE), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		drag.parallel().tween_property(view, "scale", Vector2.ONE * 0.35, 0.3)
		drag.parallel().tween_property(view, "modulate:a", 0.0, 0.3)
		drag.tween_callback(func() -> void:
			view.visible = false
			view.modulate = Color.WHITE
			view.scale = Vector2.ONE)
	await _wait(0.55)
	if not _alive():
		return
	# 계약 성립: 내 프로필과 주사위 UI에 게임이 끝날 때까지 꺼지지 않는 보라/붉은 불꽃 테두리
	board._refresh_super_marks()
	var at: Vector2 = board._profile_center(player_id)
	if at.is_finite():
		_ring(_local(at), DEVIL_RED, 90.0, 6.0, 0.4)
		board._burst_shards(_local(at), DEVIL_PURPLE, 18)
		board._floating_badge(at + Vector2(0, -50), "영구 가속 +%d" % SuperAugments.devil_bonus(), Color("f783ac"), 30)
	Sfx.play(&"skill_ult")
	await _wait(0.4)


# ---------------------------------------------------------------------------
# 4. 광란의 지뢰밭: 칸마다 붉은 경고 깜빡 → 위에서 지뢰가 다다닥 떨어져 꽂힘 → 쿵
# ---------------------------------------------------------------------------

func _minefield(_player_id: int, changes: Array) -> void:
	var tiles: Array[int] = []
	for change: Dictionary in changes:
		if change["kind"] == "place":
			tiles.append(int(change["tile"]))
	if tiles.is_empty():
		return
	var warnings: Array[Node2D] = []
	for tile: int in tiles:
		var mark := _warning_mark(board._tile_center(tile))
		warnings.append(mark)
	Sfx.play(&"attack_alert")
	await _wait(0.38)
	if not _alive():
		return
	var top: float = _local(Vector2(0.0, -40.0)).y
	for index: int in tiles.size():
		var tile: int = tiles[index]
		var target: Vector2 = board._tile_center(tile)
		var mine := _mine_icon()
		mine.position = Vector2(target.x, top)
		mine.z_index = 41
		_layer().add_child(mine)
		var fall: Tween = mine.create_tween()
		fall.tween_interval(index * 0.07)
		fall.tween_property(mine, "position", target, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_callback(_mine_landed.bind(target, warnings[index]))
		fall.tween_property(mine, "scale", Vector2(1.3, 0.75), 0.05)
		fall.tween_property(mine, "scale", Vector2.ONE, 0.08)
		fall.tween_property(mine, "modulate:a", 0.0, 0.25).set_delay(0.15)
		fall.tween_callback(mine.queue_free)
	await _wait(0.26 + tiles.size() * 0.07 + 0.12)
	if _alive():
		board.screen_shake(12.0, 0.28)
		Sfx.play(&"build_mine")
	await _wait(0.2)


func _mine_landed(at: Vector2, warning: Node2D) -> void:
	if is_instance_valid(warning):
		warning.queue_free()
	_ring(at, RED, 34.0, 4.0, 0.25)
	board._burst_shards(at, Color("495057"), 6)
	Sfx.play(&"thud")


# ---------------------------------------------------------------------------
# 5. 도적단 대습격: 상대 프로필마다 할퀴기 → 뜯겨 나온 카드가 내 손패로 (빼앗긴 카드 비행은 덱 연출이 각 프로필에서 출발한다)
# ---------------------------------------------------------------------------

func _raid(player_id: int, _changes: Array) -> void:
	var victims: Array[int] = []
	for other: int in board.state.active_players(board.state.player_ids):
		if other != player_id:
			victims.append(other)
	Sfx.play(&"attack_alert")
	for index: int in victims.size():
		var at: Vector2 = board._profile_center(victims[index])
		if not at.is_finite():
			continue
		_claw(at, index * 0.08)
		board.get_tree().create_timer(index * 0.08 + 0.12).timeout.connect(board._profile_nudge.bind(victims[index]))
	await _wait(0.45 + victims.size() * 0.08)


# ---------------------------------------------------------------------------
# 6. 주사위 도박사의 영혼: 프로필과 주사위 UI에 이글거리는 황금 화염 (굴릴 때 x배수 / 과열은 MainBoard가 주사위 위에 띄운다)
# ---------------------------------------------------------------------------

func _gambler(player_id: int) -> void:
	board._refresh_super_marks()
	var at: Vector2 = board._profile_center(player_id)
	Sfx.play(&"revenge_ignite")
	if at.is_finite():
		_flame_burst(_local(at), GOLD)
		board._floating_badge(at + Vector2(0, -50), "이동 x%d!" % SuperAugments.gambler_multiplier(), GOLD, 34)
	var tool: Vector2 = board._tool_board.get_global_rect().get_center() if board._tool_board != null and board._tool_board.is_visible_in_tree() else Vector2(INF, INF)
	if tool.is_finite():
		_flame_burst(_local(tool), GOLD)
	await _wait(0.8)


## 굴림이 배수로 커졌다: 주사위 위에 거대한 x배수! 임팩트.
func gambler_boost(at_screen: Vector2, multiplier: int) -> void:
	var at: Vector2 = _local(at_screen)
	_flame_burst(at, GOLD)
	_ring(at, GOLD, 90.0, 6.0, 0.35)
	var label: Label = _label("x%d!" % multiplier, 64, GOLD)
	label.add_theme_constant_override("outline_size", 14)
	label.add_theme_color_override("font_outline_color", Color("5c2b00"))
	label.z_index = 62
	_layer().add_child(label)
	_center_label(label)
	label.position += at + Vector2(0.0, -70.0)
	label.scale = Vector2.ONE * 2.2
	var pop: Tween = label.create_tween()
	pop.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_interval(0.5)
	pop.tween_property(label, "modulate:a", 0.0, 0.25)
	pop.tween_callback(label.queue_free)
	board.screen_shake(7.0, 0.2)
	Sfx.play(&"win")


## 과열: 주사위가 까맣게 그을리고 연기가 피어오른다.
func gambler_overheat(at_screen: Vector2, presenter: Control) -> void:
	var at: Vector2 = _local(at_screen)
	if presenter != null and presenter.visible:
		presenter.modulate = Color(0.28, 0.25, 0.25, presenter.modulate.a)
	for i: int in 9:
		var puff := Polygon2D.new()
		puff.polygon = _circle(10.0 + randf() * 6.0, 14)
		puff.color = Color(0.25, 0.25, 0.27, 0.75)
		puff.position = at + Vector2(randf_range(-28, 28), randf_range(-6, 10))
		puff.z_index = 42
		_layer().add_child(puff)
		var rise: Tween = puff.create_tween().set_parallel(true)
		rise.tween_property(puff, "position:y", puff.position.y - 70.0 - randf() * 40.0, 0.9).set_delay(i * 0.04)
		rise.tween_property(puff, "scale", Vector2.ONE * 2.4, 0.9).set_delay(i * 0.04)
		rise.tween_property(puff, "modulate:a", 0.0, 0.9).set_delay(i * 0.04)
		rise.chain().tween_callback(puff.queue_free)
	var label: Label = _label("과열!", 44, Color("ced4da"))
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color("212529"))
	label.z_index = 62
	_layer().add_child(label)
	_center_label(label)
	label.position += at + Vector2(0.0, -80.0)
	var drift: Tween = label.create_tween()
	drift.tween_property(label, "position:y", label.position.y - 30.0, 0.8)
	drift.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.55)
	drift.tween_callback(label.queue_free)
	Sfx.play(&"bad")


# ---------------------------------------------------------------------------
# 7. 강제 캐슬링 룰렛: 모든 말이 보드 가운데 공중으로 떠올라 원을 그리며 섞인 뒤 새 자리로 일제히 낙하
# ---------------------------------------------------------------------------

func _castling(changes: Array) -> void:
	var ids: Array[int] = []
	for change: Dictionary in changes:
		if change["kind"] == "castle":
			for key: String in ["a", "b"]:
				var pid: int = int(change[key])
				if not ids.has(pid):
					ids.append(pid)
	# 섞인 말과 같이 보드에 있는 말 전부 (선두 말 기준)
	for pawn: PlayerPawn in SuperAugments.board_leaders(board.state):
		if not ids.has(pawn.entity_id):
			ids.append(pawn.entity_id)
	var views: Array[Node2D] = []
	var pawns: Array[PlayerPawn] = []
	for pid: int in ids:
		var view: Node2D = _view(pid)
		var pawn: PlayerPawn = board.state.get_pawn(pid)
		if view == null or pawn == null or not view.visible:
			continue
		board._kill_fx(view)
		views.append(view)
		pawns.append(pawn)
	if views.size() < 2:
		return
	var center: Vector2 = _local(board._board_center()) + Vector2(0.0, -30.0)
	var radius: float = 70.0
	var starts: Array[Vector2] = []
	for view: Node2D in views:
		starts.append(view.position)
	Sfx.play(&"launch")
	var count: int = views.size()
	var rise: Callable = func(t: float) -> void:
		for index: int in count:
			if not is_instance_valid(views[index]):
				continue
			var slot: Vector2 = center + Vector2.from_angle(TAU * index / count) * radius
			views[index].position = starts[index].lerp(slot, t) + Vector2(0.0, -60.0 * sin(t * PI))
	var lift: Tween = board.create_tween()
	lift.tween_method(rise, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(0.3)
	if not _alive():
		return
	var ring := Line2D.new()
	ring.points = _circle(radius + 18.0, 40)
	ring.closed = true
	ring.width = 4.0
	ring.default_color = Color(GOLD, 0.7)
	ring.position = center
	ring.z_index = 15
	_layer().add_child(ring)
	Sfx.play(&"roulette_tick")
	var spin: Callable = func(t: float) -> void:
		for index: int in count:
			if is_instance_valid(views[index]):
				views[index].position = center + Vector2.from_angle(TAU * index / count + t * TAU * 2.0) * radius
		if is_instance_valid(ring):
			ring.rotation = -t * TAU
	var whirl: Tween = board.create_tween()
	whirl.tween_method(spin, 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(0.5)
	_fade_out(ring, 0.0, 0.2)
	if not _alive():
		return
	# 새 자리로 일제히 낙하
	var lands: Array[Vector2] = []
	var heads: Array[Vector2] = []
	for index: int in count:
		lands.append(board._pawn_position(pawns[index]))
		heads.append(views[index].position)
		board._fx_hints.erase(pawns[index].entity_id)
	var fall: Callable = func(t: float) -> void:
		for index: int in count:
			if is_instance_valid(views[index]):
				views[index].position = heads[index].lerp(lands[index], t) + Vector2(0.0, -40.0 * sin(t * PI))
	var drop: Tween = board.create_tween()
	drop.tween_method(fall, 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(0.32)
	if not _alive():
		return
	for land: Vector2 in lands:
		_ring(land, GOLD, 30.0, 3.0, 0.22)
	board.screen_shake(8.0, 0.2)
	Sfx.play(&"slam")
	await _wait(0.1)


# ---------------------------------------------------------------------------
# 8. 에르핀의 빵집 털이: 빵집이 노랗게 반짝 + 빵 파티클 → 대기 중이던 내 말이 높은 포물선으로 빵집에 착지 (카드는 덱에서 날아온다)
# ---------------------------------------------------------------------------

func _bakery(player_id: int, changes: Array) -> void:
	if BoardSpec.bakery_tiles.is_empty():
		return
	var tile: int = BoardSpec.bakery_tiles[0]
	var at: Vector2 = board._tile_center(tile)
	board._tile_glow(tile)
	_ring(at, GOLD, 50.0, 4.0, 0.35)
	_bread_burst(at)
	Sfx.play(&"good")
	await _wait(0.3)
	if not _alive():
		return
	var jumper: Dictionary = {}
	for change: Dictionary in changes:
		if change["kind"] == "teleport" and int(change.get("tile", -1)) == tile:
			jumper = change
	var pawn: PlayerPawn = board.state.get_pawn(int(jumper.get("pawn", -1)))
	var view: Node2D = _view(int(jumper.get("pawn", -1)))
	if pawn == null or view == null or pawn.owner_id != player_id:
		await _wait(0.3)
		return
	board._kill_fx(view)
	var from: Vector2 = board._tile_center(GameEnums.GOAL_TILE)
	var to: Vector2 = board._pawn_position(pawn)
	view.visible = true
	view.position = from
	board._fx_hints.erase(pawn.entity_id)
	Sfx.play(&"hop")
	var jump: Tween = view.create_tween()
	jump.tween_method(func(t: float) -> void:
		view.position = from.lerp(to, t) + Vector2(0.0, -170.0 * sin(t * PI))
		view.rotation = sin(t * PI) * 0.4, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(0.55)
	if not is_instance_valid(view):
		return
	view.rotation = 0.0
	_ring(to, GOLD, 40.0, 4.0, 0.25)
	_bread_burst(to)
	board.screen_shake(5.0, 0.15)
	Sfx.play(&"thud")
	await _wait(0.15)


# ---------------------------------------------------------------------------
# 9. 저격수의 표적: 붉은 조준경이 크게 떴다 0.4초 만에 줄어들며 록온 → 섬광·탄흔 → 출발선으로 회전하며 날아감
# ---------------------------------------------------------------------------

func _sniper(player_id: int, changes: Array) -> void:
	var target_id: int = -1
	for change: Dictionary in changes:
		if change["kind"] == "start":
			target_id = int(change["pawn"])
			break
	var view: Node2D = _view(target_id)
	if view == null:
		return
	var scope := _crosshair()
	scope.position = view.position
	scope.scale = Vector2.ONE * 3.2
	scope.modulate.a = 0.0
	_layer().add_child(scope)
	Sfx.play(&"charge")
	var lock: Tween = scope.create_tween().set_parallel(true)
	lock.tween_property(scope, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lock.tween_property(scope, "rotation", PI * 0.5, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lock.tween_property(scope, "modulate:a", 1.0, 0.12)
	await _wait(0.4)
	if not _alive():
		scope.queue_free()
		return
	# 록온: 조준경이 한 번 깜빡인 뒤 탕!
	var blink: Tween = scope.create_tween()
	blink.tween_property(scope, "modulate", Color(2.0, 2.0, 2.0), 0.05)
	blink.tween_property(scope, "modulate", Color.WHITE, 0.05)
	await _wait(0.1)
	Sfx.play(&"shot")
	var at: Vector2 = view.position
	_flash(at, Color.WHITE, 90.0)
	_bullet_hole(at)
	_ring(at, RED, 60.0, 5.0, 0.3)
	board.screen_shake(12.0, 0.22)
	_fade_out(scope, 0.05, 0.2)
	await _wait(0.12)
	await _eject_now(target_id, player_id)


# ---------------------------------------------------------------------------
# 10. 아우토반 니트로: 선두 말에서 다음 코너까지 네온 부스터 라인과 화살표가 쫙 깔린다 (이어서 잔상을 남기며 질주)
# ---------------------------------------------------------------------------

func _nitro(changes: Array) -> void:
	var dash: Dictionary = _first(changes, "nitro")
	var view: Node2D = _view(int(dash.get("pawn", -1)))
	var path: Array = dash.get("path", [])
	if view == null or path.is_empty():
		return
	var points := PackedVector2Array([view.position])
	for tile: Variant in path:
		points.append(board._tile_center(int(tile)))
	var glow := Line2D.new()
	glow.points = points
	glow.width = 26.0
	glow.default_color = Color(NEON, 0.45)
	glow.joint_mode = Line2D.LINE_JOINT_ROUND
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.z_index = 14
	var core := Line2D.new()
	core.points = points
	core.width = 9.0
	core.default_color = NEON.lightened(0.4)
	core.joint_mode = Line2D.LINE_JOINT_ROUND
	core.z_index = 14
	var gradient := Gradient.new()
	gradient.set_color(0, NEON_HOT)
	gradient.set_color(1, NEON)
	core.gradient = gradient
	_layer().add_child(glow)
	_layer().add_child(core)
	# 라인이 출발점에서 끝까지 쫙 깔린다
	var full: PackedVector2Array = points.duplicate()
	var lay: Callable = func(t: float) -> void:
		var shown: PackedVector2Array = _partial(full, t)
		if is_instance_valid(core):
			core.points = shown
		if is_instance_valid(glow):
			glow.points = shown
	var draw: Tween = board.create_tween()
	draw.tween_method(lay, 0.0, 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sfx.play(&"dash")
	await _wait(0.25)
	# 칸마다 화살표가 앞으로 점멸한다
	var arrows: Array[Node2D] = []
	for index: int in range(1, points.size()):
		var arrow := _chevron(points[index - 1].direction_to(points[index]))
		arrow.position = points[index]
		arrow.modulate.a = 0.0
		_layer().add_child(arrow)
		arrows.append(arrow)
		var flick: Tween = arrow.create_tween()
		flick.tween_interval(index * 0.03)
		for i: int in 2:
			flick.tween_property(arrow, "modulate:a", 1.0, 0.06)
			flick.tween_property(arrow, "modulate:a", 0.25, 0.08)
	await _wait(0.4)
	for node: Node2D in [glow, core]:
		_fade_out(node, 0.35, 0.3)
	for arrow: Node2D in arrows:
		_fade_out(arrow, 0.1, 0.2)


## 니트로 질주 중의 잔상: 말 모양 자리에 빛나는 원이 남았다 사라진다.
func ghost(view: Node2D, color: Color) -> void:
	if view == null or not is_instance_valid(view):
		return
	var shade := Polygon2D.new()
	shade.polygon = _circle(15.0, 16)
	shade.color = Color(color.lightened(0.25), 0.55)
	shade.position = view.position + Vector2(0.0, -14.0)
	shade.z_index = 2
	_layer().add_child(shade)
	var fade: Tween = shade.create_tween().set_parallel(true)
	fade.tween_property(shade, "modulate:a", 0.0, 0.3)
	fade.tween_property(shade, "scale", Vector2(1.4, 0.8), 0.3)
	fade.chain().tween_callback(shade.queue_free)


# ---------------------------------------------------------------------------
# 12. 강제 연대책임: 선두 말과 꼴찌 말 사이에 붉은 에너지 사슬이 철컥! 연결되어 팽팽해진다 (발밑 고리는 묶여 있는 내내 남는다)
# ---------------------------------------------------------------------------

func _guarantee(changes: Array) -> void:
	var bond: Dictionary = _first(changes, "bond")
	var a: Node2D = _view(int(bond.get("a", -1)))
	var b: Node2D = _view(int(bond.get("b", -1)))
	if a == null or b == null:
		return
	var from: Vector2 = a.position
	var to: Vector2 = b.position
	var chain := Line2D.new()
	chain.width = 6.0
	chain.default_color = CHAIN
	chain.z_index = 16
	chain.begin_cap_mode = Line2D.LINE_CAP_ROUND
	chain.end_cap_mode = Line2D.LINE_CAP_ROUND
	_layer().add_child(chain)
	var links: Array[Line2D] = []
	var count: int = clampi(int(from.distance_to(to) / 22.0), 4, 40)
	for i: int in count:
		var link := Line2D.new()
		link.points = _circle(5.0, 10)
		link.closed = true
		link.width = 2.5
		link.default_color = CHAIN.lightened(0.3)
		link.z_index = 17
		link.visible = false
		_layer().add_child(link)
		links.append(link)
	Sfx.play(&"charge")
	# 양쪽에서 사슬이 뻗어 가운데서 만난다 (느슨하게 처진 곡선)
	var reach: Tween = board.create_tween()
	reach.tween_method(func(t: float) -> void:
		_chain_shape(chain, links, from, to, t, 40.0), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(0.32)
	if not _alive():
		chain.queue_free()
		for link: Line2D in links:
			link.queue_free()
		return
	# 철컥! 팽팽하게 당겨진다
	Sfx.play(&"slam")
	board.screen_shake(6.0, 0.15)
	_flash((from + to) / 2.0, Color(1.0, 0.7, 0.7), 40.0)
	board._floating_badge(_screen((from + to) / 2.0) + Vector2(0, -30), "철컥!", CHAIN, 32)
	var taut: Tween = board.create_tween()
	taut.tween_method(func(sag: float) -> void:
		_chain_shape(chain, links, from, to, 1.0, sag), 40.0, 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for view: Node2D in [a, b]:
		_ring(view.position, CHAIN, 34.0, 4.0, 0.3)
	board._refresh_super_marks()
	await _wait(0.45)
	var hum: Tween = chain.create_tween()
	hum.tween_property(chain, "width", 9.0, 0.08)
	hum.tween_property(chain, "width", 6.0, 0.08)
	await _wait(0.2)
	_fade_out(chain, 0.0, 0.3)
	for link: Line2D in links:
		_fade_out(link, 0.0, 0.3)


func _chain_shape(chain: Line2D, links: Array[Line2D], from: Vector2, to: Vector2, reach: float, sag: float) -> void:
	if not is_instance_valid(chain):
		return
	var points := PackedVector2Array()
	var steps: int = 24
	for i: int in steps + 1:
		var u: float = float(i) / steps
		points.append(from.lerp(to, u) + Vector2(0.0, sag * sin(u * PI)))
	# 양 끝에서 reach만큼 자란다
	var half: int = int(ceil(steps * 0.5 * reach))
	var shown := PackedVector2Array()
	for i: int in points.size():
		if i <= half or i >= points.size() - 1 - half:
			shown.append(points[i])
	chain.points = shown if reach < 1.0 else points
	for index: int in links.size():
		var u: float = (index + 0.5) / links.size()
		var visible: bool = reach >= 1.0 or u <= reach * 0.5 or u >= 1.0 - reach * 0.5
		links[index].visible = visible
		links[index].position = from.lerp(to, u) + Vector2(0.0, sag * sin(u * PI))


# ---------------------------------------------------------------------------
# 지속 표시: 악마의 계약·도박사의 영혼 불꽃 테두리, 연대책임 발밑 고리
# ---------------------------------------------------------------------------

## 프로필·주사위 UI를 감싸는 불꽃 테두리 (끝나지 않는 표시).
class FlameBorder extends Control:
	var colors: Array[Color] = [Color("7b2cbf"), Color("c2255c")]
	var _time: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size).grow(5.0)
		for layer: int in 3:
			var flicker: float = 0.55 + 0.45 * sin(_time * (7.0 + layer * 3.0) + layer)
			var box := StyleBoxFlat.new()
			box.draw_center = false
			box.border_color = Color(colors[layer % colors.size()], 0.35 + 0.4 * flicker)
			box.set_border_width_all(3 + layer * 2)
			box.set_corner_radius_all(14 + layer * 2)
			draw_style_box(box, rect.grow(layer * 2.5))
		# 테두리를 따라 올라가는 불꽃 혀
		var tongues: int = 14
		for i: int in tongues:
			var u: float = fposmod(float(i) / tongues + _time * 0.12, 1.0)
			var base: Vector2 = _perimeter(rect, u)
			var height: float = 8.0 + 7.0 * (0.5 + 0.5 * sin(_time * 9.0 + i * 1.7))
			var tip: Vector2 = base + Vector2(0.0, -height)
			var color: Color = colors[i % colors.size()].lightened(0.2)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-4, 0), tip, base + Vector2(4, 0)]), Color(color, 0.85))

	func _perimeter(rect: Rect2, u: float) -> Vector2:
		var w: float = rect.size.x
		var h: float = rect.size.y
		var d: float = u * 2.0 * (w + h)
		if d < w:
			return rect.position + Vector2(d, 0.0)
		d -= w
		if d < h:
			return rect.position + Vector2(w, d)
		d -= h
		if d < w:
			return rect.position + Vector2(w - d, h)
		d -= w
		return rect.position + Vector2(0.0, h - d)


## host 위에 불꽃 테두리를 켜거나 끈다. colors가 비면 끈다.
static func set_flame(host: Control, flame_name: String, colors: Array[Color]) -> void:
	if host == null:
		return
	var flame: FlameBorder = host.get_node_or_null(flame_name) as FlameBorder
	if colors.is_empty():
		if flame != null:
			flame.queue_free()
		return
	if flame == null:
		flame = FlameBorder.new()
		flame.name = flame_name
		host.add_child(flame)
	flame.colors = colors


## 연대책임 발밑 고리: 묶인 말 아래 붉은 타원 고리가 숨 쉬듯 깜빡인다.
static func set_bond_ring(view: Node2D, bonded: bool) -> void:
	var ring: Line2D = view.get_node_or_null("BondRing") as Line2D
	if not bonded:
		if ring != null:
			ring.queue_free()
		return
	if ring != null:
		return
	ring = Line2D.new()
	ring.name = "BondRing"
	var points := PackedVector2Array()
	for i: int in 28:
		var angle: float = TAU * i / 28
		points.append(Vector2(cos(angle) * 17.0, sin(angle) * 7.0 + 4.0))
	ring.points = points
	ring.closed = true
	ring.width = 3.0
	ring.default_color = Color("ff4d4d")
	ring.z_index = -1
	view.add_child(ring)
	view.move_child(ring, 0)
	var pulse: Tween = ring.create_tween().set_loops()
	pulse.tween_property(ring, "modulate:a", 0.35, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(ring, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------------------
# 공용 조각
# ---------------------------------------------------------------------------

## 화면 위 큰 제목 (어떤 초증강인지): 보드 위쪽에 잠깐.
func _title(effect: StringName, player_id: int) -> void:
	var name: String = SuperAugments.display_name(effect)
	var at: Vector2 = board._board_center() + Vector2(0.0, -150.0)
	board._floating_badge(at, "%s %s" % [board._player_name(player_id), name], Color("e599f7"), 28)


## 스포트라이트: 화면을 살짝 어둡게 하고 대상만 밝은 원으로 비춘다.
func _spotlight(at: Vector2, color: Color) -> void:
	var light := Polygon2D.new()
	light.polygon = _circle(46.0, 32)
	light.color = Color(color, 0.45)
	light.position = at
	light.z_index = 1
	light.scale = Vector2.ONE * 2.2
	_layer().add_child(light)
	var beam: Tween = light.create_tween()
	beam.tween_property(light, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	beam.tween_interval(0.6)
	beam.tween_property(light, "modulate:a", 0.0, 0.3)
	beam.tween_callback(light.queue_free)
	_ring(at, color, 50.0, 4.0, 0.3)


## 커지며 사라지는 원 테두리.
func _ring(at: Vector2, color: Color, radius: float, width: float, duration: float) -> void:
	var ring := Line2D.new()
	ring.points = _circle(1.0, 32)
	ring.closed = true
	ring.width = width / 8.0
	ring.default_color = color
	ring.position = at
	ring.scale = Vector2.ONE * 8.0
	ring.z_index = 30
	_layer().add_child(ring)
	var grow: Tween = ring.create_tween().set_parallel(true)
	grow.tween_property(ring, "scale", Vector2.ONE * radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.tween_property(ring, "width", width / radius, duration)
	grow.tween_property(ring, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	grow.chain().tween_callback(ring.queue_free)


## 순간 섬광 (채운 원이 번쩍 커지며 사라진다).
func _flash(at: Vector2, color: Color, radius: float) -> void:
	var burst := Polygon2D.new()
	burst.polygon = _circle(radius, 28)
	burst.color = color
	burst.position = at
	burst.scale = Vector2.ONE * 0.3
	burst.z_index = 31
	_layer().add_child(burst)
	var pop: Tween = burst.create_tween().set_parallel(true)
	pop.tween_property(burst, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(burst, "modulate:a", 0.0, 0.22)
	pop.chain().tween_callback(burst.queue_free)


## 지그재그 번개.
func _bolt(from: Vector2, to: Vector2, color: Color) -> void:
	var points := PackedVector2Array([from])
	var segments: int = 7
	var side: Vector2 = from.direction_to(to).orthogonal()
	for i: int in range(1, segments):
		var u: float = float(i) / segments
		points.append(from.lerp(to, u) + side * randf_range(-22.0, 22.0))
	points.append(to)
	for layer: int in 2:
		var bolt := Line2D.new()
		bolt.points = points
		bolt.width = 14.0 if layer == 0 else 5.0
		bolt.default_color = Color(color, 0.45) if layer == 0 else Color(1.0, 0.92, 0.9)
		bolt.joint_mode = Line2D.LINE_JOINT_SHARP
		bolt.z_index = 32
		_layer().add_child(bolt)
		var strike: Tween = bolt.create_tween()
		strike.tween_property(bolt, "modulate:a", 0.2, 0.05)
		strike.tween_property(bolt, "modulate:a", 1.0, 0.05)
		strike.tween_property(bolt, "modulate:a", 0.0, 0.25)
		strike.tween_callback(bolt.queue_free)


## 로켓 비행: 잔불을 남기며 날아간다.
func _rocket(view: Node2D, to: Vector2, duration: float, color: Color) -> void:
	board._kill_fx(view)
	var from: Vector2 = view.position
	var travel: Callable = func(t: float) -> void:
		if not is_instance_valid(view):
			return
		view.position = from.lerp(to, t) + Vector2(0.0, -60.0 * sin(t * PI))
		if int(t * 30.0) % 2 == 0:
			board._rocket_puff(view.position)
			ghost(view, color)
	var flight: Tween = view.create_tween()
	flight.tween_method(travel, 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _wait(duration)


## 사이렌 비네팅: 화면 가장자리가 붉게 물든다.
class Siren extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var steps: int = 10
		for i: int in steps:
			var inset: float = i * 9.0
			var alpha: float = 0.45 * (1.0 - float(i) / steps)
			var box := StyleBoxFlat.new()
			box.draw_center = false
			box.border_color = Color(1.0, 0.1, 0.1, alpha)
			box.set_border_width_all(10)
			draw_style_box(box, Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0))


## 큰 도장: 크게 떨어지며 쾅 찍히고 잠깐 남는다.
func _stamp(text: String, color: Color) -> void:
	var stamp := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.9, 0.12)
	style.border_color = color
	style.set_border_width_all(7)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(10)
	stamp.add_theme_stylebox_override("panel", style)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = _label(text, 64, color)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color("3d0000"))
	stamp.add_child(label)
	stamp.z_index = 72
	board.add_child(stamp)
	stamp.reset_size()
	stamp.pivot_offset = stamp.size / 2.0
	stamp.position = board._board_center() - stamp.size / 2.0
	stamp.rotation = -0.32
	stamp.scale = Vector2.ONE * 2.6
	stamp.modulate.a = 0.0
	var slam: Tween = stamp.create_tween()
	slam.tween_property(stamp, "modulate:a", 1.0, 0.06)
	slam.parallel().tween_property(stamp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.parallel().tween_property(stamp, "rotation", -0.14, 0.16)
	slam.tween_callback(func() -> void:
		board.screen_shake(12.0, 0.25)
		Sfx.play(&"slam"))
	slam.tween_property(stamp, "scale", Vector2.ONE * 1.06, 0.06)
	slam.tween_property(stamp, "scale", Vector2.ONE, 0.06)
	slam.tween_interval(0.5)
	slam.tween_property(stamp, "modulate:a", 0.0, 0.2)
	slam.tween_callback(stamp.queue_free)


## 끌려가는 궤적 (옅은 선이 금방 사라진다).
func _pull_line(from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 3.0
	line.default_color = Color(color, 0.6)
	line.z_index = 12
	_layer().add_child(line)
	_fade_out(line, 0.15, 0.3)


## 카드 뒷면 한 장이 화면 좌표 from에서 to로 날아간다 (fade_end면 도착하며 사라진다).
func _card_back_flight(from: Vector2, to: Vector2, duration: float, delay: float, fade_end: bool) -> void:
	var card := CardDrawFX.CardBack.new()
	card.size = Vector2(42.0, 59.0)
	card.pivot_offset = card.size / 2.0
	card.position = from - card.size / 2.0
	card.z_index = 65
	card.modulate.a = 0.0
	board.add_child(card)
	var bend: Vector2 = from.lerp(to, 0.5) + Vector2(0.0, -70.0)
	var arc: Callable = func(u: float) -> void:
		if is_instance_valid(card):
			card.position = from * (1.0 - u) * (1.0 - u) + bend * 2.0 * (1.0 - u) * u + to * u * u - card.size / 2.0
			card.rotation = u * TAU * 0.5
	var fly: Tween = card.create_tween()
	fly.tween_interval(delay)
	fly.tween_property(card, "modulate:a", 1.0, 0.04)
	fly.tween_method(arc, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if fade_end:
		fly.tween_property(card, "modulate:a", 0.0, 0.08)
	fly.tween_callback(card.queue_free)


## 검붉은 오라: 겹겹이 퍼지는 고리 + 위로 피어오르는 보라 불티.
func _aura(at: Vector2, duration: float) -> void:
	for i: int in 3:
		var timer: SceneTreeTimer = board.get_tree().create_timer(i * 0.14)
		timer.timeout.connect(_ring.bind(at, DEVIL_RED if i % 2 == 0 else DEVIL_PURPLE, 56.0, 6.0, 0.4))
	var embers := CPUParticles2D.new()
	embers.position = at
	embers.z_index = 33
	embers.amount = 26
	embers.lifetime = 0.6
	embers.one_shot = true
	embers.explosiveness = 0.3
	embers.direction = Vector2.UP
	embers.spread = 40.0
	embers.initial_velocity_min = 60.0
	embers.initial_velocity_max = 140.0
	embers.gravity = Vector2(0.0, -80.0)
	embers.scale_amount_min = 3.0
	embers.scale_amount_max = 6.0
	embers.color = DEVIL_PURPLE.lightened(0.2)
	embers.emitting = true
	_layer().add_child(embers)
	board._mark_oneshot(embers, duration + 0.7)
	board.get_tree().create_timer(duration + 0.7).timeout.connect(embers.queue_free)


## 황금 화염이 확 피어오른다.
func _flame_burst(at: Vector2, color: Color) -> void:
	var fire := CPUParticles2D.new()
	fire.position = at
	fire.z_index = 33
	fire.amount = 34
	fire.lifetime = 0.55
	fire.one_shot = true
	fire.explosiveness = 0.6
	fire.direction = Vector2.UP
	fire.spread = 55.0
	fire.initial_velocity_min = 90.0
	fire.initial_velocity_max = 200.0
	fire.gravity = Vector2(0.0, -120.0)
	fire.scale_amount_min = 4.0
	fire.scale_amount_max = 8.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.6))
	ramp.set_color(1, Color(color.darkened(0.3), 0.0))
	fire.color_ramp = ramp
	fire.emitting = true
	_layer().add_child(fire)
	board._mark_oneshot(fire, 1.2)
	board.get_tree().create_timer(1.2).timeout.connect(fire.queue_free)
	_ring(at, color, 70.0, 5.0, 0.35)


## 빵 파티클: 갈색 둥근 빵 조각이 튀어 오른다.
func _bread_burst(at: Vector2) -> void:
	var bread := CPUParticles2D.new()
	bread.position = at
	bread.z_index = 33
	bread.amount = 14
	bread.lifetime = 0.7
	bread.one_shot = true
	bread.explosiveness = 0.9
	bread.direction = Vector2.UP
	bread.spread = 70.0
	bread.initial_velocity_min = 120.0
	bread.initial_velocity_max = 220.0
	bread.gravity = Vector2(0.0, 420.0)
	bread.scale_amount_min = 5.0
	bread.scale_amount_max = 9.0
	bread.color = BREAD
	bread.emitting = true
	_layer().add_child(bread)
	board._mark_oneshot(bread, 1.0)
	board.get_tree().create_timer(1.0).timeout.connect(bread.queue_free)


## 지뢰 칸 위의 붉은 경고 표식 (깜빡인다). 지뢰가 꽂히면 지운다.
func _warning_mark(at: Vector2) -> Node2D:
	var mark := Node2D.new()
	mark.position = at
	mark.z_index = 29
	var halo := Polygon2D.new()
	halo.polygon = _circle(30.0, 24)
	halo.color = Color(1.0, 0.1, 0.05, 0.35)
	mark.add_child(halo)
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([Vector2(0, -24), Vector2(24, 0), Vector2(0, 24), Vector2(-24, 0)])
	diamond.color = Color(1.0, 0.15, 0.1, 0.9)
	mark.add_child(diamond)
	var bang: Label = _label("!", 30, Color.WHITE)
	mark.add_child(bang)
	_center_label(bang)
	_layer().add_child(mark)
	var blink: Tween = mark.create_tween().set_loops(6)
	blink.tween_property(mark, "modulate:a", 0.25, 0.08)
	blink.tween_property(mark, "modulate:a", 1.0, 0.08)
	board.get_tree().create_timer(2.0).timeout.connect(mark.queue_free)
	return mark


## 지뢰 아이콘: 검은 공 + 뇌관 + 빨간 불빛.
func _mine_icon() -> Node2D:
	var mine := Node2D.new()
	var body := Polygon2D.new()
	body.polygon = _circle(11.0, 18)
	body.color = Color("212529")
	mine.add_child(body)
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var spike := Polygon2D.new()
		spike.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(0, -16), Vector2(3, 0)])
		spike.color = Color("343a40")
		spike.rotation = angle
		mine.add_child(spike)
	var light := Polygon2D.new()
	light.polygon = _circle(3.5, 10)
	light.color = Color("ff3b30")
	light.position = Vector2(3, -3)
	mine.add_child(light)
	return mine


## 조준경: 원 두 개 + 십자선 + 가운데 점.
func _crosshair() -> Node2D:
	var scope := Node2D.new()
	scope.z_index = 34
	for radius: float in [34.0, 20.0]:
		var ring := Line2D.new()
		ring.points = _circle(radius, 36)
		ring.closed = true
		ring.width = 3.5 if radius > 30.0 else 2.0
		ring.default_color = RED
		scope.add_child(ring)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var hair := Line2D.new()
		hair.points = PackedVector2Array([direction * 12.0, direction * 46.0])
		hair.width = 3.0
		hair.default_color = RED
		scope.add_child(hair)
	var dot := Polygon2D.new()
	dot.polygon = _circle(3.0, 10)
	dot.color = RED
	scope.add_child(dot)
	return scope


## 탄흔: 검은 구멍 + 금 간 자국 (잠깐 남는다).
func _bullet_hole(at: Vector2) -> void:
	var hole := Node2D.new()
	hole.position = at + Vector2(0.0, 6.0)
	hole.z_index = 11
	var pit := Polygon2D.new()
	pit.polygon = _circle(7.0, 12)
	pit.color = Color(0.08, 0.06, 0.06, 0.9)
	hole.add_child(pit)
	for i: int in 6:
		var crack := Line2D.new()
		var direction: Vector2 = Vector2.from_angle(TAU * i / 6 + randf() * 0.4)
		crack.points = PackedVector2Array([direction * 6.0, direction * (14.0 + randf() * 8.0)])
		crack.width = 2.0
		crack.default_color = Color(0.1, 0.08, 0.08, 0.8)
		hole.add_child(crack)
	_layer().add_child(hole)
	_fade_out(hole, 0.9, 0.4)


## 할퀴기: 비스듬한 붉은 발톱 자국 세 줄이 확 그어지고 파편이 튄다 (화면 좌표).
func _claw(at_screen: Vector2, delay: float) -> void:
	var at: Vector2 = _local(at_screen)
	var timer: SceneTreeTimer = board.get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		if board == null or not is_instance_valid(board):
			return
		Sfx.play(&"slam")
		board._burst_shards(at, RED, 12)
		for i: int in 3:
			var scratch := Line2D.new()
			var offset: Vector2 = Vector2(-16.0 + i * 16.0, 0.0)
			var start: Vector2 = at + offset + Vector2(-26.0, -30.0)
			var finish: Vector2 = at + offset + Vector2(26.0, 30.0)
			scratch.points = PackedVector2Array([start, start])
			scratch.width = 7.0
			scratch.default_color = Color(1.0, 0.2, 0.2, 0.95)
			scratch.begin_cap_mode = Line2D.LINE_CAP_ROUND
			scratch.end_cap_mode = Line2D.LINE_CAP_ROUND
			scratch.z_index = 66
			_layer().add_child(scratch)
			var tear: Callable = func(t: float) -> void:
				if is_instance_valid(scratch):
					scratch.points = PackedVector2Array([start, start.lerp(finish, t)])
			var rip: Tween = scratch.create_tween()
			rip.tween_method(tear, 0.0, 1.0, 0.1).set_delay(i * 0.03)
			rip.tween_property(scratch, "modulate:a", 0.0, 0.3).set_delay(0.15)
			rip.tween_callback(scratch.queue_free))


## 앞쪽을 가리키는 네온 화살표.
func _chevron(direction: Vector2) -> Node2D:
	var arrow := Line2D.new()
	arrow.points = PackedVector2Array([Vector2(-6, -8), Vector2(4, 0), Vector2(-6, 8)])
	arrow.width = 4.0
	arrow.default_color = Color.WHITE.lerp(NEON, 0.4)
	arrow.rotation = direction.angle()
	arrow.z_index = 15
	return arrow


## 꺾은선의 앞쪽 t만큼만 (0~1).
static func _partial(points: PackedVector2Array, t: float) -> PackedVector2Array:
	if points.size() < 2 or t >= 1.0:
		return points
	var total: float = 0.0
	for i: int in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	var want: float = total * t
	var out := PackedVector2Array([points[0]])
	for i: int in range(1, points.size()):
		var length: float = points[i - 1].distance_to(points[i])
		if want <= length:
			out.append(points[i - 1].lerp(points[i], want / maxf(length, 0.001)))
			return out
		want -= length
		out.append(points[i])
	return out


## 그 자리에서 바로 장외 사출 연출(처치 기록 포함)을 재생한다: 늦게 붙는 처치 단계를 꺼내 와 이 연출 순서 안에서 보여 준다.
func _eject_now(pawn_id: int, by_player: int) -> void:
	var pawn: PlayerPawn = board.state.get_pawn(pawn_id)
	if pawn == null or not _alive():
		return
	board._take_late_steps_for(pawn_id)
	if board._ejection_confirmed(pawn_id):
		board._record_ejection(pawn_id, by_player, true)
		await board._play_capture_eject(pawn_id, by_player, pawn.owner_id, false)


func _first(changes: Array, kind: String) -> Dictionary:
	for change: Dictionary in changes:
		if change["kind"] == kind:
			return change
	return {}


func _view(pawn_id: int) -> Node2D:
	var view: Node2D = board._pawn_views.get(pawn_id)
	return view if view != null and is_instance_valid(view) else null


func _layer() -> Node2D:
	return board._pawn_layer


## 화면 좌표 -> 말 층 좌표.
func _local(screen: Vector2) -> Vector2:
	return board._pawn_layer.get_global_transform().affine_inverse() * screen


## 말 층 좌표 -> 화면 좌표.
func _screen(local: Vector2) -> Vector2:
	return board._pawn_layer.get_global_transform() * local


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color("1b1f2b"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 라벨을 부모 원점 가운데에 놓는다.
func _center_label(label: Label) -> void:
	label.reset_size()
	label.position = -label.size / 2.0
	label.pivot_offset = label.size / 2.0


func _fade_out(node: CanvasItem, delay: float, duration: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var fade: Tween = node.create_tween()
	fade.tween_interval(delay)
	fade.tween_property(node, "modulate:a", 0.0, duration)
	fade.tween_callback(node.queue_free)


static func _circle(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in count:
		var angle: float = TAU * i / count
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _wait(seconds: float) -> void:
	await board.get_tree().create_timer(seconds).timeout


## 판이 초기화(새 게임·되감기)되지 않았는가.
func _alive() -> bool:
	return board != null and is_instance_valid(board) and board._fx_generation == _generation
