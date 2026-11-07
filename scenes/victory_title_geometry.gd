## Font-derived ink metrics and counter masks. Native display fonts are never replaced.
extends Control
static var geometry: Dictionary=preload("res://scenes/victory_title_geometry_data.gd").DATA
var polygons: Array[PackedVector2Array]=[]
func _init() -> void:
	name="SolidCounterFill";mouse_filter=Control.MOUSE_FILTER_IGNORE;show_behind_parent=true
func configure(label: Label, key: String) -> void:
	polygons.clear()
	var record: Dictionary=geometry[key]
	var px:=float(label.get_theme_font_size("font_size"))
	var font:=label.get_theme_font("font")
	var width:=font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(px)).x
	var xfit:=width/(float(record["advance"])*px)
	for contour: Array in record["counters"]:
		var points:=PackedVector2Array()
		for point: Array in contour:points.append(Vector2(float(point[0])*px*xfit,font.get_ascent(int(px))+float(point[1])*px))
		polygons.append(points)
	queue_redraw()
static func ink_bounds(label: Label, key: String) -> Rect2:
	if not geometry.has(key):
		var font: Font = label.get_theme_font("font")
		var px: int = label.get_theme_font_size("font_size")
		return Rect2(Vector2.ZERO,font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,px))
	var record: Dictionary=geometry[key];var box: Array=record["bbox"]
	var px:=float(label.get_theme_font_size("font_size"));var font:=label.get_theme_font("font")
	var width:=font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(px)).x
	return Rect2(Vector2(float(box[0])*px,font.get_ascent(int(px))+float(box[1])*px),Vector2(width,(float(box[3])-float(box[1]))*px))
func _draw() -> void:
	for points: PackedVector2Array in polygons:draw_colored_polygon(points,Color.BLACK)
