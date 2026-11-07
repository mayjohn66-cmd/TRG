## Satellite-style column presentation. API matches the remote SUM_03 view.
## Used by the registered SUM_03 card and local visual previews.
class_name ProtonBeamView
extends Node2D
signal landed
const HEIGHT:=360.0
const FLOOR_SCALE:=1.90
const GROUND=preload("res://scenes/spotlight_geometry.gd")
const ENERGY:Texture2D=preload("res://assets/fx/proton_beam/energy_column_v01.png")
var drop:float=1.0:
	set(value):
		drop=clampf(value,0.0,1.0)
		if _column_ink!=null:_column_ink.set_shader_parameter("drop",drop)
var rounds_left:=3
var _retire:=0.0
var _clock:=0.0
var _landed_at:=-100.0
var _touched:=true
var _board_ref:WeakRef
var _column:TextureRect
var _column_ink:ShaderMaterial
var _floor:MeshInstance2D
var _floor_ink:ShaderMaterial
var _burst:ColorRect
var _burst_ink:ShaderMaterial
var _rear_burst:ColorRect
var _rear_burst_ink:ShaderMaterial
var _flecks:Array[Sprite2D]=[]
var _label:Label
var _motion:Tween
var _audio:=PresentationAudio.new()
var _hum:AudioStreamPlayer

func _ready() -> void:
	_floor=MeshInstance2D.new();_floor.name="ProjectedContactLight"
	var quad:=QuadMesh.new();quad.size=Vector2(2,2);_floor.mesh=quad
	_floor_ink=ShaderMaterial.new();_floor_ink.shader=preload("res://scenes/proton_contact.gdshader")
	_floor.material=_floor_ink;add_child(_floor)
	_rear_burst=_make_contact_spikes(false)
	_rear_burst_ink=_rear_burst.material as ShaderMaterial
	_column=TextureRect.new();_column.name="SatelliteEnergyColumn"
	_column.texture=ENERGY;_column.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_column.stretch_mode=TextureRect.STRETCH_SCALE;_column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_column_ink=ShaderMaterial.new();_column_ink.shader=preload("res://scenes/proton_column.gdshader")
	_column.material=_column_ink;add_child(_column)
	_burst=_make_contact_spikes(true)
	_burst_ink=_burst.material as ShaderMaterial
	for i:int in 15:
		var fleck:=PaintedFx.sprite(PaintedFx.FLECK)
		fleck.name="EscapingSpark%d"%i;add_child(fleck);_flecks.append(fleck)
	_label=Label.new();_label.name="BeamLifetime"
	_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font",preload("res://assets/fonts/game_ui_font.tres"))
	_label.add_theme_font_size_override("font_size",12)
	_label.add_theme_color_override("font_color",Color("f5e8ff"))
	_label.add_theme_color_override("font_outline_color",Color("241032"))
	_label.add_theme_constant_override("outline_size",4)
	_label.position=Vector2(82,15);add_child(_label)
	configure(rounds_left)
	visibility_changed.connect(func()->void:
		set_process(is_visible_in_tree())
		if not is_visible_in_tree():_audio.cancel())
	_sync_projection();_apply_light()
	set_process(is_visible_in_tree())

func _make_contact_spikes(front:bool) -> ColorRect:
	var crown:=ColorRect.new();crown.name="ContactCrownFront" if front else "ContactCrownRear"
	crown.position=Vector2(-150,-140);crown.size=Vector2(300,220)
	crown.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var ink:=ShaderMaterial.new();ink.shader=preload("res://scenes/proton_impact.gdshader")
	ink.set_shader_parameter("front_pass",front)
	crown.material=ink;add_child(crown)
	return crown

func setup_projection(board:Node) -> void:
	_board_ref=weakref(board)
	if is_node_ready():_sync_projection()

func configure(rounds:int) -> void:
	rounds_left=rounds
	if _label!=null:_label.text="%dR"%rounds

