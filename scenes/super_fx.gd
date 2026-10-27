# File: res://scenes/super_fx.gd
# Class: class_name SuperFX
# Role: 초증강 전용 보드 연출. 로그를 읽지 않아도 보드만 보고 "이 초증강 때문에 이렇게 됐구나"를 알 수 있게, 초증강마다 고유한 장면을 보여 준다.
#       엔진은 증강을 고르는 순간 이미 결과를 정했다. MainBoard가 그 사이 엔진이 낸 변화(움직인 말·지뢰 칸·빼앗긴 카드·묶인 말·질주 길)를
#       기록해 넘기면(play의 changes), 여기서 그 결과를 연출로 보여 준다. 말 그림은 연출이 끝날 때까지 제자리에 붙잡혀 있다.
#       기존 리소스·코드 메시·트윈으로 각 효과의 과정과 결과를 보여 준다.
#       폭주 기관차(SUPER_11)는 RunawayTrainStage가 따로 보여 준다.
class_name SuperFX
extends RefCounted

const REDISTRIBUTION_STAGE = preload("res://scenes/redistribution_stage.gd")
const REDISTRIBUTION_ART = preload("res://scenes/redistribution_art.gd")
const REDISTRIBUTION_SIREN = preload("res://assets/fx/redistribution_siren.gdshader")
const DEVIL_STAGE = preload("res://scenes/devil_contract_stage.gd")
const MINEFIELD_STAGE = preload("res://scenes/minefield_stage.gd")
const RAID_STAGE = preload("res://scenes/raid_stage.gd")
const GAMBLER_STAGE = preload("res://scenes/gambler_fx.gd")
const PROFILE_AURA = preload("res://scenes/profile_super_aura.gd")
const CASTLING_STAGE = preload("res://scenes/castling_stage.gd")
const BAKERY_STAGE = preload("res://scenes/bakery_stage.gd")
const SNIPER_STAGE = preload("res://scenes/sniper_stage.gd")
const BOND_STAGE = preload("res://scenes/bond_stage.gd")
const BOND_CUFF = preload("res://scenes/bond_cuff.gd")
const NITRO_STAGE = preload("res://scenes/nitro_stage.gd")
const FATE_COIN = preload("res://scenes/fate_coin_3d.gd")
const STAGE_SPOTLIGHT = preload("res://scenes/pawn_stage_spotlight.gd")

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
	_spotlight(view, Color(1.0, 0.97, 0.75),1.35*board._motion_pace())
	Sfx.play(&"charge")
	await _wait(0.25)
	if not _alive():
		return
	# The result is already authoritative. A real two-sided coin shows that result
	# after its rising spin, slower descent and a short, readable result hold.
	var coin := FATE_COIN.new()
	coin.position = _local(board._board_center())+Vector2(0,-32)
	_layer().add_child(coin)
	Sfx.play(&"toy_click")
	coin.play(success,board._motion_pace())
	while _alive() and is_instance_valid(coin) and not coin.settled:
		await board.get_tree().process_frame
	if not _alive() or not is_instance_valid(coin):
		if is_instance_valid(coin):
			coin.queue_free()
		return
	Sfx.play(&"good" if success else &"bad")
	await _wait(0.28*board._motion_pace())
	if not _alive() or not is_instance_valid(coin):
		if is_instance_valid(coin):
			coin.queue_free()
		return
	_fade_out(coin,0.0,0.25*board._motion_pace())
	var pawn: PlayerPawn = board.state.get_pawn(pawn_id)
	if success:
		# 황금빛으로 터지며 결승선으로 로켓처럼 직행
		board._burst_shards(at, GOLD, 22)
		_ring(at, GOLD, 70.0, 5.0, 0.35)
		Sfx.play(&"rocket")
		var goal: Vector2 = board._pawn_position(pawn) if pawn != null else board._tile_center(GameEnums.GOAL_TILE)
		await _rocket(view, goal, 0.42, GOLD)
		if not _alive(): return
		_ring(goal, GOLD, 60.0, 5.0, 0.3)
		board._floating_badge(_screen(goal) + Vector2(0, -40), "완주!", GOLD, 34)
		await _wait(0.15)
	else:
		# 붉은 낙뢰가 내리꽂히고 출발선으로 튕겨 난다
		_bolt(at + Vector2(-16, -280.0), at, RED)
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
	_redistribution_stamp(Vector2(0,-70))
	await _wait(0.22)
	if not _alive():
		return
	var stage := REDISTRIBUTION_STAGE.new()
	board.add_child(stage)
	stage.play(board,changes,board._motion_pace())
	while _alive() and is_instance_valid(stage) and not stage._complete:
		await board.get_tree().process_frame
	if is_instance_valid(stage):
		stage.queue_free()
	if _alive():
		for change: Dictionary in changes:
			if change.kind=="teleport":
				board._fx_hints.erase(int(change.pawn))
		Sfx.play(&"card_get",-6.0)
	# The existing reserved draw queue now deals once from the real table-side deck.


