# File: res://tests/ui_overlap_audit.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 화면 전체 글자 겹침 점검 도구. 판 화면을 여러 상태(증강 선택·말 고르기·손패 펼침·알림·법전 칸 등)로 만들고
#       눈에 보이는 글자(Label/Button 글자)끼리 서로 겹치거나, 글자가 제 칸·화면 밖으로 잘리는 곳을 찾아 출력한다.
#       실행: godot --headless --path . -s res://tests/ui_overlap_audit.gd   (AUDIT_LANG=en 처럼 한 언어만, AUDIT_VERBOSE=1이면 전부)
#       실패로 끝내지 않는다 (찾은 곳을 눈으로 보고 고치는 용도).
extends SceneTree

const LANGS: Array[String] = ["ko", "en", "ja"]
const MIN_OVERLAP_AREA: float = 30.0

var _board: MainBoard = null
var _found: Dictionary = {}
var _skip_draft: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	L10n.install()
	GameEnums.draft_start = 1
	var only: String = OS.get_environment("AUDIT_LANG")
	for touch: bool in [false, true]:
		MobileSupport.force_touch = touch
		for lang: String in LANGS:
			if only != "" and only != lang:
				continue
			L10n.set_language(lang)
			AugmentRegistry.reload()
			await _session(lang + ("/터치" if touch else ""))
	MobileSupport.force_touch = false
	for touch: bool in [false, true]:
		MobileSupport.force_touch = touch
		for lang: String in LANGS:
			if only != "" and only != lang:
				continue
			L10n.set_language(lang)
			await _scene_session("res://scenes/start_menu.tscn", "시작 화면", lang + ("/터치" if touch else ""))
			await _scene_session("res://scenes/lobby.tscn", "로비", lang + ("/터치" if touch else ""))
	MobileSupport.force_touch = false
	L10n.set_language("ko")
	var keys: Array = _found.keys()
	keys.sort()
	for key: String in keys:
		print("AUDIT ", key, "  x", _found[key])
	print("AUDIT_DONE: %d spots" % keys.size())
	quit(0)


func _session(lang: String) -> void:
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard: int = 0
	while (not _board._draft_open or _board._intro_blocks()) and guard < 2400:
		guard += 1
		await process_frame
	await _frames(90)  # 창이 아래에서 올라오는 연출(0.5초)이 끝난 뒤에 잰다
	_scan(lang, "증강 선택")
	_board._draft_open = false
	_board._close_draft_overlay()
	_board._announcer.cancel()
	await _frames(10)
	_scan(lang, "기본 판")
	# 말 고르기 안내 + 결과 예고 + 리벤지 배지
	_board._select_title.visible = true
	_board._select_title.text = L10n.t("[어느 말을 %d칸 이동시킬까요?]") % 6
	_board._paint_revenge_glow(_board._pawn_buttons[0], true, 4, false)
	for part: Dictionary in _board._pawn_slot_parts:
		part["result"].visible = true
		part["result"].text = "처치!!"
	await _frames(10)
	_scan(lang, "말 고르기")
	for part: Dictionary in _board._pawn_slot_parts:
		part["result"].visible = false
	_board._select_title.visible = false
	# 손패 펼침
	_board._hand_open = true
	_board._refresh_all()
	await _frames(10)
	_scan(lang, "손패 펼침")
	_board._hand_open = false
	# 알림들
	_board._announce_now("템포 업", "템포 업 Lv.1 · 과열", "8라운드부터 게임이 빨라집니다!\n◆ 차례 첫 이동 +1칸\n◆ 리벤지 부스터 +6칸", Color("ff4d4d"), null, 6.0)
	await _frames(40)
	_scan(lang, "템포 업 알림")
	_board._announcer.cancel()
	_board.state.round_number = 6
	_board._announce_now("라운드", "ROUND 6", "", Color("ffd43b"), null, 6.0, true, {"key": "round", "sub": _board.round_banner_sub()})
	await _frames(40)
	_scan(lang, "라운드 배너")
	_board._announcer.cancel()
	_board._announcer.cancel()
	# 판정 도구 카드: 도구마다 요약과 펼친 족보
	var me: int = _board.local_player_id
	for tool_id: StringName in AugmentRegistry.SWAPPABLE_TOOLS:
		_board.state.tools[me] = ToolRegistry.create(tool_id)
		for expanded: bool in [false, true]:
			_board._tool_expanded = expanded
			_board._refresh_all()
			await _frames(12)
			_scan(lang, "도구 %s%s" % [tool_id, " 펼침" if expanded else ""])
	_board._tool_expanded = false
	# 손패에 카드가 가득 찬 채 펼치기
	var ids: Array[StringName] = []
	for card_id: StringName in CardRegistry.all_ids():
		if ids.size() < 8:
			ids.append(card_id)
	(_board.state.hands[me] as Array).clear()
	(_board.state.hands[me] as Array).append_array(ids)
	_board._hand_open = true
	_board._refresh_all()
	await _frames(15)
	_scan(lang, "손패 가득")
	_board._hand_open = false
	_board._refresh_all()
	# 메뉴 세 쪽
	for page: StringName in [&"main", &"settings", &"confirm_exit"]:
		_board._open_menu()
		_board._show_menu_page(page)
		await _frames(8)
		_scan(lang, "메뉴 " + str(page), _board._menu_overlay)
		_board._close_menu()
		await _frames(2)
	# 프로필 [증강] 툴팁
	var info: Button = _board._profiles[2]["panel"].find_child("ProfileInfo", true, false)
	if info != null:
		_board._tip_toggle(info, _board._fill_profile_tip.bind(2))
		await _frames(8)
		_scan(lang, "프로필 툴팁")
		_board._tip_toggle(info, _board._fill_profile_tip.bind(2))
	# 피드백 창
	var modal: FeedbackModal = _board._open_feedback()
	await _frames(10)
	if modal != null:
		_scan(lang, "피드백 창", modal)
		modal.queue_free()
		await _frames(2)
	# 결과 화면
	_board.manager.is_game_over = true
	_board._show_result_overlay()
	await _frames(40)
	_scan(lang, "결과 화면", _board._result_overlay)
	_board._close_result_overlay()
	await _frames(5)
	_board.queue_free()
	_board = null
	await _frames(3)


