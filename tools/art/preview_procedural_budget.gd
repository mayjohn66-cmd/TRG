extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1440, 920)
	var backdrop := ColorRect.new()
	backdrop.color = Color("243630")
	backdrop.size = Vector2(1440,920)
	root.add_child(backdrop)
	var factory := ToolWarmup.new()
	root.add_child(factory)
	var ids: Array[StringName] = [&"YUT", &"SLOT_777", &"LIFE_ROULETTE", &"DICE_YACHT", &"DICE_MAHJONG"]
	for i: int in ids.size():
		var view := factory._make(ids[i])
		var host := Control.new()
		host.position = Vector2((i%3)*480+20, (i/3)*450+70)
		root.add_child(host)
		host.add_child(view)
		factory._pose(ids[i],view)
		var target: Vector2 = view.custom_minimum_size
		if target.x < 1 or target.y < 1: target = view.size
		view.scale = Vector2.ONE * minf(440.0/target.x,330.0/target.y)
		view.position = (Vector2(440,330)-target*view.scale)*0.5
		var label := Label.new()
		label.text = str(ids[i])
		label.position = host.position-Vector2(0,45)
		label.add_theme_font_size_override("font_size",24)
		root.add_child(label)
	var coin := preload("res://scenes/fate_coin_3d.gd").new()
	root.add_child(coin)
	coin.position = Vector2(1200,680)
	coin.success = true
	coin.seek(1.0)
	for i: int in 12: await process_frame
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("PROCEDURAL_PREVIEW_OK")
	quit()