# ---------------------------------------------------------------------------
# 3. 악마의 계약: 완주 말 봉헌 → 봉인에 흡수 → 계약의 힘이 프로필로 이동 → 영구 가속 점화
# ---------------------------------------------------------------------------

func _devil(player_id: int, changes: Array) -> void:
	var sent: Dictionary = _first(changes, "start")
	var pawn_id: int = int(sent.get("pawn", -1))
	if _view(pawn_id)==null:
		return
	var stage := DEVIL_STAGE.new()
	board.add_child(stage)
	stage.play(board,player_id,pawn_id,board._motion_pace(),sent)
	while _alive() and is_instance_valid(stage) and not stage._complete:
		await board.get_tree().process_frame
	if is_instance_valid(stage):
		stage.queue_free()
	if _alive():
		board._fx_hints.erase(pawn_id)


# ---------------------------------------------------------------------------
# 4. 광란의 지뢰밭: 칸마다 붉은 경고 깜빡 → 위에서 지뢰가 다다닥 떨어져 꽂힘 → 쿵
# ---------------------------------------------------------------------------

func _minefield(_player_id: int, changes: Array) -> void:
	var tiles: Array[int] = []
	for change: Dictionary in changes:
		if change.get("kind")=="place" and change.get("id")=="TRP_03":
			tiles.append(int(change["tile"]))
	if tiles.is_empty():
		return
	var stage := MINEFIELD_STAGE.new()
	board.add_child(stage)
	stage.play(board,tiles,board._motion_pace())
	while _alive() and is_instance_valid(stage) and not stage._complete:
		await board.get_tree().process_frame
	if is_instance_valid(stage):
		stage.queue_free()


# ---------------------------------------------------------------------------
# 5. 도적단 대습격: 대각선 컷인·분할 퇴장 → 지원 카드 → 상대 프로필 강탈·손패 배달
# ---------------------------------------------------------------------------

func _raid(player_id: int, changes: Array) -> void:
	var receipt := _first(changes,"raid_rewards")
	var jobs: Array[Dictionary] = []
	jobs.assign(receipt.get("jobs",[]))
	var stage := RAID_STAGE.new()
	board.add_child(stage)
	stage.play(board,player_id,jobs,board._motion_pace())
	while _alive() and is_instance_valid(stage) and not stage._complete:
		await board.get_tree().process_frame
	if is_instance_valid(stage):
		stage.queue_free()


# ---------------------------------------------------------------------------
# 6. 주사위 도박사의 영혼: 프로필과 주사위 UI에 이글거리는 황금 화염 (굴릴 때 x배수 / 과열은 MainBoard가 주사위 위에 띄운다)
# ---------------------------------------------------------------------------

func _gambler(player_id: int) -> void:
	var stage := GAMBLER_STAGE.new()
	board.add_child(stage)
	stage.play(board,&"activate",player_id,{},Vector2.ZERO,null,board._motion_pace())
	while _alive() and is_instance_valid(stage) and not stage._complete:
		await board.get_tree().process_frame
	if is_instance_valid(stage):
		stage.queue_free()


func gambler_boost(at_screen: Vector2, multiplier: int, values: Dictionary = {}, target: Control = null) -> void:
	var data := values.duplicate()
	data["multiplier"] = multiplier
	_gambler_result(&"boost",at_screen,target,data)


func gambler_overheat(at_screen: Vector2, presenter: Control, values: Dictionary = {}) -> void:
	_gambler_result(&"overheat",at_screen,presenter,values)


func _gambler_result(mode: StringName, at_screen: Vector2, target: Control, values: Dictionary) -> void:
	var previous: Node2D = board.get_node_or_null("GamblerResult")
	if previous!=null:
		previous.cancel()
		previous.name = "RetiredGamblerResult"
	var stage := GAMBLER_STAGE.new()
	board.add_child(stage)
	stage.play(board,mode,-1,values,at_screen,target,board._motion_pace())


# ---------------------------------------------------------------------------
# 7. 강제 캐슬링 룰렛: 모든 말이 보드 가운데 공중으로 떠올라 원을 그리며 섞인 뒤 새 자리로 일제히 낙하
# ---------------------------------------------------------------------------

