## Art-only review sheet in the real CardSkin; does not register cards or laws.
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
	caption(sheet, "방해령 삼총사 · 카드 일러스트", Vector2(33, 22), Vector2(1300, 54), 32)
	var names: Array[String] = ["방해령 베루", "방해령 사리", "방해령 메죵"]
	var descriptions: Array[String] = ["적 말 1개를 뒤로 1칸 (도착 칸이 비어 있을 때)", "내 말 1개를 앞으로 1칸 (도착 칸이 비어 있을 때)", "적 1명의 다음 이동 눈금 -1 (최소 1칸)"]
	var files: Array[String] = ["ACT_18_BERU_V01.png", "ACT_19_SARI_V01.png", "ACT_20_MEJONG_V01.png"]
	for i: int in 3:
		var card := BaseCard.new()
		card.card_id = StringName("ACT_%d" % (18 + i))
		card.display_name = names[i]
		var body: Control = CardSkin.body(card, Vector2(350, 490), descriptions[i], "즉발", true)
		var frame := PanelContainer.new()
		frame.position = Vector2(98 + i * 410, 110)
		frame.custom_minimum_size = Vector2(350, 490)
		frame.size = Vector2(350, 490)
		frame.add_theme_stylebox_override("panel", CardSkin.frame(GameEnums.CardCategory.INSTANT, false, 20))
		frame.add_child(body)
		sheet.add_child(frame)
		var window: Control = body.find_child("ArtWindow", true, false)
		for child: Node in window.get_children(): child.queue_free()
		var picture := TextureRect.new()
		picture.name = "HauntArtReview"
		picture.texture = load("res://assets/cards/" + files[i])
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position = Vector2(2, 2)
		picture.size = window.size - Vector2(4, 4)
		window.add_child(picture)
	caption(sheet, "뒤로 밀기", Vector2(98, 626), Vector2(350, 45), 24)
	caption(sheet, "앞으로 끌기", Vector2(508, 626), Vector2(350, 45), 24)
	caption(sheet, "주사위 줄이기", Vector2(918, 626), Vector2(350, 45), 24)
	for i: int in 14: await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(out.path_join("haunt-cards-native-preview.png"))
	print("HAUNT_ART_NATIVE saved=", result == OK)
	MatchTelemetry.test_sender = Callable()
	quit(0 if result == OK else 1)
