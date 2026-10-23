## Card acquisition is visual only: the engine has already granted the card.
## Draw from the table-side deck, carry the back to centre, reveal one local
## card at a time, then match its live hand slot. Remote cards stay face down.
class_name CardDrawFX
extends Control

signal landed(player_id: int, local: bool)
signal drained

const CARD_SIZE := Vector2(84.0,118.0)
const HAND_SIZE := Vector2(140.0,196.0)
const REVEAL_SCALE: float = 2.5  # 210 x 295: readable artwork, familiar card frame.
const POP_TIME: float = 0.14
const POP_RISE: float = 32.0
const TAKE_TIME: float = 0.28
const FLIP_HALF: float = 0.11
const SHOW_TIME: float = 0.60
const FLY_TIME: float = 0.36
const OTHER_FLY_TIME: float = 0.30
const STAGGER: float = 0.06
const OTHER_END_SCALE: float = 0.4
const LOCAL_TIME: float = POP_TIME+TAKE_TIME+FLIP_HALF*2.0+SHOW_TIME+FLY_TIME

var deck_position := Vector2(1040.0,510.0)
var reveal_position := Vector2(683.0,320.0)
var face_builder: Callable = Callable()
var pending: Dictionary = {}
var in_flight: int = 0
var _deck: Control = null
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _gap: float = 0.0


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
	_build_deck()
	place_deck()


func reserve(player_id: int) -> void:
	pending[player_id] = int(pending.get(player_id,0))+1


func release(player_id: int) -> void:
	pending[player_id] = maxi(int(pending.get(player_id,0))-1,0)


func place_deck() -> void:
	if _deck != null:
		_deck.position = deck_position-CARD_SIZE/2.0+Vector2(2.5,-3.0)


func set_deck_visible(shown: bool) -> void:
	if _deck != null:
		_deck.visible = shown


## target_provider resolves the current fan slot as new cards enter the hand.
## origin preserves the existing theft animation: stolen cards leave a profile.
func draw_card(player_id: int, card_id: StringName, local: bool, target: Vector2, on_arrive: Callable = Callable(), reserved: bool = false, origin: Vector2 = Vector2(INF,INF), target_provider: Callable = Callable()) -> void:
	if local and not reserved:
		reserve(player_id)
	in_flight += 1
	_queue.append({"player":player_id,"id":card_id,"local":local,"target":target,"arrive":on_arrive,"origin":origin,"provider":target_provider})
	_start_next()


func busy() -> bool:
	return in_flight > 0


## No detached timers/tweens can reinsert a card after a new game or clear.
func clear() -> void:
	_queue.clear()
	_current.clear()
	for child: Node in get_children():
		if child != _deck:
			child.queue_free()
	pending.clear()
	in_flight = 0
	_gap = 0.0


func _start_next() -> void:
	if not _current.is_empty() or _queue.is_empty() or _gap > 0.0:
		return
	_current = _queue.pop_front()
	var start: Vector2 = _current.origin if (_current.origin as Vector2).is_finite() else deck_position
	var card := Control.new()
	card.name = "DrawnCard"
	card.set_meta("local",bool(_current.local))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = CARD_SIZE
	card.pivot_offset = CARD_SIZE/2.0
	var back := CardBack.new()
	back.size = CARD_SIZE
	card.add_child(back)
	add_child(card)
	_current.merge({"card":card,"back":back,"start":start,"lifted":start+Vector2(-12.0,-POP_RISE),"reveal":reveal_position,"time":0.0,"face":false})
	place_deck()
	Sfx.play(&"card_pick",-5.0)
	_apply_card(0.0)


func _process(delta: float) -> void:
	if _current.is_empty():
		_gap = maxf(_gap-delta,0.0)
		_start_next()
		return
	_current.time = float(_current.time)+delta
	_apply_card(float(_current.time))
	var duration: float = LOCAL_TIME if bool(_current.local) else POP_TIME+OTHER_FLY_TIME
	if float(_current.time) >= duration:
		_arrive()


func _ease(u: float) -> float:
	return smoothstep(0.0,1.0,clampf(u,0.0,1.0))


