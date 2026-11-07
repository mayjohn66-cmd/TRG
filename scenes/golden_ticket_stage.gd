## Six complementary torn fragments reunite into ONE ticket, then become its print.
extends Control
const COUNT:=6
const FIRST_AT:=0.18
const INTERVAL:=0.34
const RISE_SECONDS:=0.54
const JOIN_AT:=2.50
const JOINED_AT:=3.20
const REVEAL_AT:=JOINED_AT
const MORPH_AT:=3.92
const PRINT_AT:=4.56
const INTRO_SECONDS:=4.82
const HANDOFF_SECONDS:=1.10
const FADE_SECONDS:=0.42
const ART=preload("res://scenes/cutscene_print_art.gd")
const FOIL=preload("res://scenes/golden_ticket_print.gdshader")
const MOTIF=preload("res://scenes/victory_motif_layout.gd")
const SCATTER: Array[Vector2]=[Vector2(-0.10,-0.08),Vector2(0,-0.10),Vector2(0.11,-0.06),Vector2(-0.12,0.09),Vector2(0,0.12),Vector2(0.12,0.10)]
const TURNS: Array[float]=[-0.17,0.10,0.16,-0.12,0.08,0.19]
var pieces: Array[TextureRect]=[]
var shadows: Array[TextureRect]=[]
var ticket: TextureRect
var ticket_shadow: TextureRect
var time:=0.0
var _aspect:=2.4
var _last_time:=-99.0
var _last_view:=Vector2.ZERO

func _init() -> void:
	name="GoldenTicketStage";mouse_filter=Control.MOUSE_FILTER_IGNORE;set_process(false)

func _picture(texture: Texture2D, label: String, part: int) -> TextureRect:
	var picture:=ART.picture(texture);picture.name=label
	var ink:=ShaderMaterial.new();ink.shader=FOIL;ink.set_shader_parameter("piece_id",part)
	picture.material=ink;add_child(picture)
	return picture

func setup() -> void:
	var sheet:=TextureCache.fetch("res://assets/fx/law_fx/victory_prints/golden_ticket_v01.webp")
	var crop:=AtlasTexture.new();crop.atlas=sheet;crop.region=PaintedFx.region(sheet)
	_aspect=crop.region.size.x/crop.region.size.y
	for i: int in COUNT:
		var shadow:=_picture(crop,"FragmentShadow%d"%(i+1),i)
		shadow.modulate=Color(0.10,0.045,0.025,0.30);shadows.append(shadow)
		pieces.append(_picture(crop,"TornTicketFragment%d"%(i+1),i))
	ticket_shadow=_picture(crop,"CompleteTicketShadow",-1)
	ticket_shadow.modulate=Color(0.10,0.045,0.025,0.20)
	ticket=_picture(crop,"ReunitedGoldenTicket",-1)

static func arrival_at(i: int) -> float:
	return FIRST_AT+float(i)*INTERVAL

static func arrival(t: float, i: int) -> float:
	return smoothstep(arrival_at(i),arrival_at(i)+RISE_SECONDS,t)

static func ticket_pose(t: float, view: Vector2, aspect: float) -> Dictionary:
	t=minf(t,INTRO_SECONDS+HANDOFF_SECONDS)
	var front:=smoothstep(JOINED_AT,JOINED_AT+0.42,t)
	var move:=smoothstep(INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS,t)
	var center:=Vector2(view.x*0.50,view.y*0.47).lerp(Vector2(view.x*0.34,view.y*0.51),move)
	var width:=lerpf(view.y*lerpf(0.85,0.90,front),view.x*1.12,move)
	return {"center":center,"extent":Vector2(width,width/aspect),"angle":-0.12*move,"move":move}

static func fragment_pose(t: float, i: int, view: Vector2, aspect: float) -> Dictionary:
	var frame:=ticket_pose(t,view,aspect)
	var rise:=arrival(t,i)
	var join:=smoothstep(JOIN_AT,JOINED_AT,t)
	# Each quad samples a different jagged sixth of one shared ticket image.
	# At closure, all transforms equal the whole-ticket transform exactly.
	frame["center"]+=SCATTER[i]*view.y*(1-join)
	frame["center"].y+=(1-rise)*view.y*0.57
	frame["center"].x+=sin((1-rise)*PI)*view.y*0.025*(1 if i%2==0 else -1)
	frame["angle"]+=TURNS[i]*(1-join)+sin((1-rise)*PI*2)*0.05*(1-rise)
	frame["alpha"]=clampf(rise*3,0,1)
	return frame

func _pose(picture: TextureRect, frame: Dictionary, view: Vector2, shadow: bool = false) -> void:
	picture.size=frame["extent"];picture.pivot_offset=picture.size*0.5
	picture.position=frame["center"]-picture.size*0.5;picture.rotation=float(frame["angle"])
	if shadow:picture.position+=Vector2(3,6)*view.y/768.0
	var ink:=picture.material as ShaderMaterial
	ink.set_shader_parameter("dimensions",picture.size)
	ink.set_shader_parameter("sealing",smoothstep(JOIN_AT,JOINED_AT,time))
	ink.set_shader_parameter("gilded",0.35+0.65*smoothstep(JOIN_AT,JOINED_AT,time))
	ink.set_shader_parameter("shine",0.0)
	ink.set_shader_parameter("reveal",clampf((time-REVEAL_AT)/0.52,0,1))
	ink.set_shader_parameter("print_amount",smoothstep(MORPH_AT,PRINT_AT,time))

func seek(t: float, view: Vector2) -> void:
	time=minf(t,INTRO_SECONDS+HANDOFF_SECONDS);size=view
	if pieces.is_empty() or (time==_last_time and view==_last_view):return
	_last_time=time;_last_view=view
	var joined:=time>=JOINED_AT
	for i: int in COUNT:
		var frame:=fragment_pose(time,i,view,_aspect)
		for picture: TextureRect in [shadows[i],pieces[i]]:
			_pose(picture,frame,view,picture==shadows[i])
			picture.visible=not joined and float(frame["alpha"])>0
		shadows[i].modulate.a=float(frame["alpha"])*0.30*(1-smoothstep(JOIN_AT,JOINED_AT,time)*0.35)
		pieces[i].modulate.a=float(frame["alpha"])
	var whole:=ticket_pose(time,view,_aspect)
	for picture: TextureRect in [ticket_shadow,ticket]:
		_pose(picture,whole,view,picture==ticket_shadow)
		picture.visible=joined
	var strength:=MOTIF.opacity("LAW_02",time,INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS)
	ticket.modulate.a=strength;ticket_shadow.modulate.a=0.20*(1-smoothstep(INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS,time))