func _castling(changes: Array) -> void:
	var stage := CASTLING_STAGE.new()
	board.add_child(stage)
	stage.play(board,changes,board._motion_pace())
	while _alive() and is_instance_valid(stage) and not stage._complete:
		await board.get_tree().process_frame
	if is_instance_valid(stage):
		stage.queue_free()


# ---------------------------------------------------------------------------
# 8. 에르핀의 빵집 털이: 빵집 강조 → 대기 말 출격 → 에르핀의 빵 챙기기 → 실제 보상을 손패로 전달
# ---------------------------------------------------------------------------

func _bakery(player_id: int, changes: Array) -> void:
	var stage := BAKERY_STAGE.new()
	board.add_child(stage)
	stage.play(board,player_id,changes,board._motion_pace())
	while _alive() and is_instance_valid(stage) and not stage._complete:
		await board.get_tree().process_frame
	if is_instance_valid(stage):
		stage.queue_free()


# ---------------------------------------------------------------------------
# 9. 저격수의 표적: 붉은 조준경이 크게 떴다 0.4초 만에 줄어들며 록온 → 섬광·탄흔 → 출발선으로 회전하며 날아감
# ---------------------------------------------------------------------------

func _sniper(player_id: int, changes: Array) -> void:
	var target := _first(changes,"start")
	var target_id := int(target.get("pawn",-1))
	var stage := SNIPER_STAGE.new()
	board.add_child(stage)
	stage.play(board,player_id,target_id,board._motion_pace(),target)
	while _alive() and is_instance_valid(stage) and not stage._complete:
		await board.get_tree().process_frame
	if is_instance_valid(stage):
		stage.queue_free()
	if _alive():
		await _eject_now(target_id,player_id)


# ---------------------------------------------------------------------------
# 10. 아우토반 니트로: 선두 말에서 다음 코너까지 네온 부스터 라인과 화살표가 쫙 깔린다 (이어서 잔상을 남기며 질주)
# ---------------------------------------------------------------------------

func _nitro(changes: Array) -> void:
	await board._play_nitro_stage(_first(changes,"nitro"))


## Shared rocket helper; NitroStage renders its own pawn-shaped afterimages.
func ghost(view: Node2D, color: Color) -> void:
	if view == null or not is_instance_valid(view):
		return
	var token: PawnToken = view.get_node_or_null("Bounce/Token") as PawnToken
	if token != null and not token.artwork.is_empty():
		board._pawn_trail_sample(token, color.lightened(0.25))


# ---------------------------------------------------------------------------
# 12. 강제 연대책임: 선두 말과 꼴찌 말 사이에 붉은 에너지 사슬이 철컥! 연결되어 팽팽해진다 (발밑 고리는 묶여 있는 내내 남는다)
# ---------------------------------------------------------------------------

func _guarantee(changes: Array) -> void:
	await board._play_bond_stage(_first(changes,"bond"))


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
			var color: Color = colors[i % colors.size()].lightened(0.2)
			PaintedFx.flame(self,base,Vector2.UP,height,4.0,Color(color,0.85),_time*8+i*1.7)

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
static func set_flame(host: Control, flame_name: String, colors: Array[Color], profile: bool = false) -> void:
	if host == null:
		return
	var flame: Control = host.get_node_or_null(flame_name) as Control
	if colors.is_empty():
		if flame != null:
			host.remove_child(flame)
			flame.queue_free()
		return
	if flame == null:
		flame = PROFILE_AURA.new() if profile else FlameBorder.new()
		flame.name = flame_name
		host.add_child(flame)
	flame.colors = colors


## 연대책임 지속 표시: 금속 족쇄와 맞물린 두 고리가 함께 맥동한다.
static func set_bond_ring(view: Node2D, bonded: bool) -> void:
	var ring: Node2D = view.get_node_or_null("BondRing") as Node2D
	if not bonded:
		if ring!=null:
			ring.queue_free()
		return
	if ring!=null:
		return
	ring = BOND_CUFF.new()
	ring.name = "BondRing"
	ring.z_index = -1
	view.add_child(ring)
	view.move_child(ring,0)


# ---------------------------------------------------------------------------
# 공용 조각
# ---------------------------------------------------------------------------

## 화면 위 큰 제목 (어떤 초증강인지): 보드 위쪽에 잠깐.
func _title(effect: StringName, player_id: int) -> void:
	var name: String = SuperAugments.display_name(effect)
	var at: Vector2 = board._board_center() + Vector2(0.0, -150.0)
	board._floating_badge(at, "%s %s" % [board._player_name(player_id), name], Color("e599f7"), 28)


