## Only darts awards change to target stamps; rule state and other tools stay intact.
extends SceneTree
var checks := 0
var failures: Array[String] = []

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	_run.call_deferred()

func result(bull: bool) -> Dictionary:
	return {"tool_id":&"DICE_DARTS","steps":10 if bull else 4,"reroll":bull,"ends_turn":false,"can_continue":false,"details":{"radius":0.02 if bull else 0.7,"angle":0.1,"bull":bull}}

func _run() -> void:
	var history := RollSuccessHistory.new()
	root.add_child(history)
	await process_frame
	history.arm(1,1,&"DICE_DARTS")
	expect(not history.visible and history._success.count == 0, "no award before public reveal")
	history.reveal(1,1,result(false))
	expect(not history.visible, "ordinary hit never earns a stamp")
	history.reveal(1,2,result(true))
	history.reveal(2,1,result(true))
	expect(history._success.count == 0, "wrong owner or stale turn cannot earn a stamp")
	var source := result(true)
	var before := source.duplicate(true)
	history.reveal(1,1,source)
	var tray := history._success
	expect(history.visible and tray.visible and tray.count == 1, "bull prints one target")
	expect(source == before, "presentation does not mutate authoritative result")
	expect(not history._rows.visible and not history._footer.visible and not history._tool_icon.visible, "no redundant boxes or tool badge")
	expect(tray._stamps.size() == 1 and tray._stamps[0].texture.resource_path.ends_with("target.svg"), "reference-style target art")
	expect(tray._stamps[0].material is ShaderMaterial, "printed ink material")
	expect(tray.is_processing() and tray._stamps[0].scale.x > 1.5, "stamp starts above the paper")
	tray._process(0.14)
	expect(is_equal_approx(tray._stamps[0].scale.x,0.9), "stamp lands with short squash")
	tray._process(0.15)
	expect(tray._stamps[0].scale.is_equal_approx(Vector2.ONE), "stamp settles without continuous motion")
	tray._process(0.3)
	expect(not tray.is_processing(), "settled stamp sleeps")
	history.reveal(1,1,result(false))
	expect(tray.count == 1 and not tray.is_processing(), "ordinary hit does not replay or add an award")
	for i: int in 7: history.reveal(1,1,result(true))
	expect(tray.count == 8 and tray._stamps.size() == 6, "long chains retain total with bounded visible stamps")
	expect(history.success_count == 8 and history._header.text.is_empty() and not history._header.get_parent().visible, "award total is retained without text above stamps")
	tray._process(1.0)
	await process_frame
	for mark: TextureRect in tray._stamps:
		if not Rect2(Vector2.ZERO,tray.size).grow(2).encloses(mark.get_rect()): print("DARTS_STAMP_LAYOUT ",tray.size," / ",mark.get_rect())
		expect(Rect2(Vector2.ZERO,tray.size).grow(2).encloses(mark.get_rect()), "all target cells fit tray")
	history.arm(2,1,&"DICE_DARTS")
	expect(not history.visible and tray.count == 0 and tray._stamps.is_empty() and not tray.is_processing(), "new turn clears the stamps and animation")
	history.arm(3,2,&"YUT")
	history.reveal(3,2,{"tool_id":&"YUT","steps":4,"reroll":true,"ends_turn":false,"details":{"face":4}})
	expect(history._rows.visible and not history._header.get_parent().visible and not tray.visible, "Yut stamps also omit the heading")
	expect(history._rows.get_child_count() == 1 and (history._rows.get_child(0) as Label).text.contains("윷"), "other tool result remains intact")
	var yut := history._rows.get_child(0) as Label
	expect(yut.get_theme_color("font_outline_color") == Color.WHITE and yut.get_theme_constant("outline_size") >= 4, "Yut stamp gets a solid white glyph edge")
	for tool: StringName in [&"LIFE_ROULETTE",&"DICE_TAROT",&"DICE_YACHT",&"DICE_DARTS"]:
		history.arm(4,1,tool)
		history.reveal(4,1,{"tool_id":tool,"steps":7,"reroll":true,"details":{"face":7,"label":"success","rolled":[1],"name":"test"}})
		var material := history._success._stamps[0].material as ShaderMaterial
		expect(material != null and material.shader.resource_path.ends_with("roll_stamp_outline.gdshader"), "all printed icons share the outline effect")
		expect(not history._header.get_parent().visible and history._header.text.is_empty(), "all printed icons omit player/count headings")
		history._success._process(1.0)
		expect(not history._success.is_processing(), "outlined stamps remain idle after settling")
	history.arm(5,1,&"REVOLVER")
	history.reveal(5,1,{"tool_id":&"REVOLVER","steps":0,"reroll":false,"ends_turn":true,"details":{"fired":true}})
	expect(history._header.get_parent().visible and history._header.text == "P1", "non-stamp score heading is restored on tool change")
	history.clear()
	expect(not history.visible and history.entries.is_empty(), "reset removes public history")
	history.queue_free()
	await process_frame
	for failure: String in failures: printerr("DARTS_STAMP_FAIL ", failure)
	print("DARTS_STAMP ", checks, " assertions; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
