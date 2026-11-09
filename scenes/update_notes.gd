# File: res://scenes/update_notes.gd
# Class: class_name UpdateNotes
# Role: 로비 둥근 [업데이트 소식] 버튼의 내용과 팝업. 소식은 content_trickcal/data/patch_notes.json(ko/en/ja)을 읽는다.
#       새 업데이트가 나오면 JSON 맨 앞에 항목을 하나 더 넣고 id만 바꾸면 된다: 아직 열어 보지 않은 id면 버튼에 [N] 표시가 뜬다 (본 id는 PlayerSave에 저장).
class_name UpdateNotes
extends RefCounted

const PATH: String = "res://content_trickcal/data/patch_notes.json"
const SEEN_KEY: String = "notes_seen"
const INK := Color("17353a")

static var _cache: Array = []
static var _loaded: bool = false


## 소식 항목들(최신이 맨 앞). 읽지 못하면 빈 배열.
static func entries() -> Array:
	if not _loaded:
		_loaded = true
		var text: String = FileAccess.get_file_as_string(PATH)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary and (parsed as Dictionary).get("entries") is Array:
			_cache = (parsed as Dictionary)["entries"]
	return _cache


static func latest_id() -> String:
	var all: Array = entries()
	return str((all[0] as Dictionary).get("id", "")) if not all.is_empty() else ""


## 아직 열어 보지 않은 새 소식이 있는가 (버튼의 [N] 표시).
static func has_unseen() -> bool:
	return latest_id() != "" and str(PlayerSave.get_value(SEEN_KEY, "")) != latest_id()


static func mark_seen() -> void:
	if latest_id() != "":
		PlayerSave.set_value(SEEN_KEY, latest_id())


## {ko,en,ja} 글 하나를 지금 언어로 (그 언어 글이 비면 한국어).
static func pick(node: Variant) -> String:
	if node is Dictionary:
		var map: Dictionary = node
		var text: String = str(map.get(L10n.current_lang, ""))
		return text if text != "" else str(map.get("ko", ""))
	return str(node)


## 고른 버전 하나의 소식을 그린다 (이전 내용은 지운다). 탭 버튼은 고른 것만 눌린 상태로 둔다.
static func show_entry(list: VBoxContainer, scroll: ScrollContainer, tab_buttons: Array[Button], entry_index: int) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for index: int in tab_buttons.size():
		tab_buttons[index].set_pressed_no_signal(index == entry_index)
		tab_buttons[index].modulate = Color.WHITE if index == entry_index else Color(1, 1, 1, 0.62)
	var all: Array = entries()
	if entry_index < 0 or entry_index >= all.size():
		return
	var entry: Dictionary = all[entry_index]
	var title_text: String = pick(entry.get("title", ""))
	var date_text: String = str(entry.get("date", ""))
	var heading: Label = LobbyTheme.label(title_text + ("  ·  " + date_text if date_text != "" else ""), 22, Color("2b8a3e"))
	heading.name = "NotesTitle"
	list.add_child(heading)
	for section: Dictionary in entry.get("sections", []):
		var block := VBoxContainer.new()  # 섹션마다 한 덩어리: 머리글과 항목 사이는 좁게, 덩어리 사이는 넓게
		block.add_theme_constant_override("separation", 10)
		list.add_child(block)
		var section_label: Label = LobbyTheme.label("■ " + pick(section.get("head", "")), 19, INK)
		section_label.name = "NotesSection"
		block.add_child(section_label)
		for item: Variant in section.get("items", []):
			var line: Label = LobbyTheme.label("· " + pick(item), 16, INK)
			line.name = "NotesItem"
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(500, 0)
			line.add_theme_constant_override("line_spacing", 4)
			block.add_child(line)
	scroll.scroll_vertical = 0


## 팝업을 연다.
static func open(parent: Control) -> Control:
	mark_seen()
	var parts: Dictionary = LobbyTheme.popup(parent, 600.0)
	var overlay: Control = parts["overlay"]
	overlay.name = "UpdateNotesPopup"
	var box: VBoxContainer = parts["box"]
	box.add_child(LobbyTheme.label(L10n.t("공지사항"), 26, LobbyTheme.TEAL))
	var all: Array = entries()
	# 버전 탭: 누른 버전의 소식만 보여 준다 (처음엔 최신). 여러 버전이 쌓여도 한 번에 한 버전만 읽는다.
	var tabs := HFlowContainer.new()
	tabs.name = "NotesTabs"
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	box.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.name = "NotesScroll"
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "NotesList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	var margin := MarginContainer.new()  # 오른쪽은 스크롤바 자리
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_child(list)
	scroll.add_child(margin)
	var tab_buttons: Array[Button] = []
	for entry_index: int in all.size():
		var tab: Button = LobbyTheme.small_button(str((all[entry_index] as Dictionary).get("id", "")), Callable(), &"teal", 17)
		tab.name = "NotesTab%d" % entry_index
		tab.custom_minimum_size = Vector2(76, 40)
		tab.toggle_mode = true
		tab.pressed.connect(func() -> void: show_entry(list, scroll, tab_buttons, entry_index))
		tabs.add_child(tab)
		tab_buttons.append(tab)
	if not all.is_empty():
		show_entry(list, scroll, tab_buttons, 0)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var close := LobbyTheme.big_button(L10n.t("닫기"), overlay.queue_free, 20)
	close.name = "NotesClose"
	Sfx.bind_button(close, &"notice_close")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(close)
	# The shared popup already dismisses on a dim-background click.
	# Give that path the same close sound, without another button click layer.
	var dim: Control = overlay.get_child(0) as Control
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not overlay.has_meta("notice_close_sounded"):
				overlay.set_meta("notice_close_sounded", true)
				Sfx.play(&"notice_close"))
	return overlay
