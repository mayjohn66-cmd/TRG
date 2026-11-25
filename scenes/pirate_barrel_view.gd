## Uses the rolled hole order to seat toy swords and drive the pirate's pop.
class_name PirateBarrelView
extends Control

const SIZE := Vector2(420, 300)
const STAB_END := 0.42
const THUNK_END := 0.62
const POP_AT := 0.66
const SAFE_TOTAL := 1.05
const POP_TOTAL := 1.75
const MODEL_DIR := "res://assets/models/pirate_roulette/blender_v3/"
const BARREL: PackedScene = preload(MODEL_DIR + "oak_barrel.glb")
const SWORD: PackedScene = preload(MODEL_DIR + "toy_sword.glb")
const PIRATE: PackedScene = preload(MODEL_DIR + "pirate_figure.glb")
const SWORD_COLORS: Array[Color] = [
	Color("429d98"), Color("c1514c"), Color("5689bb"), Color("c49946"),
	Color("8375ab"), Color("6b9756"), Color("c67c53"), Color("b26986"),
]

var settled := false
var total_time := SAFE_TOTAL
var _barrel: Node3D
var _pirate: Node3D
var _slots: Array[Node3D] = []
var _swords: Array[Node3D] = []
var _popped := false
var _start_yaw := 0.0
var _end_yaw := 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(details: Dictionary) -> void:
	if _barrel == null:
		_build_stage()
	for sword: Node3D in _swords:
		sword.get_parent().remove_child(sword)
		sword.queue_free()
	_swords.clear()
	var holes: Array[int] = []
	for raw_hole: Variant in details.get("holes", []):
		var hole := int(raw_hole)
		if hole < 0 or hole >= _slots.size() or holes.has(hole):
			continue
		var sword := SWORD.instantiate() as Node3D
		var tint := SWORD_COLORS[holes.size()]
		_tint_part(sword, "RoundedToyBlade", tint)
		_tint_part(sword, "Flattened*molded*grip", tint.darkened(0.14))
		_tint_part(sword, "Recess*grip*seam*", tint.darkened(0.32))
		_slots[hole].add_child(sword)
		_swords.append(sword)
		holes.append(hole)
	_start_yaw = _slot_yaw(holes[-2]) if holes.size() > 1 else 0.10
	_end_yaw = _slot_yaw(holes[-1]) if not holes.is_empty() else _start_yaw
	_popped = bool(details.get("popped", false))
	total_time = POP_TOTAL if _popped else SAFE_TOTAL
	apply_time(0.0)


static func caption(details: Dictionary, steps: int, can_continue: bool = false) -> String:
	return ToolPirateRoulette.caption(details, steps, can_continue)


func apply_time(t: float) -> void:
	settled = t >= (POP_AT + 0.45 if _popped else THUNK_END)
	if _barrel == null:
		return
	var swivel := smoothstep(0.0, 0.24, t)
	var yaw := lerp_angle(_start_yaw, _end_yaw, swivel)
	var thunk := _recoil(t, STAB_END, THUNK_END, 0.028)
	var pop_shake := _recoil(t, POP_AT, POP_AT + 0.28, 0.043) if _popped else 0.0
	_barrel.position.x = thunk + pop_shake
	_barrel.rotation = Vector3(0.0, yaw, -(thunk + pop_shake) * 0.75)
	if not _swords.is_empty():
		var travel := smoothstep(0.11, STAB_END, t)
		_swords[-1].position.z = lerpf(0.96, 0.0, travel)
	_update_pirate(t, yaw)


func _slot_yaw(index: int) -> float:
	var offset := _slots[index].position
	var angle := atan2(offset.x, offset.z)
	var camera_side := 0.64 if index % 2 == 0 else -0.64
	return camera_side - angle


static func _recoil(t: float, start: float, end: float, strength: float) -> float:
	var decay := 1.0 - clampf(inverse_lerp(start, end, t), 0.0, 1.0)
	return sin(maxf(t - start, 0.0) * 62.0) * strength * decay


func _update_pirate(t: float, yaw: float) -> void:
	if not _popped or t < POP_AT:
		_pirate.position = Vector3.ZERO
		_pirate.rotation = Vector3(0.0, -yaw, 0.0)
		return
	var flight := t - POP_AT
	var launch := 1.0 - pow(1.0 - clampf(flight / 0.34, 0.0, 1.0), 3.0)
	var landing := smoothstep(0.37, 0.75, flight)
	var spin := smoothstep(0.02, 0.64, flight)
	var side := Vector3(0.36 * launch, 1.14 * launch - 0.20 * landing, 0.10 * launch)
	_pirate.position = Basis(Vector3.UP, -yaw) * side
	_pirate.rotation = Vector3(-0.17 * sin(spin * PI), -yaw + TAU * spin, 0.18 * sin(spin * PI))


static func _tint_part(sword: Node3D, part_name: String, tint: Color) -> void:
	for node: Node in sword.find_children(part_name, "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var material := part.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		material.albedo_color = tint
		part.set_surface_override_material(0, material)


func _build_stage() -> void:
	var stage := SubViewport.new()
	stage.name = "PirateRouletteStage"
	stage.size = Vector2i(SIZE) * 2
	stage.own_world_3d = true
	stage.transparent_bg = true
	stage.msaa_3d = Viewport.MSAA_2X
	stage.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(stage)
	var display := TextureRect.new()
	display.texture = stage.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.size = SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)

	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("e0ebf4")
	world.environment.ambient_light_energy = 0.57
	stage.add_child(world)
	for entry: Array in [[Vector3(-40, -30, 0), Color("fff0d7"), 0.94],
			[Vector3(-24, 137, 0), Color("bccbe8"), 0.46]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = entry[0]
		light.light_color = entry[1]
		light.light_energy = entry[2]
		stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.22
	camera.position = Vector3(0, 3.82, 7.0)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.83, 0))
	camera.current = true

	_barrel = BARREL.instantiate() as Node3D
	stage.add_child(_barrel)
	for index: int in ToolPirateRoulette.HOLES:
		_slots.append(_barrel.find_child("Slot%02d" % (index + 1), true, false) as Node3D)
	_pirate = PIRATE.instantiate() as Node3D
	var mount := _barrel.find_child("PirateMount", true, false) as Node3D
	mount.add_child(_pirate)
