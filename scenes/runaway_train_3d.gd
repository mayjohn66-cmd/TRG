## Static toy train. Local -X is forward, +Y is up, and Z is the axle direction.
## Each vehicle, wheel pivot and coupler has its own node for later animation.
extends RefCounted

const WAGON_COUNT := 4
const ENGINE_X := -7.2
const WAGON_FIRST_X := -2.85
const WAGON_PITCH := 3.55
var root: Node3D
var paints: Dictionary = {}
var meshes: Dictionary = {}

func build() -> Node3D:
	root = Node3D.new()
	root.name = "RunawayToyTrainV02"
	for entry: Array in [["blue","84b8c8"],["blue_dark","5894aa"],["cream","fff0d3"],["peach","e99e7e"],["orange","f2b76b"],["window","87533f"],["window_glint","b57653"],["metal","a5b0aa"],["tire","536773"],["yellow","edd391"],["mint","acd1b5"],["lilac","bcb0d5"],["floor","cfb18a"],["coupler","6d7e79"]]:
		var material := StandardMaterial3D.new()
		material.resource_name = entry[0]
		material.albedo_color = Color(entry[1])
		material.roughness = 0.46
		paints[entry[0]] = material
	var engine := _group(root,"Locomotive",Vector3(ENGINE_X,0,0))
	_build_engine(engine)
	for index: int in WAGON_COUNT:
		var wagon := _group(root,"FreightWagon%02d" % (index+1),Vector3(WAGON_FIRST_X+index*WAGON_PITCH,0,0))
		_build_wagon(wagon,["blue","yellow","mint","lilac"][index])
		_link(engine if index==0 else root.get_node("FreightWagon%02d" % index),wagon,index)
	_own(root)
	return root

