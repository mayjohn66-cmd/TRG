## Shared buff outline. Exact host silhouette; no floating aura or particles.
extends Control

const TEXTURE_OUTLINE=preload("res://scenes/ui_buff_outline.gdshader")
const FLAT_OUTLINE=preload("res://scenes/ui_buff_flat.gdshader")
const VOLT_ARCS=preload("res://scenes/ui_buff_volt_arcs.gd")
var _arcs:Control
var effects:int=0:
	set(value):
		effects=value
		_refresh_tint()
		if _arcs!=null:_arcs.advance(_time,(effects&4)!=0)
var _time:=0.0
var colors:Array[Color]=[]:
	set(value):
		colors=value
		_refresh_tint()
var _host_style:StyleBox
var _flat:StyleBoxFlat
var _texture:NinePatchRect
var _ink:ShaderMaterial
var _flat_ink:ShaderMaterial

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Containers must not inset this decoration into their content margins.
	top_level=true

func _ready() -> void:
	_sync_host()
	_arcs=VOLT_ARCS.new();_arcs.name="VoltDischargePaths"
	add_child(_arcs);_sync_host();_arcs.advance(_time,(effects&4)!=0)

func _process(delta:float) -> void:
	_sync_host()
	if not is_visible_in_tree():return
	_time+=delta
	for ink:ShaderMaterial in [_ink,_flat_ink]:
		if ink!=null:ink.set_shader_parameter("effect_time",_time)
	if _arcs!=null:_arcs.advance(_time,(effects&4)!=0)

func _sync_host() -> void:
	var host:=get_parent() as Control
	if host==null:return
	var frame:=host.get_global_transform()
	position=frame.origin
	scale=frame.get_scale()
	rotation=frame.get_rotation()
	size=host.size
	var style:=host.get_theme_stylebox("panel")
	if style!=_host_style:
		_host_style=style
		_bind_style(style)
	if _texture!=null:_texture.size=size
	if _arcs!=null:
		_arcs.size=size
		_arcs.radius=float(_flat.get_corner_radius(CORNER_TOP_RIGHT)) if _flat!=null else 9.0

func _bind_style(style:StyleBox) -> void:
	_flat=null
	if _texture!=null:
		remove_child(_texture);_texture.queue_free();_texture=null
	_ink=null
	_flat_ink=null;material=null
	if style is StyleBoxFlat:
		_flat=style.duplicate() as StyleBoxFlat
		_flat.draw_center=false
		_flat.shadow_size=0
		_flat.shadow_color=Color.TRANSPARENT
		_flat_ink=ShaderMaterial.new();_flat_ink.shader=FLAT_OUTLINE
		material=_flat_ink
	elif style is StyleBoxTexture:
		var source:=style as StyleBoxTexture
		_texture=NinePatchRect.new();_texture.name="SkinOutline"
		_texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_texture.texture=source.texture
		_texture.region_rect=source.region_rect
		for side:int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			_texture.set_patch_margin(side,roundi(source.get_texture_margin(side)))
		_texture.axis_stretch_horizontal=int(source.axis_stretch_horizontal)
		_texture.axis_stretch_vertical=int(source.axis_stretch_vertical)
		_ink=ShaderMaterial.new();_ink.shader=TEXTURE_OUTLINE
		_texture.material=_ink;add_child(_texture)
	_refresh_tint()
	if _arcs!=null:move_child(_arcs,-1)

func _refresh_tint() -> void:
	var tint:=Color.TRANSPARENT
	if not colors.is_empty():
		tint=colors[0]
		for i:int in range(1,colors.size()):tint=tint.lerp(colors[i],1.0/float(i+1))
	if _flat!=null:_flat.border_color=Color.WHITE
	for ink:ShaderMaterial in [_ink,_flat_ink]:
		if ink!=null:
			ink.set_shader_parameter("outline_tint",tint)
			ink.set_shader_parameter("effects",effects)
			ink.set_shader_parameter("effect_time",_time)
	queue_redraw()

func _draw() -> void:
	if _flat!=null and not colors.is_empty():
		draw_style_box(_flat,Rect2(Vector2.ZERO,size))
