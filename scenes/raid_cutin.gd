## A diagonal rip -> slam/eye glint -> split sweep. No gameplay or RNG changes.
extends Control

const ART = preload("res://content_trickcal/illustrations/effects/raid/raid_shing.png")
const MASK = preload("res://assets/fx/raid_cutin.gdshader")
const IMPACT_AT := 0.24
const EXIT_AT := 0.86
const DURATION := 1.20
var elapsed := 0.0
var _picture: TextureRect
var _ink: ShaderMaterial

func _ready() -> void:
	name = "RaidCutin"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture = TextureRect.new()
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.texture = ART
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ink = ShaderMaterial.new()
	_ink.shader = MASK
	_picture.material = _ink
	add_child(_picture)
	seek(0.0)

func seek(time: float) -> void:
	elapsed = time
	visible = time<DURATION
	if _picture==null:
		return
	size = get_viewport_rect().size
	# Match the screen, keeping the eyes centered in wide and narrow layouts.
	var width := maxf(size.x,size.y*1.45)
	var height := width*ART.get_height()/float(ART.get_width())
	_picture.size = Vector2(width,height)
	_picture.position = (size-_picture.size)/2.0
	_ink.set_shader_parameter("cue_time",time)
	queue_redraw()

func _slash(from: Vector2, to: Vector2, thickness: float, color: Color) -> void:
	var normal := (to-from).normalized().orthogonal()*thickness
	draw_colored_polygon(PackedVector2Array([from-normal*0.12,to-normal,to+normal*0.08,from+normal*0.26]),color)

func _draw() -> void:
	if elapsed>=DURATION:
		return
	var enter := smoothstep(0.0,0.09,elapsed)
	var leave := smoothstep(EXIT_AT,DURATION,elapsed)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.015,0.025,0.73*enter*(1.0-leave)))
	var center := size/2.0
	var direction := Vector2(1,-0.24).normalized()
	var span := size.x*0.82
	var rip := smoothstep(0.0,0.12,elapsed)*(1.0-smoothstep(0.13,0.26,elapsed))
	if rip>0.0:
		_slash(center-direction*span,center+direction*span,lerpf(2,16,rip),Color("fff2c9"))
	# Printed speed shards lead the image on entry and outrun it on exit.
	var speed := (1.0-smoothstep(0.14,0.32,elapsed)) if elapsed<EXIT_AT else leave
	if speed>0.0:
		for index: int in 3:
			var side := -1.0 if index%2==0 else 1.0
			var at := center+Vector2((-0.35+index*0.33+speed*0.24)*size.x,side*size.y*(0.20+index*0.035))
			_slash(at-direction*size.x*0.30,at+direction*size.x*0.18,5+index*2,Color("ef142e") if index==1 else Color("fff2d6"))
