extends PanelContainer

signal changed(key: String, ids: Array)

const CARD_BANS := "card_bans"
const AUGMENT_BANS := "augment_bans"
const TEAL := Color("167759")
const DARK := Color("1b4d3e")
const PALE := Color("edf5ec")
const EDGE := Color("b0cbbb")
const RED := Color("a44d57")

var _kind := CARD_BANS
var _rules: Dictionary = {}
var _tabs: Dictionary[String, Button] = {}
var _actions: Dictionary[String, Button] = {}
var _query: LineEdit
var _only_banned: Button
var _count: Label
var _scroll: ScrollContainer
var _list: VBoxContainer


func _ready() -> void:
	name = "RoomBans"
	add_theme_stylebox_override("panel", LobbyTheme.style(Color("fffdf4"), EDGE, 1, 17, 0, 13))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	add_child(column)
	var title := LobbyTheme.label("밴 설정", 20, DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_count = LobbyTheme.label("", 13, RED)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_child(_count)
	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 7)
	for entry: Array in [[CARD_BANS, "카드 밴"], [AUGMENT_BANS, "증강 밴"]]:
		var tab := _button(entry[1], TEAL, 42)
		tab.name = "CardsTab" if entry[0] == CARD_BANS else "AugmentsTab"
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.toggle_mode = true
		tab.pressed.connect(_select_tab.bind(entry[0]))
		tabs.add_child(tab)
		_tabs[entry[0]] = tab
	column.add_child(tabs)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 7)
	_query = LineEdit.new()
	_query.name = "BanSearch"
	_query.placeholder_text = "이름으로 검색"
	_query.clear_button_enabled = true
	_query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_query.add_theme_font_size_override("font_size", 15)
	_query.add_theme_color_override("font_color", DARK)
	_query.add_theme_color_override("font_placeholder_color", Color("688276"))
	_query.add_theme_color_override("caret_color", TEAL)
	_query.add_theme_stylebox_override("normal", LobbyTheme.style(Color.WHITE, EDGE, 1, 11, 0, 8))
	_query.add_theme_stylebox_override("focus", LobbyTheme.style(Color.TRANSPARENT, TEAL, 2, 11))
	_query.text_changed.connect(func(_text: String) -> void: _rebuild())
	filters.add_child(_query)
	_only_banned = _button("밴한 항목만", RED, 40)
	_only_banned.name = "BannedOnly"
	_only_banned.toggle_mode = true
	_only_banned.pressed.connect(_rebuild)
	filters.add_child(_only_banned)
	column.add_child(filters)

	_scroll = ScrollContainer.new()
	_scroll.name = "BanListScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", 10)
	_scroll.add_child(gutter)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	gutter.add_child(_list)
	_select_tab(CARD_BANS)


func refresh(rules: Dictionary) -> void:
	var previous := _rules
	_rules = rules
	if previous.get("board") != rules.get("board") and _kind == AUGMENT_BANS:
		_rebuild()
	elif _only_banned.button_pressed and previous.get(_kind) != rules.get(_kind):
		_rebuild()
	else:
		_refresh_actions()


func _select_tab(kind: String) -> void:
	_kind = kind
	for key: String in _tabs:
		_tabs[key].set_pressed_no_signal(key == _kind)
	_rebuild()


func _entries() -> Array:
	var entries: Array = []
	if _kind == CARD_BANS:
		for id: StringName in CardRegistry.all_ids():
			entries.append([String(id), CardRegistry.get_card(id).display_name])
		return entries
	for definition: AugmentDef in AugmentRegistry.all():
		if not definition.enabled:
			continue
		var title := AugmentDef.strip_title_tag(definition.title)
		if definition.category == GameEnums.AugmentCategory.LAW_ENACT:
			var variant := BoardCatalog.law_variant(_rules.get("board", BoardCatalog.DEFAULT_ID), String(definition.payload))
			title = str(variant.get("name", title))
		entries.append([String(definition.augment_id), title])
	return entries


func _rebuild() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_actions.clear()
	var query := _query.text.strip_edges().to_lower()
	var bans: Array = _rules.get(_kind, [])
	for entry: Array in _entries():
		var id: String = entry[0]
		var title := L10n.t(str(entry[1]))
		if (not query.is_empty() and not title.to_lower().contains(query)) or (_only_banned.button_pressed and not bans.has(id)):
			continue
		var row := PanelContainer.new()
		var style := LobbyTheme.style(PALE, Color("dce9dd"), 1, 11, 0, 5)
		style.content_margin_left = 12.0
		style.content_margin_right = 8.0
		row.add_theme_stylebox_override("panel", style)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 9)
		row.add_child(line)
		var label := LobbyTheme.label(title, 15, DARK)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(label)
		var action := _button("", RED, 36)
		action.name = "Ban_%s" % id
		action.toggle_mode = true
		action.custom_minimum_size.x = 60.0
		action.pressed.connect(_toggle.bind(id))
		line.add_child(action)
		_actions[id] = action
		_list.add_child(row)
	if _actions.is_empty():
		var blank := LobbyTheme.label("검색 결과가 없습니다" if not query.is_empty() else "밴한 항목이 없습니다", 14, LobbyTheme.INK_SOFT)
		blank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blank.custom_minimum_size.y = 46.0
		_list.add_child(blank)
	_scroll.scroll_vertical = 0
	_refresh_actions()


func _toggle(id: String) -> void:
	var bans: Array = (_rules.get(_kind, []) as Array).duplicate()
	if bans.has(id):
		bans.erase(id)
	else:
		bans.append(id)
	changed.emit(_kind, bans)


func _refresh_actions() -> void:
	var bans: Array = _rules.get(_kind, [])
	_count.text = L10n.tf("밴 %d개", [bans.size()])
	for id: String in _actions:
		var button := _actions[id]
		var banned := bans.has(id)
		button.set_pressed_no_signal(banned)
		button.text = "밴 해제" if banned else "밴"


static func _button(text: String, active: Color, height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", DARK)
	button.add_theme_color_override("font_hover_color", DARK)
	button.add_theme_color_override("font_focus_color", DARK)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", LobbyTheme.style(Color.WHITE, EDGE, 1, 10, 0, 8))
	button.add_theme_stylebox_override("hover", LobbyTheme.style(PALE, active, 2, 10, 0, 8))
	button.add_theme_stylebox_override("pressed", LobbyTheme.style(active, active.darkened(0.16), 2, 10, 0, 8))
	button.add_theme_stylebox_override("hover_pressed", LobbyTheme.style(active.lightened(0.08), active, 2, 10, 0, 8))
	button.add_theme_stylebox_override("focus", LobbyTheme.style(Color.TRANSPARENT, Color("b58227"), 2, 10))
	return button
