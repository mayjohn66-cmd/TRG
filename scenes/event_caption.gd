## 사건 자막 (화면 위쪽 가운데): "방금 무슨 일이 있었지?"를 연출이 끝난 뒤에도 읽을 수 있게 최근 사건 두 줄을 크게 남긴다.
## 액션 로그(_record)와 같은 순간(연출 큐 순서)에 들어온다. 새 줄은 위에 톡 튀어나오고, 이전 줄은 아래로 밀려 흐려진다.
## 각 줄은 읽을 시간(reading_seconds) + HOLD_SECONDS 동안 남았다가 사라진다. 중요한 사건(처치·함정·공격·방어·법전·순위)은 금테로 강조한다.
class_name EventCaption
extends VBoxContainer

const MAX_LINES: int = 2
## 읽을 시간 뒤에도 더 남겨 두는 시간(초).
const HOLD_SECONDS: float = 3.5
const FADE_SECONDS: float = 0.4
## 한국어를 소리 내지 않고 읽는 속도(글자/초)를 넉넉하게 잡은 값과 읽기 시작까지의 시간.
const CHARS_PER_SECOND: float = 14.0
const READ_START_SECONDS: float = 0.5
const READ_MIN_SECONDS: float = 0.8
const READ_MAX_SECONDS: float = 3.2
const WIDTH: float = 680.0
const COLOR_GOLD := Color("ffd43b")



func _init() -> void:
	name = "EventCaption"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	custom_minimum_size = Vector2(WIDTH, 0)


func _ready() -> void:
	set_process(get_child_count() > 0)  # 줄이 없으면 매 프레임 돌지 않는다 (push가 다시 켠다)


## 글(bbcode 태그는 뺀다)을 읽는 데 걸리는 시간(초).
static func reading_seconds(text: String) -> float:
	var plain: String = RegEx.create_from_string("\\[/?(color|b|i|u|font_size|outline_size|lb|rb)[^\\]]*\\]").sub(text, "", true)
	return clampf(READ_START_SECONDS + float(plain.strip_edges().length()) / CHARS_PER_SECOND, READ_MIN_SECONDS, READ_MAX_SECONDS)


## 한 줄을 올린다 (bbcode). important: 금테 + 조금 더 크게.
func push(bbcode: String, important: bool = false) -> void:
	var line := PanelContainer.new()
	line.name = "CaptionLine"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.1, 0.86)
	box.border_color = COLOR_GOLD if important else Color(1, 1, 1, 0.18)
	box.set_border_width_all(3 if important else 1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	line.add_theme_stylebox_override("panel", box)
	var label := RichTextLabel.new()
	label.name = "Text"
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", FontSizes.snap(21 if important else 18))
	label.add_theme_font_size_override("bold_font_size", FontSizes.snap(21 if important else 18))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_color_override("default_color", Color("f1f3f5"))
	label.text = bbcode
	line.add_child(label)
	add_child(line)
	move_child(line, 0)  # 새 줄이 맨 위
	var hold: float = reading_seconds(bbcode) + HOLD_SECONDS
	line.set_meta("expires", Time.get_ticks_msec() + int(hold * 1000.0))
	line.set_meta("important", important)
	# 이전 줄은 아래로 밀려 흐려진다, 넘치는 줄은 바로 치운다
	for index: int in range(1, get_child_count()):
		var old: Control = get_child(index) as Control
		if index >= MAX_LINES:
			old.queue_free()
		else:
			old.modulate = Color(1, 1, 1, 0.62)
			old.scale = Vector2(0.94, 0.94)
	line.pivot_offset = Vector2(WIDTH * 0.25, 18)
	line.scale = Vector2(1.08, 1.08)
	line.modulate.a = 0.0
	var tween: Tween = line.create_tween().set_parallel(true)
	tween.tween_property(line, "modulate:a", 1.0, 0.12)
	tween.tween_property(line, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_process(true)


## 남아 있는 줄의 글 (위 = 최신).
func lines() -> Array[String]:
	var out: Array[String] = []
	for child: Node in get_children():
		if child.is_queued_for_deletion():
			continue
		var label: RichTextLabel = child.get_node_or_null("Text") as RichTextLabel
		if label != null:
			out.append(label.text)
	return out


func clear() -> void:
	for child: Node in get_children():
		child.queue_free()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	var alive: int = 0
	for child: Node in get_children():
		var line: Control = child as Control
		if line == null or line.is_queued_for_deletion():
			continue
		alive += 1
		if bool(line.get_meta("fading", false)) or now < int(line.get_meta("expires", 0)):
			continue
		line.set_meta("fading", true)
		var tween: Tween = line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, FADE_SECONDS)
		tween.tween_callback(line.queue_free)
	if alive == 0:
		set_process(false)
