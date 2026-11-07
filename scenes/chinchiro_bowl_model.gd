## Reproducible solid ceramic bowl. Radius/height sections include an underside,
## foot, curved wall, rolled lip and an open cavity; no overlapping solid spheres.
extends RefCounted

const SEGMENTS: int = 96
const FLOOR_Y: float = 0.30
const DIE_SCALE: float = 0.70
const CREAM: Color = Color("fff4df")
const BLUE: Color = Color("315b8d")
const INNER: Array[Vector2] = [Vector2(0,0.30),Vector2(1.72,0.30),Vector2(2.0,0.42),Vector2(2.32,0.65),Vector2(2.67,1.02),Vector2(2.92,1.40),Vector2(3.08,1.79),Vector2(3.12,1.87),Vector2(3.18,1.91)]
const PROFILE: Array[Vector2] = [
	Vector2(0,0.10),Vector2(1.28,0.10),Vector2(1.40,0.12),Vector2(1.45,0.19),Vector2(1.45,0.25),
	Vector2(1.80,0.35),Vector2(2.15,0.55),Vector2(2.58,0.84),Vector2(2.94,1.22),
	Vector2(3.02,1.36),Vector2(3.04,1.40),Vector2(3.09,1.49),Vector2(3.12,1.53),Vector2(3.18,1.65),
	Vector2(3.25,1.73),Vector2(3.30,1.79),Vector2(3.31,1.85),Vector2(3.27,1.90),Vector2(3.22,1.93),
	Vector2(3.18,1.91),Vector2(3.12,1.87),Vector2(3.08,1.79),Vector2(2.92,1.40),Vector2(2.67,1.02),
	Vector2(2.32,0.65),Vector2(2.0,0.42),Vector2(1.72,0.30),Vector2(1.44,0.30),Vector2(1.40,0.30),Vector2(0,0.30)
]

static func ceramic_y(raw: float) -> float:
	return raw if raw <= FLOOR_Y else FLOOR_Y + (raw-FLOOR_Y)*1.23

static func floor_height(radius: float) -> float:
	for index: int in range(1, INNER.size()):
		if radius <= INNER[index].x:
			var a: Vector2 = INNER[index-1]
			var b: Vector2 = INNER[index]
			return ceramic_y(lerpf(a.y,b.y,clampf((radius-a.x)/(b.x-a.x),0.0,1.0)))
	return ceramic_y(INNER[-1].y + (radius-INNER[-1].x)*2.5)


## Conservative cube hull: even rotating corners stay outside the ceramic.
static func support_y(rotation: Quaternion, floor_position: Vector2) -> float:
	var required: float = FLOOR_Y
	for x: float in [-1.0,1.0]:
		for y: float in [-1.0,1.0]:
			for z: float in [-1.0,1.0]:
				var corner: Vector3 = rotation * Vector3(x,y,z) * DIE_SCALE
				var radius: float = (floor_position+Vector2(corner.x,corner.z)).length()
				required = maxf(required,floor_height(radius)-corner.y)
	return required


static func make_model() -> Node3D:
	var model := Node3D.new()
	model.name = "ChinchiroRiceBowl"
	var body := MeshInstance3D.new()
	body.name = "SolidCeramic"
	body.mesh = make_mesh()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.25
	body.material_override = material
	model.add_child(body)
	body.owner = model
	return model


static func make_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in PROFILE.size()-1:
		var paint: Color = BLUE if row in [2,9,11,15,18,27] else CREAM
		if row >= 19 and row != 27:
			var depth: float = 1.0 - (PROFILE[row].y-FLOOR_Y)/1.63
			paint = CREAM.lerp(Color("c5d3da"),0.10+depth*0.22)
		for segment: int in SEGMENTS:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for sample: Vector2i in [Vector2i(row,segment),Vector2i(row+1,segment),Vector2i(row+1,segment+1),Vector2i(row,segment+1)]:
				var angle: float = TAU * sample.y / SEGMENTS
				var p: Vector2 = PROFILE[sample.x]
				var tangent: Vector2 = PROFILE[mini(sample.x+1,PROFILE.size()-1)]-PROFILE[maxi(sample.x-1,0)]
				var previous: Vector2 = PROFILE[maxi(sample.x-1,0)]
				var next: Vector2 = PROFILE[mini(sample.x+1,PROFILE.size()-1)]
				tangent.y = ceramic_y(next.y)-ceramic_y(previous.y)
				p.y = ceramic_y(p.y)
				var normal: Vector2 = Vector2(tangent.y,-tangent.x).normalized()
				points.append(Vector3(p.x*cos(angle),p.y,p.x*sin(angle)))
				normals.append(Vector3(normal.x*cos(angle),normal.y,normal.x*sin(angle)))
			for indices: Array in [[0,1,2],[0,2,3]]:
				_triangle(st,points,normals,indices,paint)
	return st.commit()


static func _triangle(st: SurfaceTool, points: Array[Vector3], normals: Array[Vector3], indices: Array, paint: Color) -> void:
	var order: Array = indices.duplicate()
	var cross: Vector3 = (points[order[1]]-points[order[0]]).cross(points[order[2]]-points[order[0]])
	if cross.length_squared() < 0.000000001:
		return
	if cross.dot(normals[order[0]]+normals[order[1]]+normals[order[2]]) > 0.0:
		order.reverse()  # Godot front faces are clockwise.
	for index: int in order:
		var n: Vector3 = normals[index]
		var diffuse: float = clampf(n.dot(Vector3(-0.4,0.9,0.7).normalized())*0.20+0.87,0.65,1.0)
		st.set_normal(n)
		st.set_color(Color(paint.r*diffuse,paint.g*diffuse,paint.b*diffuse,1.0))
		st.add_vertex(points[index])