func _pose(card: Control, point: Vector2, card_scale: Vector2, angle: float) -> void:
	card.scale = card_scale
	card.rotation = angle
	card.position = point-CARD_SIZE/2.0


func _curve(from: Vector2, bend: Vector2, to: Vector2, u: float) -> Vector2:
	return from*pow(1.0-u,2.0)+bend*2.0*(1.0-u)*u+to*u*u


func _apply_card(t: float) -> void:
	var card: Control = _current.card
	var start: Vector2 = _current.start
	var lifted: Vector2 = _current.lifted
	var reveal: Vector2 = _current.reveal
	card.modulate.a = clampf(t/0.045,0.0,1.0)
	if t < POP_TIME:
		card.set_meta("phase",&"draw")
		var u: float = _ease(t/POP_TIME)
		_pose(card,start.lerp(lifted,u),Vector2.ONE,-0.12*u)
		return
	if not bool(_current.local):
		card.set_meta("phase",&"deliver_back")
		var u: float = _ease((t-POP_TIME)/OTHER_FLY_TIME)
		var to: Vector2 = _current.target
		_pose(card,_curve(lifted,lifted.lerp(to,0.5)+Vector2(0,-80),to,u),Vector2.ONE*lerpf(1.0,OTHER_END_SCALE,u),lerpf(-0.12,0.0,u))
		return
	if t < POP_TIME+TAKE_TIME:
		card.set_meta("phase",&"carry_back")
		var u: float = _ease((t-POP_TIME)/TAKE_TIME)
		_pose(card,_curve(lifted,lifted.lerp(reveal,0.5)+Vector2(0,-65),reveal,u),Vector2.ONE*lerpf(1.0,REVEAL_SCALE,u),-0.12*(1.0-u))
		return
	var flip: float = clampf((t-POP_TIME-TAKE_TIME)/(FLIP_HALF*2.0),0,1)
	if flip >= 0.5 and not bool(_current.face):
		_show_face()
	if flip < 1.0:
		card.set_meta("phase",&"flip")
		_pose(card,reveal,Vector2(absf(cos(PI*flip)),1.0)*REVEAL_SCALE,0.0)
		return
	var flight_start: float = POP_TIME+TAKE_TIME+FLIP_HALF*2.0+SHOW_TIME
	if t < flight_start:
		card.set_meta("phase",&"show")
		_pose(card,reveal,Vector2.ONE*REVEAL_SCALE,0.0)
		return
	card.set_meta("phase",&"hand")
	var u: float = _ease((t-flight_start)/FLY_TIME)
	var destination: Dictionary = {"position":_current.target,"rotation":0.0}
	var provider: Callable = _current.provider
	if provider.is_valid():
		destination = provider.call()
	var to: Vector2 = destination.position
	var bend: Vector2 = reveal.lerp(to,0.5)+Vector2(85.0,-30.0)
	_pose(card,_curve(reveal,bend,to,u),Vector2.ONE*lerpf(REVEAL_SCALE,HAND_SIZE.x/CARD_SIZE.x,u),float(destination.rotation)*u)


func _show_face() -> void:
	_current.face = true
	(_current.back as Control).hide()
	if face_builder.is_valid():
		var face: Control = face_builder.call(_current.id)
		if face != null:
			face.scale = CARD_SIZE/HAND_SIZE
			(_current.card as Control).add_child(face)
	Sfx.play(&"card_pick")


func _arrive() -> void:
	var job: Dictionary = _current
	_current = {}
	(job.card as Control).queue_free()
	in_flight = maxi(in_flight-1,0)
	_gap = STAGGER
	if bool(job.local):
		release(int(job.player))
	Sfx.play(&"card_get")
	var callback: Callable = job.arrive
	if callback.is_valid():
		callback.call()
	landed.emit(int(job.player),bool(job.local))
	if in_flight == 0:
		drained.emit()


func _build_deck() -> void:
	_deck = Control.new()
	_deck.name = "DeckPile"
	_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in 3:
		var back := CardBack.new()
		back.size = CARD_SIZE
		back.position = Vector2(-index*2.5,index*3.0)
		back.rotation = deg_to_rad(-4.0+index*3.5)
		_deck.add_child(back)
		_deck.move_child(back,0)
	add_child(_deck)
