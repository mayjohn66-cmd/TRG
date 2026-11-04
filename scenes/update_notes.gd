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


## 팝업을 연다.
static func open(parent: Control) -> Control:
	mark_seen()
	var parts: Dictionary = LobbyTheme.popup(parent, 600.0)
	var overlay: Control = parts["overlay"]
	overlay.name = "UpdateNotesPopup"
	var box: VBoxContainer = parts["box"]
	box.add_child(LobbyTheme.label(L10n.t("공지사항"), 26, LobbyTheme.TEAL))
	var scroll := ScrollContainer.new()
	scroll.name = "NotesScroll"
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var all: Array = entries()
	for entry_index: int in all.size():
		var entry: Dictionary = all[entry_index]
		var title_text: String = pick(entry.get("title", ""))
		var date_text: String = str(entry.get("date", ""))
		var heading: Label = LobbyTheme.label(title_text + ("  ·  " + date_text if date_text != "" else ""), 20, Color("2b8a3e"))
		heading.name = "NotesTitle"
		list.add_child(heading)
		for section: Dictionary in entry.get("sections", []):
			var section_label: Label = LobbyTheme.label("■ " + pick(section.get("head", "")), 17, INK)
			section_label.name = "NotesSection"
			list.add_child(section_label)
			for item: Variant in section.get("items", []):
				var line: Label = LobbyTheme.label("· " + pick(item), 15, INK)
				line.name = "NotesItem"
				line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				line.custom_minimum_size = Vector2(540, 0)
				list.add_child(line)
		if entry_index < all.size() - 1:
			list.add_child(HSeparator.new())
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