func _build_engine(parent: Node3D) -> void:
	_box(parent,"RoundedPeachChassis",Vector3(4.1,0.31,1.94),Vector3(0,1.04,0),"peach",0.14)
	_box(parent,"CreamChassisInset",Vector3(3.70,0.09,1.86),Vector3(-0.05,1.23,0),"cream",0.04)
	var boiler := _cylinder(parent,"BlueBoiler",0.70,2.70,Vector3(-0.62,1.92,0),"blue",0.075)
	boiler.rotation.z = PI/2.0
	for data: Vector2 in [Vector2(-0.65,0.39),Vector2(0.35,0.10)]:
		var band := _cylinder(parent,"CreamBoilerBand",0.713,data.y,Vector3(data.x,1.92,0),"cream",0.025)
		band.rotation.z = PI/2.0
	var trim := _cylinder(parent,"CoralBoilerBand",0.72,0.13,Vector3(-0.90,1.92,0),"peach",0.022)
	trim.rotation.z = PI/2.0
	for data: Array in [["CreamRoundBoilerFace",0.704,0.19,-2.02,"cream"],["InsetBoilerFace",0.55,0.06,-2.14,"floor"],["RaisedFrontRoundel",0.39,0.10,-2.20,"cream"],["RoundelButton",0.15,0.07,-2.28,"cream"]]:
		var face := _cylinder(parent,data[0],data[1],data[2],Vector3(data[3],1.92,0),data[4],0.04)
		face.rotation.z = PI/2.0
	_cylinder(parent,"TallBlueSmokestack",0.24,0.94,Vector3(-1.26,2.82,0),"blue",0.035)
	_cylinder(parent,"PeachSmokestackLip",0.33,0.20,Vector3(-1.26,3.27,0),"peach",0.055)
	_cylinder(parent,"CreamSmokestackRim",0.275,0.045,Vector3(-1.26,3.38,0),"cream",0.018)
	_cylinder(parent,"InsetSmokestackOpening",0.205,0.012,Vector3(-1.26,3.405,0),"blue_dark",0.002)
	_cylinder(parent,"SmallSteamDome",0.20,0.38,Vector3(-0.29,2.66,0),"blue",0.04)
	_cylinder(parent,"SteamDomeCap",0.235,0.09,Vector3(-0.29,2.86,0),"peach",0.025)
	_box(parent,"CreamCab",Vector3(1.51,1.89,1.65),Vector3(1.11,2.16,0),"cream",0.12)
	for side: float in [-1.0,1.0]:
		_box(parent,"PeachCabSide",Vector3(1.34,1.76,0.075),Vector3(1.12,2.18,side*0.83),"orange",0.035)
		_box(parent,"WindowPeachFrame",Vector3(0.92,0.78,0.055),Vector3(1.12,2.49,side*0.883),"peach",0.045)
		_box(parent,"RecessedBrownWindow",Vector3(0.77,0.64,0.045),Vector3(1.12,2.49,side*0.915),"window",0.07)
		_box(parent,"WindowWarmReflection",Vector3(0.032,0.45,0.012),Vector3(0.80,2.51,side*0.943),"window_glint",0.006)
		var number := TextMesh.new()
		number.text = "3"
		number.font = preload("res://assets/fonts/ONE-Mobile-POP.otf")
		number.font_size = 100
		number.pixel_size = 0.008
		number.depth = 0.025
		var badge := _part(parent,"EmbossedCabNumber3",_bake_text(number),Vector3(1.13,1.66,side*0.90),"cream")
		if side<0.0:
			badge.rotation.y = PI
		_box(parent,"CabStep",Vector3(0.81,0.12,0.23),Vector3(1.20,0.91,side*1.00),"cream",0.04)
		_box(parent,"BlueLowerSidePipe",Vector3(2.45,0.11,0.10),Vector3(-0.57,1.28,side*0.74),"blue_dark",0.045)
	# A gently arched solid roof, with projecting eaves on all four sides.
	var profile := PackedVector2Array()
	for step: int in 25:
		var t := float(step)/24.0
		profile.append(Vector2(0.10+t*2.06,3.15+sin(t*PI)*0.21))
	for step: int in range(24,-1,-1):
		var t := float(step)/24.0
		profile.append(Vector2(0.10+t*2.06,3.00+sin(t*PI)*0.21))
	_part(parent,"ArchedGoldenCabRoof",_extrude(profile,2.10),Vector3.ZERO,"orange")
	_box(parent,"CreamRoofTopVent",Vector3(0.54,0.065,0.52),Vector3(1.13,3.39,0),"peach",0.03)
	var guard := _box(parent,"RoundedFrontCowcatcher",Vector3(0.38,0.69,2.02),Vector3(-2.10,0.97,0),"peach",0.13)
	guard.rotation.z = -0.25
	for index: int in 7:
		var vent := _box(parent,"CowcatcherInsetVent%02d" % index,Vector3(0.018,0.36,0.065),Vector3(-2.304,0.98,-0.69+index*0.23),"window_glint",0.008)
		vent.rotation.z = -0.25
	for side: float in [-1.0,1.0]:
		for index: int in 3:
			_wheel(parent,"DriverWheel%d_%s" % [index,"L" if side>0 else "R"],-1.28+index*1.27,side,0.54,"metal" if index==1 else "blue",true)
		_box(parent,"CreamDrivingRod",Vector3(2.59,0.105,0.075),Vector3(0.04,0.51,side*1.15),"cream",0.045)
		for x: float in [-1.20,0.07,1.34]:
			var pin := _cylinder(parent,"DriverCrankPin",0.08,0.09,Vector3(x,0.51,side*1.20),"metal",0.018)
			pin.rotation.x = PI/2.0
	_couplers(parent,2.10)

func _build_wagon(parent: Node3D, paint: String) -> void:
	_box(parent,"PeachUnderframe",Vector3(3.03,0.25,1.92),Vector3(0,0.94,0),"peach",0.10)
	_box(parent,"OpenCargoFloor",Vector3(2.76,0.16,1.68),Vector3(0,1.14,0),"floor",0.06)
	for plank: int in 7:
		_box(parent,"InsetFloorPlank%02d" % plank,Vector3(2.57,0.035,0.195),Vector3(0,1.235,-0.69+plank*0.23),"cream",0.013)
	for side: float in [-1.0,1.0]:
		_box(parent,"RoundedCargoSide",Vector3(2.91,0.83,0.145),Vector3(0,1.60,side*0.84),paint,0.06)
		_box(parent,"CreamTopSideRail",Vector3(3.01,0.13,0.20),Vector3(0,2.02,side*0.84),"cream",0.055)
		_box(parent,"SideLowerTrim",Vector3(2.91,0.095,0.16),Vector3(0,1.24,side*0.85),paint,0.035)
		for x: float in [-1.31,0.0,1.31]:
			_box(parent,"CargoSideStanchion",Vector3(0.105,0.78,0.07),Vector3(x,1.63,side*0.935),"cream",0.025)
		for x: float in [-0.93,0.93]:
			_wheel(parent,"WagonWheel_%s_%s" % [str(x),str(side)],x,side,0.45,"blue",false)
	for x: float in [-1.38,1.38]:
		_box(parent,"RoundedCargoEnd",Vector3(0.15,0.82,1.71),Vector3(x,1.60,0),paint,0.06)
		_box(parent,"CreamTopEndRail",Vector3(0.21,0.13,1.82),Vector3(x,2.02,0),"cream",0.05)
	_couplers(parent,1.58)

