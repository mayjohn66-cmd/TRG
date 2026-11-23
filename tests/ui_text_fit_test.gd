# File: res://tests/ui_text_fit_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 글자 넘침 검사. 증강 카드 전부·생떼 카드 전부(손패 크기·확대 보기)·규칙 도감 전 장을 한국어·영어·일본어로 띄워,
#       글자가 제 칸 밖으로 삐져나오거나(한 줄 글이 칸보다 넓음, 띄어쓰기 없는 긴 낱말이 칸을 넘음) 줄 수 제한에 잘려 끝이 안 보이거나,
#       글 칸 자체가 카드 밖으로 나가는 곳을 찾는다. 흐르는 글 상자(MarqueeLabel) 안의 글은 넘쳐도 된다(천천히 흘러 다 보인다).
#       실행: godot --headless --path . -s res://tests/ui_text_fit_test.gd   (FIT_LANG=ja 처럼 한 언어만, FIT_VERBOSE=1이면 전부 출력)
extends SceneTree

const LANGS: Array[String] = ["ko", "en", "ja"]

var _problems: Array[String] = []
var _board: MainBoard = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	L10n.install()
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	_board.instant_roll_for_test = true
	root.add_child(_board)
	await process_frame
	var only: String = OS.get_environment("FIT_LANG")
	for lang: String in LANGS:
		if only != "" and only != lang:
			continue
		L10n.set_language(lang)
		AugmentRegistry.reload()
		await _check_augments(lang)
		await _check_cards(lang)
	_board.queue_free()
	await process_frame
	for lang: String in LANGS:
		if only != "" and only != lang:
			continue
		L10n.set_language(lang)
		await _check_rulebook(lang)
	L10n.set_language("ko")
	AugmentRegistry.reload()
	var verbose: bool = OS.get_environment("FIT_VERBOSE") == "1"
	for problem: String in (_problems if verbose else _problems.slice(0, 60)):
		print("  OVERFLOW ", problem)
	if _problems.is_empty():
		print("UI_TEXT_FIT_OK")
		quit(0)
	else:
		print("UI_TEXT_FIT_FAIL: %d곳" % _problems.size())
		quit(1)


func _holder() -> Control:
	var holder := Control.new()
	holder.position = Vector2(20, 20)
	root.add_child(holder)
	return holder


func _check_augments(lang: String) -> void:
	var holder: Control = _holder()
	for definition: AugmentDef in AugmentRegistry.all():
		var card: Button = MainBoard.make_augment_card(_board._augment_card_info(definition, 1), Callable(), 1.0, true)
		holder.add_child(card)
		await process_frame
		_scan(card, card, "%s 증강 %s" % [lang, definition.augment_id])
		card.free()
	holder.queue_free()


func _check_cards(lang: String) -> void:
	var holder: Control = _holder()
	for card_id: StringName in CardRegistry.all_ids():
		var face: PanelContainer = _board._make_card_face(card_id)
		holder.add_child(face)
		await process_frame
		_scan(face, face, "%s 손패카드 %s" % [lang, card_id])
		face.free()
		var size: Vector2 = MainBoard.HAND_CARD_SIZE * 2.5
		var big := PanelContainer.new()
		big.custom_minimum_size = size
		big.add_child(_board._build_card_body(card_id, size, true))
		holder.add_child(big)
		await process_frame
		_scan(big, big, "%s 확대카드 %s" % [lang, card_id])
		big.free()
	holder.queue_free()


func _check_rulebook(lang: String) -> void:
	var menu: Control = (load("res://scenes/start_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	L10n.set_language(lang)
	var book: Rulebook = Rulebook.open(menu)
	await process_frame
	for spread: int in book.spread_count():
		book.show_spread(spread)
		await process_frame
		for entry: int in book.entry_count():
			book.show_entry(entry)
			await process_frame
			_scan(book, null, "%s 도감 %d장 %d번" % [lang, spread, entry])  # 도감은 스크롤 목록이라 틀 검사 대신 칸 안 검사만
	book.close()
	menu.queue_free()
	await process_frame


## root 아래 보이는 Label마다 글이 칸에 들어가는지 본다. frame: 글 칸이 벗어나면 안 되는 바깥 틀 (카드).
func _scan(node: Node, frame: Control, where: String) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is MarqueeLabel:
		return  # 흐르는 글은 넘쳐도 다 보인다
	if node is Label:
		var problem: String = _label_problem(node as Label, frame)
		if problem != "":
			var text: String = (node as Label).atr((node as Label).text).replace("\n", "⏎")
			var key: String = "%s | %s | %s | %s" % [where, node.name, problem, text.substr(0, 60)]
			if not _problems.has(key):
				_problems.append(key)
	for child: Node in node.get_children():
		_scan(child, frame, where)


func _label_problem(label: Label, frame: Control) -> String:
	var shown: String = label.atr(label.text)
	if shown.strip_edges() == "" or label.size.x < 2.0:
		return ""
	var font: Font = label.get_theme_font("font")
	var px: int = label.get_theme_font_size("font_size")
	var width: float = label.size.x
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var widest: float = 0.0
		for line: String in shown.split("\n"):
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
		if widest > width + 2.0:
			return "가로 넘침 %.0f>%.0f" % [widest, width]
		var lines: int = shown.count("\n") + 1
		var tall: float = lines * font.get_height(px) + (lines - 1) * label.get_theme_constant("line_spacing")
		if label.size.y > 0.0 and tall > label.size.y + 1.5:
			return "세로 넘침 %.0f>%.0f" % [tall, label.size.y]
	else:
		# 줄바꿈으로도 못 나누는 덩어리(띄어쓰기 없는 긴 낱말)가 칸보다 넓은가
		# 웹 빌드는 일본어 낱말 경계 사전이 없어 띄어쓰기에서만 나뉠 수 있다: AUTOWRAP_WORD는 띄어쓰기 사이 덩어리가 칸보다 넓으면 넘친다
		if label.autowrap_mode == TextServer.AUTOWRAP_WORD:
			for line: String in shown.split("\n"):
				for chunk: String in line.split(" "):
					var chunk_width: float = font.get_string_size(chunk, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
					if chunk_width > width + 2.0:
						return "긴 낱말 넘침 %.0f>%.0f" % [chunk_width, width]
		if label.get_line_count() > label.get_visible_line_count():
			return "잘림 %d/%d줄" % [label.get_visible_line_count(), label.get_line_count()]
		var needed: float = label.get_line_count() * (font.get_height(px) + label.get_theme_constant("line_spacing")) - label.get_theme_constant("line_spacing")
		if not label.clip_text and needed > label.size.y + 4.0 and label.size.y > 0.0:
			return "세로 넘침 %.0f>%.0f" % [needed, label.size.y]
	# 배지·칩처럼 Panel 안에 놓인 글 칸은 그 Panel 밖으로 나가면 안 된다 (글이 칩 밖으로 삐져나와 보임)
	var holder: Node = label.get_parent()
	if frame != null and holder is Panel and not (holder as Panel).get_global_rect().grow(2.0).encloses(label.get_global_rect()):
		return "칩 밖 %s > %s" % [str(label.size), str((holder as Panel).size)]
	if frame != null:
		var outer: Rect2 = frame.get_global_rect().grow(3.0)
		var rect: Rect2 = label.get_global_rect()
		if not outer.encloses(rect):
			return "틀 밖 %s" % str(rect)
	return ""
