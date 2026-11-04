## One short confirmation on the real board, before the themed law introduction.
extends Control
const DURATION := 1.05
const HIT_AT := 0.28
const FONT: Font = preload("res://assets/fonts/ONE-Mobile-POP.otf")
var time := -1.0
var law_name := ""
var accent := Color("ffd43b")
var ink := Color("211a20")
var _headline: Label
var _name: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	set_process(false)
	_headline = _label("조건 달성!",52)
	_name = _label("",27)

func _label(text: String, px: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",px)
	label.add_theme_constant_override("outline_size",5)
	label.add_theme_color_override("font_outline_color",Color("15111c"))
	add_child(label)
	return label

func setup(title: String, color: Color, dark: Color) -> void:
	law_name = title
	accent = color.lightened(0.28)
	ink = dark
	_name.text = title
	_headline.add_theme_color_override("font_color",accent)
	_name.add_theme_color_override("font_color",Color("fff5df"))

func seek(seconds: float, view: Vector2) -> void:
	time = seconds
	size = view
	visible = seconds >= 0.0 and seconds < DURATION
	var unit: float = minf(view.x/1366.0,view.y/768.0)
	var enter: float = smoothstep(0.08,0.26,seconds)
	var leave: float = smoothstep(0.78,DURATION,seconds)
	var press: float = sin(clampf((seconds-HIT_AT)/0.15,0.0,1.0)*PI)*0.06
	var extent := Vector2(650,140)*unit
	position = Vector2(lerpf(-view.x*0.7,0,enter)+leave*view.x*0.7,0)
	_headline.size = Vector2(extent.x,79*unit)
	_headline.position = Vector2((view.x-extent.x)*0.5,view.y*0.51)
	_headline.pivot_offset = _headline.size*0.5
	_headline.scale = Vector2(1.0+press,1.0-press)
	_headline.add_theme_font_size_override("font_size",roundi(52*unit))
	_name.position = _headline.position+Vector2(0,78*unit)
	_name.size = Vector2(extent.x,46*unit)
	_name.add_theme_font_size_override("font_size",roundi(27*unit))
	modulate.a = enter*(1.0-leave)
	queue_redraw()

func _draw() -> void:
	var unit: float = minf(size.x/1366.0,size.y/768.0)
	var center := Vector2(size.x*0.5,size.y*0.51+64*unit)
	var extent := Vector2(675,145)*unit
	var corners := PackedVector2Array([center+Vector2(-extent.x*0.5+20*unit,-extent.y*0.5),center+Vector2(extent.x*0.5,-extent.y*0.5-5*unit),center+extent*0.5,center+Vector2(-extent.x*0.5,-extent.y*0.5+extent.y)])
	draw_colored_polygon(corners,Color(ink,0.90))
	var line_y: float = center.y+extent.y*0.5-3*unit
	draw_line(Vector2(center.x-extent.x*0.47,line_y),Vector2(center.x+extent.x*0.47,line_y),Color(accent,0.8),3*unit,true)
