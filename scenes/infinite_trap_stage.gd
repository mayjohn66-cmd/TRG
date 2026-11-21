## The complete planted-card hillside freezes and becomes ONE full-scene print.
extends Control
const COUNT:=18
const ROW_SIZE:=6
const FIELD_AT:=0.82
const FIELD_GAP:=0.065
const HERO_DROP_AT:=2.48
const IMPACT_AT:=3.08
const MORPH_AT:=3.74
const PRINT_AT:=4.38
const FREEZE_AT:=IMPACT_AT+0.42
const INTRO_SECONDS:=4.66
const HANDOFF_SECONDS:=0.92
const FADE_SECONDS:=0.42
const ART=preload("res://scenes/cutscene_print_art.gd")
const HILLS=preload("res://scenes/trap_hill_art.gd")
const SOURCE_PATH:="res://assets/fx/law_fx/victory_prints/infinite_trap_card_v01.webp"
const PRINT=preload("res://scenes/infinite_trap_print.gdshader")
const SCENE_PRINT=preload("res://scenes/trap_scene_print.gdshader")
const CRACK=preload("res://assets/fx/law_fx/arena_crack_v01.webp")
var field: Array[TextureRect]=[]
var hero: TextureRect
var tableau: CanvasGroup
var scene_ink: ShaderMaterial
var source: Texture2D
var _aspect:=0.72
var _last_time:=-99.0
var _last_sampled:=-99.0
var _last_view:=Vector2.ZERO
var _terrain: Terrain
var _ground: Ground
var time:=0.0

class Terrain extends Control:
	var stage: Control
	func _draw() -> void:HILLS.native(self,size,minf(stage.time,FREEZE_AT),1.0-stage.background_simplify())

class Ground extends Control:
	var stage: Control
	func _draw() -> void:stage.paint_ground(self)

func _init() -> void:
	name="InfiniteTrapStage";mouse_filter=Control.MOUSE_FILTER_IGNORE;set_process(false)

func _picture(texture: Texture2D, label: String, native: bool) -> TextureRect:
	var picture:=ART.picture(texture);picture.name=label
	var ink:=ShaderMaterial.new();ink.shader=PRINT;ink.set_shader_parameter("native_surface",native)
	picture.material=ink;tableau.add_child(picture)
	return picture

func setup(_focus: Vector2, _reference: Vector2) -> void:
	source=TextureCache.fetch_transient(SOURCE_PATH)
	var region:=PaintedFx.region(source);_aspect=region.size.x/region.size.y
	var crop:=AtlasTexture.new();crop.atlas=source;crop.region=region
	tableau=CanvasGroup.new();tableau.name="WholeHillIllustration";tableau.fit_margin=0;tableau.clear_margin=2
	scene_ink=ShaderMaterial.new();scene_ink.shader=SCENE_PRINT;tableau.material=scene_ink;add_child(tableau)
	_terrain=Terrain.new();_terrain.stage=self;_terrain.mouse_filter=Control.MOUSE_FILTER_IGNORE;tableau.add_child(_terrain)
	_ground=Ground.new();_ground.stage=self;_ground.mouse_filter=Control.MOUSE_FILTER_IGNORE;tableau.add_child(_ground)
	for i: int in COUNT:field.append(_picture(crop,"Planted2DTrap%d"%(i+1),true))
	hero=_picture(crop,"GiantCentralTrapCard",true)
	(hero.material as ShaderMaterial).set_shader_parameter("focal_card",true)

func background_simplify() -> float:
	return smoothstep(INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS,time)

static func _hash(i: int) -> float:
	return float(posmod(i*73+19,127))/126.0

static func field_impact_at(i: int) -> float:
	return FIELD_AT+float(i)*FIELD_GAP+0.36+_hash(i+6)*0.10

static func field_frame(t: float, i: int, view: Vector2, aspect: float) -> Dictionary:
	var layer:=i/ROW_SIZE;var column:=i%ROW_SIZE
	var x:=0.035+(float(column)+0.5+(_hash(i+3)-0.5)*0.36)/float(ROW_SIZE)*0.93
	if layer==2 and absf(x-0.5)<0.10:x+=0.10 if x>=0.5 else -0.10
	var ground:=Vector2(x*view.x,HILLS.ridge_y(layer,x)*view.y)
	var birth:=FIELD_AT+float(i)*FIELD_GAP
	var fall:=clampf((t-birth)/(field_impact_at(i)-birth),0,1)
	var height:=view.y*(0.075+float(layer)*0.035+_hash(i+2)*0.025)
	var drop:=view.y*0.95*(1-fall*fall)
	var center:=ground-Vector2(0,height*0.28+drop)
	var angle:=(_hash(i+9)-0.5)*0.32+sin(fall*PI)*0.09
	return {"center":center,"extent":Vector2(height*aspect,height),"angle":angle,"ground":ground,"slope":HILLS.slope(layer,x)*view.y/view.x,"clip":0.28+drop/height,"alpha":smoothstep(birth,birth+0.10,t)}

