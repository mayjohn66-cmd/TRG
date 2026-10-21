## Shared board artwork and projected property-style tile geometry.
class_name BoardSkin
extends RefCounted

const TRACK_INSET: float = 0.08
## Board-normalized dimensions: narrow along the track, deep toward the center.
const NORMAL_WIDTH: float = 0.108
const NORMAL_SIZE: float = 0.142
const CORNER_SIZE: float = 0.19
## 일반 타일 폭(트랙 방향) 상한
const MAX_TILE_WIDTH: float = 0.12
const SURFACE: Texture2D = preload("res://assets/board/trickcal/board_surface.png")

## 타일 크기: 일반 타일은 이웃과 거의 맞닿도록 폭을 넓히고, 코너 타일만 크게 키운다 (코너 둘레의 이웃과는 겹치지 않게 BoardLayout.CORNER_REACH 안에서 계산).
static func tile_metrics() -> Dictionary:
	var length: float = 1.0 - 2.0 * TRACK_INSET
	var spacing: float = length * (1.0 - 2.0 * BoardLayout.CORNER_REACH) / float(maxi(BoardSpec.side - 2, 1))
	var width: float = minf(spacing - 0.0015, MAX_TILE_WIDTH)
	var reach: float = length * BoardLayout.CORNER_REACH
	var room: float = 2.0 * (reach - width / 2.0 - 0.002)
	return {"width": width, "depth": minf(NORMAL_SIZE, room), "corner": minf(CORNER_SIZE, room)}


static func definition(index: int) -> Dictionary:
	# Color bands describe existing tile types, never player ownership.
	var step: int = BoardSpec.side
	var horizontal_row: bool = index in range(step + 1, step * 2) or index in range(step * 3 + 1, step * 4)
	var metrics: Dictionary = tile_metrics()
	var width: float = metrics.width
	var depth: float = metrics.depth
	var footprint := Vector2(width,depth) if horizontal_row else Vector2(depth,width)
	var data: Dictionary = {"kind":"normal", "fill":Color("fff6df"), "edge":Color("7c9558"), "ink":Color("486135"), "band":Color("b4d479"), "footprint":footprint, "diameter":depth, "major":false}
	if index in BoardSpec.bakery_tiles:
		data.merge({"kind":"bakery", "band":Color("f4bd55"), "edge":Color("b68b43"), "ink":Color("845221")},true)
	if index in BoardSpec.portal_tiles:
		data.merge({"kind":"portal", "band":Color("5fc4c9"), "edge":Color("3f8f96"), "ink":Color("24636b")},true)  # 청록: 보라색 함정 타일과 구분
	if index in BoardSpec.corner_tiles:
		data.merge({"diameter":metrics.corner, "footprint":Vector2.ONE*float(metrics.corner), "major":true},true)
		if index == GameEnums.GOAL_TILE:
			data.merge({"kind":"start", "edge":Color("5d8c3d"), "ink":Color("416c2b")},true)
		elif index == BoardSpec.halfway_tile:
			data.merge({"kind":"half", "edge":Color("b68b43"), "ink":Color("845221")},true)
		else:
			data.merge({"kind":"corner", "edge":Color("5d8c3d"), "ink":Color("416c2b")},true)
	return data

static func track(norm: Vector2) -> Vector2:
	return Vector2.ONE*TRACK_INSET + norm*(1.0-2.0*TRACK_INSET)

