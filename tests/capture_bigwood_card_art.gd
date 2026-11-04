## Registered CNT_08 review using production data and CardSkin.
extends SceneTree

var out := OS.get_environment("DARTS_CAPTURE_OUT")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	var sheet := Control.new()
	root.add_child(sheet)
	var background := ColorRect.new()
	background.size = Vector2(1366, 768)
	background.color = Color("f9f2df")
	sheet.add_child(background)
	CardSkin.label(sheet, "GalleryTitle", "이쪽을 봐라! · 빅우드 카드", Rect2(24, 18, 1318, 44), 30, CardSkin.INK, true)
	var card: BaseCard = CardRegistry.get_card(&"CNT_08")
	var sizes: Array[Vector2] = [Vector2(400, 560), Vector2(140, 196)]
	var locations: Array[Vector2] = [Vector2(260, 105), Vector2(880, 276)]
	var art_found := true
	for i: int in 2:
		var frame := PanelContainer.new()
		frame.position = locations[i]
		frame.size = sizes[i]
		frame.custom_minimum_size = sizes[i]
		frame.add_theme_stylebox_override("panel", CardSkin.frame(card.category, false, 16 if i == 0 else 8))
		var body := CardSkin.body(card, sizes[i], MainBoard.card_summary(card.card_id), "방어", i == 0)
		frame.add_child(body)
		sheet.add_child(frame)
		art_found = art_found and body.find_child("CardArt", true, false) != null
		CardSkin.label(sheet, "SizeCaption%d" % i, "상세 보기" if i == 0 else "손패 크기", Rect2(locations[i].x, locations[i].y + sizes[i].y + 16, sizes[i].x, 36), 20, CardSkin.INK, true)
	for i: int in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(out.path_join("bigwood-card-native-preview.png"))
	print("BIGWOOD_CARD_ART_NATIVE art_found=", art_found, " saved=", result == OK)
	MatchTelemetry.test_sender = Callable()
	quit(0 if result == OK and art_found else 1)
