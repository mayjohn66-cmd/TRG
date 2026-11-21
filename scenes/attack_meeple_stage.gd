## Three sliced crowned tokens, one black knight impact, then the same printed knight.
extends Control
const ART = preload("res://scenes/cutscene_print_art.gd")
const INTRO_SECONDS := 3.65
const SLASH_AT := 0.54
const SLASH_GAP := 0.24
const DROP_AT := 1.38
const IMPACT_AT := 1.95
const LAUNCH_AT := IMPACT_AT+0.08
const MORPH_AT := 2.75
const PRINT_AT := 3.35
const HANDOFF_SECONDS := 0.65
const FADE_SECONDS := 0.42
const CUT := 0.54
const CRACK := preload("res://assets/fx/law_fx/arena_crack_v01.webp")
var pawns: Array[Dictionary] = []
var knight: TextureRect
var rim: TextureRect
var print_art: TextureRect
var _basic_aspect := 0.65
var _knight_aspect := 0.65
var _focus := Vector2.ZERO
var _reference := Vector2.ONE
var time := 0.0
var _last_time := -99.0
var _last_view := Vector2.ZERO
var _accents: Accents
var _ground: Ground

class Ground extends Control:
	var stage: Control
	func _draw() -> void: stage.paint_ground(self)

class Accents extends Control:
	var stage: Control
	func _draw() -> void: stage.paint_accents(self)

func _init() -> void:
	name="AttackMeepleStage";mouse_filter=Control.MOUSE_FILTER_IGNORE;set_process(false)

static func _crop(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var result:=AtlasTexture.new();result.atlas=sheet;result.region=region;return result

func setup(focus: Vector2, reference: Vector2) -> void:
	_focus=focus;_reference=reference
	_ground=Ground.new();_ground.stage=self;_ground.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_ground)
	var basic:=TextureCache.fetch("res://assets/fx/law_fx/victory_prints/basic_pawn_cutscene_v02.webp")
	var region:=PaintedFx.region(basic);_basic_aspect=region.size.x/region.size.y
	var upper:=_crop(basic,Rect2(region.position,region.size*Vector2(1,CUT)))
	var lower:=_crop(basic,Rect2(region.position+Vector2(0,region.size.y*CUT),region.size*Vector2(1,1-CUT)))
	for i: int in 3:
		var entry: Dictionary={}
		for key: String in ["upper","lower","crown"]:
			var texture: Texture2D=upper if key=="upper" else (lower if key=="lower" else LawFeedback.icon("crown"))
			var picture:=ART.picture(texture);picture.name="CrownedPawn%d%s"%[i+1,key]
			add_child(picture);entry[key]=picture
		pawns.append(entry)
	var source:=TextureCache.fetch("res://assets/fx/law_fx/victory_prints/attack_knight_native_v02.webp")
	var native:=_crop(source,PaintedFx.region(source));_knight_aspect=native.region.size.x/native.region.size.y
	rim=ART.picture(native);rim.material=ART.material(true)
	(rim.material as ShaderMaterial).set_shader_parameter("paper_silhouette",true);add_child(rim)
	knight=ART.picture(native);knight.material=ART.material(true)
	(knight.material as ShaderMaterial).set_shader_parameter("black_piece",true);add_child(knight)
	var illustration:=TextureCache.fetch("res://assets/fx/law_fx/victory_prints/attack_knight_print_v03.webp")
	print_art=ART.picture(_crop(illustration,PaintedFx.region(illustration)));print_art.material=ART.material();add_child(print_art)
	_accents=Accents.new();_accents.stage=self;_accents.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_accents)

static func launch(t: float, i: int, part: int, view: Vector2) -> Dictionary:
	var u:=clampf((t-LAUNCH_AT)/0.66,0,1)
	var x: float=(float(i-1)*0.48+float(part-1)*0.14)*view.x*u
	var y: float=view.y*(-(0.66+float(part)*0.07)*u+0.76*u*u)
	return {"offset":Vector2(x,y),"angle":u*(float(i-1)*2.2+float(part-1)*1.6),"alpha":1.0-smoothstep(0.65,1.0,u)}

func hero_frame(t: float, view: Vector2) -> Dictionary:
	t=minf(t,INTRO_SECONDS+HANDOFF_SECONDS)
	var fall:=clampf((t-DROP_AT)/(IMPACT_AT-DROP_AT),0,1)
	var height:=view.y*0.46
	var ground:=_focus*view/_reference+Vector2(0,view.y*0.16)
	var drop:=-view.y*1.1*(1-fall*fall)
	var squash:=1.0-0.07*sin(clampf((t-IMPACT_AT)/0.17,0,1)*PI) if t>=IMPACT_AT else 1.0
	var extent:=Vector2(height*_knight_aspect,height*squash)
	var center:=ground+Vector2(0,drop-extent.y*0.5)
	var move:=smoothstep(INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS,t)
	var print_height:=view.y*1.42
	var print_width:=print_height*print_art.texture.get_width()/float(print_art.texture.get_height())
	return {"center":center.lerp(Vector2(0.27,0.64)*view,move),"extent":extent.lerp(Vector2(print_width,print_height),move),"ground":ground,"enter":smoothstep(DROP_AT,DROP_AT+0.12,t)}

