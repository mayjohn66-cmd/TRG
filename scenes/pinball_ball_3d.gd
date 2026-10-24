## Standalone visual asset, centred at its origin. Motion and physics belong
## to the later pinball presentation, not to the reusable steel ball model.
extends RefCounted

const RADIUS: float = 0.115
const DIAMETER: float = RADIUS * 2.0


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "PinballSteelBallV01"
	var sphere := SphereMesh.new()
	sphere.resource_name = "SmoothSteelSphere"
	sphere.radius = RADIUS
	sphere.height = DIAMETER
	sphere.radial_segments = 64
	sphere.rings = 31
	var steel := StandardMaterial3D.new()
	steel.resource_name = "PolishedSteel"
	steel.albedo_color = Color("c3cbd2")
	steel.metallic = 1.0
	steel.roughness = 0.12
	var mesh := MeshInstance3D.new()
	mesh.name = "SteelBallMesh"
	mesh.mesh = sphere
	mesh.material_override = steel
	root.add_child(mesh)
	mesh.owner = root
	return root