func hero_frame(t: float, view: Vector2) -> Dictionary:
	t=minf(t,FREEZE_AT)
	var fall:=clampf((t-HERO_DROP_AT)/(IMPACT_AT-HERO_DROP_AT),0,1)
	# Leave the upper third open for the docked title; keep the whole tableau frozen.
	var height:=view.y*0.55
	var ground:=Vector2(view.x*0.5,HILLS.ridge_y(2,0.5)*view.y)
	var drop:=view.y*1.1*(1-fall*fall)
	var center:=ground-Vector2(0,height*0.28+drop)
	var extent:=Vector2(height*_aspect,height)
	var angle:=sin(fall*PI)*0.05
	return {"center":center,"extent":extent,"ground":ground,"angle":angle,"slope":HILLS.slope(2,0.5)*view.y/view.x,"clip":0.28+drop/height,"alpha":smoothstep(HERO_DROP_AT,HERO_DROP_AT+0.10,t)}

func _pose(picture: TextureRect, frame: Dictionary, amount: float) -> void:
	picture.size=frame["extent"];picture.pivot_offset=picture.size*0.5
	picture.position=frame["center"]-picture.size*0.5;picture.rotation=float(frame["angle"])
	var ink:=picture.material as ShaderMaterial
	ink.set_shader_parameter("dimensions",picture.size);ink.set_shader_parameter("amount",amount)
	ink.set_shader_parameter("card_angle",float(frame["angle"]))
	ink.set_shader_parameter("ground_slope",float(frame["slope"]))
	ink.set_shader_parameter("ground_offset",float(frame["clip"]))

func seek(t: float, view: Vector2) -> void:
	time=minf(t,INTRO_SECONDS+HANDOFF_SECONDS);size=view
	if hero==null or (time==_last_time and view==_last_view):return
	var sampled:=minf(time,FREEZE_AT)
	var pose_changed:=sampled!=_last_sampled or view!=_last_view
	_last_time=time;_last_view=view;_last_sampled=sampled
	if pose_changed:
		_terrain.size=view;_terrain.queue_redraw()
		for i: int in COUNT:
			var frame:=field_frame(sampled,i,view,_aspect)
			_pose(field[i],frame,0.0)
			field[i].modulate.a=float(frame["alpha"])
			field[i].visible=field[i].modulate.a>0
		var frame:=hero_frame(sampled,view)
		_pose(hero,frame,0.0);hero.modulate.a=float(frame["alpha"]);hero.visible=hero.modulate.a>0
		_ground.size=view;_ground.queue_redraw()
	scene_ink.set_shader_parameter("amount",smoothstep(MORPH_AT,PRINT_AT,time))
	scene_ink.set_shader_parameter("caption",smoothstep(INTRO_SECONDS,INTRO_SECONDS+0.50,time))
	scene_ink.set_shader_parameter("print_scale",view.y/768.0)
	var simplify:=background_simplify()
	scene_ink.set_shader_parameter("backdrop_simplify",simplify)
	for picture: TextureRect in field:
		(picture.material as ShaderMaterial).set_shader_parameter("backdrop_simplify",simplify)
	(hero.material as ShaderMaterial).set_shader_parameter("backdrop_simplify",simplify)
	# Only surface detail changes after the source composition has frozen.
	_terrain.queue_redraw();_ground.queue_redraw()
	# Project the complete frozen print as one oversized backdrop, keeping card relationships.
	var zoom:=lerpf(1.0,1.65,smoothstep(INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS,time))
	tableau.scale=Vector2.ONE*zoom
	tableau.position=(1.0-zoom)*Vector2(0.45,0.85)*view

func paint_ground(canvas: CanvasItem) -> void:
	var sampled:=minf(time,FREEZE_AT)
	var ratio:=size.y/768.0
	var detail:=1.0-background_simplify()
	for i: int in COUNT:
		var age:=sampled-field_impact_at(i)
		if age<0:continue
		var at: Vector2=field_frame(sampled,i,size,_aspect)["ground"]
		if detail>0.01:PaintedFx.stamp(canvas,CRACK,at,Vector2(50,10)*ratio,Color(0.35,0.22,0.42,0.65*detail))
		if age<0.16:PaintedFx.stamp(canvas,PaintedFx.DUST,at,Vector2(68,18)*ratio*(0.5+age*3),Color(0.92,0.82,0.90,(1-age/0.16)*0.50))
	var age:=sampled-IMPACT_AT
	if age>=0:
		var at: Vector2=hero_frame(IMPACT_AT,size)["ground"]
		PaintedFx.stamp(canvas,CRACK,at,Vector2(340,52)*ratio,Color(0.30,0.16,0.37,lerpf(0.20,1.0,detail)))
		if age<0.38:
			var burst:=clampf(age/0.38,0,1)
			PaintedFx.stamp(canvas,PaintedFx.DUST,at,Vector2(440,60)*ratio*(0.4+burst),Color(1,0.88,0.98,(1-burst)*0.65))
			PaintedFx.stamp(canvas,PaintedFx.IMPACT,at,Vector2(300,48)*ratio,Color(1,0.94,1,(1-burst)*0.70))
