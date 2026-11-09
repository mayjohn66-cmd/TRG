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


## 한 버전의 본문(섹션·항목)을 body 안에 채운다.
static func fill_body(body: VBoxContainer, entry: Dictionary) -> void:
	for section: Dictionary in entry.get("sections", []):
		var block := VBoxContainer.new()  # 섹션마다 한 덩어리: 머리글과 항목 사이는 좁게, 덩어리 사이는 넓게
		block.add_theme_constant_override("separation", 8)
		body.add_child(block)
		var section_label: Label = LobbyTheme.label("■ " + pick(section.get("head", "")), 18, Color("2b8a3e"))
		section_label.name = "NotesSection"
		block.add_child(section_label)
		for item: Variant in section.get("items", []):
			var line: Label = LobbyTheme.label("· " + pick(item), 16, INK)
			line.name = "NotesItem"
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(470, 0)
			line.add_theme_constant_override("line_spacing", 4)
			block.add_child(line)


## 공지 한 줄: [공지] 1.0.1 업데이트 ........ ▼ [보기]. 누르면 그 아래에 본문이 펼쳐진다 (한 번에 하나만).
static func make_row(entry: Dictionary, index: int, rows: Array[Dictionary]) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	var header := Button.new()
	header.name = "NotesRow%d" % index
	header.custom_minimum_size = Vector2(0, 48)
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_stylebox_override("normal", LobbyTheme.style(Color("c9e3c4"), Color("8fbf88"), 2, 6, 0, 8))
	header.add_theme_stylebox_override("hover", LobbyTheme.style(Color("d8eed3"), Color("8fbf88"), 2, 6, 0, 8))
	header.add_theme_stylebox_override("pressed", LobbyTheme.style(Color("b9d8b3"), Color("8fbf88"), 2, 6, 0, 8))
	header.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var line := HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 12
	line.offset_right = -12
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 14)
	header.add_child(line)
	var tag: Label = LobbyTheme.label(L10n.t("공지"), 16, Color("2b8a3e"))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(tag)
	var date_text: String = str(entry.get("date", ""))
	var title: Label = LobbyTheme.label(pick(entry.get("title", "")) + ("  ·  " + date_text if date_text != "" else ""), 18, INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(title)
	var arrow: Label = LobbyTheme.label("", 16, Color("d98b00"))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(arrow)
	wrap.add_child(header)
	var body_panel := PanelContainer.new()
	body_panel.name = "NotesBody%d" % index
	body_panel.add_theme_stylebox_override("panel", LobbyTheme.style(Color("eef7e9"), Color("8fbf88"), 2, 6, 0, 16))
	body_panel.visible = false
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body_panel.add_child(body)
	fill_body(body, entry)
	wrap.add_child(body_panel)
	rows.append({"panel": body_panel, "arrow": arrow})
	header.pressed.connect(func() -> void: toggle_row(rows, index))
	return wrap


## index 줄을 펼친다 (이미 펼쳐져 있으면 접는다). 다른 줄은 모두 접는다.
static func toggle_row(rows: Array[Dictionary], index: int) -> void:
	var open_now: bool = not (rows[index]["panel"] as Control).visible
	for i: int in rows.size():
		var show: bool = open_now and i == index
		(rows[i]["panel"] as Control).visible = show
		(rows[i]["arrow"] as Label).text = ("▲ [" + L10n.t("접기") + "]") if show else ("▼ [" + L10n.t("보기") + "]")


## 팝업을 연다.
static func open(parent: Control) -> Control:
	mark_seen()
	var parts: Dictionary = LobbyTheme.popup(parent, 600.0)
	var overlay: Control = parts["overlay"]
	overlay.name = "UpdateNotesPopup"
	var box: VBoxContainer = parts["box"]
	box.add_child(LobbyTheme.label(L10n.t("공지사항"), 26, LobbyTheme.TEAL))
	var all: Array = entries()
	var scroll := ScrollContainer.new()
	scroll.name = "NotesScroll"
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "NotesList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()  # 오른쪽은 스크롤바 자리
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_child(list)
	scroll.add_child(margin)
	var rows: Array[Dictionary] = []
	for entry_index: int in all.size():
		list.add_child(make_row(all[entry_index], entry_index, rows))
	if not rows.is_empty():
		toggle_row(rows, 0)  # 가장 새 소식은 처음부터 펼쳐 둔다
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
