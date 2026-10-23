# File: res://scenes/card_draw_fx.gd
# Class: class_name CardDrawFX
# Role: 카드 획득 연출. 빵집·기물 능력·카드 패키지 증강 등으로 생떼 카드를 얻으면 보드 한가운데 덱 뭉치에서 카드 뒷면이 톡 뽑혀 올라오고,
#       - 내 카드(하단 손패 주인): 그 자리에서 앞면으로 휙 뒤집혀 어떤 카드인지 보여 준 뒤 곡선을 그리며 손패 자리로 빨려 들어간다.
#       - 다른 사람 카드: 뒷면 그대로 그 사람 프로필로 슈슉 날아가 꽂히고, 프로필이 살짝 흔들리며 효과음이 난다 (무슨 카드인지는 비밀).
#       여러 장은 0.08초 간격으로 다다닥 이어진다. 모든 트윈은 0.6초 안에 끊는다. 연출만 담당하며 게임 진행을 막지 않는다.
class_name CardDrawFX
extends Control

## 카드가 도착했다 (local: 내 손패로 들어왔다 → 손패를 다시 그려 숨겨 둔 카드를 보인다).
signal landed(player_id: int, local: bool)

## 덱·비행 카드 크기 (손패 카드 140x196의 0.6배).
const CARD_SIZE: Vector2 = Vector2(84.0, 118.0)
const HAND_SIZE: Vector2 = Vector2(140.0, 196.0)
const POP_TIME: float = 0.15
const POP_RISE: float = 30.0
const FLIP_HALF: float = 0.09
const SHOW_TIME: float = 0.1
const FLY_TIME: float = 0.32
const OTHER_FLY_TIME: float = 0.25
const STAGGER: float = 0.08
const DECK_FADE: float = 0.12
const OTHER_END_SCALE: float = 0.4

## 덱 뭉치 한가운데의 화면 좌표 (MainBoard가 보드 한가운데로 맞춘다).
var deck_position: Vector2 = Vector2(683.0, 300.0)
## 카드 앞면을 만드는 함수: card_id -> Control(HAND_SIZE). 내 카드를 뒤집을 때 쓴다.
var face_builder: Callable = Callable()
## 아직 손패에 내려앉지 않은 내 카드 수 (플레이어 id -> 장수). 그동안 손패의 마지막 카드들은 숨겨 둔다.
var pending: Dictionary = {}
## 지금 날고 있는 카드 수 (테스트용).
var in_flight: int = 0

var _deck: Control = null
var _deck_tween: Tween = null
var _last_launch: float = -1.0


## 카드 뒷면: 남색 바탕 + 금색 테두리 + 가운데 마름모 문양.
class CardBack extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var body := StyleBoxFlat.new()
		body.bg_color = Color("2b3a67")
		body.border_color = Color("ffd43b")
		body.set_border_width_all(3)
		body.set_corner_radius_all(9)
		body.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		body.shadow_size = 4
		draw_style_box(body, rect)
		var inner := StyleBoxFlat.new()
		inner.bg_color = Color("3b4f8a")
		inner.border_color = Color(1.0, 0.85, 0.3, 0.55)
		inner.set_border_width_all(1)
		inner.set_corner_radius_all(6)
		draw_style_box(inner, rect.grow(-7.0))
		var c: Vector2 = size / 2.0
		var r: Vector2 = size * Vector2(0.24, 0.2)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r.y), c + Vector2(r.x, 0), c + Vector2(0, r.y), c + Vector2(-r.x, 0)]), Color("ffd43b"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r.y * 0.5), c + Vector2(r.x * 0.5, 0), c + Vector2(0, r.y * 0.5), c + Vector2(-r.x * 0.5, 0)]), Color("2b3a67"))


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_build_deck()  # 덱 뭉치는 처음부터 만들어 두고 뽑을 때만 보인다