## 주변은 어둡게, 선택된 말에는 위에서 내려오는 무대 조명.
func _spotlight(view: Node2D, color: Color, hold_time: float = 0.6) -> void:
	var light := STAGE_SPOTLIGHT.new()
	board.add_child(light)
	light.illuminate(board,view,color,hold_time)


## 가운데가 빈 붓결 압력파.
func _ring(at: Vector2, color: Color, radius: float, _width: float, duration: float) -> void:
	var ring := PaintedFx.sprite(PaintedFx.RIPPLE)
	ring.name = "PaintedPressure"
	ring.position = at
	var shape := Vector2(1,0.65) * 2.0 / ring.region_rect.size.x
	ring.scale = shape * 8.0
	ring.modulate = color
	ring.z_index = 0
	_layer().add_child(ring)
	_layer().move_child(ring,0)
	board._mark_oneshot(ring,duration)
	var grow: Tween = ring.create_tween().set_parallel(true)
	grow.tween_property(ring, "scale", shape * radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.tween_property(ring, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	grow.chain().tween_callback(ring.queue_free)


## 작은 섬광 중심과 비정형 빛결이 짧게 퍼진다.
func _flash(at: Vector2, color: Color, radius: float) -> void:
	var burst := PaintedFx.sprite(PaintedFx.IMPACT)
	burst.name = "PaintedFlipContact"
	burst.modulate = color
	burst.position = at
	var extent := Vector2.ONE * radius * 2 / burst.region_rect.size
	burst.scale = extent * 0.3
	burst.z_index = 31
	_layer().add_child(burst)
	board._mark_oneshot(burst,0.22)
	var pop: Tween = burst.create_tween().set_parallel(true)
	pop.tween_property(burst, "scale", extent, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(burst, "modulate:a", 0.0, 0.22)
	pop.chain().tween_callback(burst.queue_free)


## 가지가 갈라지는 실제 번개 그림. 밝은 중심선의 양 끝을 발사점·착지점에 맞춘다.
func _bolt(from: Vector2, to: Vector2, color: Color) -> void:
	var bolt := PaintedFx.lightning(from,to,color)
	bolt.name = "PaintedLightning"
	bolt.z_index = 32
	_layer().add_child(bolt)
	board._mark_oneshot(bolt,0.35)
	var strike: Tween = bolt.create_tween()
	strike.tween_property(bolt, "modulate:a", 0.2, 0.05)
	strike.tween_property(bolt, "modulate:a", 1.0, 0.05)
	strike.tween_property(bolt, "modulate:a", 0.0, 0.25)
	strike.tween_callback(bolt.queue_free)


## 로켓 비행: 잔불을 남기며 날아간다.
func _rocket(view: Node2D, to: Vector2, duration: float, color: Color) -> void:
	board._kill_fx(view)
	var from: Vector2 = view.position
	var source: WeakRef = weakref(view)
	var sample := {"position":from, "step":-1}
	board._fx_trail(view,duration,color)
	var travel: Callable = func(t: float) -> void:
		var pawn_view: Node2D = source.get_ref()
		if not _alive() or not is_instance_valid(pawn_view):
			return
		pawn_view.position = from.lerp(to, t) + Vector2(0.0, -60.0 * sin(t * PI))
		var step := int(t * 15.0)
		if step != sample.step:
			board._rocket_puff(pawn_view.position,pawn_view.position.direction_to(sample.position),color)
			sample.step = step
		sample.position = pawn_view.position
	var flight: Tween = view.create_tween()
	flight.tween_method(travel, 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _wait(duration)


## 사이렌 비네팅: 화면 가장자리가 붉게 물든다.
class Siren extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var veil := ColorRect.new()
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var ink := ShaderMaterial.new()
		ink.shader = REDISTRIBUTION_SIREN
		veil.material = ink
		add_child(veil)


## 큰 도장: 크게 떨어지며 쾅 찍히고 잠깐 남는다.
func _redistribution_stamp(offset: Vector2 = Vector2.ZERO) -> void:
	var stamp := TextureRect.new()
	stamp.name = "RedistributionStamp"
	var localized := REDISTRIBUTION_ART.stamp_for_language()
	var texture := AtlasTexture.new()
	texture.atlas = localized.texture
	texture.region = REDISTRIBUTION_ART.region(localized.texture,localized.region)
	stamp.texture = texture
	stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp.size = Vector2(localized.width,localized.width*texture.region.size.y/texture.region.size.x)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.z_index = 72
	board.add_child(stamp)
	stamp.pivot_offset = stamp.size / 2.0
	stamp.position = board._board_center()+offset-stamp.size/2.0
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
	fire.amount = 30  # 한 번에 터지는 파티클은 30개 이하
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
