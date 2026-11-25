extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for i: int in 6:
		await process_frame

func geometry(panel: RoomRulesPanel) -> Array:
	var rects: Array = [(panel.find_child("RulesCard", true, false) as Control).get_global_rect(), panel._body.get_global_rect(), panel._scroll.get_global_rect(), panel._ban_panel.get_global_rect()]
	for child: Control in panel._scroll.get_child(0).get_child(0).get_children():
		rects.append(child.get_global_rect())
	return rects

func check_geometry(panel: RoomRulesPanel, expected: Array, context: String) -> void:
	var actual := geometry(panel)
	for i: int in actual.size():
		var a: Rect2 = actual[i]
		var e: Rect2 = expected[i]
		if a.position.distance_to(e.position) > 1.1 or a.size.distance_to(e.size) > 1.1:
			failures.append("%s item %d %s -> %s" % [context, i, e, a])

func run() -> void:
	L10n.install()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for viewport_size: Vector2i in [Vector2i(1366, 868), Vector2i(720, 502)]:
		root.size = viewport_size
		for lang: String in ["ko", "en", "ja"]:
			L10n.set_language(lang)
			GameSession.reset_rules()
			GameSession.set_board(BoardCatalog.DEFAULT_ID)
			var host := Control.new()
			root.add_child(host)
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var panel := RoomRulesPanel.open(host, true)
			await settle()
			var baseline := geometry(panel)
			var selectors: Array = [panel._preset]
			selectors.append_array(panel._selectors.values())
			for selector: Control in selectors:
				for i: int in selector._options.size() + 1:
					(selector.get_node("Next") as Button).pressed.emit()
					await settle()
					check_geometry(panel, baseline, "%s %s %s" % [viewport_size, lang, selector.name])
			panel._on_reset()
			await settle()
			var bans := panel._ban_panel
			if panel._layout_tabs.visible:
				panel._select_page(1)
				await settle()
			var ban_baseline := geometry(panel)
			for kind: String in ["card_bans", "augment_bans"]:
				bans._select_tab(kind)
				await settle()
				check_geometry(panel, ban_baseline, "%s %s ban tab" % [viewport_size, lang])
				for id: String in bans._actions.keys().slice(0, 4):
					bans._toggle(id)
					await settle()
					check_geometry(panel, ban_baseline, "%s %s ban toggle" % [viewport_size, lang])
				for query: String in ["없는결과", "해적", ""]:
					bans._query.text = query
					bans._query.text_changed.emit(query)
					await settle()
					check_geometry(panel, ban_baseline, "%s %s filter" % [viewport_size, lang])
			panel.close()
			host.queue_free()
			await settle()
	GameSession.reset_rules()
	if failures.is_empty():
		print("ROOM_RULES_STABLE_GEOMETRY_OK")
	else:
		for failure: String in failures.slice(0, 25):
			printerr(failure)
		print("ROOM_RULES_STABLE_GEOMETRY_FAIL ", failures.size())
	quit(0 if failures.is_empty() else 1)
