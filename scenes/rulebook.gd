# File: res://scenes/rulebook.gd
# Class: class_name Rulebook
# Role: 게임 규칙 책자. 펼침면(왼쪽·오른쪽 쪽) 8장을 넘겨 보는 보드게임 규칙서 모양의 팝업으로, 시작하기 / 한 턴 / 보드 읽기 / 잡기·완주 / 판정 도구 / 말과 필살기 / 생떼 카드 / 증강과 법전을 쉬운 말로 설명한다. 카드·교칙 문구는 코드의 실제 데이터를 읽어 와 규칙과 어긋나지 않는다
class_name Rulebook
extends Control

const PAPER: Color = Color("fff8e4")
const PAPER_EDGE: Color = Color("d9b97a")
const COVER: Color = Color("2f8f4e")
const COVER_DARK: Color = Color("1f6a38")
const INK: Color = Color("3a2f1f")
const ACCENT: Color = Color("c2457a")
const GREEN: Color = Color("2f8f4e")
const BLUE: Color = Color("2f7fb8")
const GOLD: Color = Color("c98a14")
const TAB_NAMES: Array[String] = ["시작", "한 턴", "보드", "잡기", "도구", "말", "카드", "법전"]

## 모든 쪽 번호(0부터)와 현재 펼침면.
var spread: int = 0
var _left_holder: Control = null
var _right_holder: Control = null
var _tabs: Array[Button] = []
var _page_label: Label = null
var _prev: Button = null
var _next: Button = null
var _chapter_title: Label = null


## 부모 위에 책자 팝업을 연다. 반환: 책자 노드 (이름은 Popup이라 설정·규칙 팝업과 같은 방식으로 찾는다).
static func open(parent: Control, start_spread: int = 0) -> Rulebook:
	var book := Rulebook.new()
	parent.add_child(book)
	book.show_spread(start_spread)
	return book


func _init() -> void:
	name = "Popup"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0.08, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			close())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var cover := PanelContainer.new()
	cover.custom_minimum_size = Vector2(1140, 640)
	cover.add_theme_stylebox_override("panel", _box(COVER, COVER_DARK, 6, 30, 22, 14, Color(0, 0, 0, 0.5)))
	center.add_child(cover)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	cover.add_child(column)
	column.add_child(_build_header())
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 0)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(pages)
	_left_holder = _page_frame(pages, true)
	var spine := ColorRect.new()
	spine.color = Color(0.5, 0.36, 0.16, 0.55)
	spine.custom_minimum_size = Vector2(4, 0)
	pages.add_child(spine)
	_right_holder = _page_frame(pages, false)
	column.add_child(_build_footer())


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_RIGHT: show_spread(spread + 1)
		KEY_LEFT: show_spread(spread - 1)
		KEY_ESCAPE: close()
		_: return
	get_viewport().set_input_as_handled()


func close() -> void:
	queue_free()


func spread_count() -> int:
	return TAB_NAMES.size()


# ---------------------------------------------------------------------------
# 틀
# ---------------------------------------------------------------------------

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "에르핀의 억지 레이스 · 규칙 책자"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("fff3bf"))
	title.add_theme_color_override("font_outline_color", COVER_DARK)
	title.add_theme_constant_override("outline_size", 6)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	for index: int in TAB_NAMES.size():
		var tab := Button.new()
		tab.name = "Tab%d" % index
		tab.text = TAB_NAMES[index]
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(70, 34)
		tab.add_theme_font_size_override("font_size", 15)
		tab.pressed.connect(show_spread.bind(index))
		row.add_child(tab)
		_tabs.append(tab)
	var close_button := Button.new()
	close_button.name = "CloseBook"
	close_button.text = "닫기"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(76, 34)
	close_button.add_theme_font_size_override("font_size", 15)
	close_button.add_theme_color_override("font_color", Color.WHITE)
	close_button.add_theme_stylebox_override("normal", _box(Color("d6336c"), Color("fff3bf"), 2, 12, 0, 4))
	close_button.add_theme_stylebox_override("hover", _box(Color("e64980"), Color("fff3bf"), 2, 12, 0, 4))
	close_button.add_theme_stylebox_override("pressed", _box(Color("a61e4d"), Color("fff3bf"), 2, 12, 0, 4))
	close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_button.pressed.connect(close)
	row.add_child(close_button)
	return row