func _couplers(parent: Node3D, reach: float) -> void:
	for sign_value: float in [-1.0,1.0]:
		var marker := Marker3D.new()
		marker.name = "FrontCoupler" if sign_value<0 else "RearCoupler"
		marker.position = Vector3(reach*sign_value,0.87,0)
		parent.add_child(marker)
		_box(parent,"CouplerSocket",Vector3(0.30,0.19,0.30),Vector3((reach-0.08)*sign_value,0.87,0),"coupler",0.055)

func _link(front: Node3D, back: Node3D, index: int) -> void:
	var a: Vector3 = front.position+(front.get_node("RearCoupler") as Node3D).position
	var b: Vector3 = back.position+(back.get_node("FrontCoupler") as Node3D).position
	var holder := _group(root,"Coupling%02d" % (index+1),(a+b)/2.0)
	_box(holder,"CreamDrawbar",Vector3(absf(b.x-a.x)+0.16,0.09,0.19),Vector3.ZERO,"cream",0.035)
	for position_x: float in [a.x-holder.position.x,b.x-holder.position.x]:
		_cylinder(holder,"RoundCouplerPin",0.08,0.16,Vector3(position_x,0.03,0),"peach",0.018)

func _wheel(parent: Node3D, title: String, x: float, side: float, radius: float, paint: String, driver: bool) -> void:
	var pivot := _group(parent,title,Vector3(x,radius+0.035,side*0.96))
	var tire := _cylinder(pivot,"RoundedWheelTread",radius,0.27,Vector3.ZERO,"tire",0.06)
	tire.rotation.x = PI/2.0
	var disc := _cylinder(pivot,"PastelWheelFace",radius*0.91,0.10,Vector3(0,0,side*0.145),paint,0.045)
	disc.rotation.x = PI/2.0
	var inset := _cylinder(pivot,"InsetHubRing",radius*0.62,0.042,Vector3(0,0,side*0.204),"cream" if paint=="metal" else "blue_dark",0.018)
	inset.rotation.x = PI/2.0
	var hub := _cylinder(pivot,"RoundedAxleCap",radius*0.34,0.11,Vector3(0,0,side*0.235),paint,0.028)
	hub.rotation.x = PI/2.0
	if side<0.0:
		var axle := _cylinder(parent,"SteelCrossAxle",0.085,1.92,Vector3(x,radius+0.035,0),"metal",0.015)
		axle.rotation.x = PI/2.0
	pivot.set_meta("wheel_radius",radius)
	pivot.set_meta("driver",driver)

