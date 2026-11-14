## Existing body v0.2 and cylinder v0.3, assembled with an axial fit adjustment in this assembly only.
extends Node3D

const BODY = preload("res://assets/models/revolver/body_v02.scn")
const CYLINDER = preload("res://assets/models/revolver/cylinder_v03.tscn")

func _ready() -> void:
	var body: Node3D = BODY.instantiate()
	body.name = "Body"
	add_child(body)
	var mount: Marker3D = body.get_node("EmptyCylinderMount")
	mount.name = "CylinderMount"
	var cylinder: Node3D = CYLINDER.instantiate()
	cylinder.name = "Cylinder"
	# Local Z becomes body X at the mount. Fit the existing frame's axial span.
	# Preserve radius and source asset; assembled drum length is 1.50 * 1.44 = 2.16.
	cylinder.scale.z = 1.44
	cylinder.position.z = 0.04
	mount.add_child(cylinder)
