## SUPER_02 presentation only: gather -> equalize -> shuffle -> return to live deck.
extends Node2D

signal finished

const ART = preload("res://scenes/redistribution_art.gd")
const GATHER_END := 0.55
const MOVE_START := 0.62
const MOVE_END := 1.22
const SHUFFLE_START := 1.30
const SHUFFLE_END := 1.80
const RETURN_START := 1.85
const RETURN_END := 2.22
const TOTAL_TIME := 2.28
var phase: StringName = &"gather"
var elapsed := 0.0
var pace := 1.0
var reference_player := -1
var pawns: Array[Dictionary] = []
var cards: Array[Dictionary] = []
var target_tiles: Array[int] = []
var hand_counts: Dictionary = {}
var _board_ref: WeakRef
var _generation := 0
var _sound_phase := -1
var _complete := false
var _local_sources: Dictionary = {}
var _floor: FloorInk

func play(board: MainBoard, changes: Array, speed: float) -> void:
	name = "RedistributionStage"
	z_index = 16
	pace = clampf(speed,0.35,2.0)
	_board_ref = weakref(board)
	_generation = board._fx_generation
	var local_owner := board._dock_owner()
	if board._dock!=null and board._dock.is_visible_in_tree():
		var index := 0
		for child: Node in board._dock.get_children():
			if child is Control and not child.is_queued_for_deletion():
				_local_sources[index] = board.get_global_transform().affine_inverse()*((child as Control).get_global_transform()*((child as Control).size/2.0))
				index += 1
	for change: Dictionary in changes:
		if change.kind=="redistribution":
			hand_counts = change.hands.duplicate()
			reference_player = int(change.reference)
		elif change.kind=="redistribution_pose":
			for pose: Dictionary in change.pawns:
				var view: Node2D = board._pawn_views.get(int(pose.pawn))
				if view==null:
					continue
				board._kill_fx(view)
				var moving: bool = view.position.distance_to(pose.position)>1.0 or view.visible!=bool(pose.visible)
				pawns.append({"view":weakref(view),"from":view.position,"to":pose.position,"was_visible":view.visible,"visible":pose.visible,"moving":moving,"z":view.z_index,"scale":view.scale,"modulate":view.modulate})
				if bool(pose.visible) and not target_tiles.has(int(pose.tile)):
					target_tiles.append(int(pose.tile))
	# Include a few backs from the existing deck: the returned hands join this deck.
	for index: int in mini(3,board.state.card_deck.size()):
		_add_card(0,index)
	for owner: int in hand_counts:
		for index: int in int(hand_counts[owner]):
			_add_card(owner,index,_local_sources.get(index,Vector2(INF,INF)) if owner==local_owner else Vector2(INF,INF))
	# Replace collected old faces with the already-reserved, hidden new hand.
	board._refresh_hands()
	_floor = FloorInk.new()
	_floor.name = "RedistributionFloorInk"
	_floor.stage_ref = weakref(self)
	board._board_layer.add_child(_floor)
	_floor.transform = board._board_layer.get_global_transform().affine_inverse()*get_global_transform()
	_update_pose(board)

func _add_card(owner: int, ordinal: int, source: Vector2 = Vector2(INF,INF)) -> void:
	var shell := Node2D.new()
	var back := PaintedBack.new()
	back.size = CardDrawFX.CARD_SIZE
	shell.add_child(back)
	shell.z_index = cards.size()
	add_child(shell)
	cards.append({"node":shell,"owner":owner,"ordinal":ordinal,"source":source})

func _process(delta: float) -> void:
	if _board_ref==null:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null or board._fx_generation!=_generation:
		queue_free()
		return
	elapsed += delta/pace
	phase = &"gather" if elapsed<MOVE_START else (&"equalize" if elapsed<SHUFFLE_START else (&"shuffle" if elapsed<RETURN_START else &"return"))
	_update_pose(board)
	var sound_phase := 0 if elapsed<MOVE_START else (1 if elapsed<SHUFFLE_START else (2 if elapsed<1.55 else (3 if elapsed<RETURN_START else 4)))
	if sound_phase!=_sound_phase:
		_sound_phase = sound_phase
		Sfx.play(&"warp" if sound_phase==1 else &"toy_click",-7.0)
	_floor.transform = board._board_layer.get_global_transform().affine_inverse()*get_global_transform()
	_floor.queue_redraw()
	if elapsed>=TOTAL_TIME:
		_complete = true
		set_process(false)
		finished.emit()

