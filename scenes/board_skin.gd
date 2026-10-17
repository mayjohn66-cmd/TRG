## Shared board artwork and projected property-style tile geometry.
class_name BoardSkin
extends RefCounted

const TRACK_INSET: float = 0.08
## Board-normalized dimensions: narrow along the track, deep toward the center.
const NORMAL_WIDTH: float = 0.108
const NORMAL_SIZE: float = 0.142
const CORNER_SIZE: float = 0.144
const SURFACE: Texture2D = preload("res://assets/board/trickcal/board_surface.png")

static func definition(index: int) -> Dictionary:
	# Color bands describe existing tile types, never player ownership.
	var horizontal_row: bool = index in range(7,12) or index in range(19,24)
	var footprint := Vector2(NORMAL_WIDTH,NORMAL_SIZE) if horizontal_row else Vector2(NORMAL_SIZE,NORMAL_WIDTH)
	var data: Dictionary = {"kind":"normal", "fill":Color("fff6df"), "edge":Color("7c9558"), "ink":Color("486135"), "band":Color("b4d479"), "footprint":footprint, "diameter":NORMAL_SIZE, "major":false}
	if index in GameEnums.BAKERY_TILES:
		data.merge({"kind":"bakery", "band":Color("f4bd55"), "edge":Color("b68b43"), "ink":Color("845221")},true)
	if index in GameEnums.PORTAL_TILES:
		data.merge({"kind":"portal", "band":Color("ac87c7"), "edge":Color("8d6a9c"), "ink":Color("69457d")},true)
	if index in GameEnums.CORNER_TILES:
		data.merge({"diameter":CORNER_SIZE, "footprint":Vector2.ONE*CORNER_SIZE, "major":true},true)
		if index == GameEnums.GOAL_TILE:
			data.merge({"kind":"start", "edge":Color("5d8c3d"), "ink":Color("416c2b")},true)
		elif index == GameEnums.HALFWAY_TILE:
			data.merge({"kind":"half", "edge":Color("b68b43"), "ink":Color("845221")},true)
		else:
			data.merge({"kind":"corner", "edge":Color("5d8c3d"), "ink":Color("416c2b")},true)
	return data

static func track(norm: Vector2) -> Vector2:
	return Vector2.ONE*TRACK_INSET + norm*(1.0-2.0*TRACK_INSET)

