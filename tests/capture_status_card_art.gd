## Actual registered card artwork in the real CardSkin.
extends SceneTree

var out: String = OS.get_environment("DARTS_CAPTURE_OUT")

func _initialize() -> void:
	_run.call_deferred()

func caption(parent: Node, text: String, at: Vector2, box: Vector2, px: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = box
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", CardSkin.FONT)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", Color("35282f"))
	parent.add_child(label)

func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	var sheet := Control.new()
	root.add_child(sheet)
	var paper := ColorRect.new()
	paper.size = Vector2(1366, 768)
	paper.color = Color("f9f2df")
	sheet.add_child(paper)
	caption(sheet, "기억상실빔 · 강화 망치", Vector2(33, 22), Vector2(1300, 54), 32)
	for i: int in 2:
		var id := StringName("ACT_%d" % (16 + i))
		var card: BaseCard = CardRegistry.get_card(id)
		var description: String = GameData.text("cards", id, "desc")
		var body: Control = CardSkin.body(card, Vector2(400, 560), description, "즉발", true)
		var frame := PanelContainer.new()
		frame.position = Vector2(208 + i * 550, 110)
		frame.custom_minimum_size = Vector2(400, 560)
		frame.size = Vector2(400, 560)
		frame.add_theme_stylebox_override("panel", CardSkin.frame(GameEnums.CardCategory.INSTANT, false, 20))
		frame.add_child(body)
		sheet.add_child(frame)
	for i: int in 14: await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(out.path_join("status-cards-native-preview.png"))
	print("STATUS_ART_NATIVE saved=", result == OK)
	MatchTelemetry.test_sender = Callable()
	quit(0 if result == OK else 1)