func seek(t: float, view: Vector2) -> void:
	time=minf(t,INTRO_SECONDS+HANDOFF_SECONDS);size=view
	if knight==null or (time==_last_time and view==_last_view):return
	_last_time=time;_last_view=view
	var height:=view.y*0.22;var width:=height*_basic_aspect
	for i: int in pawns.size():
		var foot:=_focus*view/_reference+Vector2(float(i-1)*minf(view.x*0.19,view.y*0.32),view.y*0.16)
		var sliced:=smoothstep(SLASH_AT+float(i)*SLASH_GAP,SLASH_AT+float(i)*SLASH_GAP+0.13,time)
		for part: int in 3:
			var key: String=["upper","lower","crown"][part]
			var picture: TextureRect=pawns[i][key]
			var extent:=Vector2(width,height*CUT) if part==0 else (Vector2(width,height*(1-CUT)) if part==1 else Vector2(height*0.52,height*0.44))
			var center:=foot+Vector2(0,-height+extent.y*0.5) if part==0 else (foot+Vector2(0,-extent.y*0.5) if part==1 else foot+Vector2(0,-height*1.08))
			center+=Vector2((float(i)-1.0)*(8 if part!=1 else -4),-12 if part!=1 else 3)*sliced*view.y/768.0
			var flight:=launch(time,i,part,view)
			picture.size=extent;picture.pivot_offset=extent*0.5
			picture.position=center+flight["offset"]-extent*0.5
			picture.rotation=float(i-1)*0.10*sliced+float(flight["angle"])
			picture.modulate.a=smoothstep(0,0.18,time)*float(flight["alpha"])
			picture.visible=picture.modulate.a>0.001
	var pose:=hero_frame(time,view);var mix:=smoothstep(MORPH_AT,PRINT_AT,time)
	for picture: TextureRect in [rim,knight,print_art]:
		var extent: Vector2=pose["extent"]*(1.025 if picture==rim else 1.0)
		picture.size=extent;picture.position=pose["center"]-extent*0.5
		picture.visible=float(pose["enter"])>0 and (mix>0 if picture==print_art else mix<1)
		picture.modulate.a=float(pose["enter"])*preload("res://scenes/victory_motif_layout.gd").opacity("LAW_08",time,INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS)
		var ink:=picture.material as ShaderMaterial
		ink.set_shader_parameter("dimensions",extent);ink.set_shader_parameter("amount",mix)
	_accents.size=view;_accents.queue_redraw()
	_ground.size=view;_ground.queue_redraw()

func paint_accents(canvas: CanvasItem) -> void:
	if knight==null:return
	var ratio:=size.y/768.0
	for i: int in 3:
		var cut_time:=SLASH_AT+float(i)*SLASH_GAP
		var k:=(time-cut_time)/0.19
		if k<0 or k>=1:continue
		var at:=_focus*size/_reference+Vector2(float(i-1)*minf(size.x*0.19,size.y*0.32),size.y*(0.16-0.22*(1-CUT)))
		var from:=at+Vector2(-110,-38)*ratio
		var to:=at+Vector2(110,38)*ratio
		PaintedFx.streak(canvas,from,from.lerp(to,minf(1,k*2.2)),22*ratio,Color(1,0.96,0.85,1-k))
		PaintedFx.stamp(canvas,PaintedFx.IMPACT,at,Vector2(140,75)*ratio,Color(1,0.80,0.45,(1-k)*0.7))
func paint_ground(canvas: CanvasItem) -> void:
	# Ground marks expand behind the base, never over the knight's front silhouette.
	var ratio:=size.y/768.0
	var age:=time-IMPACT_AT
	if age>=0 and age<0.70:
		var at: Vector2=hero_frame(IMPACT_AT,size)["ground"]-Vector2(0,8)*ratio
		var burst:=clampf(age/0.42,0,1)
		PaintedFx.stamp(canvas,CRACK,at,Vector2(390,64)*ratio,Color(1,1,1,1-smoothstep(0.35,0.70,age)))
		PaintedFx.stamp(canvas,PaintedFx.DUST,at-Vector2(0,8)*ratio,Vector2(470,64)*ratio*(0.6+burst),Color(1,0.86,0.66,(1-burst)*0.65))
		PaintedFx.stamp(canvas,PaintedFx.IMPACT,at,Vector2(320,65)*ratio,Color(1,0.93,0.75,(1-burst)*0.65))
