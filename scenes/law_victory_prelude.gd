## Deterministic board-space introductions; no simulation, timers or RNG.
extends Control

const DURATION := 1.65
const IMPACT_AT := 0.54
const ALCHEMY = preload("res://scenes/alchemy_victory_motion.gd")
const DICE_SOUL = preload("res://scenes/dice_soul_stage.gd")
const PERMA = preload("res://scenes/perma_death_stage.gd")
const ATTACK = preload("res://scenes/attack_meeple_stage.gd")
const MOCHI = preload("res://scenes/mochi_slayer_stage.gd")
const TICKET = preload("res://scenes/golden_ticket_stage.gd")
const MONATIUM_CASH = preload("res://scenes/monatium_cash_stage.gd")
const TRAP = preload("res://scenes/infinite_trap_stage.gd")
const RACE = preload("res://scenes/race_finish_stage.gd")
const HURRICANE = preload("res://scenes/hurricane_force_stage.gd")
var _hurricane: HURRICANE
var law_id := ""
var focus := Vector2.ZERO
var source_view := Vector2.ONE
var spots: Array[Vector2] = []
var time := 0.0
var _circle: TextureRect
var _circle_material: ShaderMaterial
var _dice_soul: DICE_SOUL
var _perma: PERMA
var _attack: ATTACK
var _mochi: MOCHI
var _ticket: TICKET
var _monatium_cash: MONATIUM_CASH
var _trap: TRAP
var _race: RACE
var _scene_materials: Array[ShaderMaterial]=[]
var _scene_blend:=-1.0
var _backdrop_mix:=-1.0

static func impact_at(id: String) -> float:
	if id=="LAW_09": return HURRICANE.IMPACT_AT
	if id=="FINISH": return RACE.SKID_AT
	if id=="LAW_03": return TRAP.IMPACT_AT
	if id=="LAW_02": return MONATIUM_CASH.IMPACT_AT if VictoryLaw.variant_active(id) else TICKET.REVEAL_AT
	if id=="LAW_08": return ATTACK.IMPACT_AT
	if id=="LAW_06": return PERMA.IMPACT_AT
	if id=="LAW_07": return DICE_SOUL.FRONT_AT
	return 1.10 if id=="LAW_05" else IMPACT_AT

static func duration_for(id: String) -> float:
	if id=="LAW_09": return HURRICANE.INTRO_SECONDS
	if id=="FINISH": return RACE.INTRO_SECONDS
	if id=="LAW_03": return TRAP.INTRO_SECONDS
	if id=="LAW_02": return MONATIUM_CASH.INTRO_SECONDS if VictoryLaw.variant_active(id) else TICKET.INTRO_SECONDS
	if id=="LAW_01": return MOCHI.INTRO_SECONDS
	if id=="LAW_08": return ATTACK.INTRO_SECONDS
	if id=="LAW_06": return PERMA.INTRO_SECONDS
	if id=="LAW_07": return DICE_SOUL.INTRO_SECONDS
	return ALCHEMY.INTRO_SECONDS if id=="LAW_05" else DURATION