## 카드 한 장을 뽑아 날린다. local이면 앞면으로 뒤집어 target(손패 자리 가운데)으로, 아니면 뒷면 그대로 target(프로필 가운데)으로.
## on_arrive: 도착 순간에 부를 함수 (프로필 흔들기 등).
func draw_card(player_id: int, card_id: StringName, local: bool, target: Vector2, on_arrive: Callable = Callable()) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var delay: float = maxf(0.0, _last_launch + STAGGER - now)
	_last_launch = now + delay
	if local:
		pending[player_id] = int(pending.get(player_id, 0)) + 1
	in_flight += 1
	_show_deck()
	var card := Control.new()
	card.name = "DrawnCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = CARD_SIZE
	card.pivot_offset = CARD_SIZE / 2.0
	card.position = deck_position - CARD_SIZE / 2.0
	card.modulate.a = 0.0
	var back := CardBack.new()
	back.size = CARD_SIZE
	card.add_child(back)
	add_child(card)
	var lifted: Vector2 = deck_position + Vector2(0.0, -POP_RISE)
	var tween: Tween = card.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	# 1) 덱 뭉치에서 0.15초 만에 위로 톡
	tween.tween_property(card, "modulate:a", 1.0, 0.05)
	tween.parallel().tween_property(card, "position", lifted - CARD_SIZE / 2.0, POP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "scale", Vector2.ONE * 1.08, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if local:
		# 2) 앞면으로 휙 뒤집어(가로 1 -> 0 -> 1) 잠깐 보여 주고, 곡선을 그리며 손패 자리로 빨려 들어간다 (손패 크기로 커진다)
		tween.tween_property(card, "scale:x", 0.0, FLIP_HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(_show_face.bind(card, back, card_id))
		tween.tween_property(card, "scale:x", 1.08, FLIP_HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_interval(SHOW_TIME)
		var grow: float = HAND_SIZE.x / CARD_SIZE.x
		var bend: Vector2 = Vector2(clampf(lifted.x - target.x, -1.0, 1.0) * 140.0, -40.0)
		tween.tween_method(_fly.bind(card, lifted, lifted.lerp(target, 0.5) + bend, target, 1.08, grow, 0.0), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		# 3) 뒷면 그대로 0.25초 만에 프로필로 슈슉 (빙글 돌며 작아진다)
		var arc: Vector2 = Vector2(0.0, -90.0)
		var spin: float = TAU * (0.5 if target.x > lifted.x else -0.5)
		tween.tween_method(_fly.bind(card, lifted, lifted.lerp(target, 0.5) + arc, target, 1.08, OTHER_END_SCALE, spin), 0.0, 1.0, OTHER_FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_arrive.bind(card, player_id, local, on_arrive))


## 덱에서 뽑혀 나와 이동 중이거나 손패 도착을 기다리는 카드가 있는가.
func busy() -> bool:
	return in_flight > 0


## 진행 중인 비행을 모두 지운다 (새 게임 등).
func clear() -> void:
	for child: Node in get_children():
		if child != _deck:
			child.queue_free()
	pending.clear()
	in_flight = 0
	_last_launch = -1.0
	if _deck != null:
		_deck.visible = false


func _show_face(card: Control, back: Control, card_id: StringName) -> void:
	back.visible = false
	if face_builder.is_valid():
		var face: Control = face_builder.call(card_id)
		if face != null:
			face.scale = CARD_SIZE / HAND_SIZE
			card.add_child(face)
	Sfx.play(&"card_pick")


## 곡선 비행: 2차 베지어 곡선 위의 u 위치, 크기·회전을 함께 바꾼다.
func _fly(u: float, card: Control, from: Vector2, bend: Vector2, to: Vector2, from_scale: float, to_scale: float, spin: float) -> void:
	if not is_instance_valid(card):
		return
	var point: Vector2 = from * (1.0 - u) * (1.0 - u) + bend * 2.0 * (1.0 - u) * u + to * u * u
	var s: float = lerpf(from_scale, to_scale, u)
	card.scale = Vector2.ONE * s
	card.rotation = spin * u
	card.position = point - CARD_SIZE / 2.0


func _arrive(card: Control, player_id: int, local: bool, on_arrive: Callable) -> void:
	if is_instance_valid(card):
		card.queue_free()
	in_flight = maxi(in_flight - 1, 0)
	if local:
		pending[player_id] = maxi(int(pending.get(player_id, 0)) - 1, 0)
	Sfx.play(&"card_get")
	if on_arrive.is_valid():
		on_arrive.call()
	landed.emit(player_id, local)
	if in_flight == 0:
		_hide_deck()


## 겹쳐진 카드 뭉치 (뽑는 동안만 보인다).
func _show_deck() -> void:
	_build_deck()
	move_child(_deck, 0)
	_deck.position = deck_position - CARD_SIZE / 2.0 + Vector2(2.5, -3.0)
	if _deck_tween != null and _deck_tween.is_valid():
		_deck_tween.kill()
	if not _deck.visible:
		_deck.visible = true
		_deck.modulate.a = 0.0
	_deck_tween = _deck.create_tween()
	_deck_tween.tween_property(_deck, "modulate:a", 1.0, DECK_FADE * (1.0 - _deck.modulate.a))


func _build_deck() -> void:
	if _deck == null:
		_deck = Control.new()
		_deck.name = "DeckPile"
		_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for index: int in 3:
			var back := CardBack.new()
			back.size = CARD_SIZE
			back.position = Vector2(-index * 2.5, index * 3.0)
			back.rotation = deg_to_rad(-4.0 + index * 3.5)
			_deck.add_child(back)
			_deck.move_child(back, 0)
		_deck.visible = false
		add_child(_deck)


func _hide_deck() -> void:
	if _deck == null:
		return
	if _deck_tween != null and _deck_tween.is_valid():
		_deck_tween.kill()
	_deck_tween = _deck.create_tween()
	_deck_tween.tween_interval(0.1)
	_deck_tween.tween_property(_deck, "modulate:a", 0.0, DECK_FADE)
	_deck_tween.tween_callback(func() -> void: _deck.visible = false)
