## Cosmetic clock only; the eight fragments retain the illustrated die texture.
class_name HammerForgeView
extends Control
signal impact(success: bool, value: int)
const SIZE := Vector2(500,250)
const HIT_AT := 0.27
const TOTAL_TIME := 0.64
const SUCCESS_TIME := 1.05
const NUMBER_FONT: Font = preload("res://assets/fonts/ONE-Mobile-POP.otf")
const BREAK_AT := 0.40
const BREAK_TIME := 1.22
const HAMMER: Texture2D = preload("res://assets/fx/forge/HAMMER_V01.png")
const ANVIL: Texture2D = preload("res://assets/fx/forge/ANVIL_EMPTY_V02.png")
const DIE: Texture2D = preload("res://assets/fx/forge/DIE_V02.png")
const DIE_RECT := Rect2(155,42,94,94)
const RIM := [Vector2(0,0),Vector2(0.43,0),Vector2(1,0),Vector2(1,0.48),Vector2(1,1),Vector2(0.56,1),Vector2(0,1),Vector2(0,0.54)]
const CENTER := Vector2(0.51,0.49)
var level := 0
var breaking := false
var shattered := false
var _time := SUCCESS_TIME
var _pace := 1.0
var _audio:=PresentationAudio.new()
func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): cancel())
func show_level(value: int, animate: bool, pace: float = 1.0) -> void:
	if value == level and not breaking: return
	var increased: bool = value > level
	level = value
	breaking = false
	shattered = false
	_pace = maxf(pace,0.1)
	_time = 0.0 if animate and increased else SUCCESS_TIME
	_audio.start(self,[PresentationAudio.cue(0.12,&"hammer_swing"),PresentationAudio.cue(HIT_AT,&"hammer_hit"),PresentationAudio.cue(HIT_AT+0.14,&"hammer_success")])
	if _time>0.0:_audio.cancel()
	set_process(_time < SUCCESS_TIME)
	queue_redraw()
func begin_break(value: int, pace: float) -> void:
	_audio.start(self,[PresentationAudio.cue(0.12,&"hammer_swing"),PresentationAudio.cue(HIT_AT,&"hammer_hit"),PresentationAudio.cue(BREAK_AT,&"hammer_break")])
	level = value
	breaking = true
	shattered = false
	_time = 0.0
	_pace = maxf(pace,0.1)
	set_process(true)
	queue_redraw()
func cancel() -> void:
	_audio.cancel()
	level = 0
	breaking = false
	shattered = false
	_time = SUCCESS_TIME
	set_process(false)
	queue_redraw()
func _process(delta: float) -> void:
	var end: float = BREAK_TIME if breaking else SUCCESS_TIME
	var previous: float = _time
	_time = minf(_time + delta/_pace,end)
	_audio.advance(_time)
	if previous < HIT_AT and _time >= HIT_AT: impact.emit(not breaking,level)
	shattered = breaking and _time >= BREAK_AT
	if _time >= end: set_process(false)
	queue_redraw()
func break_finished() -> bool:
	return breaking and _time >= BREAK_TIME
func success_finished() -> bool:
	return not breaking and _time >= SUCCESS_TIME
