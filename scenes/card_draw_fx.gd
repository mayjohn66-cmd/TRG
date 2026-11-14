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
## 뒤에 기다리는 카드 한 장마다 지금 카드의 재생 속도에 더하는 배수 (여러 장을 한꺼번에 받을 때 연출이 길게 늘어지지 않게).
const BATCH_SPEEDUP: float = 0.7
## 묶음으로 받은 카드의 최소 재생 배속 (마지막 장 포함).
const BATCH_MIN_RATE: float = 1.5

var deck_position := Vector2(1040.0,510.0)
var reveal_position := Vector2(683.0,320.0)
var face_builder: Callable = Callable()
var pending: Dictionary = {}
var in_flight: int = 0
var _deck: Control = null
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _gap: float = 0.0
## 다 쓴 카드 껍데기 (다음 카드에 다시 쓴다).
const MAX_IDLE_SHELLS: int = 4
var _idle_shells: Array[Control] = []


## Portrait card projected flat onto the table, with its key facing right.
static func deck_transform() -> Transform2D:
	var frame := Transform2D(Vector2(0.28,0.62),Vector2(-1.10,0.23),Vector2.ZERO)
	frame.origin = -frame.basis_xform(CARD_SIZE/2.0)
	return frame


static func deck_outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2.ZERO,Vector2(CARD_SIZE.x,0),CARD_SIZE,Vector2(0,CARD_SIZE.y)]:
		var point: Vector2 = deck_transform()*corner
		points.append(point)
		points.append(point+Vector2(0,12))
	return Geometry2D.convex_hull(points)


## White paper edges make the pile read as a flat stack rather than a fan.
class DeckPile extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var top := PackedVector2Array()
		for corner: Vector2 in [Vector2.ZERO,Vector2(CardDrawFX.CARD_SIZE.x,0),CardDrawFX.CARD_SIZE,Vector2(0,CardDrawFX.CARD_SIZE.y)]:
			top.append(CardDrawFX.deck_transform()*corner)
		var shadow := PackedVector2Array()
		for point: Vector2 in top:
			shadow.append(point+Vector2(2,17))
		draw_colored_polygon(shadow,Color(0.03,0.04,0.06,0.28))
		for edge: int in [1,2]:
			var a: Vector2 = top[edge]
			var b: Vector2 = top[(edge+1)%4]
			draw_colored_polygon(PackedVector2Array([a,b,b+Vector2(0,12),a+Vector2(0,12)]),Color("fff8e7") if edge==1 else Color("ddd5bf"))
			for layer: int in range(2,13,2):
				draw_line(a+Vector2(0,layer),b+Vector2(0,layer),Color("c6bca2"),0.7,true)
			draw_line(a+Vector2(0,12),b+Vector2(0,12),Color("755330"),1.0,true)


## Navy back, warm gold frame and a simple key emblem, matching the reference.
class CardBack extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var body := StyleBoxFlat.new()
		body.bg_color = Color("18263f")
		body.border_color = Color("dc9d37")
		body.set_border_width_all(3)
		body.set_corner_radius_all(9)
		body.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		body.shadow_size = 4
		draw_style_box(body, rect)
		var inner := StyleBoxFlat.new()
		inner.bg_color = Color("20314c")
		inner.border_color = Color(1.0, 0.85, 0.3, 0.55)
		inner.set_border_width_all(1)
		inner.set_corner_radius_all(6)
		draw_style_box(inner, rect.grow(-7.0))
		var c: Vector2 = size / 2.0
		var gold := Color("f5c45c")
		var head: Vector2 = c+Vector2(0,-20)
		draw_arc(head,8.0,0,TAU,32,gold,3.0,true)
		draw_arc(head+Vector2(-5,-4),4.0,PI*0.5,PI*1.9,20,gold,2.0,true)
		draw_arc(head+Vector2(5,-4),4.0,PI*1.1,TAU*1.25,20,gold,2.0,true)
		draw_line(head+Vector2(0,8),head+Vector2(0,43),gold,3.0,true)
		draw_polyline(PackedVector2Array([head+Vector2(0,30),head+Vector2(7,30),head+Vector2(7,35)]),gold,3.0,true)
		draw_polyline(PackedVector2Array([head+Vector2(0,39),head+Vector2(7,39),head+Vector2(7,44)]),gold,3.0,true)


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
		_deck.position = deck_position


func set_deck_visible(shown: bool) -> void:
	if _deck != null:
		_deck.visible = shown


## target_provider resolves the current fan slot as new cards enter the hand.
## origin preserves the existing theft animation: stolen cards leave a profile.
func draw_card(player_id: int, card_id: StringName, local: bool, target: Vector2, on_arrive: Callable = Callable(), reserved: bool = false, origin: Vector2 = Vector2(INF,INF), target_provider: Callable = Callable(), grouped: bool = false, origin_provider: Callable = Callable()) -> void:
	if local and not reserved:
		reserve(player_id)
	in_flight += 1
	# 이미 날고 있거나 줄 선 카드가 있으면 한꺼번에 받는 묶음이다: 묶음의 카드는 마지막 장까지 조금 빨리 돈다
	var batch: bool = grouped or not _current.is_empty() or not _queue.is_empty()
	if batch and not _current.is_empty():
		_current["batch"] = true
	_queue.append({"player":player_id,"id":card_id,"local":local,"target":target,"arrive":on_arrive,"origin":origin,"provider":target_provider,"origin_provider":origin_provider,"batch":batch})
	_start_next()


