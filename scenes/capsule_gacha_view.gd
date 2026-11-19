## The roll clock drives the real machine, coin, capsule halves and acrylic prize.
class_name CapsuleGachaView
extends Control

const SIZE := Vector2(420, 300)
const COIN_AT := 0.10
const TURN_AT := 0.80
const TURN_END := 1.60
const DROP_AT := 1.65
const OPEN_AT := 2.30
const REVEAL_AT := 2.75
const TOTAL_TIME := 4.25
const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const MODEL_DIR := "res://assets/models/capsule_gacha/"
const MACHINE: PackedScene = preload(MODEL_DIR + "machine.glb")
const COIN: PackedScene = preload(MODEL_DIR + "coin.glb")
const CAPSULE: PackedScene = preload(MODEL_DIR + "capsule.glb")
const PRIZES: Dictionary = {
	&"avatar_02": preload(MODEL_DIR + "butter.glb"),
	&"avatar_05": preload(MODEL_DIR + "shady.glb"),
	&"avatar_07": preload(MODEL_DIR + "belita.glb"),
	&"avatar_08": preload(MODEL_DIR + "joan.glb"),
	&"avatar_01": preload(MODEL_DIR + "erpin.glb"),
}

var settled := false
var _name := ""
var _steps := 3
var _rarity_name := ""
var _secret := false
var _art: Texture2D
var _viewport: SubViewport
var _camera: Camera3D
var _machine: Node3D
var _knob: Node3D
var _flap: Node3D
var _stock: Node3D
var _stock_rest: Array[Transform3D] = []
var _coin: Node3D
var _coin_entry: Node3D
var _exit: Node3D
var _capsule: Node3D
var _lid: Node3D
var _prize: Node3D
var _cup_material: StandardMaterial3D
var _lip_material: StandardMaterial3D
var _time := 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(details: Dictionary, _kept: int = 0) -> void:
	if _viewport == null:
		_build_stage()
	_name = str(details.get("name", ""))
	_steps = int(details.get("steps", 3))
	_rarity_name = str(details.get("rarity_name", ""))
	_secret = bool(details.get("secret", false))
	var color := Color(str(details.get("color", "ffd43b")))
	_cup_material.albedo_color = color
	_cup_material.metallic = 0.38 if _secret else 0.0
	_lip_material.albedo_color = color.darkened(0.20)
	if is_instance_valid(_prize):
		_viewport.remove_child(_prize)
		_prize.queue_free()
	var avatar := StringName(details.get("avatar", &"avatar_02"))
	var scene: PackedScene = PRIZES.get(avatar, PRIZES[&"avatar_02"])
	_prize = scene.instantiate() as Node3D
	_viewport.add_child(_prize)
	var acrylic := _prize.find_child("CharacterAcrylic", true, false) as MeshInstance3D
	_art = (acrylic.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture
	apply_time(0.0)


static func caption(details: Dictionary, steps: int) -> String:
	return ToolCapsuleGacha.caption(details, steps)


func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "CapsuleMachine3D"
	_viewport.size = Vector2i(840, 600)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	var display := TextureRect.new()
	display.texture = _viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.size = SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("e9efff")
	world.environment.ambient_light_energy = 0.64
	_viewport.add_child(world)
	for entry: Array in [[Vector3(-48, -32, 0), 0.78], [Vector3(-30, 138, 0), 0.38]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = entry[0]
		light.light_energy = entry[1]
		_viewport.add_child(light)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 3.60
	_viewport.add_child(_camera)
	_camera.position = Vector3(0.15, 3.05, 9.0)
	_camera.look_at(Vector3(0.15, 1.47, 0.0))
	_camera.current = true
	_machine = MACHINE.instantiate() as Node3D
	_machine.position = Vector3(-1.15, 0.0, 0.0)
	_machine.rotation.y = 0.13
	_viewport.add_child(_machine)
	_knob = _machine.find_child("TurnKnob", true, false) as Node3D
	_flap = _machine.find_child("PickupFlap", true, false) as Node3D
	_coin_entry = _machine.find_child("CoinEntry", true, false) as Node3D
	_exit = _machine.find_child("CapsuleExit", true, false) as Node3D
	_stock = _machine.find_child("CapsuleStock", true, false) as Node3D
	for capsule: Node3D in _stock.get_children():
		_stock_rest.append(capsule.transform)
	_coin = COIN.instantiate() as Node3D
	_viewport.add_child(_coin)
	_coin.scale = Vector3.ONE * 0.23
	_capsule = CAPSULE.instantiate() as Node3D
	_viewport.add_child(_capsule)
	_capsule.scale = Vector3.ONE * 0.69
	_lid = _capsule.find_child("ClearLid", true, false) as Node3D
	var cup := _capsule.find_child("CupShell", true, false) as MeshInstance3D
	_cup_material = cup.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	cup.set_surface_override_material(0, _cup_material)
	var lip := _capsule.find_child("CupLip", true, false) as MeshInstance3D
	_lip_material = lip.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	lip.set_surface_override_material(0, _lip_material)


func apply_time(t: float) -> void:
	_time = t
	settled = t >= REVEAL_AT
	if _viewport == null:
		return
	var turn := smoothstep(TURN_AT, TURN_END, t)
	_knob.rotation.z = deg_to_rad(-11.0) - TAU * turn
	var churn := sin(turn * PI) * 0.065
	for index: int in _stock.get_child_count():
		var capsule := _stock.get_child(index) as Node3D
		capsule.transform = _stock_rest[index]
		capsule.position += Vector3(sin(turn * TAU * 3.0 + index), sin(turn * TAU * 4.0 + index * 1.7), 0.0) * churn
		capsule.rotate_z(sin(turn * TAU * 2.0 + index) * churn * 4.0)
	var insertion := smoothstep(COIN_AT, TURN_AT - 0.12, t)
	var slot := _coin_entry.global_position
	_coin.visible = t >= COIN_AT and t < TURN_AT - 0.04
	_coin.position = (slot + Vector3(-0.77, 0.63, 1.0)).lerp(slot - Vector3(0.0, 0.0, 0.08), insertion)
	_coin.position.y += sin(insertion * PI) * 0.18
	_coin.rotation = Vector3(PI * 0.5, 0.0, insertion * TAU)
	var roll := smoothstep(DROP_AT, OPEN_AT - 0.05, t)
	var rest := Vector3(1.20, 0.36, 1.05)
	var opening := smoothstep(OPEN_AT, REVEAL_AT, t)
	_capsule.visible = t >= DROP_AT
	_capsule.position = _exit.global_position.lerp(rest, roll)
	_capsule.position.y += sin(roll * PI) * 0.23
	_capsule.rotation.z = (1.0 - roll) * TAU * 1.35
	_capsule.position += Vector3(-0.26, -0.08, 0.0) * opening
	_lid.position = Vector3(0.56, 1.16, -0.14) * opening
	_lid.rotation = Vector3(-0.35, 0.0, -0.68) * opening
	_flap.rotation.x = -sin(smoothstep(DROP_AT - 0.10, DROP_AT + 0.46, t) * PI) * 1.20
	if is_instance_valid(_prize):
		_prize.visible = t >= OPEN_AT
		_prize.position = rest + Vector3(0.0, lerpf(-0.22, 0.34, opening), 0.12)
		_prize.scale = Vector3.ONE * lerpf(0.05, 1.50, opening)
		_prize.rotation = Vector3(-0.05, -0.14 + sin(opening * PI) * 0.28, sin(opening * PI) * 0.13)
	queue_redraw()


func _draw() -> void:
	if not settled:
		return
	var opacity := smoothstep(REVEAL_AT, REVEAL_AT + 0.16, _time)
	var ink := Color("3a3347")
	var top := Vector2(305, 23)
	_text(L10n.t(_name), top, 17, Color(ink, opacity), 174.0)
	_text(L10n.t(_rarity_name), top + Vector2(0, 22), 13, Color(Color("9e5c28"), opacity), 174.0)
	_text(L10n.t("%d칸 전진!") % _steps, top + Vector2(0, 49), 23, Color(Color("ce4a2e"), opacity), 174.0)


func _text(value: String, at: Vector2, px: int, color: Color, max_width: float) -> void:
	var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if width > max_width:
		px = maxi(1, floori(px * max_width / width))
		width = FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var baseline := (FONT.get_ascent(px) - FONT.get_descent(px)) * 0.5
	draw_string(FONT, at + Vector2(-width * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
