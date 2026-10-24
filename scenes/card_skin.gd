## Card art stays text-free; all names and rules are live game data.
class_name CardSkin
extends RefCounted

const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const ART_SHADER: Shader = preload("res://scenes/card_art.gdshader")
const INK: Color = Color("333333")
const PANEL: Color = Color("e9f5cf")
const HEADER: Color = Color("cde793")
const GREEN: Color = Color("5da530")
const FILLS: Dictionary = {
	GameEnums.CardCategory.INSTANT: Color("d98b2b"),
	GameEnums.CardCategory.TRAP: Color("8e4aa8"),
	GameEnums.CardCategory.SUMMON: Color("2f9a85"),
	GameEnums.CardCategory.COUNTER: Color("4c6ef5"),
}
const EDGES: Dictionary = {
	GameEnums.CardCategory.INSTANT: Color("89551a"),
	GameEnums.CardCategory.TRAP: Color("58366b"),
	GameEnums.CardCategory.SUMMON: Color("205e54"),
	GameEnums.CardCategory.COUNTER: Color("2b3f9e"),
}

const WARNING_RED: Color = Color("e03131")
## 설치자·사용자 본인의 말까지 잡거나 멈출 수 있는 카드: 카드 왼쪽 위에 경고 아이콘을 띄우고 상세 설명에 이 문구를 적는다.
const SELF_RISK: Dictionary = {
	&"TRP_03": "폭발 반경 안에 있으면 내 말도 출발선으로 날아갑니다",
	&"TRP_05": "내 말이 밟아도 멈추고, 연쇄로 터진 지뢰에 내 말도 휘말립니다",
	&"ACT_09": "데스매치에서 지면 내 선두 말이 출발선으로 날아갑니다",
}


## 빨간 삼각 경고 아이콘 (흰 안쪽 테두리 + 느낌표). 그림 파일 없이 크기에 맞춰 그린다.
class WarningIcon extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		var o: Vector2 = (size - Vector2(s, s)) / 2.0
		var outer := PackedVector2Array([o + Vector2(s * 0.5, s * 0.04), o + Vector2(s * 0.98, s * 0.92), o + Vector2(s * 0.02, s * 0.92)])
		draw_colored_polygon(outer, WARNING_RED)
		var ring := PackedVector2Array([o + Vector2(s * 0.5, s * 0.04), o + Vector2(s * 0.98, s * 0.92), o + Vector2(s * 0.02, s * 0.92), o + Vector2(s * 0.5, s * 0.04)])
		draw_polyline(ring, Color("a51111"), maxf(1.0, s * 0.06), true)
		var inner := PackedVector2Array([o + Vector2(s * 0.5, s * 0.2), o + Vector2(s * 0.84, s * 0.83), o + Vector2(s * 0.16, s * 0.83), o + Vector2(s * 0.5, s * 0.2)])
		draw_polyline(inner, Color.WHITE, maxf(1.0, s * 0.045), true)
		draw_line(o + Vector2(s * 0.5, s * 0.36), o + Vector2(s * 0.5, s * 0.62), Color.WHITE, maxf(1.5, s * 0.1), true)
		draw_circle(o + Vector2(s * 0.5, s * 0.73), maxf(1.0, s * 0.06), Color.WHITE)