func _init() -> void:
	name = "LawVictoryPrelude"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func setup(id: String, center: Vector2, reference: Vector2, cause: Array[Vector2]) -> void:
	law_id = id
	focus = center
	source_view = reference
	spots = cause.duplicate()
	if id=="LAW_09" and _hurricane==null:
		_hurricane=HURRICANE.new();add_child(_hurricane);_hurricane.setup(center,reference)
	if id=="FINISH" and _race==null:
		_race=RACE.new();add_child(_race);_race.setup()
	if id=="LAW_03" and _trap==null:
		_trap=TRAP.new();add_child(_trap);_trap.setup(center,reference)
	if id == "LAW_02":
		if VictoryLaw.variant_active(id):
			_monatium_cash = MONATIUM_CASH.new()
			add_child(_monatium_cash)
			_monatium_cash.setup(center, reference)
		else:
			_ticket = TICKET.new()
			add_child(_ticket)
			_ticket.setup()
	if id=="LAW_01" and _mochi==null:
		_mochi=MOCHI.new();add_child(_mochi);_mochi.setup(center,reference)
	if id=="LAW_08" and _attack==null:
		_attack=ATTACK.new();add_child(_attack);_attack.setup(center,reference)
	if id=="LAW_06" and _perma==null:
		_perma=PERMA.new();add_child(_perma);_perma.setup(center,reference)
	if id=="LAW_07" and _dice_soul==null:
		_dice_soul = DICE_SOUL.new()
		add_child(_dice_soul)
	if id=="LAW_05" and _circle==null:
		_circle = TextureRect.new()
		_circle.name = "TransmutationCircle"
		_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sheet := LawFeedback.icon("alchemy")
		var crop := AtlasTexture.new()
		crop.atlas = sheet
		crop.region = PaintedFx.region(sheet)
		_circle.texture = crop
		_circle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_circle.stretch_mode = TextureRect.STRETCH_SCALE
		_circle_material = ShaderMaterial.new()
		_circle_material.shader = preload("res://scenes/alchemy_reveal.gdshader")
		_circle.material = _circle_material
		add_child(_circle)
	_collect_scene_materials(self)

func _collect_scene_materials(node: Node) -> void:
	if node is CanvasItem and node.material is ShaderMaterial:
		var ink:=node.material as ShaderMaterial
		for uniform: Dictionary in ink.shader.get_shader_uniform_list():
			if str(uniform["name"])=="scene_blend" and not _scene_materials.has(ink):_scene_materials.append(ink)
	for child: Node in node.get_children():_collect_scene_materials(child)

func set_scene_palette(paper: Color, ink: Color) -> void:
	for material: ShaderMaterial in _scene_materials:
		material.set_shader_parameter("paper_tone",paper)
		material.set_shader_parameter("ink_tone",ink)

func set_scene_blend(amount: float) -> void:
	if is_equal_approx(amount,_scene_blend):return
	_scene_blend=amount
	for material: ShaderMaterial in _scene_materials:material.set_shader_parameter("scene_blend",amount)

func set_backdrop_mix(amount: float) -> void:
	if is_equal_approx(amount,_backdrop_mix):return
	_backdrop_mix=amount
	for material: ShaderMaterial in _scene_materials:material.set_shader_parameter("backdrop_mix",amount)

func seek(t: float, view: Vector2) -> void:
	time = t
	size = view
	if _hurricane!=null: _hurricane.seek(time,view)
	if _dice_soul!=null: _dice_soul.seek(time,view)
	if _perma!=null: _perma.seek(time,view)
	if _attack!=null: _attack.seek(time,view)
	if _mochi!=null: _mochi.seek(time,view)
	if _ticket!=null: _ticket.seek(time,view)
	if _monatium_cash != null:
		_monatium_cash.seek(time, view)
	if _trap!=null: _trap.seek(time,view)
	if _race!=null: _race.seek(time,view)
	if _circle!=null:
		var region := PaintedFx.region(LawFeedback.icon("alchemy"))
		var frame := ALCHEMY.pose(time,view,focus,source_view,region.size.y/region.size.x)
		_circle.size = frame["extent"]
		_circle.pivot_offset = _circle.size*0.5
		_circle.position = frame["center"]-_circle.size*0.5
		_circle.rotation = float(frame["angle"])
		_circle.modulate.a=lerpf(1.0,0.34,smoothstep(ALCHEMY.INTRO_SECONDS,ALCHEMY.INTRO_SECONDS+ALCHEMY.FADE_SECONDS,time))
		_circle_material.set_shader_parameter("completion",_ramp(time,0.18,impact_at(law_id)))
		_circle_material.set_shader_parameter("closure",sin(_ramp(time,impact_at(law_id),1.40)*PI))
	queue_redraw()

