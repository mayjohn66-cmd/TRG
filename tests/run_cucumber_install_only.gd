## Scoped cucumber rule and installation-art checks; no unrelated suites.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	BoardSpec.apply(24)
	var probe := TestV11Content.new()
	probe.tree = self
	probe.current_test = "test_mob_kyui_cucumber_is_edible_and_trap_cards_recharge"
	probe.test_mob_kyui_cucumber_is_edible_and_trap_cards_recharge()
	probe.cleanup()
	probe.current_test = "public_installation_art"
	var cucumber := TrapCucumber.new(1)
	cucumber.is_hidden_trap = false # The skill command publishes the installation.
	probe.check_eq(MainBoard._structure_kind(cucumber), &"cucumber", "public cucumber is a visible installation")
	cucumber.is_hidden_trap = true
	probe.check_eq(MainBoard._structure_kind(cucumber), &"", "hidden attachments stay hidden")
	var mine := TrapMine.new(2)
	mine.is_hidden_trap = false
	probe.check_eq(MainBoard._structure_kind(mine), &"mine", "public mine is preserved")
	mine.is_hidden_trap = true
	probe.check_eq(MainBoard._structure_kind(mine), &"", "card mine remains hidden")
	probe.check_eq(MainBoard._structure_kind(Hotel.new(2)), &"hotel", "hotel is preserved")
	var model := MainBoard.BoardStructure.new()
	model.kind = &"cucumber"
	root.add_child(model)
	probe.check(not model.artwork.is_empty(), "cucumber artwork loads")
	if not model.artwork.is_empty():
		var texture: Texture2D = model.artwork.texture
		probe.check(texture.resource_path.ends_with("CUCUMBER_V01.png"), "uses the real cucumber prop")
		probe.check(texture.get_width() <= 256 and texture.get_height() <= 256, "runtime image stays small")
		probe.check(texture.get_image().detect_alpha() != Image.ALPHA_NONE, "sprite has true alpha")
	probe.check(not model.is_processing(), "cucumber has no idle animation processing")
	model.queue_free()
	await process_frame
	for failure: String in probe.failures: printerr("CUCUMBER_FAIL ", failure)
	print("CUCUMBER_CORE ", probe.assertions, " assertions; ", probe.failures.size(), " failures")
	quit(0 if probe.failures.is_empty() else 1)
