## Isolated visual proof of the production stamp materials, not product UI.
extends SceneTree
var folder := OS.get_environment("DARTS_CAPTURE_OUT")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var surface := Control.new()
	root.add_child(surface)
	var backdrop := ColorRect.new()
	backdrop.color = Color("17242f")
	backdrop.size = Vector2(1366,768)
	surface.add_child(backdrop)
	# Busy light and dark print backgrounds make missing/soft edges obvious.
	for index: int in 6:
		var cell := Control.new()
		cell.position = Vector2(38+(index%3)*438,40+(index/3)*350)
		surface.add_child(cell)
		for band: int in 9:
			var stripe := ColorRect.new()
			stripe.position = Vector2((band%3)*134,(band/3)*99)
			stripe.size = Vector2(134,99)
			stripe.color = Color("708c4c") if (band+index)%2==0 else Color("303f52")
			cell.add_child(stripe)
		var tool: StringName = [&"LIFE_ROULETTE",&"DICE_TAROT",&"DICE_YACHT",&"DICE_DARTS",&"YUT",&"YUT"][index]
		var history := RollSuccessHistory.new()
		history.position = Vector2(45,84)
		history.scale = Vector2(1.6,1.6)
		cell.add_child(history)
		history.arm(index,1,tool)
		if tool == &"YUT":
			var face := 4 if index == 4 else 5
			history.reveal(index,1,{"tool_id":tool,"steps":face,"reroll":true,"details":{"face":face}})
		else:
			for count: int in 3:
				history.reveal(index,1,{"tool_id":tool,"steps":7,"reroll":true,"details":{"face":7,"label":"success","name":"success","rolled":[1]}})
				history._success._process(1.0)
	for i: int in 24: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("all-stamps-outline.png"))
	print("STAMP_GALLERY_OK")
	quit()