func _draw() -> void:
	if law_id=="FINISH":return # Its road stage begins with an opaque single-colour frame.
	var ratio := minf(size.x/1366.0,size.y/768.0)
	var at := focus*size/source_view
	var dim := 0.38*_ramp(time,0,0.18)
	if law_id=="LAW_05":
		dim = lerpf(dim,0.82,smoothstep(ALCHEMY.RISE_AT,ALCHEMY.FRONT_AT,time))
		dim *= 1.0-smoothstep(ALCHEMY.INTRO_SECONDS,ALCHEMY.INTRO_SECONDS+ALCHEMY.FADE_SECONDS,time)
	elif law_id=="LAW_07":
		dim = lerpf(dim,0.82,smoothstep(1.12,DICE_SOUL.FRONT_AT,time))
		dim *= 1.0-smoothstep(DICE_SOUL.INTRO_SECONDS,DICE_SOUL.INTRO_SECONDS+DICE_SOUL.FADE_SECONDS,time)
	elif law_id=="LAW_06":
		dim=lerpf(dim,0.82,smoothstep(PERMA.FALL_AT,PERMA.IMPACT_AT,time))
		dim*=1.0-smoothstep(PERMA.INTRO_SECONDS,PERMA.INTRO_SECONDS+PERMA.FADE_SECONDS,time)
	elif law_id=="LAW_08":
		dim=lerpf(dim,0.76,smoothstep(ATTACK.DROP_AT,ATTACK.IMPACT_AT,time))
		dim*=1.0-smoothstep(ATTACK.INTRO_SECONDS,ATTACK.INTRO_SECONDS+ATTACK.FADE_SECONDS,time)
	elif law_id=="LAW_01":
		dim=lerpf(dim,0.76,smoothstep(MOCHI.MORPH_AT,MOCHI.PRINT_AT,time))
		dim*=1.0-smoothstep(MOCHI.INTRO_SECONDS,MOCHI.INTRO_SECONDS+MOCHI.FADE_SECONDS,time)
	elif law_id=="LAW_02":
		dim = lerpf(dim, 0.80, smoothstep(0.18, 1.0, time))
		var intro := MONATIUM_CASH.INTRO_SECONDS if _monatium_cash != null else TICKET.INTRO_SECONDS
		var fade := MONATIUM_CASH.FADE_SECONDS if _monatium_cash != null else TICKET.FADE_SECONDS
		dim *= 1.0 - smoothstep(intro, intro + fade, time)
	elif law_id=="LAW_03":
		dim=lerpf(dim,0.82,smoothstep(0.30,TRAP.IMPACT_AT,time))
		dim*=1.0-smoothstep(TRAP.INTRO_SECONDS,TRAP.INTRO_SECONDS+TRAP.FADE_SECONDS,time)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.06,0.055,0.08,dim))
	match law_id:
		"LAW_01": pass # One clipped sword pulls out and becomes its matching print.
		"LAW_02": pass # The board's ticket or cash prop carries into the matching print.
		"LAW_03": pass # Drawn 2D hills and planted cards lead into the same giant-card print.
		"LAW_04": _jackpot(at,ratio)
		"LAW_05": _alchemy(at,ratio)
		"LAW_06": pass # The actual basic pawn carries into its matching illustration.
		"LAW_07": pass # The child owns one real 3D world, carried into the finale.
		"LAW_08": pass # Sliced crowned pawns, knight impact and the matching print.

static func sword_depth(t: float) -> float:
	return MOCHI.depth(t)

func _stamps(at: Vector2, ratio: float, icon_name: String, count: int) -> void:
	for i: int in count:
		var hit := _ramp(time,0.16+float(i)*0.14,0.32+float(i)*0.14)
		if hit<=0.0: continue
		var x := (float(i)-float(count-1)*0.5)*94*ratio
		var point := at+Vector2(x,-sin(float(i)*0.8)*18*ratio)
		var scale := lerpf(1.6,1.0,1-pow(1-hit,3))
		PaintedFx.stamp(self,LawFeedback.icon(icon_name),point,Vector2.ONE*90*ratio*scale,Color(1,1,1,hit))
		if icon_name=="bolt" and i>0:
			PaintedFx.streak(self,point-Vector2(82*ratio,0),point,10*ratio,Color(0.4,0.85,1,hit*0.8))
		if hit<1: PaintedFx.stamp(self,PaintedFx.IMPACT,point,Vector2(120,65)*ratio,Color(1,0.88,0.5,(1-hit)*0.7))