static func outline(projector: Callable, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	return _rounded_outline(projector, Rect2(0,0,1,1), 0.062, offset)

static func safe_outline(projector: Callable) -> PackedVector2Array:
	return _rounded_outline(projector, Rect2(0.065,0.065,0.87,0.87), 0.07, Vector2.ZERO)

static func _rounded_outline(projector: Callable, rect: Rect2, radius: float, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var a: Vector2 = rect.position
	var b: Vector2 = rect.end
	var corners: Array[Vector2] = [Vector2(b.x-radius,a.y+radius),Vector2(b.x-radius,b.y-radius),Vector2(a.x+radius,b.y-radius),Vector2(a.x+radius,a.y+radius)]
	for c: int in 4:
		for s: int in 17:
			var angle: float = -PI/2.0+c*PI/2.0+s*PI/32.0
			var uv: Vector2 = corners[c]+Vector2(cos(angle),sin(angle))*radius
			result.append((projector.call(Vector2(-0.11,-0.11)+uv*1.22) as Vector2)+offset)
	return result

static func make_surface() -> MeshInstance2D:
	var face := MeshInstance2D.new()
	face.texture = SURFACE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
    float r = 0.062;
    vec2 q = abs(UV - vec2(0.5)) - vec2(0.5-r);
    float d = length(max(q,vec2(0.0))) + min(max(q.x,q.y),0.0)-r;
    COLOR = texture(TEXTURE,UV);
    COLOR.a *= 1.0-smoothstep(-0.0006,0.0006,d);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	face.material = material
	return face

static func update_surface(face: MeshInstance2D, projector: Callable) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const STEPS: int = 24
	for y: int in STEPS+1:
		for x: int in STEPS+1:
			var uv := Vector2(float(x)/STEPS,float(y)/STEPS)
			var p: Vector2 = projector.call(Vector2(-0.11,-0.11)+uv*1.22)
			vertices.append(Vector3(p.x,p.y,0))
			uvs.append(uv)
	for y: int in STEPS:
		for x: int in STEPS:
			var i: int = y*(STEPS+1)+x
			indices.append_array(PackedInt32Array([i,i+1,i+STEPS+1,i+1,i+STEPS+2,i+STEPS+1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	face.mesh = mesh

class Symbol extends Control:
	var kind: String = "normal"
	var ink: Color = Color("5da530")
	var fill: Color = Color("e9f5cf")
	var tile_id: int = -1
	var direction: Vector2 = Vector2.RIGHT

	func stroke(points: PackedVector2Array, width: float = 4.5, color: Color = Color.TRANSPARENT) -> void:
		var line_ink: Color = ink if color.a == 0.0 else color
		draw_polyline(points,line_ink,width,true)
		draw_circle(points[0],width/2.0,line_ink,true,-1,true)
		draw_circle(points[-1],width/2.0,line_ink,true,-1,true)

	func round_box(rect: Rect2, color: Color, radius: int) -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		draw_style_box(style,rect)

	func quadratic(points: PackedVector2Array, a: Vector2, control: Vector2, b: Vector2) -> PackedVector2Array:
		for i: int in range(1,17):
			var t: float = float(i)/16.0
			points.append((1.0-t)*(1.0-t)*a+2.0*(1.0-t)*t*control+t*t*b)
		return points

	func cubic(points: PackedVector2Array, a: Vector2, c1: Vector2, c2: Vector2, b: Vector2) -> PackedVector2Array:
		for i: int in range(1,25):
			var t: float = float(i)/24.0
			points.append(pow(1.0-t,3)*a+3.0*pow(1.0-t,2)*t*c1+3.0*(1.0-t)*t*t*c2+t*t*t*b)
		return points

	func arrow(a: Vector2, b: Vector2) -> void:
		# Rounded silhouette reconstructed from the user's reference in a 500x500 viewbox.
		var p := PackedVector2Array([Vector2(44,133),Vector2(173,133)])
		p = quadratic(p,Vector2(173,133),Vector2(195,133),Vector2(195,110))
		p.append(Vector2(195,70))
		p = cubic(p,Vector2(195,70),Vector2(195,32),Vector2(231,12),Vector2(261,35))
		p.append(Vector2(477,212))
		p = cubic(p,Vector2(477,212),Vector2(503,233),Vector2(503,267),Vector2(477,288))
		p.append(Vector2(261,465))
		p = cubic(p,Vector2(261,465),Vector2(231,488),Vector2(195,468),Vector2(195,430))
		p.append(Vector2(195,390))
		p = quadratic(p,Vector2(195,390),Vector2(195,369),Vector2(173,369))
		p.append(Vector2(44,369))
		p = cubic(p,Vector2(44,369),Vector2(20,369),Vector2(1,350),Vector2(1,325))
		p.append(Vector2(1,177))
		p = cubic(p,Vector2(1,177),Vector2(1,153),Vector2(20,133),Vector2(44,133))
		var d: Vector2 = (b-a).normalized()
		var n := Vector2(-d.y,d.x)
		var ratio: float = a.distance_to(b)/494.0
		var result := PackedVector2Array()
		for point: Vector2 in p:
			var local: Vector2 = (point-Vector2(248,250))*ratio
			result.append((a+b)/2.0+d*local.x+n*local.y)
		draw_colored_polygon(result,ink)
		result.append(result[0])
		draw_polyline(result,ink,1.0,true)

	func _draw() -> void:
		if kind == "normal":
			return
		elif kind == "bakery":
			draw_set_transform(Vector2.ZERO,-0.22)
			round_box(Rect2(-27,-17,54,34),ink,17)
			for x: float in [-13.0,0.0,13.0]:
				stroke(PackedVector2Array([Vector2(x+3,-8),Vector2(x-3,7)]),4.5,fill)
		elif kind == "portal":
			round_box(Rect2(-21,-25,42,47),ink,4)
			round_box(Rect2(-16,-19,32,35),fill,2)
			round_box(Rect2(-25,-29,50,7),ink,3)
			stroke(PackedVector2Array([Vector2(0,-19),Vector2(0,17)]),4)
			for x: float in [-6.0,6.0]:
				draw_circle(Vector2(x,1),2.4,ink,true,-1,true)
			for x: float in [-16.0,10.0]:
				round_box(Rect2(x,21,6,7),ink,2)
		elif kind == "half":
			# 반환점: 깃대와 삼각 깃발
			stroke(PackedVector2Array([Vector2(-10,20),Vector2(-10,-20)]),4)
			draw_colored_polygon(PackedVector2Array([Vector2(-8,-20),Vector2(18,-10),Vector2(-8,0)]),ink)
			round_box(Rect2(-18,17,16,6),ink,3)
		elif kind == "start":
			stroke(PackedVector2Array([Vector2(-14,19),Vector2(-14,-19)]),4)
			draw_colored_polygon(PackedVector2Array([Vector2(-12,-18),Vector2(16,-18),Vector2(11,0),Vector2(-12,0)]),ink)
			for p: Vector2 in [Vector2(-8,-15),Vector2(5,-15),Vector2(-1,-8)]:
				draw_rect(Rect2(p,Vector2(7,7)),fill)
		elif kind == "corner":
			arrow(-direction*24.0,direction*24.0)

static func shape(major: bool, inset: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var width: float = 96.0-2.0*inset
	var radius: float = minf(8.0 if major else 5.0,width/2.0)
	var lo: float = inset
	var hi: float = inset+width
	var centers: Array[Vector2] = [Vector2(hi-radius,lo+radius),Vector2(hi-radius,hi-radius),Vector2(lo+radius,hi-radius),Vector2(lo+radius,lo+radius)]
	for corner: int in 4:
		for step: int in 9:
			var angle: float = -PI/2.0+corner*PI/2.0+step*PI/16.0
			points.append(centers[corner]+Vector2(cos(angle),sin(angle))*radius)
	return points


class Ring extends ReferenceRect:
	var points := PackedVector2Array()
	var line_width: float = 3.0
	func _ready() -> void:
		line_width = border_width
		border_width = 0.0

	func _draw() -> void:
		if points.size() < 3:
			return
		var closed: PackedVector2Array = points.duplicate()
		closed.append(closed[0])
		draw_polyline(closed,border_color,line_width,true)

class Tile extends Control:
	var index: int = 0
	var data: Dictionary = {}
	var outline_points := PackedVector2Array()
	var layers: Array[PackedVector2Array] = []
	var side := PackedVector2Array()
	var shadow := PackedVector2Array()
	var band := PackedVector2Array()
	var symbol: Symbol
	var arrow_target: int = -1

	func initialize(tile_index: int) -> void:
		index = tile_index
		data = BoardSkin.definition(index)
		if data.kind != "normal":
			symbol = Symbol.new()
			symbol.kind = data.kind
			symbol.tile_id = index
			symbol.ink = data.ink
			symbol.fill = data.fill
			symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(symbol)

	func configure(projector: Callable, world_center: Vector2, span: float, visual_depth: float, direction: Vector2) -> void:
		var center: Vector2 = projector.call(world_center)
		var diameter: float = data.diameter
		layers.clear()
		for inset: float in [0.0,1.8,3.6]:
			var points := PackedVector2Array()
			for pixel: Vector2 in BoardSkin.shape(data.major,inset):
				var point: Vector2 = projector.call(world_center+(pixel/96.0-Vector2.ONE/2.0)*(data.footprint as Vector2))
				points.append((point-center)/scale+size/2.0)
			layers.append(points)
		outline_points = layers[0]
		band.clear()
		var inward: Vector2 = [Vector2.LEFT,Vector2.DOWN,Vector2.RIGHT,Vector2.UP][index/6]
		if not data.major:
			# The strip follows the inner edge on all four sides of the board.
			var strips: Array[Rect2] = [Rect2(0,0,21,96),Rect2(0,75,96,21),Rect2(75,0,21,96),Rect2(0,0,96,21)]
			var strip: Rect2 = strips[index/6]
			var clip := PackedVector2Array([strip.position,Vector2(strip.end.x,strip.position.y),strip.end,Vector2(strip.position.x,strip.end.y)])
			var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(BoardSkin.shape(false,3.6),clip)
			if not clipped.is_empty():
				for pixel: Vector2 in clipped[0]:
					var point: Vector2 = projector.call(world_center+(pixel/96.0-Vector2.ONE/2.0)*(data.footprint as Vector2))
					band.append((point-center)/scale+size/2.0)
		side.clear()
		shadow.clear()
		var thickness: float = 2.0*span/760.0*visual_depth
		for p: Vector2 in outline_points:
			side.append(p+Vector2(0,thickness)/scale)
			shadow.append(p+Vector2(0,thickness*2.0)/scale)
		if symbol != null:
			var mark_center: Vector2 = projector.call(world_center if data.major else world_center-inward*0.014)
			symbol.position = (mark_center-center)/scale+size/2.0
			var mark_scale: float = diameter*span*visual_depth/96.0*(1.05 if data.major else 0.75)
			symbol.scale = Vector2.ONE*mark_scale/scale
			symbol.direction = direction
			symbol.queue_redraw()
		for child: Node in get_children():
			if child is Ring:
				(child as Ring).points = outline_points
				(child as Ring).queue_redraw()
		queue_redraw()

	func _draw() -> void:
		if layers.is_empty():
			return
		var edge: Color = data.edge
		var fill: Color = data.fill
		draw_colored_polygon(shadow,Color(0.22,0.35,0.13,0.12))
		draw_colored_polygon(side,edge.darkened(0.16))
		var colors: Array[Color] = [edge,Color("fffdf5"),fill]
		for i: int in layers.size():
			draw_colored_polygon(layers[i],colors[i])
		if band.size() >= 3:
			draw_colored_polygon(band,data.band)

	func _has_point(point: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(point,outline_points)

	func contains_global(point: Vector2) -> bool:
		return _has_point(get_global_transform().affine_inverse()*point)
