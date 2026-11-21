## White brush tear -> narrow eye strip -> ink closes over the eyes and pinches out.
extends Control

const ART = preload("res://content_trickcal/illustrations/effects/raid/raid_shing.png")
const MASK = preload("res://assets/fx/raid_cutin.gdshader")
const IMPACT_AT := 0.20
const EXIT_AT := 0.68
const DURATION := 1.05
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
	_picture.size = size
	_picture.position = Vector2.ZERO
	_ink.set_shader_parameter("cue_time",time)
	_ink.set_shader_parameter("frame_aspect",size.x/maxf(size.y,1.0))
	queue_redraw()

func _fleck(at: Vector2, length: float, width: float, lean: float) -> void:
	var points := PackedVector2Array([Vector2(-length*0.5,width*0.1),Vector2(-length*0.1,-width*0.55),Vector2(length*0.15,-width*0.25),Vector2(length*0.5,-width*0.1),Vector2(length*0.1,width*0.55),Vector2(-length*0.12,width*0.20)])
	draw_set_transform(at,lean)
	draw_colored_polygon(points,Color("fffef8"))
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if elapsed>=DURATION:
		return
	var enter := smoothstep(0.0,0.08,elapsed)
	var leave := smoothstep(EXIT_AT,DURATION,elapsed)
	# The reference leaves the fight readable above and below a thin eye ribbon.
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.015,0.025,0.24*enter*(1.0-leave)))
	var brush := smoothstep(0.63,0.74,elapsed)*(1.0-smoothstep(0.92,DURATION,elapsed))
	if brush>0.0:
		for index: int in 5:
			var x := 0.30+index*0.13
			var side := -1.0 if index%2==0 else 1.0
			var at := Vector2(size.x*(x+leave*0.045),size.y*(0.71-x*0.37+side*(0.12+leave*0.045)))
			_fleck(at,size.x*(0.028+index*0.004)*brush,size.y*(0.015+index*0.002)*brush,-0.36)
