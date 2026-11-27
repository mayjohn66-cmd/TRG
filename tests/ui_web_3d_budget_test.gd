## Exercise the actual warm-up -> cache -> presenter path, including repeated reuse.
extends SceneTree

const Budget = preload("res://scenes/web_3d_budget.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func run() -> void:
	var factory := ToolWarmup.new()
	var presenter := RollPresenter.new()
	root.add_child(factory)
	root.add_child(presenter)
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	for id: StringName in ToolWarmup.ORDER:
		var view := factory._make(id)
		root.add_child(view)
		factory._pose(id, view)
		var dimensions: Dictionary = {}
		for target: Node in view.find_children("*", "SubViewport", true, false):
			dimensions[target] = (target as SubViewport).size
		for cycle: int in 3:
			factory._freeze(view)
			for target: SubViewport in dimensions:
				var expected: Vector2i = Budget.PARKED_SIZE if target.own_world_3d and not target.disable_3d else dimensions[target]
				check(target.size == expected, "%s parked target/printed atlas %d" % [id,cycle])
			Budget.restore(view)
			for target: SubViewport in dimensions:
				check(target.size == dimensions[target], "%s active size restored %d" % [id,cycle])
		factory._freeze(view)
		if presenter.adopt_view(id, view):
			var tool := ToolRegistry.create(id)
			presenter._result = tool.roll(rng).to_dict()
			presenter._mode = id
			presenter._build(id)
			for target: SubViewport in dimensions:
				check(target.size == dimensions[target], "%s presenter restores its cached viewport" % id)
			presenter._clear()
			for target: SubViewport in dimensions:
				if target.own_world_3d and not target.disable_3d:
					check(target.size == Budget.PARKED_SIZE, "%s parked after playback" % id)
		else:
			view.free()
	presenter.release_views()
	presenter.queue_free()
	factory.queue_free()
	await process_frame
	if failures.is_empty(): print("WEB_3D_BUDGET_OK ", checks, " checks")
	else:
		for message: String in failures: printerr("WEB_3D_BUDGET_FAIL ",message)
	quit(0 if failures.is_empty() else 1)
