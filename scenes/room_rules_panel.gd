# File: res://scenes/room_rules_panel.gd
# Class: class_name RoomRulesPanel
# Role: [방 규칙 설정] 창. 싱글(놀이터) 커스텀과 친선 줘팸터 방장이 함께 쓴다. 4가지 규칙을 버튼으로 고르고, 고른 값은
#       GameSession.set_rule로 브라우저 프로필에 남는다 (바꾸지 않은 항목은 난이도 기본값). 온라인은 방장이 판을 시작할 때 모두에게 보낸다.
class_name RoomRulesPanel
extends Control

signal closed()

## [키, 제목, 설명, [[값, 버튼 글], ...]]
const ROWS: Array = [
	["trap_reveal", "함정 카드 정체", "공개: 누가 설치한 함정이든 아이콘과 효과가 보입니다. 비공개: 상대가 설치한 함정은 밟거나 해체하기 전까지 [? 수상한 함정]으로만 보입니다.",
		[[true, "공개 [기본]"], [false, "비공개 [심리전]"]]],
	["super_freq", "초증강 등장 빈도", "증강 드래프트에 초증강이 나오는 확률입니다.",
		[[1, "기본"], [3, "대축제 (확률 3배)"], [0, "끄기"]]],
	["laws", "특수 승리 법전", "끄면 드래프트에 법전이 나오지 않고, 말 4개 완주로만 순위를 가립니다.",
		[[true, "켜기 [기본]"], [false, "끄기 [완주 승부만]"]]],
	["speed", "게임 속도", "스피드전: 템포 업이 4·8·12라운드에 오르고 리벤지 부스터가 +2칸 커져 10~12라운드 안에 결판이 납니다.",
		[["normal", "기본 템포"], ["speed", "스피드전"]]],
]

var _buttons: Dictionary = {}  # 키 -> [[값, 버튼], ...]
## 친선전 방장 화면에서 열었다: 난이도와 상관없는 방 규칙(GameSession.room_rules)을 보여 준다.
var room_mode: bool = false


## 화면 전체를 덮는 창을 만들어 parent에 붙인다.
static func open(parent: Node, for_room: bool = false) -> RoomRulesPanel:
	var panel := RoomRulesPanel.new()
	panel.name = "RoomRulesPanel"
	panel.room_mode = for_room
	parent.add_child(panel)
	return panel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not get_parent() is Control:
		size = get_viewport_rect().size  # 창(Window)에 바로 붙으면 앵커가 화면을 따르지 않는다
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", LobbyTheme.style(LobbyTheme.MINT, LobbyTheme.TEAL, 4, 26, 8, 22))
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(760, 0)
	card.add_child(column)
	var title := LobbyTheme.label("방 규칙 설정", 30, LobbyTheme.TEAL)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	for row: Array in ROWS:
		column.add_child(_make_row(row))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(footer)
	var reset := LobbyTheme.small_button("기본값으로", _on_reset, &"gray", 18)
	reset.name = "ResetRules"
	reset.custom_minimum_size = Vector2(180, 44)
	footer.add_child(reset)
	var ok := LobbyTheme.cream_button("확인", close, 24)
	ok.name = "CloseRules"
	ok.custom_minimum_size = Vector2(220, 56)
	footer.add_child(ok)
	_refresh()


func _make_row(row: Array) -> Control:
	var key: String = row[0]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.tooltip_text = row[2]
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var head := LobbyTheme.label(row[1], 20, LobbyTheme.INK)
	head.tooltip_text = row[2]
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(head)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	box.add_child(choices)
	var list: Array = []
	for option: Array in row[3]:
		var button := LobbyTheme.small_button(option[1], _on_pick.bind(key, option[0]), &"teal", 17)
		button.name = "Rule_%s_%s" % [key, str(option[0])]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 42)
		button.tooltip_text = row[2]
		button.clip_text = true
		choices.add_child(button)
		list.append([option[0], button])
	_buttons[key] = list
	var note := LobbyTheme.label(row[2], 13, LobbyTheme.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(740, 0)
	box.add_child(note)
	return box


func _on_pick(key: String, value: Variant) -> void:
	GameSession.set_rule(key, value)
	_refresh()


func _on_reset() -> void:
	GameSession.reset_rules()
	_refresh()


## 지금 규칙을 버튼에 표시한다 (고른 값은 진하게, 나머지는 흐리게).
func _refresh() -> void:
	var rules: Dictionary = GameSession.room_rules() if room_mode else GameSession.match_rules()
	for key: String in _buttons.keys():
		for pair: Array in _buttons[key]:
			var chosen: bool = str(rules.get(key)) == str(pair[0])
			var button: Button = pair[1]
			button.set_pressed_no_signal(chosen)
			button.modulate = Color.WHITE if chosen else Color(1, 1, 1, 0.55)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
