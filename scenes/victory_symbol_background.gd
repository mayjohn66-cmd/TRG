## High-contrast pop-art print plates, halftone props and a single stage clock.
extends Control
const THEME = preload("res://scenes/law_victory_theme.gd")
const ALCHEMY = preload("res://scenes/alchemy_victory_motion.gd")
const TRAP_HILLS = preload("res://scenes/trap_hill_art.gd")
const FOOTER_ART = preload("res://scenes/victory_footer_art.gd")
const PRINT_ROOT := "res://assets/fx/law_fx/victory_prints/"
const KEYS: Dictionary = {
	"FINISH":[],"LAW_01":[],"LAW_02":[],
	"LAW_03":[],"LAW_04":["jackpot"],"LAW_05":["alchemy"],
	"LAW_06":[],"LAW_07":[],"LAW_08":[],
	"LAW_09":[],
}
var theme_id := ""
var _pattern: Stage

class Stage extends Control:
	var scene_id := ""
	var ink := Color.BLACK
	var accent := Color.WHITE
	var paper := Color.WHITE
	var textures: Dictionary = {}
	var time := 0.0
	var racing := false
	var _unit := 1.0

	func _p(x: float, y: float) -> Vector2:
		return Vector2(x*size.x,y*size.y)

	func _progress(start: float, end: float) -> float:
		var k := clampf((time-start)/(end-start),0,1)
		return 1-pow(1-k,3)

	func _patch(points: Array, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array(points),color)

	func _curve(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i: int in 81: points.append(a.bezier_interpolate(b,c,d,float(i)/80.0))
		return points

	func _print(key: String, at: Vector2, width: float, color: Color, angle: float = 0, reveal: float = 1) -> void:
		if reveal<=0 or color.a<=0: return
		var texture := textures[key] as Texture2D
		var region := PaintedFx.region(texture)
		var extent := Vector2(width,width*region.size.y/region.size.x)
		draw_set_transform(at,angle)
		draw_texture_rect_region(texture,Rect2(-extent*0.5,extent*Vector2(clampf(reveal,0,1),1)),Rect2(region.position,region.size*Vector2(clampf(reveal,0,1),1)),color)
		draw_set_transform(Vector2.ZERO)

	func _textured_path(key: String, points: PackedVector2Array, amount: float, width: float, color: Color) -> void:
		if amount<=0 or points.size()<2: return
		var texture := textures[key] as Texture2D
		var region := PaintedFx.region(texture)
		var tex_size := texture.get_size()
		var count := float(points.size()-1)
		var end := count*clampf(amount,0,1)
		for i: int in range(ceili(end)):
			var stop := minf(float(i+1),end)
			var part := stop-float(i)
			var a := points[i]
			var b := a.lerp(points[i+1],part)
			var na := (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized().orthogonal()*width*_unit*0.5
			var nb := (points[mini(i+2,points.size()-1)]-points[i]).normalized().orthogonal()*width*_unit*0.5
			nb = na.lerp(nb,part)
			var ua := (region.position.x+region.size.x*float(i)/count)/tex_size.x
			var ub := (region.position.x+region.size.x*stop/count)/tex_size.x
			var top := region.position.y/tex_size.y
			var bottom := region.end.y/tex_size.y
			draw_polygon(PackedVector2Array([a-na,a+na,b+nb,b-nb]),PackedColorArray([color]),PackedVector2Array([Vector2(ua,top),Vector2(ua,bottom),Vector2(ub,bottom),Vector2(ub,top)]),texture)

	func _draw() -> void:
		if size.x<2 or size.y<2: return
		_unit = size.y/768.0
		if scene_id=="FINISH":
			_finish_frame();return
		if scene_id!="FINISH":draw_rect(Rect2(Vector2.ZERO,size),paper)
		if scene_id=="LAW_03":TRAP_HILLS.poster(self,size,ink,accent,paper)
		else:_pop_backdrop()
		match scene_id:
			"FINISH": pass # Oversized red tire imprints remain unobstructed in the carried stage.
			"LAW_01": _arena()
			"LAW_02": pass # The reunited golden ticket is carried by its own stage.
			"LAW_03": pass # One planted trap-card illustration is carried by its own stage.
			"LAW_04": _casino()
			"LAW_05": _alchemy()
			"LAW_06": pass # The toppled pawn's illustration is carried by its own stage.
			"LAW_07": pass # Three actual 3D dice are carried over the printed backdrop.
			"LAW_08": pass # Keep the knight action, without decorative background slashes.
		if scene_id!="LAW_03":_footer()

	func _finish_frame() -> void:
		var enter:=_progress(0.32,0.92)
		var drop:=(1-enter)*0.30
		_patch([_p(-0.03,0.75+drop),_p(1.03,0.72+drop),_p(1.03,1.06+drop),_p(-0.03,1.06+drop)],Color(ink,enter))

	func _footer() -> void:
		var enter:=_progress(0.32,0.92)
		var edge:=FOOTER_ART.edge(size,(1-enter)*0.30)
		var fill:=FOOTER_ART.body(size,(1-enter)*0.30)
		draw_colored_polygon(fill,Color(ink,enter));draw_polyline(edge,Color(accent,0.70*enter),2.5*_unit,true)

	func _pop_backdrop() -> void:
		# One large accent plate and a cut edge frame the portrait as a printed cutout.
		_patch([_p(0.60,-0.10),_p(1.08,0),_p(1.08,1.08),_p(0.43,0.82)],accent)
		draw_line(_p(0.60,-0.10),_p(0.43,0.82),paper,8*_unit,true)
		if scene_id=="LAW_04":
			_patch([_p(-0.03,0.05),_p(0.57,-0.01),_p(0.52,0.53),_p(-0.03,0.59)],accent)
			_patch([_p(-0.05,0.015),_p(0.55,-0.035),_p(0.50,0.50),_p(-0.05,0.56)],ink)
		elif scene_id=="LAW_02":
			_patch([_p(-0.10,0.12),_p(0.08,-0.10),_p(0.52,0.85),_p(0.38,1.05)],accent)
			_patch([_p(0.23,-0.10),_p(0.37,-0.10),_p(0.06,1.10),_p(-0.07,1.10)],Color(accent,0.48))
		elif scene_id=="LAW_06":
			_patch([_p(-0.04,0.07),_p(0.56,-0.03),_p(0.50,0.64),_p(-0.04,0.70)],ink)
		elif scene_id=="LAW_07":
			_patch([_p(-0.06,0.48),_p(0.52,0.32),_p(0.56,0.55),_p(-0.06,0.72)],Color(accent,0.22))
		elif scene_id=="LAW_05":
			_patch([_p(-0.06,0.34),_p(0.50,0.50),_p(0.48,0.75),_p(-0.06,0.57)],Color(accent,0.30))
		else:
			_patch([_p(-0.04,0.47),_p(0.54,0.31),_p(0.59,0.53),_p(-0.02,0.75)],Color(accent,0.18))

	func _arena() -> void:
		for row: int in 15:
			for column: int in 23:
				var at := _p(float(column)/22.0,float(row)/14.0)
				var direction := Vector2(10,-9 if (row+column)%2==0 else 9)*_unit
				draw_line(at,at+direction,Color(ink,0.075),2*_unit,true)

	func _casino() -> void:
		var stop := _progress(0.18,0.84)
		_print("jackpot",_p(0.38,0.61),size.x*(1.18+(1-stop)*0.045),Color(1,1,1,0.40),-0.07+(1-stop)*0.12)


	func _alchemy() -> void:
		var region := PaintedFx.region(textures["alchemy"])
		var frame := ALCHEMY.poster_pose(time,size,region.size.y/region.size.x)
		_print("alchemy",frame["center"],float(frame["extent"].x),Color(1,1,1,0.34),float(frame["angle"]))

func _init() -> void:
	name = "VictorySymbolBackground"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func setup(id: String) -> void:
	theme_id = id
	_pattern = Stage.new()
	_pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pattern)
	_pattern.scene_id = id
	_pattern.ink = Color(str(THEME.of(id)["ink"]))
	_pattern.accent = Color(str(THEME.of(id)["accent"]))
	_pattern.paper = Color(str(THEME.PAPERS[id]))
	_pattern.racing = id=="FINISH"
	for key: String in KEYS[id]: _pattern.textures[key] = TextureCache.fetch(PRINT_ROOT+key+"_v02.webp")
	var pop_material := ShaderMaterial.new()
	pop_material.shader = preload("res://scenes/victory_pop_print.gdshader")
	pop_material.set_shader_parameter("print_ink",_pattern.ink)
	pop_material.set_shader_parameter("print_paper",Color("fff0cd") if id=="LAW_04" else _pattern.paper)
	pop_material.set_shader_parameter("alpha_cutoff",0.48 if id=="LAW_04" else 0.0)
	pop_material.set_shader_parameter("print_accent",_pattern.accent)
	pop_material.set_shader_parameter("pixel_dots",false)
	_pattern.material = pop_material

func seek(time: float, leave: float, view: Vector2) -> void:
	var open := 1-pow(1-clampf(time/0.20,0,1),3)
	# The closed seal carries straight through the full-frame crossfade; no second reveal.
	modulate.a = smoothstep(0.0,ALCHEMY.FADE_SECONDS,time) if theme_id in ["FINISH","LAW_01","LAW_02","LAW_03","LAW_05","LAW_06","LAW_07","LAW_08"] else 1.0
	size = view if theme_id in ["FINISH","LAW_01","LAW_02","LAW_03","LAW_05","LAW_06","LAW_07","LAW_08"] else Vector2(view.x*open,view.y)
	var changed := _pattern.size!=view or _pattern.time!=minf(time,1.10)
	_pattern.size = view
	_pattern.time = minf(time,1.10)
	_pattern.position.x = -view.x*leave*0.12
	_pattern.modulate.a = 1-leave
	(_pattern.material as ShaderMaterial).set_shader_parameter("print_scale",view.y/768.0)
	if changed: _pattern.queue_redraw()
