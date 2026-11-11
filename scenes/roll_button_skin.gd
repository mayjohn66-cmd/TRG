## Native painted raised/recessed button sheet. Labels and actions remain live.
extends Node
const SHEET:Texture2D=preload("res://assets/ui/trickcal/roll_button_v01/roll_button_states.png")
const CITY_SHEET:Texture2D=preload("res://assets/ui/trickcal/monatium_buttons/roll.png")
static var _faces:Dictionary={}
var _last_key:=""

static func _face(pressed:bool, city:bool=false) -> AtlasTexture:
	if not _faces.has(city):
		var sheet:Texture2D=CITY_SHEET if city else SHEET
		var ratio:Vector2=sheet.get_size()/Vector2(1774,887)
		var faces:Array[AtlasTexture]=[]
		for i:int in 2:
			var atlas:=AtlasTexture.new();atlas.atlas=sheet
			atlas.region=Rect2(Vector2(52+i*887,60)*ratio,Vector2(784,784)*ratio)
			atlas.filter_clip=true;faces.append(atlas)
		_faces[city]=faces
	return _faces[city][1 if pressed else 0]

static func apply(button:Button, city:bool=false) -> void:
	button.set_meta("roll_art_font_max",32 if button.size.x>140 else 24)
	button.clip_text=true
	button.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state:String in ["normal","hover","pressed","disabled"]:
		var box:=StyleBoxTexture.new();box.texture=_face(state=="pressed",city)
		box.set_texture_margin_all(0.0);box.set_content_margin_all(0.0)
		box.content_margin_top=button.size.y*0.045 if state=="pressed" else 0.0
		box.content_margin_bottom=0.0 if state=="pressed" else button.size.y*0.035
		box.modulate_color={"normal":Color.WHITE,"hover":Color(1.08,1.08,1.04),"pressed":Color.WHITE,"disabled":Color(0.60,0.64,0.52,0.85)}[state]
		button.add_theme_stylebox_override(state,box)
	var focus:=StyleBoxFlat.new();focus.draw_center=false
	focus.border_color=Color("81e6eb") if city else Color(1.0,0.94,0.70,0.9);focus.set_border_width_all(2)
	focus.set_corner_radius_all(roundi(button.size.x*0.5));focus.set_expand_margin_all(2.0)
	button.add_theme_stylebox_override("focus",focus)
	for state:String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,Color("fff8db"))
	button.add_theme_color_override("font_disabled_color",Color("c9c5ad"))
	button.add_theme_color_override("font_outline_color",Color("18374d") if city else Color("294522"))
	button.add_theme_constant_override("outline_size",3)
	if button.get_node_or_null("RollButtonArt")==null:
		var driver:=new();driver.name="RollButtonArt";button.add_child(driver)
	fit_text(button)

static func fit_text(button:Button) -> void:
	var font:=button.get_theme_font("font")
	var maximum:int=int(button.get_meta("roll_art_font_max",24))
	var pixels:int=maximum
	var room:float=button.size.x*0.72
	while pixels>14:
		var width:float=0.0
		for line:String in button.text.split("\n"):
			width=maxf(width,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x)
		if width<=room:break
		pixels-=1
	button.add_theme_font_size_override("font_size",pixels)

func _process(_delta:float) -> void:
	var button:=get_parent() as Button
	if button==null or not button.is_visible_in_tree():return
	var key:String=button.text+str(button.size)+str(button.get_meta("roll_art_font_max",24))
	if key!=_last_key:
		_last_key=key;fit_text(button)
