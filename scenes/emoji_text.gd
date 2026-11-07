# File: res://scenes/emoji_text.gd
# Class: class_name EmojiText
# Role: 글 속 이모지를 글꼴이 아니라 그림(assets/ui/trickcal/emoji/*.png)으로 보여 준다. 웹·모바일에서 이모지 글꼴이 깨지는 것을 피한다.
#       글에는 {e:이름} 표식을 넣는다 (예: "{e:target} 승리 조건: ..."). build()가 줄마다 [그림 + 글자]로 쌓은 Control을 돌려주고,
#       로그·번역 비교처럼 글자만 필요한 곳은 strip()으로 표식을 뗀다. 없는 이름이면 표식만 조용히 뺀다.
class_name EmojiText
extends RefCounted

const DIR: String = "res://assets/ui/trickcal/emoji/"
const NAMES: Array[String] = ["target", "fire"]
const MARKER_PATTERN: String = "\\{e:([a-z_]+)\\}"


## 표식이 들어 있는가.
static func has_marker(text: String) -> bool:
	return text.contains("{e:")


## 표식을 뗀 글자 (그림 자리는 비운다).
static func strip(text: String) -> String:
	var matcher: RegEx = RegEx.create_from_string(MARKER_PATTERN)
	return matcher.sub(text, "", true).replace("  ", " ").strip_edges()


static func texture(name: String) -> Texture2D:
	var path: String = DIR + name + ".png"
	return load(path) as Texture2D if NAMES.has(name) and ResourceLoader.exists(path) else null


## 줄마다 [그림][글자] 가로줄을 세로로 쌓는다. outline_color가 있으면 글자에 외곽선을 입힌다 (도장 알림용).
## max_width가 0보다 크면 한 줄이 그 폭을 넘을 때 글자·그림 크기를 줄여 맞춘다.
static func build(text: String, size_px: int, color: Color, outline_px: int = 0, outline_color: Color = Color.BLACK, max_width: float = 0.0) -> Control:
	var matcher: RegEx = RegEx.create_from_string(MARKER_PATTERN)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for line: String in text.split("\n"):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line_px: int = size_px
		if max_width > 0.0:
			var font: Font = ThemeDB.fallback_font
			var plain: String = matcher.sub(line, "", true).strip_edges()
			var icons: int = matcher.search_all(line).size()
			var width: float = font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x + icons * size_px * 1.3 + outline_px * 2.0
			if width > max_width:
				line_px = maxi(int(size_px * max_width / width), 12)
		var cursor: int = 0
		var pieces: Array = []
		for found: RegExMatch in matcher.search_all(line):
			pieces.append(line.substr(cursor, found.get_start() - cursor))
			pieces.append(texture(found.get_string(1)))
			cursor = found.get_end()
		pieces.append(line.substr(cursor))
		for piece: Variant in pieces:
			if piece is Texture2D:
				var icon := TextureRect.new()
				icon.texture = piece
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(line_px * 1.15, line_px * 1.15)
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(icon)
			elif str(piece).strip_edges() != "":
				var label := Label.new()
				label.text = str(piece).strip_edges()
				label.add_theme_font_size_override("font_size", line_px)
				label.add_theme_color_override("font_color", color)
				if outline_px > 0:
					label.add_theme_color_override("font_outline_color", outline_color)
					label.add_theme_constant_override("outline_size", outline_px)
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(label)
		column.add_child(row)
	return column