static func style(fill: Color, edge: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(0)
	box.corner_detail = 12
	return box


static func frame(category: GameEnums.CardCategory, selected: bool, radius: int = 8) -> StyleBoxFlat:
	var box: StyleBoxFlat = style(FILLS[category], Color("e3c360") if selected else EDGES[category], 3 if selected else 2, radius)
	box.shadow_color = Color(0, 0, 0, 0.16)
	box.shadow_offset = Vector2(0, 3)
	box.shadow_size = 8 if selected else 4
	return box


static func panel(parent: Control, node_name: String, rect: Rect2, fill: Color, edge: Color, border: int, radius: int) -> Panel:
	var item := Panel.new()
	item.name = node_name
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_stylebox_override("panel", style(fill, edge, border, radius))
	parent.add_child(item)
	return item


## 번역된 긴 이름이 손패 카드의 이름 칸(두 줄까지)에 들어가도록 글자 크기를 줄인다.
## 한 줄로 들어가는 크기와 두 줄로 들어가는 크기 중 큰 쪽을 쓴다 (줄 높이는 글꼴의 실제 높이).
static func fit_title_px(text: String, box_width: float, box_height: float, start_px: int, min_px: int) -> int:
	for px: int in FontSizes.steps(start_px, min_px):  # 표준 크기만 재 본다 (크기마다 글리프를 굽는다)
		var text_width: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var line_height: float = FONT.get_height(px)
		if text_width <= box_width and line_height <= box_height:
			return px
		if text_width <= box_width * 1.8 and line_height * 2.0 - 2.0 <= box_height:
			return px
	return FontSizes.snap(min_px)


## 여러 줄로 감싼 글이 상자(가로 box_width, 세로 box_height)에 다 들어가는 가장 큰 글자 크기 (start_px에서 min_px까지 줄여 본다).
## 낱말 경계에서 나누되 칸보다 긴 낱말(띄어쓰기 없는 일본어 등)은 글자 단위로 나눈다 (AUTOWRAP_WORD_SMART와 같다). 화면에 나갈 글(번역된 글)을 넘긴다.
## line_spacing: 그 라벨의 줄 간격 (NAN이면 테마 기본값, 라벨은 줄마다 이만큼 더 띄운다).
static func fit_px(text: String, box_width: float, box_height: float, start_px: int, min_px: int, line_spacing: float = NAN, font: Font = null) -> int:
	var face: Font = font if font != null else FONT
	if is_nan(line_spacing):
		line_spacing = default_line_spacing()
	var flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	for px: int in FontSizes.steps(start_px, min_px):  # 표준 크기만 재 본다 (크기마다 글리프를 굽는다)
		var wrapped: Vector2 = face.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, box_width, px, -1, flags)
		var line_height: float = face.get_height(px)
		var lines: int = maxi(1, roundi(wrapped.y / line_height))
		if lines * (line_height + line_spacing) - line_spacing <= box_height + 0.5:
			return px
	return FontSizes.snap(min_px)


static var _default_spacing: float = NAN


## 라벨의 기본 줄 간격 (테마 값).
static func default_line_spacing() -> float:
	if is_nan(_default_spacing):
		var probe := Label.new()
		_default_spacing = float(probe.get_theme_constant("line_spacing"))
		probe.free()
	return _default_spacing


## 함정 카드의 발동 방식: 즉시 발동(밟는 순간, 지나가든 멈추든) / 조건 발동(조건이 붙음) / 착지 발동(멈췄을 때만).
const TRAP_TRIGGERS: Dictionary = {
	&"TRP_02": "조건 발동",  # 눈금 4 이상으로 지나가거나 멈출 때
	&"TRP_03": "즉시 발동",
	&"TRP_05": "즉시 발동",
	&"TRP_06": "즉시 발동",
	&"TRP_07": "조건 발동",  # 멈추지 않고 지나갈 때만
	&"TRP_08": "즉시 발동",
	&"TRP_C01": "착지 발동",
	&"TRP_C02": "즉시 발동",
	&"TRP_C03": "조건 발동",  # 카드 1장을 바치거나, 없으면 멈춤
	&"TRP_C04": "즉시 발동",
}