func _scene_session(path: String, name: String, lang: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await _frames(30)
	_scan(lang, name, scene)
	scene.queue_free()
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## 눈에 보이는 글자 칸을 모아 겹침·잘림을 찾는다.
func _scan(lang: String, state: String, scan_root: Node = null) -> void:
	var items: Array[Dictionary] = []
	_skip_draft = state != "증강 선택"
	if scan_root != null:
		_collect(scan_root, items)
	elif state == "증강 선택":
		_collect(_board._draft_overlay, items)  # 창 아래 어둡게 깔린 판의 글자는 보지 않는다
	else:
		_collect(_board, items)
	var view: Rect2 = Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size)
	if OS.get_environment("AUDIT_VERBOSE") != "":
		var layers: Dictionary = {}
		for item: Dictionary in items:
			layers[item["layer"]] = int(layers.get(item["layer"], 0)) + 1
		print("SCAN %s/%s: %d texts, view %s, layers %s" % [lang, state, items.size(), view, layers])
	for item: Dictionary in items:
		var rect: Rect2 = item["rect"]
		if rect.size.x < 2.0 or rect.size.y < 2.0:
			continue
		if not view.encloses(rect.grow(-1.0)) and rect.intersects(view):
			_note("%s/%s 화면 밖으로 나감: '%s' %s" % [lang, state, _clip(item["text"]), _fmt(rect)])
		if item["clipped"]:
			_note("%s/%s 글이 칸보다 커 잘림: '%s' 칸 %s 글 %s" % [lang, state, _clip(item["text"]), _fmt(item["box"]), _fmt(rect)])
	_scan_buttons(lang, state, scan_root if scan_root != null else (_board._draft_overlay if state == "증강 선택" else _board))
	for i: int in items.size():
		for j: int in range(i + 1, items.size()):
			var a: Dictionary = items[i]
			var b: Dictionary = items[j]
			if a["node"].is_ancestor_of(b["node"]) or b["node"].is_ancestor_of(a["node"]):
				continue
			if a["layer"] != b["layer"]:
				continue  # 서로 다른 겹(예: 알림 창과 그 아래 판)은 보는 사람이 가리는 것으로 안다
			var overlap: Rect2 = (a["rect"] as Rect2).intersection(b["rect"])
			if overlap.size.x * overlap.size.y >= MIN_OVERLAP_AREA and overlap.size.x > 3.0 and overlap.size.y > 3.0:
				_note("%s/%s 글자 겹침: '%s' %s <-> '%s' %s" % [lang, state, _clip(a["text"]), _fmt(a["rect"]), _clip(b["text"]), _fmt(b["rect"])])


## 버튼 상자끼리 겹치는 곳 (글자가 안 겹쳐도 한 버튼이 다른 버튼을 덮는 경우).
func _scan_buttons(lang: String, state: String, scan_root: Node) -> void:
	var buttons: Array[Button] = []
	_collect_buttons(scan_root, buttons)
	for i: int in buttons.size():
		for j: int in range(i + 1, buttons.size()):
			var a: Button = buttons[i]
			var b: Button = buttons[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a) or _layer_of(a) != _layer_of(b):
				continue
			var overlap: Rect2 = a.get_global_rect().intersection(b.get_global_rect())
			if overlap.size.x > 6.0 and overlap.size.y > 6.0 and overlap.size.x * overlap.size.y >= 150.0:
				_note("%s/%s 버튼 겹침: '%s' %s <-> '%s' %s" % [lang, state, _clip(_shown(a)), _fmt(a.get_global_rect()), _clip(_shown(b)), _fmt(b.get_global_rect())])


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if _board != null and (node == _board._hand_stack or node == _board._dock or node == _board._pawn_bar):
		return
	if _skip_draft and _board != null and node == _board._draft_overlay:
		return
	if node is Button and (node as Button).is_visible_in_tree() and (node as Button).modulate.a > 0.2:
		var rect: Rect2 = (node as Button).get_global_rect()
		if rect.size.x >= 20.0 and rect.size.y >= 14.0:
			out.append(node as Button)
	for child: Node in node.get_children():
		_collect_buttons(child, out)


