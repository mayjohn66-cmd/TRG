## SUPER_04: projected warning -> staggered impact -> bury -> armed tile handoff.
## Uses existing mine/warning art. Simulation, trap secrecy and card delivery stay intact.
extends Node2D

const WARNING_END := 0.62
const DROP_TIME := 0.36
const STAGGER := 0.28
const LAND_HOLD := 0.16
const BURY_TIME := 0.22
var elapsed := 0.0
var pace := 1.0
var phase: StringName = &"warning"
var tiles: Array[int] = []
var landed: Array[int] = []
var armed: Array[int] = []
var artwork: Dictionary = {}
var warning_art: Texture2D
var _complete := false
var _board_ref: WeakRef
var _generation := 0
var _floor: FloorInk
var _announced_armed := false

func play(board: MainBoard, targets: Array[int], speed: float) -> void:
	name = "MinefieldStage"
	z_index = 14
	_board_ref = weakref(board)
	_generation = board._fx_generation
	pace = clampf(speed,0.35,2.0)
	tiles.assign(targets)
	artwork = PawnArt.load_sprite(["res://assets/board/structures/MINE.png"])
	warning_art = BoardSkin.warning_texture()
	for tile: int in tiles:
		board._trap_pending[tile] = get_instance_id()
	board._refresh_tiles()
	_floor = FloorInk.new()
	_floor.name = "MinefieldFloorInk"
	_floor.stage_ref = weakref(self)
	board._board_layer.add_child(_floor)
	_floor.transform = board._board_layer.get_global_transform().affine_inverse()*board.get_global_transform()
	Sfx.play(&"attack_alert",-5.0)

func arm_time(index: int) -> float:
	return WARNING_END+index*STAGGER+DROP_TIME+LAND_HOLD+BURY_TIME

func total_time() -> float:
	return arm_time(maxi(tiles.size()-1,0))+0.48

func _process(delta: float) -> void:
	if _board_ref==null:
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null or board._fx_generation!=_generation:
		queue_free()
		return
	elapsed += delta/pace
	phase = &"warning" if elapsed<WARNING_END else (&"plant" if elapsed<arm_time(tiles.size()-1) else &"armed")
	var dirty := false
	for index: int in tiles.size():
		var tile := tiles[index]
		var impact := WARNING_END+index*STAGGER+DROP_TIME
		if elapsed>=impact and not landed.has(tile):
			landed.append(tile)
			Sfx.play(&"thud",-6.0)
			board.screen_shake(2.8,0.10)
		if elapsed>=arm_time(index) and not armed.has(tile):
			armed.append(tile)
			_release_tile(board,tile)
			dirty = true
	if dirty:
		board._refresh_tiles()
	if phase==&"armed" and not _announced_armed:
		_announced_armed = true
		Sfx.play(&"build_mine",-4.0)
	_floor.transform = board._board_layer.get_global_transform().affine_inverse()*board.get_global_transform()
	_floor.queue_redraw()
	queue_redraw()
	if elapsed>=total_time():
		_complete = true
		set_process(false)

func _target(board: MainBoard, tile: int) -> Vector2:
	return board._pawn_layer.transform*board._tile_center(tile)

func _tile_frame(board: MainBoard, tile: BoardSkin.Tile) -> Transform2D:
	return board.get_global_transform().affine_inverse()*tile.get_global_transform()