static func label(parent: Control, node_name: String, text: String, rect: Rect2, px: int, color: Color = INK, centered: bool = false, wrap: bool = false) -> Label:
	var item := Label.new()
	item.name = node_name
	# Enable wrapping before assigning text, so the first minimum width is bounded.
	if wrap:
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.clip_text = true
	item.text = text
	if not wrap:
		# 한 줄 글(종류 배지·효과 종류 등): 글꼴(언어)에 따라 줄 높이·폭이 커져도 칸 밖으로 밀려나지 않게 칸에 맞춰 줄인다
		var shown: String = L10n.t(text)
		px = FontSizes.snap(px)
		while px > 6 and (FONT.get_height(px) > rect.size.y + 1.0 or FONT.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > rect.size.x + 1.0):
			px = FontSizes.next_down(px)  # 표준 크기로만 줄인다
	item.add_theme_font_override("font", FONT)
	item.add_theme_font_size_override("font_size", px)
	item.add_theme_color_override("font_color", color)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	item.position = rect.position
	item.size = rect.size
	# 카드가 아직 화면 트리 밖이면 글꼴 지정이 반영되기 전 기본 글꼴(16px)로 잰 글 폭만큼 칸이 늘어나 있다 (작은 배지 글이 밖으로 밀림).
	# 트리에 들어간 뒤 칸 크기를 다시 준다
	item.set_deferred("size", rect.size)
	return item


