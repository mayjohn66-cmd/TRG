extends SceneTree
var checks := 0
var failures: Array[String] = []

func expect(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var pawn := PlayerPawn.new()
	pawn.kind = GameEnums.PawnKind.ARCADE
	pawn.unit_no = 6
	pawn.owner_id = 1
	expect(pawn.sub_type()==GameEnums.PawnSubType.MOB_KYUI,"correct Kyui subtype")
	var paths := PawnArt.candidates(pawn)
	expect(paths[0].ends_with("MOB_KYUI_V01.png"),"board prefers the new character sprite")
	expect(paths.has(PawnArt.ROOT+"MOB_KYUI.png") and ResourceLoader.exists(PawnArt.ROOT+"MOB_KYUI.png"),"old art remains an intact fallback")
	var art := PawnArt.sprite(pawn)
	expect(not art.is_empty(),"character sprite resolves")
	var texture: Texture2D = art.texture
	expect(texture.resource_path.ends_with("MOB_KYUI_V01.png"),"new art is actually loaded")
	expect(texture.get_width()<=256 and texture.get_height()<=256,"runtime texture stays within board budget")
	var image := texture.get_image()
	expect(image!=null and image.detect_alpha()!=Image.ALPHA_NONE,"real transparent source")
	expect(art.region.has_area() and Rect2(Vector2.ZERO,texture.get_size()).encloses(art.region),"measured silhouette is fully inside source")
	var def := AugmentRegistry.get_def(&"EVO_7_6")
	var icon := AugmentArt.load_first(AugmentArt.candidates(def))
	expect(icon==texture,"draft/history/ability icon shares the same Kyui sprite")
	for color: Color in [Color("e5484d"),Color("4686ff"),Color("3ba86c"),Color("eab83b")]:
		var token := PawnToken.new()
		token.configure(pawn,color)
		root.add_child(token)
		expect(token.artwork.texture==texture,"all owners keep the same character appearance")
		expect(token.owner_color==color and token.scale==Vector2.ONE,"owner base color and token dimensions remain unchanged")
		token.queue_free()
	pawn.skill_used = true
	expect(PawnArt.sprite(pawn).texture==texture,"using the skill does not switch back to the cucumber placeholder")
	var basic := PlayerPawn.new()
	expect(PawnArt.candidates(basic)[0].ends_with("PAWN_DEFAULT.png"),"basic pawn remains unchanged")
	var other := PlayerPawn.new()
	other.kind = GameEnums.PawnKind.ARCADE
	other.unit_no = 7
	expect(PawnArt.candidates(other).has(PawnArt.ROOT+"ODD_MELON.png"),"original melon art remains an intact fallback")
	await process_frame
	for failure: String in failures: printerr("KYUI_ART_FAIL ",failure)
	print("KYUI_ART ",checks," assertions; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
