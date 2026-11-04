## Preview-only center strike. Visual copies fly; board and simulation remain in place.
extends Control
const INTRO_SECONDS := 2.65
const HANDOFF_SECONDS := 0.85
const IMPACT_AT := 0.66
const ART = preload("res://scenes/cutscene_print_art.gd")
const TORNADO: Texture2D = preload("res://assets/fx/law_fx/victory_prints/hurricane_tornado_v02.png")
const TRAP_BACK:Texture2D=preload("res://assets/board/traps/HIDDEN.png")
var time := 0.0
var landed := false
var contact_point := Vector2.ZERO
var focus := Vector2(683,335)
var _reference := Vector2(1366,768)
var _tornado: TextureRect
var _wind: ShaderMaterial
var _debris: Array[Dictionary] = []
var _tiles: Array[Dictionary] = []
var _hidden := false

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_process(false)
	var crop:=AtlasTexture.new()
	crop.atlas=TORNADO;crop.region=PaintedFx.region(TORNADO)
	_tornado=ART.picture(crop)
	_tornado.name="CenterStrikeHurricane"
	_wind=ShaderMaterial.new()
	_wind.shader=preload("res://scenes/hurricane_wind.gdshader")
	_tornado.material=_wind
	add_child(_tornado)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():restore_board())

func setup(center:Vector2, reference:Vector2) -> void:
	focus=center;_reference=reference

## Snapshot presentation nodes only; never remove an attachment or move a PlayerPawn.
func set_board_context(board:Node) -> void:
	restore_board()
	for entry:Dictionary in _debris:
		(entry.copy as Node).queue_free()
	_debris.clear();_tiles.clear()
	_reference=get_viewport_rect().size
	focus=board.get_global_transform_with_canvas()*(board._surface_project(Vector2.ONE*0.5)+board._off_center)
	for pawn:PlayerPawn in board.state.pawns:
		if not pawn.has_left_start or pawn.is_finished:continue
		var original:Node2D=board._pawn_views.get(pawn.entity_id)
		if original==null or not original.is_visible_in_tree():continue
		var token:PawnToken=original.get_node("Bounce/Token")
		var copy:=PawnToken.new()
		copy.ground_shadow=false;copy.shield_motion=false
		copy.configure(pawn,token.owner_color,token.use_art)
		add_child(copy);copy.set_process(false);copy.hide()
		var frame:=token.get_global_transform_with_canvas()
		_debris.append({"copy":copy,"original":original,"visible":original.visible,"from":frame.origin,"scale":frame.get_scale(),"angle":frame.get_rotation(),"kind":"pawn"})
	for index:int in board._trap_tiles:
		var tile:BoardSkin.Tile=board._tile_views[index]
		if not tile.trap_on or tile.trap_icon==null:continue
		_tiles.append({"node":tile,"icon":tile.trap_icon,"pulse":tile.trap_pulse})
		var copy:=Sprite2D.new()
		# The lifted card turns its common back toward the viewer; no hidden identity leaks.
		copy.texture=TRAP_BACK;copy.region_enabled=true
		copy.region_rect=BoardSkin.trap_region(TRAP_BACK)
		var extent:=Vector2(64,64)*copy.region_rect.size/maxf(copy.region_rect.size.x,copy.region_rect.size.y)
		copy.scale=extent/copy.region_rect.size
		var carrier:=Node2D.new();carrier.add_child(copy)
		add_child(carrier);carrier.hide()
		var direction:=Vector2.RIGHT if tile.data.major else BoardSkin.symbol_axis(index)
		var frame:Transform2D=tile.get_global_transform_with_canvas()*BoardSkin.decal_frame(tile.plane,minf(tile.data.footprint.x,tile.data.footprint.y)*0.86,direction)
		_debris.append({"copy":carrier,"original":null,"from":frame.origin,"scale":frame.get_scale(),"angle":frame.get_rotation(),"kind":"trap"})
	move_child(_tornado,0)

