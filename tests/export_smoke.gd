# File: tests/export_smoke.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 웹으로 내보낸 index.pck를 직접 읽어 에디터에서만 맞고 웹에서 틀리는 문제를 잡는다 (CI: godot --main-pack build/web/index.pck -s <이 파일의 절대 경로>).
#       예: CSV BOM 검사가 웹 내보내기에서 begins_with("")로 바뀌어 모든 표의 첫 글자가 잘려 화면에 문구 키(btn.roll)가 나오고 CSV 수치가 무시됐다.
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	if L10n.tr_ui("btn.roll") != "굴리기":
		failures.append("ui_strings.csv: btn.roll = %s" % L10n.tr_ui("btn.roll"))
	if not GameData.table("augments").has("CARD_PACKAGE") or not GameData.table("cards").has("ACT_02") or not GameData.table("dice").has("YUT"):
		failures.append("밸런스 CSV의 id 열을 읽지 못했다")
	if AugmentRegistry.get_def(&"CARD_02") == null:
		failures.append("표에만 있는 증강(CARD_02)이 없다")
	if UpdateNotes.entries().is_empty() or UpdateNotes.latest_id() == "":
		failures.append("patch_notes.json이 내보낸 묶음에 없다 (export_presets.cfg include_filter 확인): 업데이트 소식이 비어 보인다")
	for id: String in LawRegistry.ALL_IDS:
		var definition := AugmentRegistry.get_def(StringName("AUG_" + id))
		if definition == null or AugmentArt.load_first(AugmentArt.candidates(definition)) == null:
			failures.append("Missing exported law icon: " + id)
	for id: StringName in [&"TOOL_DICE_STOCK", &"TOOL_DICE_DARTS", &"AUG_UTIL_DRIFT", &"AUG_UTIL_BOUNTY"]:
		var definition := AugmentRegistry.get_def(id)
		var icon := AugmentArt.load_first(AugmentArt.candidates(definition))
		if icon == null or not icon.resource_path.contains("_V02.png"):
			failures.append("Latest augment artwork missing from exported pack: " + str(id))
	for path: String in ["res://assets/cards/CNT_08.png", "res://assets/cards/SUM_03.png",
		"res://assets/cards/ACT_16_LETHE_MIB_V04.png", "res://assets/cards/ACT_17_BANA_V01.png",
		"res://assets/cards/ACT_18_BERU_V01.png", "res://assets/cards/ACT_19_SARI_V01.png", "res://assets/cards/ACT_20_MEJONG_V01.png"]:
		if not ResourceLoader.exists(path):failures.append("Missing card artwork: " + path)
	for event: StringName in [&"dart_hit", &"stock_bull", &"hammer_success", &"proton_hum", &"hurricane_wind", &"page_flip", &"report_slam"]:
		if not Sfx.has_sound(event):failures.append("Missing exported sound: " + str(event))
	if failures.is_empty():
		print("EXPORT_SMOKE_OK")
	else:
		for failure: String in failures:
			printerr("EXPORT_SMOKE_FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