func _collect(node: Node, out: Array[Dictionary]) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if _board != null and (node == _board._hand_stack or node == _board._dock) and node != null:
		return  # 손패는 카드를 겹쳐 쌓아 펼치는 것이 설계라 글자 겹침으로 세지 않는다 (카드 글자는 ui_text_fit_test가 본다)
	if _skip_draft and _board != null and node == _board._draft_overlay:
		return  # 증강 선택 창이 아닌 상태를 볼 때 남아 있는 창은 건너뛴다
	if node is Label and str((node as Label).text).strip_edges() != "":
		var label: Label = node as Label
		if label.is_visible_in_tree() and label.modulate.a > 0.2 and label.self_modulate.a > 0.2:
			out.append(_describe_label(label))
	elif node is Button and not (node as Button).text.strip_edges().is_empty():
		var button: Button = node as Button
		if button.is_visible_in_tree() and button.modulate.a > 0.2:
			var font: Font = button.get_theme_font("font")
			var size_px: int = button.get_theme_font_size("font_size")
			var box: Rect2 = button.get_global_rect()
			var wrap_width: float = maxf(box.size.x - 40.0, 10.0) if button.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0  # 체크박스 칸 등 앞 장식 폭만큼 뺀다
			var text_size: Vector2 = font.get_multiline_string_size(_shown(button), HORIZONTAL_ALIGNMENT_LEFT, wrap_width, size_px)
			var rect: Rect2 = Rect2(box.position + (box.size - text_size) * 0.5, text_size)
			out.append({"node": button, "text": _shown(button), "rect": rect, "box": box, "clipped": text_size.x > box.size.x + 1.0 or text_size.y > box.size.y + 1.0, "layer": _layer_of(button)})
	for child: Node in node.get_children():
		_collect(child, out)


## 화면에 실제로 보이는 글 (Label·Button은 text를 번역해서 그린다).
func _shown(node: Node) -> String:
	var raw: String = str(node.get("text"))
	return node.atr(raw) if node.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else raw


func _describe_label(label: Label) -> Dictionary:
	var font: Font = label.get_theme_font("font")
	var size_px: int = label.get_theme_font_size("font_size")
	var box: Rect2 = label.get_global_rect()
	var width: float = box.size.x
	var text_size: Vector2
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		text_size = font.get_multiline_string_size(_shown(label), label.horizontal_alignment, width, size_px)
	else:
		text_size = font.get_multiline_string_size(_shown(label), label.horizontal_alignment, -1, size_px)
	var x: float = box.position.x
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER: x = box.position.x + (box.size.x - text_size.x) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT: x = box.end.x - text_size.x
	var y: float = box.position.y
	match label.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER: y = box.position.y + (box.size.y - text_size.y) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM: y = box.end.y - text_size.y
	var rect: Rect2 = Rect2(Vector2(x, y), text_size)
	var clipped: bool = (text_size.y > box.size.y + 2.0 and not label.clip_text) or (label.clip_text and (text_size.x > box.size.x + 1.0 or text_size.y > box.size.y + 1.0))
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF and text_size.x > box.size.x + 2.0 and label.get_parent() is Control and (label.get_parent() as Control).clip_contents:
		clipped = true
	return {"node": label, "text": _shown(label), "rect": rect, "box": box, "clipped": clipped, "layer": _layer_of(label)}


## 같은 겹(CanvasLayer·z_index 기준 맨 위 조상)끼리만 겹침을 본다.
func _layer_of(node: Node) -> String:
	var parts: Array[String] = []
	var current: Node = node
	while current != null:
		if current is CanvasLayer:
			parts.append("L%d" % (current as CanvasLayer).layer)
		if current is CanvasItem and (current as CanvasItem).z_index != 0 and (current as CanvasItem).z_as_relative:
			parts.append("z%d" % (current as CanvasItem).z_index)
		current = current.get_parent()
	return ",".join(parts)


func _note(message: String) -> void:
	_found[message] = int(_found.get(message, 0)) + 1


func _clip(text: String) -> String:
	var line: String = text.replace("\n", " / ")
	return line.substr(0, 24) + ("…" if line.length() > 24 else "")


func _fmt(rect: Rect2) -> String:
	return "(%d,%d %dx%d)" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