func restore_board() -> void:
	if _hidden:
		for entry:Dictionary in _debris:
			var original:CanvasItem=entry.original
			if is_instance_valid(original):original.visible=entry.visible
		for entry:Dictionary in _tiles:
			var tile:BoardSkin.Tile=entry.node
			if is_instance_valid(tile):
				tile.set_trap(true,entry.icon)
				tile.set_trap_pulse(entry.pulse)
	_hidden=false;landed=false
	for entry:Dictionary in _debris:
		if is_instance_valid(entry.copy):entry.copy.hide()

func _exit_tree() -> void:
	restore_board()

func seek(seconds:float, view:Vector2) -> void:
	time=seconds;size=view
	var unit:float=minf(view.x/1366.0,view.y/768.0)
	var handoff:float=smoothstep(INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS,seconds)
	contact_point=focus*view/_reference
	if seconds<IMPACT_AT and _hidden:restore_board()
	if seconds>=IMPACT_AT and not _hidden:
		for entry:Dictionary in _debris:
			var original:CanvasItem=entry.original
			if is_instance_valid(original):original.hide()
		for entry:Dictionary in _tiles:
			var tile:BoardSkin.Tile=entry.node
			if is_instance_valid(tile):tile.set_trap(false)
		_hidden=true
	landed=seconds>=IMPACT_AT
	var approach:float=pow(smoothstep(0.08,IMPACT_AT,seconds),2.1)
	var contact:float=clampf((seconds-IMPACT_AT)/0.18,0,1)
	var squash:float=sin(contact*PI)*0.10
	var extent:Vector2=Vector2(550*(1+squash),640*(1-squash))*unit
	extent=extent.lerp(Vector2(520,610)*unit,handoff)
	var anchor:Vector2=contact_point+Vector2(0,-view.y*1.15*(1-approach))
	anchor=anchor.lerp(view*Vector2(0.34,0.91),handoff)
	_tornado.size=extent
	# Cropped dust-base center is the contact point; no sideways oscillation at impact.
	_tornado.position=anchor-extent*Vector2(0.50,0.96)
	_tornado.modulate=Color(1,1,1,smoothstep(0.02,0.15,seconds)*lerpf(1.0,0.66,handoff))
	_wind.set_shader_parameter("wind_time",lerpf(seconds,INTRO_SECONDS,handoff))
	_wind.set_shader_parameter("print_lock",handoff)
	for i:int in _debris.size():
		var entry:Dictionary=_debris[i]
		var copy:Node2D=entry.copy
		var flight:float=maxf(0,seconds-IMPACT_AT-0.055)
		var from:Vector2=entry.from*view/_reference
		var radial:Vector2=(from-contact_point).normalized()
		if radial.is_zero_approx():radial=Vector2.from_angle(i*2.399)
		var tangent:=Vector2(-radial.y,radial.x)
		var launch:Vector2=(radial*510+tangent*170)*unit
		copy.visible=_hidden and seconds<2.45
		copy.position=from+launch*flight+radial*flight*flight*170*unit+Vector2(0,-280*flight+55*flight*flight)*unit
		copy.rotation=float(entry.angle)+flight*(3.8 if i%2==0 else -4.6)
		var growth:float=lerpf(1.0,2.15,smoothstep(0.0,0.20,flight)) if entry.kind=="trap" else 1+minf(flight,0.7)*0.65
		copy.scale=entry.scale*view/_reference*growth
		copy.modulate=Color(0.78,0.78,0.78,1-smoothstep(1.55,2.35,seconds))
	queue_redraw()

func _draw() -> void:
	var strike:float=clampf((time-IMPACT_AT)/0.23,0,1)
	if strike>0 and strike<1:
		PaintedFx.stamp(self,PaintedFx.DUST,contact_point,Vector2(165,52)*(0.7+strike),Color(0.85,1.0,0.90,(1-strike)*0.8))
