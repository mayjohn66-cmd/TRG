## 벨라티엔 가마솥의 3D 연출. 게임에서 확정한 물약만 표시한다.
class_name CauldronBrewView
extends Control

const BREW_TIME: float = 1.25
const MODEL_DIR := "res://assets/models/cauldron/"
const RENDER_SIZE := Vector2i(464, 448)
const RISE_TIME: float = 0.35

var potion_color: Color = Color("7fd18b")
var good: bool = true
var t: float = 0.0
var pace: float = 1.0
var _viewport: SubViewport
var _camera: Camera3D
var _bottle: Node3D
var _liquid: MeshInstance3D
var _liquid_material: StandardMaterial3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func play(potion: StringName, color: Color, is_good: bool, motion_pace: float = 1.0) -> void:
	pace = maxf(motion_pace, 0.01)
	potion_color = color
	good = is_good
	if _viewport == null:
		_build_stage()
	if is_instance_valid(_bottle):
		_viewport.remove_child(_bottle)
		_bottle.queue_free()
	var scene := load(MODEL_DIR + "potion_%s.glb" % potion) as PackedScene
	_bottle = scene.instantiate() as Node3D
	_bottle.name = "BrewedPotion"
	_viewport.add_child(_bottle)
	set_time(0.0)
	set_process(true)


func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "CauldronViewport"
	_viewport.size = RENDER_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)

	var display := TextureRect.new()
	display.texture = _viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var world := WorldEnvironment.new()
	var lighting := Environment.new()
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Color("e4d9fc")
	lighting.ambient_light_energy = 0.45
	world.environment = lighting
	_viewport.add_child(world)
	for settings: Array in [[Vector3(-36, -30, 0), 0.95], [Vector3(-26, 140, 0), 0.60]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = settings[0]
		light.light_energy = settings[1]
		_viewport.add_child(light)

	var scene := load(MODEL_DIR + "cauldron.glb") as PackedScene
	var pot := scene.instantiate() as Node3D
	_viewport.add_child(pot)
	_liquid = pot.find_child("PotionSurface", true, false) as MeshInstance3D
	_liquid_material = _liquid.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	_liquid.set_surface_override_material(0, _liquid_material)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 2.94
	_viewport.add_child(_camera)
	_camera.position = Vector3(0.0, 3.5, 7.0)
	_camera.look_at(Vector3(0, 1.32, 0))
	_camera.current = true


func _process(delta: float) -> void:
	set_time(t + delta / pace)


## 연출 시간만 갱신한다. 물약 종류와 판정에는 관여하지 않는다.
func set_time(at: float) -> void:
	t = at
	var agitation := minf(t / BREW_TIME, 1.0)
	_liquid.position.y = 1.105 + agitation * (0.022 + 0.014 * sin(t * 14.0))
	_liquid_material.albedo_color = Color("56a138").lerp(potion_color.darkened(0.28), smoothstep(0.10, 0.85, agitation))
	_liquid_material.emission = _liquid_material.albedo_color

	var progress := clampf((t - BREW_TIME) / RISE_TIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	_bottle.visible = t >= BREW_TIME
	# 처음에는 솥 안쪽에 있고, 솥의 앞면에 가려진 채로 위로 나온다.
	_bottle.position = Vector3(0.0, lerpf(0.40, 1.50, eased) + sin(progress * PI) * 0.075, lerpf(0.03, 0.16, eased))
	_bottle.position.y += 0.020 * sin((t - BREW_TIME - RISE_TIME) * 4.5) if progress >= 1.0 else 0.0
	_bottle.rotation = Vector3(0, lerpf(-0.58, 0.18, eased), lerpf(-0.22, 0.02, eased))
	_bottle.scale = Vector3.ONE * lerpf(0.48, 0.71, eased)
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_camera):
		return
	var pixels := size / Vector2(RENDER_SIZE)
	var mouth := _camera.unproject_position(Vector3(0, 1.22, 0)) * pixels
	var fire := _camera.unproject_position(Vector3(0, 0.12, 0.05)) * pixels
	var heat := minf(t / BREW_TIME, 1.0)
	# 불빛과 거품은 솥 입구와 발치의 3D 좌표를 기준으로 배치한다.
	draw_set_transform(fire, 0.0, Vector2(1.0, 0.26))
	draw_circle(Vector2.ZERO, 43.0, Color(1.0, 0.36, 0.12, 0.14 + 0.05 * sin(t * 12.0)), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	for i: int in 8:
		var age := fposmod(t * (0.84 + 0.08 * i) + i * 0.37, 1.0)
		var offset := Vector2(lerpf(-43.0, 43.0, fposmod(i * 0.381, 1.0)), -age * lerpf(25.0, 70.0, heat))
		var radius := lerpf(2.0, 5.0, fposmod(i * 0.61, 1.0)) * (1.0 - age * 0.4)
		draw_circle(mouth + offset, radius, Color(potion_color.lightened(0.35), (1.0 - age) * 0.86), true, -1.0, true)
	if not good and t > BREW_TIME * 0.6:
		for i: int in 5:
			var age := fposmod(t * 0.66 + i * 0.21, 1.0)
			var offset := Vector2((i - 2) * 13.0 + sin(age * TAU) * 10.0, -18.0 - age * 78.0)
			draw_circle(mouth + offset, 5.0 + age * 12.0, Color(0.14, 0.08, 0.20, (1.0 - age) * 0.47), true, -1.0, true)