func busy() -> bool:
	return in_flight > 0


## 날아가는 카드 껍데기(뒷면)는 다 쓰면 숨겨 두었다가 다음 카드에 다시 쓴다 (카드마다 노드를 새로 만들고 지우지 않게).
func _take_shell() -> Control:
	while not _idle_shells.is_empty():
		var shell: Control = _idle_shells.pop_back()
		if is_instance_valid(shell) and not shell.is_queued_for_deletion():
			shell.name = "DrawnCard"
			shell.remove_meta("phase")  # 앞 카드의 단계가 남지 않게
			shell.modulate = Color.WHITE
			shell.visible = true
			move_child(shell, -1)
			return shell
	var card := Control.new()
	card.name = "DrawnCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = CARD_SIZE
	card.pivot_offset = CARD_SIZE/2.0
	var back := CardBack.new()
	back.size = CARD_SIZE
	var surface := Node2D.new()
	surface.add_child(back)
	card.add_child(surface)
	card.set_meta(&"back_surface", surface)
	add_child(card)
	return card


## 도착한 카드: 앞면은 지우고 뒷면 껍데기만 숨겨 둔다 (MAX_IDLE_SHELLS개까지).
func _park_shell(card: Control) -> void:
	var surface: Node2D = card.get_meta(&"back_surface")
	for child: Node in card.get_children():
		if child != surface:
			child.queue_free()
	surface.show()
	if _idle_shells.size() >= MAX_IDLE_SHELLS:
		card.queue_free()
		return
	card.visible = false
	card.name = "IdleCardShell"
	_idle_shells.append(card)


## No detached timers/tweens can reinsert a card after a new game or clear.
func clear() -> void:
	_idle_shells.clear()
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
	var card: Control = _take_shell()
	card.set_meta("local",bool(_current.local))
	var surface: Node2D = card.get_meta(&"back_surface")
	_current.merge({"card":card,"back":surface,"start":start,"lifted":start+Vector2(-12.0,-POP_RISE),"reveal":reveal_position,"time":0.0,"face":false,"from_deck":not (_current.origin as Vector2).is_finite()})
	place_deck()
	Sfx.play(&"card_pick",-5.0)
	_apply_card(0.0)


func _process(delta: float) -> void:
	if _current.is_empty():
		_gap = maxf(_gap-delta,0.0)
		_start_next()
		return
	# 뒤에 카드가 줄 서 있으면(초증강·패키지로 여러 장) 뽑기·옮기기·날아가기를 빨리 감는다: 한 장만 받으면 원래 속도, 줄이 길수록 최대 3.1배, 묶음은 최소 1.5배.
	var rate: float = 1.0+BATCH_SPEEDUP*float(mini(_queue.size(),3))
	if bool(_current.get("batch",false)):
		rate = maxf(rate,BATCH_MIN_RATE)
	if (_current.card as Control).get_meta("phase",&"") == &"show":
		rate = 1.0  # 앞면을 크게 보여 주는 동안은 원래 속도 (읽을 틈)
	_current.time = float(_current.time)+delta*rate
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
	var start: Vector2 = deck_position if bool(_current.from_deck) else _current.start
	var origin_provider: Callable = _current.get("origin_provider",Callable())
	if origin_provider.is_valid():
		var current_origin: Vector2 = origin_provider.call()
		if current_origin.is_finite(): start = current_origin
	var lifted := start+Vector2(-12.0,-POP_RISE)
	var reveal := reveal_position
	_current.start = start
	_current.lifted = lifted
	_current.reveal = reveal
	var upright: float = _ease((t-POP_TIME)/(TAKE_TIME if bool(_current.local) else OTHER_FLY_TIME))
	var surface: Node2D = _current.back
	var frame: Transform2D = deck_transform() if bool(_current.from_deck) else Transform2D.IDENTITY
	frame.origin = Vector2.ZERO
	frame = frame.interpolate_with(Transform2D.IDENTITY,upright)
	frame.origin = CARD_SIZE/2.0-frame.basis_xform(CARD_SIZE/2.0)
	surface.transform = frame
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
		var provider: Callable = _current.provider
		if provider.is_valid():
			var destination: Dictionary = provider.call()
			if (destination.position as Vector2).is_finite(): to = destination.position
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
	(_current.back as CanvasItem).hide()
	if face_builder.is_valid():
		var face: Control = face_builder.call(_current.id)
		if face != null:
			face.scale = CARD_SIZE/HAND_SIZE
			(_current.card as Control).add_child(face)
	Sfx.play(&"card_pick")


func _arrive() -> void:
	var job: Dictionary = _current
	_current = {}
	_park_shell(job.card as Control)
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
	_deck = DeckPile.new()
	_deck.name = "DeckPile"
	_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := Node2D.new()
	surface.transform = deck_transform()
	var back := CardBack.new()
	back.size = CARD_SIZE
	surface.add_child(back)
	_deck.add_child(surface)
	add_child(_deck)