func _draw() -> void:
	var offset := Vector2((size.x-SIZE.x)*0.5,0)
	var angle := 16.0
	var rebound := 0.0
	var contact_end: float = BREAK_AT if breaking else 0.32
	if _time < 0.14:
		angle = lerpf(16.0,34.0,smoothstep(0.0,0.14,_time))
	elif _time < HIT_AT:
		angle = lerpf(34.0,-55.0,pow((_time-0.14)/(HIT_AT-0.14),2.0))
	elif _time < contact_end:
		angle = -55.0
		rebound = 2.0
	elif _time < TOTAL_TIME:
		angle = lerpf(-55.0,16.0,1.0-pow(1.0-(_time-contact_end)/(TOTAL_TIME-contact_end),3.0))
	draw_texture_rect(ANVIL,Rect2(offset+Vector2(60,43+rebound),Vector2(292,219)),false)
	if not shattered:
		var die_box := Rect2(offset+DIE_RECT.position+Vector2(0,rebound),DIE_RECT.size)
		if not breaking and _time >= HIT_AT:
			var beat: float = _time-HIT_AT
			var squash: float = sin(clampf(beat/0.10,0.0,1.0)*PI)*0.13 if beat < 0.10 else 0.0
			var jump: float = sin(clampf((beat-0.07)/0.36,0.0,1.0)*PI)*12.0
			var stretched := DIE_RECT.size*Vector2(1.0+squash,1.0-squash)
			die_box = Rect2(offset+DIE_RECT.position+Vector2((DIE_RECT.size.x-stretched.x)*0.5,DIE_RECT.size.y-stretched.y-jump),stretched)
		draw_texture_rect(DIE,die_box,false)
		if not breaking and _time >= HIT_AT:
			var gleam: float = 1.0-smoothstep(0.05,0.28,_time-HIT_AT)
			draw_texture_rect(DIE,die_box,false,Color(1.0,0.82,0.30,gleam*0.55))
		if breaking and _time >= HIT_AT:
			for uv: Vector2 in RIM:
				draw_line(offset+DIE_RECT.position+CENTER*DIE_RECT.size,offset+DIE_RECT.position+CENTER.lerp(uv,0.67)*DIE_RECT.size,Color("432525"),1.6,true)
	else:
		_draw_fragments(offset,_time-BREAK_AT)
	draw_set_transform(offset+Vector2(298,104),deg_to_rad(angle))
	draw_texture_rect(HAMMER,Rect2(-40,-130,80,160),false)
	draw_set_transform(Vector2.ZERO)
	if not breaking and _time >= HIT_AT and _time < SUCCESS_TIME:
		_draw_success(offset,_time-HIT_AT)

func _draw_success(offset: Vector2, seconds: float) -> void:
	var at := offset+Vector2(206,59)
	var strength: float = 1.0+minf(level-1,4)*0.08
	# Local contact flash only, with no full-screen wash or persistent halo.
	if seconds < 0.16:
		var flash: float = 1.0-seconds/0.16
		var star := PackedVector2Array()
		for i: int in 16:
			var radius: float = (25.0 if i%2==0 else 7.0)*strength*flash
			star.append(at+Vector2.from_angle(i*TAU/16.0)*radius)
		draw_colored_polygon(star,Color(1,0.83,0.25,flash))
		draw_circle(at,5.0*flash,Color(1,0.99,0.86,flash))
	var fade: float = 1.0-smoothstep(0.28,0.60,seconds)
	for i: int in 8:
		var direction := Vector2.from_angle(-PI+0.13+i*(PI-0.26)/7.0)
		var origin: Vector2 = at+direction*(12.0+seconds*(115.0+i*5.0)*strength)+Vector2(0,85.0*seconds*seconds)
		var tail: Vector2 = origin-direction*(9.0*(1.0-seconds/0.75))
		draw_line(tail,origin,Color(0.37,0.18,0.05,fade),4.0,true)
		draw_line(tail,origin,Color(1,0.85,0.32,fade),2.1,true)
	var text: String = "+%d" % level
	var alpha: float = smoothstep(0.04,0.12,seconds)*(1.0-smoothstep(0.52,0.77,seconds))
	var text_at := offset+Vector2(279,98-34.0*(1.0-pow(1.0-clampf(seconds/0.65,0.0,1.0),2.0)))
	draw_string_outline(NUMBER_FONT,text_at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,42,6,Color(0.18,0.10,0.06,alpha))
	draw_string(NUMBER_FONT,text_at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,42,Color(1,0.88,0.36,alpha))
func _draw_fragments(offset: Vector2, seconds: float) -> void:
	var alpha: float = 1.0-smoothstep(0.38,0.76,seconds)
	for i: int in RIM.size():
		var uv := PackedVector2Array([CENTER,RIM[i],RIM[(i+1)%RIM.size()]])
		var middle: Vector2 = (uv[0]+uv[1]+uv[2])/3.0
		var velocity: Vector2 = (middle-CENTER).normalized()*(116.0+i*5.0)+Vector2(0,-96)
		var origin: Vector2 = offset+DIE_RECT.position+middle*DIE_RECT.size+velocity*seconds+Vector2(0,220*seconds*seconds)
		draw_set_transform(origin,(i-3.5)*seconds*1.7)
		var points := PackedVector2Array()
		for value: Vector2 in uv: points.append((value-middle)*DIE_RECT.size)
		draw_polygon(points,PackedColorArray([Color(1,1,1,alpha)]),uv,DIE)
	draw_set_transform(Vector2.ZERO)
