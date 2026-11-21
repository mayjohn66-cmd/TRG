## The sword and its crack stay planted, become one print composition and carry left.
extends Control
const ART=preload("res://scenes/cutscene_print_art.gd")
const SOURCE=preload("res://assets/fx/law_fx/arena_sword_v01.webp")
const CRACK=preload("res://assets/fx/law_fx/arena_crack_v01.webp")
const PRINT=preload("res://scenes/planted_sword_print.gdshader")
const IMPACT_AT:=0.54
const MORPH_AT:=1.10
const PRINT_AT:=2.30
const INTRO_SECONDS:=2.65
const HANDOFF_SECONDS:=0.70
const STOP_AT:=INTRO_SECONDS+HANDOFF_SECONDS
const FADE_SECONDS:=0.42
const MOTIF=preload("res://scenes/victory_motif_layout.gd")
var native: TextureRect
var print_art: TextureRect
var _ground: Ground
var _focus:=Vector2.ZERO
var _reference:=Vector2.ONE
var _aspect:=0.35
var time:=0.0
var _last_time:=-99.0
var _last_view:=Vector2.ZERO

class Ground extends Control:
	var stage: Control
	func _draw() -> void:stage.paint_ground(self)

func _init() -> void:
	name="MochiSlayerStage";mouse_filter=Control.MOUSE_FILTER_IGNORE;set_process(false)

func _ink(erase: bool, whole: bool = false) -> ShaderMaterial:
	var result:=ShaderMaterial.new();result.shader=PRINT
	result.set_shader_parameter("erase",erase);result.set_shader_parameter("whole_surface",whole)
	return result

func setup(focus: Vector2, reference: Vector2) -> void:
	_focus=focus;_reference=reference
	_ground=Ground.new();_ground.stage=self;_ground.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_ground.material=_ink(false,true);add_child(_ground)
	var original:=AtlasTexture.new();original.atlas=SOURCE;original.region=PaintedFx.region(SOURCE)
	_aspect=original.region.size.x/original.region.size.y
	native=ART.picture(original);native.material=_ink(true);add_child(native)
	# Both layers use precisely the same sword; the buried silhouette never changes.
	print_art=ART.picture(original);print_art.material=_ink(false);add_child(print_art)

static func depth(t: float) -> float:
	var push:=clampf((t-IMPACT_AT)/(0.80-IMPACT_AT),0,1)
	return 0.50*(1-pow(1-push,3))

func pose(t: float, view: Vector2) -> Dictionary:
	t=minf(t,STOP_AT)
	var move:=smoothstep(MORPH_AT,STOP_AT,t)
	var ground:=(_focus*view/_reference).lerp(Vector2(0.26,0.61)*view,move)
	var fall:=clampf((t-0.12)/(IMPACT_AT-0.12),0,1)
	var drop:=(1-fall*fall)*view.y*1.15
	var height:=view.y*lerpf(0.74,1.40,move)
	var buried:=depth(t)
	var top:=ground.y-height*(1-buried)-drop
	return {"center":Vector2(ground.x,top+height*0.5),"extent":Vector2(height*_aspect,height),"fraction":clampf((ground.y-top)/height,0,1),"depth":buried,"tip_y":top+height,"ground":ground,"angle":0.0,"move":move,"scale":height/(view.y*0.74)}

func seek(t: float, view: Vector2) -> void:
	time=minf(t,STOP_AT);size=view
	if native==null or (time==_last_time and view==_last_view):return
	_last_time=time;_last_view=view
	var frame:=pose(time,view);var ink:=smoothstep(MORPH_AT,PRINT_AT,time)
	var strength:=MOTIF.opacity("LAW_01",time,PRINT_AT,STOP_AT)
	for picture: TextureRect in [native,print_art]:
		picture.size=frame["extent"];picture.pivot_offset=picture.size*0.5
		picture.position=frame["center"]-picture.size*0.5;picture.rotation=0.0
		picture.visible=ink<1 if picture==native else ink>0
		picture.modulate.a=strength
		var material:=picture.material as ShaderMaterial
		material.set_shader_parameter("amount",ink);material.set_shader_parameter("print_scale",view.y/768.0)
		material.set_shader_parameter("dimensions",picture.size)
		material.set_shader_parameter("visible_fraction",float(frame["fraction"]))
	var ground_ink:=_ground.material as ShaderMaterial
	ground_ink.set_shader_parameter("amount",ink);ground_ink.set_shader_parameter("print_scale",view.y/768.0)
	_ground.size=view;_ground.queue_redraw()
	_ground.modulate.a=strength

func paint_ground(canvas: CanvasItem) -> void:
	var age:=time-IMPACT_AT
	if age<0:return
	var frame:=pose(time,size);var at: Vector2=frame["ground"]
	var ratio:=size.y/768.0*float(frame["scale"])
	PaintedFx.stamp(canvas,CRACK,at,Vector2(310,74)*ratio,Color.WHITE)
	if age<0.38:
		var burst:=clampf(age/0.32,0,1)
		PaintedFx.stamp(canvas,PaintedFx.DUST,at-Vector2(0,8)*ratio,Vector2(320,75)*ratio*(0.5+burst),Color(1,0.88,0.65,(1-burst)*0.8))
		PaintedFx.stamp(canvas,PaintedFx.IMPACT,at,Vector2(340,65)*ratio,Color(1,0.88,0.54,(1-burst)*0.8))
