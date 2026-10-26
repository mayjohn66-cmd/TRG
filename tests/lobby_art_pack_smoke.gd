## Only the new lobby artwork and its on-demand pack. No networking or game tests.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var pack := OS.get_environment("LOBBY_ART_PACK")
	if not pack.is_empty():
		assert(not AvatarPacks.is_ready(AvatarPacks.UI_LOBBY), "Lobby pictures stay outside the main download")
		assert(ProjectSettings.load_resource_pack(pack, false), "Lobby art pack mounts")
	assert(AvatarPacks.is_ready(AvatarPacks.UI_LOBBY), "Both painted icons exist")
	var wait: Texture2D = load(AvatarPacks.UI_LOBBY_DIR + "/UI_LOBBY_WAIT.png")
	var crown: Texture2D = load(AvatarPacks.UI_LOBBY_DIR + "/UI_LOBBY_CROWN.png")
	assert(wait.get_width() <= 192 and crown.get_width() <= 64, "Imported sizes fit their UI roles")
	assert(wait.get_image().get_pixel(0,0).a < 0.01 and crown.get_image().get_pixel(0,0).a < 0.01, "Transparent padding")
	for color: Color in [Color("1c7ed6"),Color("2f9e44"),Color("f08c00")]:
		var card := HubKit.seat_card(2, color, true)
		root.add_child(card.root)
		await process_frame
		var icon: TextureRect = card.avatar.get_child(0).get_child(0)
		assert(icon.texture == wait, "Seat uses the illustrated texture")
		assert((icon.material as ShaderMaterial).get_shader_parameter("seat_color").is_equal_approx(color), "Seat accent is preserved")
		card.root.queue_free()
		await process_frame
	print("LOBBY_ART_PACK_OK: transparent icons, seat palettes and pack availability")
	quit(0)