func _update_pose(board: MainBoard) -> void:
	var u := smoothstep(MOVE_START,MOVE_END,elapsed)
	for info: Dictionary in pawns:
		var view: Node2D = (info.view as WeakRef).get_ref()
		if view==null or not bool(info.moving):
			continue
		if elapsed<MOVE_START:
			view.position = info.from
			view.visible = info.was_visible
			continue
		view.z_index = 12
		view.visible = (bool(info.was_visible) or bool(info.visible)) and (u<1.0 or bool(info.visible))
		view.position = (info.from as Vector2).lerp(info.to,u)+Vector2(0,-50.0*sin(u*PI))
		view.rotation = clampf(((info.to as Vector2)-(info.from as Vector2)).x/1200.0,-0.18,0.18)*sin(u*PI)
		view.scale = (info.scale as Vector2)*(1.0+0.12*sin(u*PI))
		view.modulate.a = (1.0 if bool(info.was_visible) else smoothstep(0.0,0.3,u))*(1.0 if bool(info.visible) else 1.0-smoothstep(0.65,1.0,u))
	var center := board._board_center()+Vector2(0,35)
	var deck := board._draw_fx.deck_position
	for index: int in cards.size():
		var info: Dictionary = cards[index]
		var shell: Node2D = info.node
		var owner := int(info.owner)
		var source := deck if owner==0 else board._profile_center(owner)
		if (info.source as Vector2).is_finite():
			source = info.source
		var offset := Vector2((index%3)*1.7,-index*1.7)
		var flat := _flat_pose(center+offset,0.65)
		var delay := int(info.ordinal)*0.055
		var gather := smoothstep(delay,GATHER_END,elapsed)
		var start := _upright_pose(source,0.52,(-0.12 if index%2==0 else 0.12))
		if owner==0:
			start = _flat_pose(source,1.0)
		shell.transform = start.interpolate_with(flat,gather)
		shell.position.y -= sin(gather*PI)*55.0
		shell.modulate.a = smoothstep(delay,delay+0.10,elapsed)
		if elapsed>=SHUFFLE_START and elapsed<SHUFFLE_END:
			var shuffle := clampf((elapsed-SHUFFLE_START)/(SHUFFLE_END-SHUFFLE_START),0.0,1.0)
			var split := sin(shuffle*TAU)*sin(shuffle*PI)
			shell.position += Vector2(split*(46.0 if index%2==0 else -46.0),-absf(split)*10.0)
			shell.rotation += split*(0.12 if index%2==0 else -0.12)
		if elapsed>=RETURN_START:
			var returned := smoothstep(RETURN_START,RETURN_END,elapsed)
			shell.transform = flat.interpolate_with(_flat_pose(deck+offset*0.4,1.0),returned)
			shell.position.y -= sin(returned*PI)*28.0
			shell.modulate.a = 1.0-smoothstep(0.82,1.0,returned)

func _flat_pose(center: Vector2, scale_factor: float) -> Transform2D:
	var flat := CardDrawFX.deck_transform()
	return Transform2D(flat.x*scale_factor,flat.y*scale_factor,center+flat.origin*scale_factor)

func _upright_pose(center: Vector2, scale_factor: float, angle: float) -> Transform2D:
	var basis := Transform2D(angle,Vector2.ZERO).scaled_local(Vector2.ONE*scale_factor)
	basis.origin = center-basis.basis_xform(CardDrawFX.CARD_SIZE/2.0)
	return basis

func draw_floor(ink: Node2D) -> void:
	if _board_ref==null:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null:
		return
	var alpha := smoothstep(0.25,MOVE_START,elapsed)*(1.0-smoothstep(SHUFFLE_START,RETURN_START,elapsed))
	var seal_region := ART.region(ART.EXCHANGE,ART.EXCHANGE_REGION)
	var gather_alpha := smoothstep(0.0,0.18,elapsed)*(1.0-smoothstep(RETURN_START,RETURN_END,elapsed))
	# A painted exchange seal sits on the same floor plane as the collected deck.
	ink.draw_set_transform(board._board_center()+Vector2(0,35),0.0,Vector2(1,0.50))
	ink.draw_texture_rect_region(ART.EXCHANGE,Rect2(-88,-88,176,176),seal_region,Color(1,1,1,gather_alpha*0.82))
	ink.draw_set_transform_matrix(Transform2D.IDENTITY)
	for tile: int in target_tiles:
		var tile_view: BoardSkin.Tile = board._tile_views.get(tile)
		if tile_view==null:
			continue
		var footprint: Vector2 = tile_view.data.footprint
		var frame := get_global_transform().affine_inverse()*tile_view.get_global_transform()
		frame *= BoardSkin.decal_frame(tile_view.plane,minf(footprint.x,footprint.y)*0.72,BoardSkin.symbol_axis(tile))
		ink.draw_set_transform_matrix(frame)
		ink.draw_texture_rect_region(ART.EXCHANGE,Rect2(-32,-32,64,64),seal_region,Color(1,1,1,alpha*0.82))
	ink.draw_set_transform_matrix(Transform2D.IDENTITY)

class FloorInk extends Node2D:
	var stage_ref: WeakRef
	func _draw() -> void:
		var stage: Node2D = stage_ref.get_ref() if stage_ref!=null else null
		if stage!=null:
			stage.draw_floor(self)

## Local to this effect: the rest of the game's card presentation stays as it was.
class PaintedBack extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_texture_rect_region(ART.CARD_BACK,Rect2(Vector2.ZERO,size),ART.region(ART.CARD_BACK,ART.CARD_BACK_REGION))

func _exit_tree() -> void:
	if is_instance_valid(_floor):
		_floor.queue_free()
	var board: MainBoard = _board_ref.get_ref() if _board_ref!=null else null
	for info: Dictionary in pawns:
		var view: Node2D = (info.view as WeakRef).get_ref()
		if view==null or not bool(info.moving):
			continue
		view.z_index = int(info.z)
		view.scale = info.scale
		view.rotation = 0.0
		view.modulate = info.modulate
		if _complete:
			view.position = info.to
			view.visible = info.visible
		elif board!=null and board.state!=null:
			# Rewind/reset has already restored authoritative state; show that state.
			for pawn: PlayerPawn in board.state.pawns:
				if board._pawn_views.get(pawn.entity_id)==view:
					view.position = board._pawn_position(pawn)
					view.visible = pawn.has_left_start and not pawn.is_finished and pawn.carrier==null
					break