func _group(parent: Node3D, title: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.position = at
	parent.add_child(node,true)
	return node

func _part(parent: Node3D, title: String, shape: Mesh, at: Vector3, paint: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = title
	part.mesh = shape
	part.material_override = paints[paint]
	part.position = at
	parent.add_child(part,true)
	return part

func _bake_text(source: TextMesh) -> ArrayMesh:
	# TextMesh includes zero-area contour triangles. Keep only usable geometry in exports.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface: int in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for offset: int in range(0,indices.size(),3):
			var a := indices[offset]
			var b := indices[offset+1]
			var c := indices[offset+2]
			_triangle(st,points[a],points[b],points[c],normals[a],normals[b],normals[c])
	st.index()
	return st.commit()

func _box(parent: Node3D, title: String, dimensions: Vector3, at: Vector3, paint: String, bevel: float) -> MeshInstance3D:
	var key := "box_%s_%s" % [str(dimensions),str(bevel)]
	if not meshes.has(key):
		meshes[key] = _round_box(dimensions,bevel)
	return _part(parent,title,meshes[key],at,paint)

func _cylinder(parent: Node3D, title: String, radius: float, height: float, at: Vector3, paint: String, bevel: float) -> MeshInstance3D:
	var key := "cylinder_%s_%s_%s" % [str(radius),str(height),str(bevel)]
	if not meshes.has(key):
		var b := minf(bevel,minf(radius*0.45,height*0.45))
		meshes[key] = _lathe(PackedVector2Array([Vector2(0,-height/2),Vector2(radius-b,-height/2),Vector2(radius,-height/2+b),Vector2(radius,height/2-b),Vector2(radius-b,height/2),Vector2(0,height/2)]),40)
	return _part(parent,title,meshes[key],at,paint)

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (b-a).cross(c-a).length_squared()<0.000000000001:
		return
	var points: Array[Vector3] = [a,b,c]
	var normals: Array[Vector3] = [na,nb,nc]
	if (b-a).cross(c-a).dot(na+nb+nc)>0.0:
		points = [a,c,b]
		normals = [na,nc,nb]
	for index: int in 3:
		st.set_normal(normals[index])
		st.set_uv(Vector2(points[index].x,points[index].z))
		st.add_vertex(points[index])

func _round_box(dimensions: Vector3, radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := dimensions/2.0
	var r := minf(radius,minf(half.x,minf(half.y,half.z))*0.95)
	var inner := half-Vector3.ONE*r
	for axis: int in 3:
		var u := (axis+1)%3
		var v := (axis+2)%3
		for side: float in [-1.0,1.0]:
			var us: Array[float] = [-half[u],-half[u]+r*0.5,-inner[u],inner[u],half[u]-r*0.5,half[u]]
			var vs: Array[float] = [-half[v],-half[v]+r*0.5,-inner[v],inner[v],half[v]-r*0.5,half[v]]
			for row: int in 5:
				for col: int in 5:
					var points: Array[Vector3] = []
					var normals: Array[Vector3] = []
					for pair: Vector2i in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
						var raw := Vector3.ZERO
						raw[axis] = half[axis]*side
						raw[u] = us[pair.x]
						raw[v] = vs[pair.y]
						var core := raw.clamp(-inner,inner)
						var normal := (raw-core).normalized()
						points.append(core+normal*r)
						normals.append(normal)
					_triangle(st,points[0],points[1],points[2],normals[0],normals[1],normals[2])
					_triangle(st,points[0],points[2],points[3],normals[0],normals[2],normals[3])
	st.index()
	return st.commit()

func _lathe(profile: PackedVector2Array, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in profile.size()-1:
		var delta := profile[row+1]-profile[row]
		for side: int in sides:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for pair: Vector2i in [Vector2i(row,side),Vector2i(row+1,side),Vector2i(row+1,side+1),Vector2i(row,side+1)]:
				var angle := float(pair.y)*TAU/sides
				points.append(Vector3(cos(angle)*profile[pair.x].x,profile[pair.x].y,sin(angle)*profile[pair.x].x))
				normals.append(Vector3(delta.y*cos(angle),-delta.x,delta.y*sin(angle)).normalized())
			_triangle(st,points[0],points[1],points[2],normals[0],normals[1],normals[2])
			_triangle(st,points[0],points[2],points[3],normals[0],normals[2],normals[3])
	st.index()
	return st.commit()

func _extrude(profile: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(profile)
	for side: float in [-1.0,1.0]:
		for offset: int in range(0,triangles.size(),3):
			var p: Array[Vector3] = []
			for index: int in 3:
				var xy := profile[triangles[offset+index]]
				p.append(Vector3(xy.x,xy.y,side*depth/2.0))
			_triangle(st,p[0],p[1],p[2],Vector3(0,0,side),Vector3(0,0,side),Vector3(0,0,side))
	for index: int in profile.size():
		var a := profile[index]
		var b := profile[(index+1)%profile.size()]
		var normal := Vector3(a.y-b.y,b.x-a.x,0).normalized()
		var p: Array[Vector3] = [Vector3(a.x,a.y,-depth/2),Vector3(b.x,b.y,-depth/2),Vector3(b.x,b.y,depth/2),Vector3(a.x,a.y,depth/2)]
		_triangle(st,p[0],p[1],p[2],normal,normal,normal)
		_triangle(st,p[0],p[2],p[3],normal,normal,normal)
	st.index()
	return st.commit()

func _own(node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_own(child)
