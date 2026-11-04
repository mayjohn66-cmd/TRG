## Paper and oversized diagonal tire imprints; no road or lane graphics.
extends Control
const SOLID_SECONDS:=0.34
const INTRO_SECONDS:=0.40
const SKID_AT:=INTRO_SECONDS+1.55
const SKID_END:=SKID_AT+0.60
const PAPER:=Color("f4efdc")
const SKID_COLOR:=Color("d52634")
const TREAD_WIDTH:=0.22
const TREAD_OFFSET:=0.125
const SOURCE_PATH:="res://assets/fx/law_fx/victory_prints/race_tread_mask_v01.webp"
var source: Texture2D
var _marks: Marks
var time:=0.0
var _last_time:=-99.0
var _last_view:=Vector2.ZERO

class Marks extends Control:
	var stage: Control
	func _draw() -> void:stage.paint_skids(self)

func _init() -> void:
	name="RaceFinishStage";mouse_filter=Control.MOUSE_FILTER_IGNORE;set_process(false)

func setup() -> void:
	source=TextureCache.fetch_transient(SOURCE_PATH)
	_marks=Marks.new();_marks.stage=self;_marks.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();material.shader=preload("res://scenes/race_tread_mask.gdshader")
	var region:=PaintedFx.region(source);var tex_size:=source.get_size()
	material.set_shader_parameter("edge_ink",Color("711b26"))
	material.set_shader_parameter("source_region",Vector4(region.position.x/tex_size.x,region.position.y/tex_size.y,region.size.x/tex_size.x,region.size.y/tex_size.y))
	_marks.material=material;add_child(_marks)

static func skid_progress(t: float) -> float:
	var u:=clampf((t-SKID_AT)/(SKID_END-SKID_AT),0,1)
	return 1-pow(1-u,3)

static func skid_path(view: Vector2) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for i: int in 161:
		points.append(Vector2(-0.18,0.98).bezier_interpolate(Vector2(0.00,0.85),Vector2(0.50,0.65),Vector2(1.10,0.12),float(i)/160.0)*view)
	return points

static func track_points(view: Vector2, side: int) -> PackedVector2Array:
	var path:=skid_path(view);var points:=PackedVector2Array()
	for i: int in path.size():
		var normal:=(path[mini(i+1,160)]-path[maxi(i-1,0)]).normalized().orthogonal()
		points.append(path[i]+normal*float(side)*TREAD_OFFSET*view.y)
	return points

func seek(t: float, view: Vector2) -> void:
	time=minf(t,SKID_END);size=view
	if time==_last_time and view==_last_view:return
	_last_time=time;_last_view=view
	_marks.size=view;_marks.queue_redraw();queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),PAPER)

func _tread(canvas: CanvasItem, points: PackedVector2Array, amount: float, width: float, tint: Color, offset: Vector2) -> void:
	if source==null or amount<=0:return
	var region:=PaintedFx.region(source);var tex_size:=source.get_size()
	var end:=float(points.size()-1)*clampf(amount,0,1)
	for i: int in range(ceili(end)):
		var stop:=minf(float(i+1),end);var part:=stop-float(i)
		var a:=points[i]+offset;var b:=points[i].lerp(points[i+1],part)+offset
		var na:=(points[mini(i+1,160)]-points[maxi(i-1,0)]).normalized().orthogonal()*width*0.5
		var nb:=(points[mini(i+2,160)]-points[i]).normalized().orthogonal()*width*0.5
		nb=na.lerp(nb,part)
		# One continuous imprint avoids a visible repeat seam.
		var u0:=float(i)/160.0;var u1:=u0+part/160.0
		var ua:=(region.position.x+region.size.x*u0)/tex_size.x
		var ub:=(region.position.x+region.size.x*u1)/tex_size.x
		var top:=region.position.y/tex_size.y;var bottom:=region.end.y/tex_size.y
		canvas.draw_polygon(PackedVector2Array([a-na,a+na,b+nb,b-nb]),PackedColorArray([tint]),PackedVector2Array([Vector2(ua,top),Vector2(ua,bottom),Vector2(ub,bottom),Vector2(ub,top)]),source)

func paint_skids(canvas: CanvasItem) -> void:
	var amount:=skid_progress(time)
	if amount<=0:return
	var ratio:=size.y/768.0
	for side: int in [-1,1]:
		var track:=track_points(size,side)
		_tread(canvas,track,amount,size.y*TREAD_WIDTH*1.04,Color(0.25,0.03,0.06,0.50),Vector2(3,6)*ratio)
		_tread(canvas,track,amount,size.y*TREAD_WIDTH,SKID_COLOR,Vector2.ZERO)