static func body(card: BaseCard, card_size: Vector2, summary_text: String, category_name: String, detailed: bool) -> Control:
	var holder := Control.new()
	holder.name = "CardBody"
	holder.custom_minimum_size = card_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hand uses a larger title area and a short summary, not shrunken detail text.
	var k: float = card_size.x / (280.0 if detailed else 140.0)
	var margin: float = (20.0 if detailed else 10.0) * k
	var width: float = card_size.x - margin * 2.0
	var title_px: int = roundi((20.0 if detailed else 12.0) * k)
	var title_h: float = (36.0 if detailed else 30.0) * k
	var shown_name: String = L10n.t(card.display_name)  # 화면에 실제로 나갈 이름 (영어 화면이면 영어)
	if detailed and FONT.get_string_size(shown_name, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x > width - 12.0 * k:
		title_px = roundi(18.0 * k)
		title_h = 52.0 * k
	# 이름이 이름 칸(최대 두 줄)에 다 들어가도록 글자를 줄인다 (언어마다 길이가 달라도 칸 밖으로 나가거나 잘리지 않게)
	title_px = fit_px(shown_name, width - 12.0 * k, title_h - 4.0 * k, title_px, roundi((12.0 if detailed else 8.0) * k), -roundi(2 * k))
	var name_panel: Panel = panel(holder, "NamePanel", Rect2(margin, margin, width, title_h), HEADER, GREEN, maxi(1, roundi(2 * k)), roundi(10 * k))
	var title: Label = label(name_panel, "CardTitle", card.display_name, Rect2(6 * k, 2 * k, width - 12 * k, title_h - 4 * k), title_px, INK, true, true)
	title.max_lines_visible = 2
	title.add_theme_constant_override("line_spacing", -roundi(2 * k))
	var art_y: float = margin + title_h + (12.0 if detailed else 4.0) * k
	var detail_y: float = (260.0 if detailed else 138.0) * k
	var art_h: float = detail_y - art_y - (12.0 if detailed else 6.0) * k
	var art: Panel = panel(holder, "ArtWindow", Rect2(margin, art_y, width, art_h), PANEL, GREEN, maxi(1, roundi(2 * k)), roundi(10 * k))
	var art_path: String = "res://assets/cards/%s.png" % card.card_id
	var table_icon: String = GameData.text("cards", card.card_id, "icon_file")  # cards_table.csv의 icon_file
	if table_icon != "":
		var candidate: String = table_icon if table_icon.begins_with("res://") else "res://assets/cards/" + table_icon
		if ResourceLoader.exists(candidate):
			art_path = candidate
	if ResourceLoader.exists(art_path):
		var picture := TextureRect.new()
		picture.name = "CardArt"
		picture.texture = TextureCache.fetch(art_path)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var inset: float = 2.0 * k
		# Fit the complete illustration: crowns, ears and props must not be cropped.
		var available: Vector2 = art.size - Vector2.ONE * inset * 2.0
		var source_size: Vector2 = picture.texture.get_size()
		var fit_scale: float = minf(available.x / source_size.x, available.y / source_size.y)
		picture.size = source_size * fit_scale
		picture.position = (art.size - picture.size) * 0.5
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Clip the illustration to a rounded window; don't cover its border.
		var material := ShaderMaterial.new()
		material.shader = ART_SHADER
		material.set_shader_parameter("window_size", picture.size)
		material.set_shader_parameter("radius", 8.0 * k)
		picture.material = material
		art.add_child(picture)
	else:
		# Retain a neutral letter emblem for cards whose own art isn't ready.
		label(art, "CardEmblem", shown_name.left(1), Rect2(Vector2.ZERO, art.size), roundi((56.0 if detailed else 36.0) * k), EDGES[card.category], true)
	if SELF_RISK.has(card.card_id):
		# 내 말도 휘말리는 카드: 일러스트 창 왼쪽 위에 경고 아이콘 (문구는 상세 설명에)
		var icon := WarningIcon.new()
		icon.name = "SelfRiskIcon"
		var icon_size: float = (40.0 if detailed else 26.0) * k
		icon.position = Vector2(margin - 4.0 * k, art_y - 3.0 * k)
		icon.size = Vector2(icon_size, icon_size)
		holder.add_child(icon)
	var detail: Panel = panel(holder, "EffectPanel", Rect2(margin, detail_y, width, card_size.y - detail_y - margin), PANEL, GREEN, maxi(1, roundi(2 * k)), roundi(10 * k))
	# 종류 배지는 글에 맞춰 넓어진다 (영어 Summon·일본어 召喚처럼 한국어보다 긴 이름도 배지 안에 들어가게, 효과 칸 폭의 절반까지)
	var badge_px: int = roundi((14.0 if detailed else 9.0) * k)
	var badge_text_width: float = FONT.get_string_size(L10n.t(category_name), HORIZONTAL_ALIGNMENT_LEFT, -1, badge_px).x
	var badge_size := Vector2(clampf(badge_text_width + (12.0 if detailed else 8.0) * k, (48.0 if detailed else 30.0) * k, width * 0.5), maxf((20.0 if detailed else 15.0) * k, FONT.get_height(badge_px) + 2.0))
	var padding: float = (8.0 if detailed else 4.0) * k
	var badge: Panel = panel(detail, "CategoryBadge", Rect2(Vector2.ONE * padding, badge_size), FILLS[card.category], FILLS[card.category], 0, roundi(7 * k))
	var badge_ink: Color = Color("f9f9f3") if card.category == GameEnums.CardCategory.TRAP or card.category == GameEnums.CardCategory.COUNTER else Color("111111")
	label(badge, "CategoryName", category_name, Rect2(Vector2.ZERO, badge_size), badge_px, badge_ink, true)
	if detailed:
		var tag: String = "타일 설치" if card.needs_tile() else "즉시 효과"
		if TRAP_TRIGGERS.has(card.card_id):
			tag = TRAP_TRIGGERS[card.card_id]  # 함정은 모두 타일에 깔리므로 언제 발동하는지로 나눠 보여 준다
		if card.category == GameEnums.CardCategory.SUMMON:
			tag = "NPC 소환"
		elif card.category == GameEnums.CardCategory.COUNTER:
			tag = "피격 시 발동"
		label(detail, "EffectKind", tag, Rect2(padding * 2 + badge_size.x, padding, width - badge_size.x - padding * 3, badge_size.y), roundi(14 * k))
	var summary_y: float = maxf((36.0 if detailed else 21.0) * k, padding + badge_size.y + 2.0 * k)
	var summary_box := Rect2(padding, summary_y, width - padding * 2, detail.size.y - summary_y - padding)
	var summary_spacing: float = default_line_spacing() if detailed else -roundi(3 * k)
	# 효과 설명이 칸에 끝까지 들어가도록 글자를 줄인다 (긴 번역도 잘리지 않게)
	var summary_px: int = fit_px(L10n.t(summary_text), summary_box.size.x, summary_box.size.y, roundi((16.0 if detailed else 11.0) * k), roundi((10.0 if detailed else 7.0) * k), summary_spacing)
	var summary: Label = label(detail, "CardSummary", summary_text, summary_box, summary_px, INK, false, true)
	if not detailed:
		summary.add_theme_constant_override("line_spacing", roundi(summary_spacing))
	summary.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return holder
