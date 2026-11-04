## The real basic-token sprite staggers, falls left, then becomes matching print art.
extends Control
const ART = preload("res://scenes/cutscene_print_art.gd")
const INTRO_SECONDS := 2.80
const FALL_AT := 0.98
const IMPACT_AT := 1.58
const MORPH_AT := 1.92
const PRINT_AT := 2.50
const HANDOFF_SECONDS := 0.65
const FADE_SECONDS := 0.42
const MOTIF=preload("res://scenes/victory_motif_layout.gd")
var token: TextureRect
var print_art: TextureRect
var _focus := Vector2.ZERO
var _reference := Vector2.ONE
var _aspect := 0.65
var time := 0.0
var _last_time := -99.0
var _last_view := Vector2.ZERO

func _init() -> void:
	name="PermaDeathStage";mouse_filter=Control.MOUSE_FILTER_IGNORE;set_process(false)

func setup(focus: Vector2, reference: Vector2) -> void:
	_focus=focus;_reference=reference
	var sheet := TextureCache.fetch("res://assets/fx/law_fx/victory_prints/basic_pawn_cutscene_v02.webp")
	var crop := AtlasTexture.new();crop.atlas=sheet;crop.region=PaintedFx.region(sheet)
	_aspect=crop.region.size.x/crop.region.size.y
	token=ART.picture(crop);token.material=ART.material(true,false,true)
	add_child(token)
	print_art=ART.picture(ART.fallen_pawn());print_art.material=ART.material()
	add_child(print_art)

func frame(t: float, view: Vector2) -> Dictionary:
	t=minf(t,INTRO_SECONDS+HANDOFF_SECONDS)
	var ratio := minf(view.x/1366.0,view.y/768.0)
	var enter := smoothstep(0.05,0.30,t)
	var height := view.y*0.36*lerpf(0.78,1.0,enter)
	var extent := Vector2(height*_aspect,height)
	var fall := clampf((t-FALL_AT)/(IMPACT_AT-FALL_AT),0,1)
	var lean := sin(t*17.0)*(0.07+0.12*clampf(t/FALL_AT,0,1))
	var stop_lean := sin(FALL_AT*17.0)*0.19
	var angle := lean if t<FALL_AT else lerpf(stop_lean,-PI*0.5,fall*fall)
	var ground := _focus*view/_reference+Vector2(0,55)*ratio
	if t<FALL_AT: ground+=Vector2(sin(t*13.0)*14.0,-absf(sin(t*13.0))*4.0)*ratio
	var center := ground+Vector2(0,-height*0.5).rotated(angle)
	var flat := Vector2(height,extent.x)
	var handoff := smoothstep(INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS,t)
	var target_width := view.x*1.02
	var picture_aspect := print_art.texture.get_height()/float(print_art.texture.get_width())
	var print_extent := flat.lerp(Vector2(target_width,target_width*picture_aspect),handoff)
	center=center.lerp(Vector2(0.32,0.58)*view,handoff)
	return {"ground":ground,"native_extent":extent,"angle":angle,"center":center,"print_extent":print_extent}

func seek(t: float, view: Vector2) -> void:
	time=minf(t,INTRO_SECONDS+HANDOFF_SECONDS);size=view
	if token==null:return
	if time==_last_time and view==_last_view:return
	_last_time=time;_last_view=view
	var pose := frame(t,view)
	var native_extent: Vector2=pose["native_extent"]
	token.size=native_extent;token.pivot_offset=Vector2(native_extent.x*0.5,native_extent.y)
	token.position=pose["ground"]-token.pivot_offset;token.rotation=pose["angle"]
	var mix := smoothstep(MORPH_AT,PRINT_AT,t)
	print_art.size=pose["print_extent"];print_art.position=pose["center"]-print_art.size*0.5
	print_art.visible=mix>0;token.visible=mix<1
	print_art.modulate.a=MOTIF.opacity("LAW_06",time,INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS)
	for picture: TextureRect in [token,print_art]:
		var ink := picture.material as ShaderMaterial
		ink.set_shader_parameter("dimensions",picture.size);ink.set_shader_parameter("amount",mix)
	queue_redraw()

func _draw() -> void:
	if token==null:return
	var pose := frame(time,size)
	var age := time-IMPACT_AT
	if age>=0 and age<0.28:
		var k := age/0.28
		PaintedFx.stamp(self,PaintedFx.DUST,pose["center"]+Vector2(0,35)*size.y/768.0,Vector2(320,90)*size.y/768.0*(0.6+k),Color(1,0.86,0.75,(1-k)*0.65))