func draw_floor(ink: Node2D) -> void:
	var board: MainBoard = _board_ref.get_ref()
	if board==null:
		return
	for index: int in tiles.size():
		var tile: BoardSkin.Tile = board._tile_views.get(tiles[index])
		if tile==null:
			continue
		var impact := WARNING_END+index*STAGGER+DROP_TIME
		var fade := 1.0-smoothstep(arm_time(index)+0.14,total_time(),elapsed)
		var pulse := 0.55+0.45*pow(sin(elapsed*8.0),2.0)
		var frame := _tile_frame(board,tile)
		var points := PackedVector2Array()
		for point: Vector2 in tile.layers[-1]:
			points.append(frame*point)
		var edge := points.duplicate()
		edge.append(edge[0])
		ink.draw_colored_polygon(points,Color(0.95,0.17,0.10,0.28*pulse*fade))
		ink.draw_polyline(edge,Color(1.0,0.31,0.13,0.88*fade),2.4,true)
		var warn_alpha := smoothstep(0.0,0.16,elapsed)*(1.0-smoothstep(impact-0.18,impact,elapsed))
		var footprint: Vector2 = tile.data.footprint
		var warning_frame := frame*BoardSkin.decal_frame(tile.plane,minf(footprint.x,footprint.y)*0.67,BoardSkin.symbol_axis(tile.index))
		ink.draw_set_transform_matrix(warning_frame)
		ink.draw_texture_rect(warning_art,Rect2(-32,-32,64,64),false,Color(1,1,1,warn_alpha))
		ink.draw_set_transform_matrix(Transform2D.IDENTITY)
		var foot := _target(board,tiles[index])
		var near := smoothstep(WARNING_END+index*STAGGER,impact,elapsed)
		if elapsed<arm_time(index):
			ink.draw_set_transform(foot,0,Vector2(1,0.37))
			ink.draw_circle(Vector2.ZERO,lerpf(7,18,near),Color(0.13,0.08,0.05,0.32*near))
			ink.draw_set_transform_matrix(Transform2D.IDENTITY)
		if armed.has(tiles[index]):
			var u := clampf((elapsed-arm_time(index))/0.42,0.0,1.0)
			ink.draw_polyline(edge,Color(1,0.86,0.49,(1-u)*0.9),5.0*(1-u)+1,true)

func _draw() -> void:
	if _board_ref==null or artwork.is_empty():
		return
	var board: MainBoard = _board_ref.get_ref()
	if board==null:
		return
	var region: Rect2 = artwork.region
	for index: int in tiles.size():
		var start := WARNING_END+index*STAGGER
		var impact := start+DROP_TIME
		if elapsed<start:
			continue
		var target := _target(board,tiles[index])
		var depth := board._depth_scale(BoardLayout.tile_norm(tiles[index]).y)
		var mine_size := region.size*(minf(48.0/region.size.x,43.0/region.size.y)*depth)
		var fall := clampf((elapsed-start)/DROP_TIME,0.0,1.0)
		var land := clampf((elapsed-impact)/LAND_HOLD,0.0,1.0)
		var bury := smoothstep(impact+LAND_HOLD,arm_time(index),elapsed)
		var foot := target+Vector2(-14*(1-fall),-190*(1-fall*fall))
		var squash := Vector2(1.0+0.20*sin(land*PI),1.0-0.18*sin(land*PI)) if elapsed>=impact else Vector2.ONE
		var size := mine_size*squash
		if bury<1.0:
			var visible_height := size.y*(1.0-bury)
			# Clip at the tile surface while the body sinks; the lamp goes last.
			var rect := Rect2(foot+Vector2(-size.x/2.0,-visible_height),Vector2(size.x,visible_height))
			var cropped := Rect2(region.position,Vector2(region.size.x,region.size.y*(1.0-bury)))
			draw_texture_rect_region(artwork.texture,rect,cropped,Color(1,1,1,smoothstep(0.0,0.1,fall)))
		if elapsed>=impact and elapsed<impact+0.32:
			var dust := clampf((elapsed-impact)/0.32,0,1)
			for piece: int in 7:
				var angle := piece*TAU/7.0
				var at := target+Vector2(cos(angle)*dust*33,sin(angle)*dust*12-13*sin(dust*PI))
				draw_circle(at,2.4*(1-dust),Color(0.53,0.37,0.23,(1-dust)*0.75))

func _release_tile(board: MainBoard, tile: int) -> void:
	var owner: Variant = board._trap_pending.get(tile)
	if owner is int and owner==get_instance_id():
		board._trap_pending.erase(tile)

func _exit_tree() -> void:
	if is_instance_valid(_floor):
		_floor.queue_free()
	var board: MainBoard = _board_ref.get_ref() if _board_ref!=null else null
	if board!=null:
		for tile: int in tiles:
			_release_tile(board,tile)
		if not board.is_queued_for_deletion() and board.state!=null:
			board._refresh_tiles()

class FloorInk extends Node2D:
	var stage_ref: WeakRef

	func _draw() -> void:
		var stage: Node2D = stage_ref.get_ref() if stage_ref!=null else null
		if stage!=null:
			stage.draw_floor(self)