func _jackpot(at: Vector2, ratio: float) -> void:
	var texture := LawFeedback.icon("jackpot")
	var font := preload("res://scenes/law_victory_theme.gd").font_for("LAW_04",L10n.current_lang)
	var enter := 1-pow(1-_ramp(time,0.10,0.42),3)
	if enter<=0.001: return
	var width := 324.0*ratio
	var extent := Vector2(width,width*texture.get_height()/texture.get_width())
	var point := at+Vector2(0,-22-(1-enter)*100)*ratio
	var scale := lerpf(0.76,1.0,enter)
	draw_set_transform(point,0,Vector2.ONE*scale)
	draw_texture_rect(texture,Rect2(-extent*0.5,extent),false,Color(1,1,1,enter))
	# Stop the reels left to right on the same clock. No random result is generated.
	for i: int in 3:
		if time>=0.26+float(i)*0.14: continue
		var window := Rect2(-extent*0.5+extent*Vector2(0.203+float(i)*0.21,0.313),extent*Vector2(0.176,0.361))
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(Color("fff0cd"),enter)
		fill.set_corner_radius_all(roundi(5*ratio))
		draw_style_box(fill,window)
		var number := str(1+(floori(time*25)+i*3)%9)
		var px := maxi(12,roundi(window.size.y*0.78))
		var text_size := font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,px)
		var baseline := window.position+Vector2((window.size.x-text_size.x)*0.5,window.size.y*0.82)
		draw_string_outline(font,baseline,number,HORIZONTAL_ALIGNMENT_LEFT,-1,px,maxi(1,roundi(2*ratio)),Color(Color("271721"),enter))
		draw_string(font,baseline,number,HORIZONTAL_ALIGNMENT_LEFT,-1,px,Color(Color("c93235"),enter))
	draw_set_transform(Vector2.ZERO)
	if time>=IMPACT_AT:
		var burst := _ramp(time,IMPACT_AT,1.02)
		for i: int in 6:
			var a := float(i)*TAU/6-0.4
			var chip_at := point+Vector2(cos(a)*190,sin(a)*85-45)*ratio*burst
			PaintedFx.stamp(self,LawFeedback.icon("chip"),chip_at,Vector2(36,28)*ratio,Color(1,1,1,(1-burst)*0.90),a+burst)


func _alchemy(_at: Vector2, ratio: float) -> void:
	var points := node_positions(size)
	var grounded := 1.0-smoothstep(ALCHEMY.RISE_AT,ALCHEMY.FRONT_AT,time)
	for i: int in points.size():
		var point := points[i]
		var ignite := _ramp(time,0.05+float(i)*0.10,0.23+float(i)*0.10)
		var connect := _ramp(time,0.26+float(i)*0.12,0.68+float(i)*0.12)
		var next := points[(i+1)%points.size()]
		if connect>0:
			PaintedFx.streak(self,point,point.lerp(next,connect),7*ratio,Color(1,0.83,0.34,0.70*grounded))
		if ignite>0:
			PaintedFx.stamp(self,PaintedFx.RIPPLE,point,Vector2(80,32)*ratio,Color(1,0.86,0.38,ignite*0.65*grounded))
			PaintedFx.stamp(self,LawFeedback.icon("alchemy_node"),point+Vector2(0,-48)*ratio,Vector2(25,39)*ratio,Color(1,1,1,ignite*grounded))
	var complete := _ramp(time,impact_at(law_id),1.40)
	if complete>0 and complete<1:
		for point: Vector2 in points:
			PaintedFx.stamp(self,PaintedFx.FLECK,point-Vector2(0,32)*ratio*complete,Vector2(36,62)*ratio,Color(1,0.93,0.58,sin(complete*PI)))

func node_positions(view: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for point: Vector2 in spots: points.append(point*view/source_view)
	if points.size()<3:
		var ratio := minf(view.x/1366.0,view.y/768.0)
		var at := focus*view/source_view
		points = [at+Vector2(-140,40)*ratio,at+Vector2(0,-70)*ratio,at+Vector2(140,40)*ratio]
	return points

static func _ramp(t: float, start: float, end: float) -> float:
	return clampf((t-start)/maxf(end-start,0.001),0,1)