func descend(duration:float=0.55) -> Tween:
	_stop_motion();show();_retire=0.0;drop=0.0;_touched=false;_landed_at=-100.0
	_audio.start(self);_audio.fire(&"proton_descend")
	_motion=create_tween()
	_motion.tween_property(self,"drop",1.0,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	return _motion

func fade_out(duration:float=0.7) -> void:
	_stop_motion()
	_motion=create_tween()
	_motion.tween_property(self,"_retire",1.0,duration).set_trans(Tween.TRANS_LINEAR)
	_motion.tween_callback(queue_free)

func cancel() -> void:
	_audio.cancel()
	_stop_motion();hide();set_process(false)

func _stop_motion() -> void:
	if _motion!=null and _motion.is_valid():_motion.kill()

func _exit_tree() -> void:
	_stop_motion();_audio.cancel()

func _process(delta:float) -> void:
	_clock+=delta
	if not _touched and drop>=0.985:
		_touched=true;_landed_at=_clock;landed.emit()
		_audio.fire(&"proton_land")
		_hum=_audio.fire(&"proton_hum",-3.0,true)
	_sync_projection();_apply_light()

func _sync_projection() -> void:
	var foot:Vector2=get_global_transform_with_canvas().origin
	var above:Vector2=get_global_transform_with_canvas().affine_inverse()*Vector2(foot.x,-70)
	var height:float=maxf(HEIGHT,-above.y)
	var width:float=maxf(0.001,1.0-smoothstep(0.0,1.0,_retire))
	_column.position=Vector2(-150*width,-height);_column.size=Vector2(300,height+62)
	_column.scale=Vector2(width,1.0)
	_column_ink.set_shader_parameter("column_size",_column.size)
	_column_ink.set_shader_parameter("foot_y",height)
	var frame:=Transform2D(Vector2(34.93,22.17),Vector2(-34.93,22.17),Vector2.ZERO)
	var board:Node=_board_ref.get_ref() if _board_ref!=null else null
	if board!=null:frame=GROUND.floor_axes(board,self)
	var base:=Transform2D(frame.x*FLOOR_SCALE,frame.y*FLOOR_SCALE,Vector2.ZERO)
	_floor.transform=Transform2D(base.x*width,base.y*width,Vector2.ZERO)
	_column_ink.set_shader_parameter("floor_axis_x",base.x)
	_column_ink.set_shader_parameter("floor_axis_y",base.y)
	for crown:ColorRect in [_burst,_rear_burst]:
		crown.scale=Vector2.ONE*width;crown.position=Vector2(-150,-140)*width
	for ink:ShaderMaterial in [_burst_ink,_rear_burst_ink]:
		ink.set_shader_parameter("floor_axis_x",base.x)
		ink.set_shader_parameter("floor_axis_y",base.y)

func _apply_light() -> void:
	var impact:float=exp(-maxf(0,_clock-_landed_at)*10.0)
	# The full-height column narrows around its fixed axis; its contact contracts with it.
	var width:float=1.0-smoothstep(0.0,1.0,_retire)
	if is_instance_valid(_hum):_hum.volume_db=-3.0+linear_to_db(maxf(width,0.0001))
	var contact:float=smoothstep(0.975,1.0,drop)*sqrt(width)
	_column_ink.set_shader_parameter("flow_time",_clock)
	_column_ink.set_shader_parameter("drop",drop)
	_column_ink.set_shader_parameter("retract",_retire)
	_column_ink.set_shader_parameter("impact",impact)
	_column_ink.set_shader_parameter("contact",contact)
	_floor_ink.set_shader_parameter("flow_time",_clock)
	_floor_ink.set_shader_parameter("strength",contact)
	_floor_ink.set_shader_parameter("impact",impact)
	for ink:ShaderMaterial in [_burst_ink,_rear_burst_ink]:
		ink.set_shader_parameter("contact_age",maxf(0.0,_clock-_landed_at))
		ink.set_shader_parameter("strength",contact)
		ink.set_shader_parameter("impact",impact)
	_label.modulate.a=contact
	for i:int in _flecks.size():
		var p:float=fposmod((_clock-_landed_at)*3.4+float(i)*0.173,1.0)
		var angle:float=float(i)*2.39996+0.2
		var ground:Vector2=_floor.transform.basis_xform(Vector2.from_angle(angle))*(0.30+sqrt(p)*1.25)
		var fleck:Sprite2D=_flecks[i]
		var lift:float=sin(p*PI)*(28.0+float(i%4)*14.0)*width
		fleck.position=ground+Vector2(0,-lift)
		fleck.rotation=(ground+Vector2(0,-lift)).angle()+PI*0.5
		fleck.scale=Vector2(3.5,19.0+float(i%3)*7.0)*(1.0-p*0.45)*width/fleck.region_rect.size
		fleck.modulate=Color(0.85,0.97,1.0,smoothstep(0.0,0.10,p)*(1.0-p)*contact*1.3)
