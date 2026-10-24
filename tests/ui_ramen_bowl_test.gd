## Focused difficulty-bowl check. Does not load the board, duels or other tools.
extends SceneTree

const BowlModel = preload("res://scenes/ramen_bowl_model.gd")

var started: bool = false
var failures: Array[String] = []

func _process(_delta: float) -> bool:
	if not started:
		started = true
		run()
	return false

func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func run() -> void:
	var picker := FireLevelPicker.create(2)
	root.add_child(picker)
	await process_frame
	var bowl: FireLevelPicker.RamenBowl = picker._bowl
	expect(bowl.model_root != null and bowl.camera != null, "3D bowl and camera exist")
	var ceramic: MeshInstance3D = bowl.model_root.get_node("CeramicBody")
	var noodles: MeshInstance3D = bowl.model_root.get_node("Noodles")
	expect(ceramic.mesh.get_aabb().size.y > 1.4 and ceramic.mesh.get_aabb().size.x > 3.2, "deep ceramic shape has volume")
	expect(noodles.mesh.get_aabb().end.y < BowlModel.LIP_Y, "noodles remain below the lip")
	expect(noodles.mesh.get_aabb().size.y > 0.03, "noodles are tubes with real volume")
	var previous_span := Vector2.ZERO
	picker.set_level(3)
	for sample: int in 101:
		bowl._reaction = float(sample) / 100.0
		var span: Vector2 = bowl.pour_span()
		expect(span.x >= previous_span.x and span.y >= previous_span.y and span.x <= span.y, "both stream ends fall downward")
		previous_span = span
	expect(previous_span == Vector2.ONE, "cutoff reaches noodles")
	for step: int in [5, 1, 4, 2]:
		picker.set_level(step)
	# Advance this bowl only, without game timers or unrelated scenes.
	bowl._process(1.0)
	expect(bowl.level == 2 and bowl._shown_sauce.is_equal_approx(FireLevelPicker.SAUCE[2]), "rapid selection settles to rose")
	expect(not bowl.source_node.visible, "finished sauce is hidden")
	picker.set_level(5)
	bowl._process(1.0)
	expect(bowl.source_node.visible, "highest difficulty keeps pouring")
	picker.hide()
	await process_frame
	expect(not bowl.is_processing() and bowl.render_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden bowl does not process or render")
	picker.show()
	await process_frame
	expect(bowl.is_processing(), "visible bowl resumes")
	# Load cost: the menu reads the baked noodles instead of building them, and the bake matches the generator.
	expect(ResourceLoader.exists(BowlModel.BAKED_NOODLES), "baked noodle mesh exists (run tools/bake_ramen_noodles.gd)")
	var built: ArrayMesh = BowlModel.noodle_mesh()
	var baked: ArrayMesh = load(BowlModel.BAKED_NOODLES)
	expect(noodles.mesh == baked, "bowl uses the baked noodle mesh")
	expect(baked != null and baked.surface_get_array_len(0) == built.surface_get_array_len(0) and baked.get_aabb().is_equal_approx(built.get_aabb()), "baked noodles match noodle_mesh() (re-run the bake after changing it)")
	# First-render cost: no shadow pass or MSAA, and a hidden bowl can compile its shaders ahead of time.
	var key_lights: Array = bowl.render_view.find_children("*", "DirectionalLight3D", true, false)
	expect(key_lights.all(func(light: DirectionalLight3D) -> bool: return not light.shadow_enabled), "bowl lights cast no shadows")
	expect(bowl.render_view.msaa_3d == Viewport.MSAA_DISABLED, "supersampled viewport skips MSAA")
	picker.hide()
	await process_frame
	picker.prewarm()
	expect(bowl.render_view.render_target_update_mode == SubViewport.UPDATE_ONCE, "prewarm renders one hidden frame")
	picker.queue_free()
	await process_frame
	if failures.is_empty():
		print("UI_RAMEN_BOWL_OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("UI_RAMEN_BOWL_FAIL: " + message)
		quit(1)