static func outline(projector: Callable, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	return _rounded_outline(projector, Rect2(0,0,1,1), 0.062, offset)

static func safe_outline(projector: Callable) -> PackedVector2Array:
	return _rounded_outline(projector, Rect2(0.03,0.03,0.94,0.94), 0.07, Vector2.ZERO)

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

## Flat source decals are projected by the same board-plane basis as the tile.
const DECALS: Dictionary = {
	"bakery": preload("res://assets/board/decals/BOARD_BAKERY.png"),
	"portal": preload("res://assets/board/decals/BOARD_PORTAL.png"),
	"start": preload("res://assets/board/decals/BOARD_START.png"),
	"half": preload("res://assets/board/decals/BOARD_HALF.png"),
	"corner": preload("res://assets/board/decals/BOARD_CORNER.png"),
	"boost": preload("res://assets/board/decals/BOARD_BOOST.png"),
}
const FLAT_INK: Shader = preload("res://assets/board/decals/flat_ink.gdshader")
const WARNING_SOURCE: Texture2D = preload("res://assets/board/decals/NPC_WARNING.png")
const WARNING_BOUNDS: Rect2 = Rect2(0.0632622,0.0733945,0.8681402,0.8323603)
## Opaque subject bounds in the unchanged 1254px native sources; discard only empty atlas margin.
const DECAL_BOUNDS: Dictionary = {
	"bakery": Rect2(196,409,862,482), "portal": Rect2(296,268,662,739),
	"start": Rect2(308,272,638,750), "half": Rect2(362,246,590,778),
	"corner": Rect2(99,307,1098,665), "boost": Rect2(175,431,909,391),
}
## Native multicolor trap subjects, normalized so imported mip sizes keep the same fit.
const TRAP_BOUNDS: Dictionary = {
	"TRP_02": Rect2(0.1602871,0.1977671,0.6794258,0.5693780),
	"TRP_03": Rect2(0.1427432,0.1068581,0.7807018,0.7719298),
	"TRP_05": Rect2(0.1172249,0.2432217,0.8301435,0.5303030),
	"TRP_06": Rect2(0.1379585,0.2208931,0.7328549,0.5598086),
	"TRP_07": Rect2(0.0725678,0.3317384,0.8548644,0.3492823),
	"TRP_08": Rect2(0.1531100,0.2663477,0.6937799,0.4601276),
	"TRP_C01": Rect2(0.1259968,0.1929825,0.7432217,0.6092504),
	"TRP_C02": Rect2(0.2272727,0.0948963,0.5454545,0.8133971),
	"TRP_C03": Rect2(0.1467305,0.2224880,0.7432217,0.5566188),
	"TRP_C04": Rect2(0.1076555,0.1379585,0.7854864,0.7121212),
	"HIDDEN": Rect2(0.2328549,0.1451356,0.5334928,0.7424242),
	"TRP_01": Rect2(0.1714514,0.1586922,0.6730463,0.6921850),
}

static func trap_region(texture: Texture2D) -> Rect2:
	var key := texture.resource_path.get_file().get_basename()
	var bounds: Rect2 = TRAP_BOUNDS.get(key,Rect2(0,0,1,1))
	bounds = bounds.grow(0.008).intersection(Rect2(0,0,1,1))
	return Rect2(bounds.position*texture.get_size(),bounds.size*texture.get_size())

static func forward_world(index: int) -> Vector2:
	return (BoardLayout.tile_norm((index+1)%BoardSpec.tile_count)-BoardLayout.tile_norm(index)).normalized()

## A tile-local stamp: +X follows its short edge, -Y faces the board center.
static func symbol_axis(index: int) -> Vector2:
	return [Vector2.UP,Vector2.LEFT,Vector2.DOWN,Vector2.RIGHT][mini(index/BoardSpec.side,3)]

## Local decal +X follows a world-plane direction, not a screen-space angle.
static func decal_frame(plane: Transform2D, span: float, direction: Vector2 = Vector2.RIGHT, center: Vector2 = Vector2.ZERO) -> Transform2D:
	var along := direction.normalized()
	var across := Vector2(-along.y,along.x)
	return Transform2D(plane.basis_xform(along)*span/64.0,plane.basis_xform(across)*span/64.0,plane*center)

static func decal_texture(kind: String) -> AtlasTexture:
	var source: Texture2D = DECALS[kind]
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2((DECAL_BOUNDS[kind] as Rect2).position/1254.0*source.get_size(),(DECAL_BOUNDS[kind] as Rect2).size/1254.0*source.get_size())
	atlas.filter_clip = true
	return atlas

static func warning_texture() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = WARNING_SOURCE
	var bounds := WARNING_BOUNDS.grow(0.006).intersection(Rect2(0,0,1,1))
	atlas.region = Rect2(bounds.position*WARNING_SOURCE.get_size(),bounds.size*WARNING_SOURCE.get_size())
	atlas.filter_clip = true
	return atlas

## Multicolor warning ink is preserved; the monochrome terrain shader is not used.
class WarningMark extends Node2D:
	var texture: Texture2D

	func _draw() -> void:
		if texture == null:
			texture = BoardSkin.warning_texture()
		var extent := Vector2(64,64)*texture.get_size()/maxf(texture.get_width(),texture.get_height())
		draw_texture_rect(texture,Rect2(-extent/2.0,extent),false)

class Symbol extends Node2D:
	var kind: String = "normal"
	var texture: Texture2D
	var ink: Color = Color("416c2b")

	func _ready() -> void:
		var flat := ShaderMaterial.new()
		flat.shader = BoardSkin.FLAT_INK
		flat.set_shader_parameter("ink",ink)
		material = flat

	func _draw() -> void:
		if not BoardSkin.DECALS.has(kind):
			return
		if texture == null:
			texture = BoardSkin.decal_texture(kind)
		var extent := Vector2(64,64)*texture.get_size()/maxf(texture.get_width(),texture.get_height())
		draw_texture_rect(texture,Rect2(-extent/2.0,extent),false)

static func shape(major: bool, inset: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var width: float = 96.0-2.0*inset
	var radius: float = minf(8.0 if major else 2.5,width/2.0)
	var lo: float = inset
	var hi: float = inset+width
	var centers: Array[Vector2] = [Vector2(hi-radius,lo+radius),Vector2(hi-radius,hi-radius),Vector2(lo+radius,hi-radius),Vector2(lo+radius,lo+radius)]
	for corner: int in 4:
		for step: int in 9:
			var angle: float = -PI/2.0+corner*PI/2.0+step*PI/16.0
			points.append(centers[corner]+Vector2(cos(angle),sin(angle))*radius)
	return points


## 타일 윤곽선을 따라 그리는 테두리 (경로 예고·선택 표시). ReferenceRect처럼 border_color/border_width로 쓰지만 사각 테두리는 그리지 않는다.
class Ring extends Control:
	var points := PackedVector2Array()
	var border_color: Color = Color.WHITE:
		set(value):
			border_color = value
			queue_redraw()
	var border_width: float = 3.0:
		set(value):
			border_width = value
			queue_redraw()
	var editor_only: bool = false

	func _draw() -> void:
		if points.size() < 3:
			return
		var closed: PackedVector2Array = points.duplicate()
		closed.append(closed[0])
		draw_polyline(closed,border_color,border_width,true)

class Tile extends Control:
	var index: int = 0
	var data: Dictionary = {}
	var outline_points := PackedVector2Array()
	var layers: Array[PackedVector2Array] = []
	var side := PackedVector2Array()
	var shadow := PackedVector2Array()
	var band := PackedVector2Array()
	var symbol: Symbol
	var corner_arrow: Symbol
	var boost_symbol: Symbol
	var warning_mark: WarningMark
	var warning_flow: Symbol
	var plane := Transform2D.IDENTITY
	var arrow_target: int = -1
	## 함정이 깔린 발판: 타일 전체가 보라색으로 바뀌고 가운데에 그 함정의 그림(정체를 모르면 물음표)이 붙는다. pulse는 0~1로 main_board가 갱신한다.
	var trap_on: bool = false
	var trap_pulse: float = 0.0
	var trap_icon: Texture2D = null
	## 중립 NPC 습격 예고: 0 없음 / 1 이동 경로 / 2 잡히는 위험 타일(삼각 경고). direction은 화면 방향이다.
	var danger_level: int = 0
	var danger_dir: Vector2 = Vector2.ZERO
	var danger_pulse: float = 0.0
	## 코랄 부스터 존. 그림은 보드 평면의 진행 방향, flow_dir은 화면 방향, dash_phase는 밝기 펄스다.
	var dash_on: bool = false
	var flow_dir: Vector2 = Vector2.RIGHT
	var dash_phase: float = 0.0
	## 템포 업으로 당겨진 결승선 안의 칸: 체크무늬 결승 깃발 무늬가 덮인다.
	var goal_on: bool = false

	func initialize(tile_index: int) -> void:
		index = tile_index
		data = BoardSkin.definition(index)
		if data.kind != "normal":
			symbol = Symbol.new()
			symbol.kind = data.kind
			symbol.ink = data.ink
			add_child(symbol)
		if data.kind in ["start","half"]:
			corner_arrow = Symbol.new()
			corner_arrow.kind = "corner"
			add_child(corner_arrow)
		if BoardSpec.dash_tiles.has(index):
			boost_symbol = Symbol.new()
			boost_symbol.kind = "boost"
			boost_symbol.ink = Color("fff3d2")
			add_child(boost_symbol)
		warning_mark = WarningMark.new()
		warning_mark.name = "NpcWarning"
		warning_mark.z_index = 10
		warning_mark.visible = false
		add_child(warning_mark)
		warning_flow = Symbol.new()
		warning_flow.name = "NpcHeading"
		warning_flow.kind = "corner"
		warning_flow.ink = Color("fff3d2")
		warning_flow.z_index = 11
		warning_flow.visible = false
		add_child(warning_flow)

	func configure(projector: Callable, world_center: Vector2, span: float, visual_depth: float, direction: Vector2) -> void:
		var center: Vector2 = projector.call(world_center)
		plane = Transform2D(((projector.call(world_center+Vector2.RIGHT) as Vector2)-center)/scale,((projector.call(world_center+Vector2.DOWN) as Vector2)-center)/scale,size/2.0)
		layers.clear()
		for inset: float in [0.0,1.8,3.6]:
			var points := PackedVector2Array()
			for pixel: Vector2 in BoardSkin.shape(data.major,inset):
				var point: Vector2 = projector.call(world_center+(pixel/96.0-Vector2.ONE/2.0)*(data.footprint as Vector2))
				points.append((point-center)/scale+size/2.0)
			layers.append(points)
		outline_points = layers[0]
		band.clear()
		var inward: Vector2 = [Vector2.LEFT,Vector2.DOWN,Vector2.RIGHT,Vector2.UP][mini(index/BoardSpec.side, 3)]
		if not data.major:
			# The strip follows the inner edge on all four sides of the board.
			var strips: Array[Rect2] = [Rect2(0,0,21,96),Rect2(0,75,96,21),Rect2(75,0,21,96),Rect2(0,0,96,21)]
			var strip: Rect2 = strips[mini(index/BoardSpec.side, 3)]
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
			var footprint: Vector2 = data.footprint
			var mark_span: float = minf(footprint.x,footprint.y)*(0.62 if data.major else 0.74)
			var mark_offset: Vector2 = Vector2(-0.014,-0.014) if corner_arrow != null else (Vector2.ZERO if data.major else -inward*0.011)
			var stamp_axis: Vector2 = direction if data.kind == "corner" else (Vector2.RIGHT if data.major else BoardSkin.symbol_axis(index))
			symbol.transform = BoardSkin.decal_frame(plane,mark_span,stamp_axis,mark_offset)
			symbol.queue_redraw()
		if corner_arrow != null:
			corner_arrow.transform = BoardSkin.decal_frame(plane,float(data.diameter)*0.28,direction,Vector2.ONE*float(data.diameter)*0.27)
			corner_arrow.queue_redraw()
		if boost_symbol != null:
			var footprint: Vector2 = data.footprint
			boost_symbol.transform = BoardSkin.decal_frame(plane,minf(footprint.x,footprint.y)*0.79,direction)
		_refresh_danger_mark()
		for child: Node in get_children():
			if child is Ring:
				(child as Ring).points = outline_points
				(child as Ring).queue_redraw()
		queue_redraw()

	func set_trap(on: bool, icon: Texture2D = null) -> void:
		if trap_on != on or trap_icon != icon:
			if trap_on != on:
				trap_pulse = 0.0
			trap_on = on
			trap_icon = icon if on else null
			_refresh_floor_symbols()
			queue_redraw()

	func set_trap_pulse(value: float) -> void:
		trap_pulse = value
		queue_redraw()

	func set_danger(level: int, direction: Vector2 = Vector2.ZERO) -> void:
		if danger_level != level or danger_dir != direction:
			danger_level = level
			danger_dir = direction
			_refresh_floor_symbols()
			_refresh_danger_mark()
			queue_redraw()

	func set_danger_pulse(value: float) -> void:
		danger_pulse = value
		queue_redraw()

	func set_goal(on: bool) -> void:
		if goal_on != on:
			goal_on = on
			_refresh_boost_symbol()
			queue_redraw()

	func set_dash(on: bool, flow: Vector2) -> void:
		dash_on = on
		flow_dir = flow if flow != Vector2.ZERO else Vector2.RIGHT
		_refresh_boost_symbol()
		queue_redraw()

	func _refresh_boost_symbol() -> void:
		if boost_symbol != null:
			boost_symbol.visible = dash_on and not trap_on and not goal_on and danger_level < 2

	func _refresh_floor_symbols() -> void:
		if symbol != null:
			symbol.visible = not trap_on and danger_level < 2
		if corner_arrow != null:
			corner_arrow.visible = not trap_on and danger_level < 2
		_refresh_boost_symbol()

	func _refresh_danger_mark() -> void:
		if warning_mark == null or warning_flow == null:
			return
		warning_mark.visible = danger_level >= 2
		warning_flow.visible = danger_level > 0 and danger_dir != Vector2.ZERO
		var footprint: Vector2 = data.footprint
		var short_edge := minf(footprint.x,footprint.y)
		var heading := plane.affine_inverse().basis_xform(danger_dir).normalized() if danger_dir != Vector2.ZERO else Vector2.ZERO
		var axis := Vector2.RIGHT if data.major else BoardSkin.symbol_axis(index)
		warning_mark.transform = BoardSkin.decal_frame(plane,short_edge*(0.59 if data.major else 0.72),axis,-heading*short_edge*0.06)
		warning_flow.transform = BoardSkin.decal_frame(plane,short_edge*0.23,heading if heading != Vector2.ZERO else Vector2.RIGHT,heading*short_edge*0.37)
		warning_mark.queue_redraw()
		warning_flow.queue_redraw()

	func set_dash_phase(value: float) -> void:
		dash_phase = value
		if boost_symbol != null:
			boost_symbol.modulate.a = 0.88+0.12*sin(dash_phase*TAU)
		queue_redraw()

	func _draw() -> void:
		if layers.is_empty():
			return
		_draw_tile()
		if goal_on:
			_draw_goal()
		if dash_on and not trap_on and not goal_on:
			_draw_dash()
		if trap_on:
			_draw_trap()
		if danger_level > 0:
			_draw_danger()

	## 당겨진 결승선: 타일 안쪽에 흑백 체크무늬를 깔고 금색 테두리를 두른다.
	func _draw_goal() -> void:
		var inner: PackedVector2Array = layers[layers.size() - 1]
		var box := Rect2(inner[0], Vector2.ZERO)
		for point: Vector2 in inner:
			box = box.expand(point)
		var cells: int = 4
		var cell := box.size / float(cells)
		for row: int in cells:
			for column: int in cells:
				var square := PackedVector2Array([box.position + cell * Vector2(column, row), box.position + cell * Vector2(column + 1, row), box.position + cell * Vector2(column + 1, row + 1), box.position + cell * Vector2(column, row + 1)])
				var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(square, inner)
				var tone: Color = Color(0.08, 0.08, 0.1, 0.78) if (row + column) % 2 == 0 else Color(0.97, 0.97, 0.97, 0.78)
				for piece: PackedVector2Array in clipped:
					draw_colored_polygon(piece, tone)
		var closed: PackedVector2Array = outline_points.duplicate()
		closed.append(closed[0])
		draw_polyline(closed, Color("ffd43b"), 4.0, true)

	## 함정도 발판과 같은 평면에 붙인다. 부스터 위 함정은 보라색 표시가 우선한다.
	func _draw_trap() -> void:
		var closed: PackedVector2Array = outline_points.duplicate()
		closed.append(closed[0])
		draw_colored_polygon(layers[1], Color("5b2a86"))
		draw_colored_polygon(layers[layers.size() - 1], Color("8e4ec6").lerp(Color("b07be0"), 0.35 * trap_pulse))
		draw_polyline(closed, Color(0.22, 0.04, 0.42, 0.85 + 0.15 * trap_pulse), 4.0, true)
		var inner: PackedVector2Array = layers[1].duplicate()
		inner.append(inner[0])
		draw_polyline(inner, Color(0.85, 0.65, 1.0, 0.35 + 0.5 * trap_pulse), 2.0, true)
		if trap_icon == null or danger_level >= 2:
			return
		var footprint: Vector2 = data.footprint
		var direction := Vector2.RIGHT if data.major else BoardSkin.symbol_axis(index)
		var frame := BoardSkin.decal_frame(plane,minf(footprint.x,footprint.y)*0.86,direction)
		var region := BoardSkin.trap_region(trap_icon)
		var extent := Vector2(64,64)*region.size/maxf(region.size.x,region.size.y)
		draw_set_transform_matrix(frame)
		draw_texture_rect_region(trap_icon,Rect2(-extent/2.0,extent),region)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	## Coral accelerator zone and a projected chevron decal; pulse never hides the floor.
	func _draw_dash() -> void:
		var inner: PackedVector2Array = layers[layers.size()-1]
		draw_colored_polygon(layers[1],Color("b74838"))
		draw_colored_polygon(inner,Color("f7785b").lerp(Color("ffae73"),0.16+0.12*sin(dash_phase*TAU)))
		var rim := inner.duplicate()
		rim.append(rim[0])
		draw_polyline(rim,Color("ffe4a3"),1.4,true)

	## 경로 바닥만 펄스한다. 경고 그림과 방향 화살표는 위쪽 자식 레이어에서 타일 평면에 붙인다.
	func _draw_danger() -> void:
		var closed: PackedVector2Array = outline_points.duplicate()
		closed.append(closed[0])
		var strong: bool = danger_level >= 2
		var alpha: float = (0.2 + 0.32 * danger_pulse) if strong else (0.08 + 0.14 * danger_pulse)
		draw_colored_polygon(layers[layers.size() - 1], Color(0.9, 0.08, 0.08, alpha))
		draw_polyline(closed, Color(0.85, 0.05, 0.05, 0.55 + 0.45 * danger_pulse), 5.0 if strong else 3.0, true)

	func _draw_tile() -> void:
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