func _page_frame(parent: Control, is_left: bool) -> Control:
	var page := PanelContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = _box(PAPER, PAPER_EDGE, 3, 8, 0, 14)
	if is_left:
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_right = 0
	else:
		style.corner_radius_top_left = 0
		style.corner_radius_bottom_left = 0
	page.add_theme_stylebox_override("panel", style)
	parent.add_child(page)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("separation", 8)
	scroll.add_child(holder)
	return holder


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_prev = _nav_button("이전 쪽")
	_prev.name = "PrevPage"
	_prev.pressed.connect(func() -> void: show_spread(spread - 1))
	row.add_child(_prev)
	_page_label = Label.new()
	_page_label.add_theme_font_size_override("font_size", 16)
	_page_label.add_theme_color_override("font_color", Color("fff3bf"))
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_page_label)
	_next = _nav_button("다음 쪽")
	_next.name = "NextPage"
	_next.pressed.connect(func() -> void: show_spread(spread + 1))
	row.add_child(_next)
	return row


func _nav_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(130, 38)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", Color(INK, 0.35))
	button.add_theme_stylebox_override("normal", _box(Color("ffe9b8"), PAPER_EDGE, 3, 14, 0, 6))
	button.add_theme_stylebox_override("hover", _box(Color("fff3d1"), PAPER_EDGE, 3, 14, 0, 6))
	button.add_theme_stylebox_override("pressed", _box(Color("f0d9a0"), PAPER_EDGE, 3, 14, 0, 6))
	button.add_theme_stylebox_override("disabled", _box(Color("d9d2bd"), Color("b5ad92"), 3, 14, 0, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


static func _box(bg: Color, border: Color, border_width: int, radius: int, shadow: int, margin: int, shadow_color: Color = Color(0, 0, 0, 0.2)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.shadow_color = shadow_color
	box.shadow_size = shadow
	box.set_content_margin_all(margin)
	return box


## 펼침면을 바꾼다 (범위 밖이면 끝으로 맞춘다).
func show_spread(index: int) -> void:
	spread = clampi(index, 0, spread_count() - 1)
	for holder: Control in [_left_holder, _right_holder]:
		for child: Node in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	var content: Dictionary = _chapter(spread)
	_fill(_left_holder, content["title"], content["left"], spread * 2 + 1)
	_fill(_right_holder, "", content["right"], spread * 2 + 2)
	for index2: int in _tabs.size():
		var active: bool = index2 == spread
		_tabs[index2].add_theme_color_override("font_color", INK if active else Color.WHITE)
		_tabs[index2].add_theme_stylebox_override("normal", _box(Color("fff3bf") if active else COVER_DARK, Color("fff3bf"), 2, 12, 0, 4))
		_tabs[index2].add_theme_stylebox_override("hover", _box(Color("fff8d6") if active else Color("2a8a4a"), Color("fff3bf"), 2, 12, 0, 4))
		_tabs[index2].add_theme_stylebox_override("pressed", _box(Color("ffe48a"), Color("fff3bf"), 2, 12, 0, 4))
		_tabs[index2].add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_page_label.text = "%d - %d쪽  /  전체 %d쪽" % [spread * 2 + 1, spread * 2 + 2, spread_count() * 2]
	_prev.disabled = spread == 0
	_next.disabled = spread == spread_count() - 1


func _fill(holder: Control, title: String, blocks: Array, page_number: int) -> void:
	if title != "":
		var heading := Label.new()
		heading.text = title
		heading.add_theme_font_size_override("font_size", 30)
		heading.add_theme_color_override("font_color", COVER_DARK)
		holder.add_child(heading)
		var rule := ColorRect.new()
		rule.color = Color(PAPER_EDGE, 0.9)
		rule.custom_minimum_size = Vector2(0, 3)
		holder.add_child(rule)
	for block: Variant in blocks:
		holder.add_child(block as Control)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(fill)
	var number := Label.new()
	number.text = "- %d -" % page_number
	number.add_theme_font_size_override("font_size", 14)
	number.add_theme_color_override("font_color", Color(INK, 0.55))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(number)


# ---------------------------------------------------------------------------
# 글 부품
# ---------------------------------------------------------------------------

## BBCode 문단. [b]굵게[/b] [color=#c2457a]강조[/color]
func _rich(text: String, size_px: int = 19) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size", size_px)
	label.add_theme_font_size_override("bold_font_size", size_px)
	label.add_theme_color_override("default_color", INK)
	label.add_theme_constant_override("line_separation", 3)
	label.custom_minimum_size = Vector2(440, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	return label


## 색 띠가 붙은 작은 소제목.
func _heading(text: String, color: Color = ACCENT) -> Control:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	return label


## 노란 말풍선 팁 상자.
func _tip(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("fff0b8"), Color("e0b23a"), 2, 12, 0, 10))
	var label: RichTextLabel = _rich("[b]꿀팁[/b]  " + text, 18)
	panel.add_child(label)
	return panel


## 번호 동그라미 + 설명 한 줄 (한 턴 순서 등).
func _step(number: int, title: String, body: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var badge := Label.new()
	badge.text = str(number)
	badge.add_theme_font_size_override("font_size", 26)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.custom_minimum_size = Vector2(46, 46)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", _box(color, Color.WHITE, 3, 23, 0, 0))
	row.add_child(badge)
	var text: RichTextLabel = _rich("[b][color=#%s]%s[/color][/b]\n%s" % [color.to_html(false), title, body], 19)
	text.custom_minimum_size = Vector2(380, 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	return row


# ---------------------------------------------------------------------------
# 내용 (펼침면 8장)
# ---------------------------------------------------------------------------

func _chapter(index: int) -> Dictionary:
	match index:
		0: return _ch_start()
		1: return _ch_turn()
		2: return _ch_board()
		3: return _ch_capture()
		4: return _ch_tools()
		5: return _ch_pawns()
		6: return _ch_cards()
	return _ch_laws()


func _ch_start() -> Dictionary:
	return {
		"title": "시작하기",
		"left": [
			_rich("주사위만 굴리는 게임이 아니에요. [b]윷, 룰렛, 화투, 마작[/b]까지 굴려 가며 둘에서 넷이 한 바퀴를 도는 [color=#c2457a]억지 레이스[/color]예요!"),
			_heading("이기는 법"),
			_rich("내 말 [b]4개를 전부[/b] 결승선(0번 칸)에 먼저 넣으면 승리예요. 한 개라도 남으면 계속 달려야 해요."),
			_heading("준비물"),
			_rich("· 내 말 4개 (처음엔 모두 출발선에 서 있어요)\n· 생떼 카드 손패 (최대 7장, 빵집이나 증강으로 얻어요)\n· 가운데 법전 4칸 (모두에게 적용되는 규칙 카드가 걸려요)"),
			_tip("처음이라면 [b]놀이터[/b]에서 컴퓨터와 먼저 한 판 해 보세요. 몇 판이면 금방 익숙해져요."),
		],
		"right": [
			_heading("이 게임의 재미 세 가지", GREEN),
			_step(1, "말마다 능력이 달라요", "체스 폰은 퀸으로 승급하고, 장기 포는 말을 넘어 달려요. 말마다 한 판에 한 번 쓰는 필살기도 있어요.", ACCENT),
			_step(2, "굴리는 도구가 바뀌어요", "증강으로 주사위를 윷, 룰렛, 홀덤, 슬롯… 으로 바꿔요. 도구마다 규칙이 달라요.", BLUE),
			_step(3, "카드와 법전으로 판을 뒤집어요", "함정을 깔고, 말을 뒤로 밀고, 가운데 법전으로 모두의 규칙을 바꿔요.", GOLD),
			_rich("[b]주의![/b] 눈금은 항상 공정해요. 파워 게이지는 연출일 뿐이라서 세게 눌러도 큰 숫자가 더 잘 나오진 않아요."),
		],
	}


func _ch_turn() -> Dictionary:
	return {
		"title": "한 턴은 이렇게",
		"left": [
			_step(1, "카드 한 장 (안 써도 돼요)", "굴리기 전에, 카드를 [b]보드판 위로 끌어다 놓으면[/b] 발동해요. 한 턴에 한 장까지예요.", GOLD),
			_step(2, "굴리기", "[b]굴리기[/b] 버튼을 꾹 눌러 파워를 모으고 손을 떼요. (R이나 스페이스 키도 돼요)", GREEN),
			_step(3, "말 고르기", "나온 눈금만큼 움직일 말을 골라요. 아래 말 카드나 보드 위의 말을 누르면 돼요.", BLUE),
			_step(4, "정산", "도착한 칸의 효과가 터져요. 피해를 입었다면 [b]바이츠 더 더스트[/b] 카드로 이번 턴을 되돌릴 수 있어요.", ACCENT),
		],
		"right": [
			_heading("알아 두면 편해요", GREEN),
			_rich("· [b]재굴림[/b]: 윷말은 상대를 잡거나 4·5가 나오면 한 번 더 굴려요.\n· [b]빽도[/b]: 눈금이 마이너스면 뒤로 가요. 출발선에서 뒤로 가면 23번 칸으로 가요.\n· [b]증강[/b]: 1, 4, 7라운드처럼 [b]3라운드마다[/b] 모두가 3장 중 하나를 골라요.\n· [b]제한 시간[/b]: 온라인에서는 단계마다 시간이 있고, 지나면 알아서 진행돼요."),
			_tip("카드는 [b]굴리기 전에만[/b] 낼 수 있어요. 눈금을 보고 고민하고 싶다면 이번 턴 카드는 아껴 두세요."),
			_heading("컴퓨터(AI) 차례", GREEN),
			_rich("컴퓨터는 잠깐 생각하는 척(?)하다가 움직여요. 느리다 싶으면 설정에서 [b]연출 속도[/b]를 바꿔 보세요."),
		],
	}


func _ch_board() -> Dictionary:
	var board := MiniBoard.new()
	board.custom_minimum_size = Vector2(400, 400)
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return {
		"title": "보드 읽기",
		"left": [
			_rich("보드는 [b]24칸짜리 사각 한 바퀴[/b]예요. 우하단 0번에서 출발해 반시계로 돌고, 한 바퀴를 다 돌면 다시 0번이 결승선이에요."),
			_heading("눈여겨볼 칸"),
			_rich("[color=#2f8f4e][b]6번, 18번 점프 코너[/b][/color]  딱 멈추면 6번은 10번으로, 18번은 21번으로 폴짝!\n[color=#c98a14][b]12번 반환점[/b][/color]  여기를 지나면 체스 폰이 퀸으로, 쇼기 말이 승급해요.\n[color=#d9822b][b]빵집 4·10·14·20번[/b][/color]  멈추면 생떼 카드 한 장!\n[color=#8e4aa8][b]옷장 9번, 16번[/b][/color]  딱 멈추면 9번은 16번으로, 16번은 20번으로 순간이동!"),
			_tip("점프와 옷장은 [b]딱 멈출 때만[/b] 작동해요. 그냥 지나가면 아무 일도 없어요. 눈금을 잘 맞춰 보세요."),
		],
		"right": [
			board,
			_rich("가운데는 비어 있어요. 굴리기 버튼과 주사위 연출이 이 빈 무대에서 펼쳐져요.", 15),
		],
	}


func _ch_capture() -> Dictionary:
	return {
		"title": "잡기 · 업기 · 완주",
		"left": [
			_heading("잡기"),
			_rich("적 말이 서 있는 칸에 [b]멈추면 그 말은 출발선으로[/b] 돌아가요. [b]출발선(0번)은 안전[/b]해서 잡을 수 없고, 내 말끼리는 잡지 않아요."),
			_heading("업기 (윷말만)"),
			_rich("윷말끼리 같은 칸에서 만나면 [b]하나로 합쳐[/b] 한꺼번에 움직여요. 든든하지만 잡히면 [color=#d6336c]같이 잡혀요[/color]! 합칠지 말지는 고를 수 있어요."),
			_heading("완주"),
			_rich("출발한 말이 0번에 닿으면 완주예요. 눈금이 남아도 괜찮아요. (법전 [b]결승선 문턱[/b]이 걸려 있으면 남은 만큼 튕겨 나와요.) 말 4개가 모두 완주하면 승리!"),
		],
		"right": [
			_heading("이럴 땐 어떻게 되나요?", GREEN),
			_rich("[b]Q. 내 말이 앞에 있는데 적이 뒤에서 쫓아와요![/b]\n나중에 도착해서 [b]멈춘 쪽이 잡아요[/b]. 스쳐 지나가기만 하면 안 잡혀요.\n\n[b]Q. 함정은 어떻게 보여요?[/b]\n컴퓨터 대전에서는 상대가 깐 함정이 [b]뒷면[/b]으로만 보여요. 밟아 보기 전엔 몰라요. 대신 내 함정은 내가 보여요.\n\n[b]Q. 적이 막고 있는데 지나갈 수 있어요?[/b]\n네! 멈추지만 않으면 지나가요. (장기 포는 말을 넘으면 보너스를 받아요.)\n\n[b]Q. 무인도에 갇혔어요![/b]\n[b]짝수 눈금[/b]이 나오면 탈출해요. 홀수면 제자리예요."),
			_tip("잡힌 말은 [b]출발선에서 처음부터[/b]예요. 완주 직전에 잡히면 억울하니 선두 말은 적 앞을 조심하세요."),
		],
	}


func _ch_tools() -> Dictionary:
	return {
		"title": "굴리는 도구",
		"left": [
			_rich("처음엔 [b]기본 주사위[/b]로 시작해요. 증강으로 아래 도구 중 하나로 바꿀 수 있고, 도구마다 규칙이 달라요. 게임 중 오른쪽 카드에 규칙표가 나와요."),
			_rich("[b]주사위[/b]  1~6칸, 공정한 기본 도구\n[b]윷[/b]  도 1 · 개 2 · 걸 3 · 윷 4 · 모 5, 빽도는 -1\n[b]인생게임 룰렛[/b]  원판을 돌려 1~10칸. 7이 나오면 7칸에 한 번 더!\n[b]홀덤[/b]  카드 족보에 따라 1~15칸 (플러시 이상은 15칸)\n[b]친치로[/b]  4~6칸의 고눈금! 대신 [color=#d6336c]삐끗하면 -6칸[/color]"),
		],
		"right": [
			_rich("[b]777 슬롯[/b]  릴 3개. 꽝 1칸 · 두 개 일치 4칸 · 세 개 일치 8칸 · 777은 20칸!\n[b]러시안 룰렛[/b]  당길수록 칸이 쌓이지만, 실탄이 나오면 [color=#d6336c]전부 증발[/color]하고 턴 종료. 언제 멈출지는 내 선택!\n[b]화투[/b]  패 2장의 족보로 0~8칸. 망통이면 0칸에 턴 종료\n[b]마작[/b]  패를 뽑아 족보로 칸 수가 정해져요\n[b]타로[/b]  카드 5장 중 한 장. 장마다 효과가 달라요"),
			_tip("러시안 룰렛은 [b]멈추기[/b] 버튼이 생명이에요. 욕심내다 한 방에 날아가지 마세요."),
		],
	}


func _ch_pawns() -> Dictionary:
	return {
		"title": "말과 필살기",
		"left": [
			_rich("증강으로 기본 말을 여섯 계열 중 하나로 [b]진화[/b]시켜요. 보드 위 말에는 한 글자 라벨이 붙고, 마우스를 올리면 능력이 나와요."),
			_rich("[b][color=#c2457a]윷말[/color][/b]  잡거나 4·5가 나오면 한 번 더. 만나면 업기\n[b][color=#2f7fb8]체스[/color][/b]  폰은 12번 이상에서 퀸으로 승급 · 나이트는 함정과 말을 뛰어넘기 · 비숍은 코너를 스치면 +2칸 · 룩은 [b]필살기 캐슬링[/b](아군과 위치 교환)\n[b][color=#c98a14]장기[/color][/b]  포는 길에 말이 있으면 +3칸 · 차는 [b]필살기 돌진[/b](선두 적을 잡으러 직진) · 마는 앞 칸이 비면 +2칸 · 상은 +3칸"),
		],
		"right": [
			_rich("[b][color=#2f8f4e]모노폴리[/color][/b]  미니카는 도착 칸에 호텔을 짓고 · 비행기는 옷장에서 더 멀리 날아가고 [b]필살기 직항 워프[/b] · 증기선은 첫 적 함정을 부수고 · 강아지는 빵집을 스치기만 해도 카드!\n[b]바둑[/b]  흑돌은 [b]필살기 알까기[/b](손가락으로 튕겨 직선의 적을 탈락) · 백돌은 잡히지 않고 같은 칸 아군도 지켜요(눈금 -1)\n[b][color=#8e4aa8]쇼기[/color][/b]  12번 이상을 지나면 [b]승급[/b](이동 +1칸) · 보병은 [b]필살기 모치고마 낙하[/b](대기 중인 말을 바로 옆에 투입) · 비차 +2칸 · 각행은 코너 +2칸 · 계마는 첫 2칸 함정을 무시"),
			_tip("필살기는 말마다 [b]한 판에 한 번[/b]! 내 프로필 카드에서 눌러요. 굴리기 전에만 쓸 수 있고, 잡혀서 출발선으로 가도 되살아나지 않아요."),
		],
	}


func _card_line(card_id: StringName) -> String:
	var card: BaseCard = CardRegistry.get_card(card_id)
	var summary: String = str(MainBoard.CARD_SUMMARIES.get(card_id, "")).replace("\n", " ")
	return "[b]%s[/b]  %s" % [card.display_name, summary]


func _ch_cards() -> Dictionary:
	var instant: Array[String] = []
	for card_id: StringName in [&"ACT_01", &"ACT_02", &"ACT_03", &"ACT_04", &"ACT_05", &"ACT_06", &"ACT_07", &"ACT_08", &"ACT_09"]:
		instant.append(_card_line(card_id))
	var placed: Array[String] = []
	for card_id: StringName in [&"TRP_01", &"TRP_02", &"TRP_03", &"TRP_04", &"TRP_05", &"SUM_01", &"SUM_02"]:
		placed.append(_card_line(card_id))
	return {
		"title": "생떼 카드",
		"left": [
			_rich("빵집이나 증강에서 얻는 카드예요. 손패는 [b]최대 7장[/b]이고, 카드를 보드판으로 끌어다 놓아 써요."),
			_heading("바로 터지는 카드"),
			_rich("\n".join(instant), 17),
		],
		"right": [
			_heading("깔아 두는 카드 (함정 · 소환)", GREEN),
			_rich("놓은 뒤 [b]칸을 골라[/b] 설치해요. 함정은 상대에게 뒷면으로 보여요.\n" + "\n".join(placed), 17),
			_tip("가위바위보 결투 카드는 [b]상대 프로필이나 말 위에[/b] 놓으면 그 상대와 바로 붙어요. 이기면 상대 말을 직접 골라 2칸 밀어내고, 밀려난 칸의 함정까지 터져요!"),
		],
	}


func _ch_laws() -> Dictionary:
	var laws: Array[String] = []
	for index: int in 8:
		var law: LawResource = LawRegistry.create("LAW_%02d" % (index + 1))
		if law != null:
			laws.append("[b]%s[/b]  %s" % [law.law_name, law.description])
	return {
		"title": "증강과 법전",
		"left": [
			_heading("증강 (3라운드마다)", GREEN),
			_rich("1, 4, 7라운드처럼 [b]3라운드마다[/b] 모두가 3장 중 하나를 골라요. 마음에 안 들면 카드마다 [b]한 번 다시 뽑기[/b]가 있어요.\n· [b]기물 지급[/b]  말 하나를 새 기물로 진화\n· [b]도구 교체[/b]  굴리는 도구 바꾸기\n· [b]교칙 제정[/b]  가운데 법전에 새 규칙 걸기\n· [b]카드 패키지[/b]  생떼 카드 여러 장"),
			_heading("가운데 법전 (4칸)"),
			_rich("새 교칙이 들어오면 [b]가장 오래된 교칙이 밀려나요[/b]. 모두에게 적용되니, 나에게 유리한 교칙을 밀어내기 전에 써먹어 보세요. [b]이의 있음![/b] 카드로 하나를 지울 수도 있어요."),
		],
		"right": [
			_heading("교칙 8종"),
			_rich("\n".join(laws), 18),
			_tip("[b]과속 단속[/b]이 걸려 있으면 큰 눈금이 의미 없어져요. 이럴 땐 칸 수보다 [b]점프 코너와 빵집[/b]을 노려 보세요."),
		],
	}


# ---------------------------------------------------------------------------
# 미니 보드 그림 (보드 읽기 쪽)
# ---------------------------------------------------------------------------

## 24칸 사각 트랙을 작게 그리고 점프·옷장 이동을 화살표로 보여 준다.
class MiniBoard extends Control:
	const CELL: float = 34.0
	const CORNER: float = 44.0

	func _tile_pos(index: int) -> Vector2:
		var pad: float = 34.0
		var span: float = size.x - pad * 2.0
		return Vector2(pad, pad) + BoardLayout.tile_norm(index) * span

	func _draw() -> void:
		var paper := StyleBoxFlat.new()
		paper.bg_color = Color("e8f5c8")
		paper.border_color = Color("b9d48a")
		paper.set_border_width_all(3)
		paper.set_corner_radius_all(22)
		draw_style_box(paper, Rect2(Vector2.ZERO, size))
		var font: Font = get_theme_default_font()
		# 이동선 (타일 아래)
		_arc(6, 10, Color("2f8f4e"))
		_arc(18, 21, Color("2f8f4e"))
		_dashed(9, 16, Color("8e4aa8"))
		_dashed(16, 20, Color("8e4aa8"))
		for index: int in GameEnums.TILE_COUNT:
			var center: Vector2 = _tile_pos(index)
			var corner: bool = GameEnums.CORNER_TILES.has(index)
			var side: float = CORNER if corner else CELL
			var fill: Color = Color("fffdf0")
			var edge: Color = Color("b9a56a")
			if GameEnums.BAKERY_TILES.has(index):
				fill = Color("ffd98a")
				edge = Color("d9822b")
			elif GameEnums.PORTAL_TILES.has(index):
				fill = Color("e6d2f0")
				edge = Color("8e4aa8")
			elif index == 0:
				fill = Color("86d94f")
				edge = Color("2f8f4e")
			elif index == GameEnums.HALFWAY_TILE:
				fill = Color("ffe48a")
				edge = Color("c98a14")
			elif corner:
				fill = Color("b6ea8c")
				edge = Color("2f8f4e")
			var box := StyleBoxFlat.new()
			box.bg_color = fill
			box.border_color = edge
			box.set_border_width_all(3)
			box.set_corner_radius_all(9 if not corner else 12)
			draw_style_box(box, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)))
			var label: String = str(index)
			if index == 0:
				label = "출발"
			var label_size: int = 13 if not corner else 15
			var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
			draw_string(font, center + Vector2(-width / 2.0, label_size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color("3a2f1f"))
		# 안쪽 범례
		var legend: Array = [[Color("86d94f"), "출발 · 결승"], [Color("b6ea8c"), "점프 코너 (6 → 10, 18 → 21)"], [Color("ffe48a"), "반환점 (승급 기준)"], [Color("ffd98a"), "빵집 (카드 1장)"], [Color("e6d2f0"), "옷장 (9 → 16, 16 → 20)"]]
		var origin := Vector2(92, 118)
		for index: int in legend.size():
			var spot: Vector2 = origin + Vector2(0, index * 30.0)
			var swatch := StyleBoxFlat.new()
			swatch.bg_color = legend[index][0]
			swatch.border_color = Color("8a7a45")
			swatch.set_border_width_all(2)
			swatch.set_corner_radius_all(5)
			draw_style_box(swatch, Rect2(spot, Vector2(20, 20)))
			draw_string(font, spot + Vector2(28, 16), legend[index][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("3a2f1f"))

	func _arc(from_tile: int, to_tile: int, color: Color) -> void:
		var a: Vector2 = _tile_pos(from_tile)
		var b: Vector2 = _tile_pos(to_tile)
		var mid: Vector2 = (a + b) / 2.0 + (size / 2.0 - (a + b) / 2.0).normalized() * 34.0
		var points := PackedVector2Array()
		for step: int in 17:
			var t: float = float(step) / 16.0
			points.append((1.0 - t) * (1.0 - t) * a + 2.0 * (1.0 - t) * t * mid + t * t * b)
		draw_polyline(points, color, 4.0, true)
		var tip: Vector2 = points[16]
		var dir: Vector2 = (points[16] - points[14]).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip + dir * 6.0, tip - dir * 8.0 + side * 7.0, tip - dir * 8.0 - side * 7.0]), color)

	func _dashed(from_tile: int, to_tile: int, color: Color) -> void:
		var a: Vector2 = _tile_pos(from_tile)
		var b: Vector2 = _tile_pos(to_tile)
		draw_dashed_line(a, b, color, 3.5, 9.0, true)
		var dir: Vector2 = (b - a).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([b - dir * 22.0 + dir * 8.0, b - dir * 30.0 + side * 7.0, b - dir * 30.0 - side * 7.0]), color)
