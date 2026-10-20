# File: res://scenes/kill_cutin.gd
# Class: class_name KillCutIn
# Role: 말을 잡았을 때 화면 맨 위에 순간 번쩍 보여 주는 처치 컷신 (다키스트 던전 "A Singular Strike!" 패러디). 암전 + 집중선·십자 섬광 -> 일러스트가 1.45배에서 쾅 내리꽂힘 + 화면 흔들림·타격음 -> 붓터치 배너에 패러디 대사.
# 연출만 담당하고 게임 상태는 건드리지 않는다. 일러스트 파일(content_trickcal/illustrations/cutins/kill_*.png)이 없으면 공격 기물 실루엣과 폭발 그래픽을 코드로 그린다
class_name KillCutIn
extends CanvasLayer

const TOTAL_SECONDS: float = 0.65
const ART_DIR: String = "res://content_trickcal/illustrations/cutins"
const ART_NAMES: Array[String] = ["kill_punch", "kill_hammer", "kill_chess_lance", "kill_finger_flick"]
const LINES: Array[String] = [
	"단 한 번의 일격! (A SINGULAR STRIKE!)",
	"치명적인 볼따구 강타! (ANNIHILATED!)",
	"자비 없는 장외 추방! (OBLITERATED!)",
	"완벽한 억까의 순간! (DECIMATED!)",
]
const DIM_COLOR: Color = Color(0.05, 0.02, 0.02, 0.78)


## 집중선: 화면 가장자리에서 가운데 쪽으로 뻗는 날카로운 삼각형들. progress가 0->1로 가면서 안쪽으로 길어진다.
class ImpactLines extends Control:
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = center.length()
		var inner: float = radius * lerpf(1.0, 0.34, progress)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i: int in 44:
			var angle: float = TAU * float(i) / 44.0 + rng.randf_range(-0.05, 0.05)
			var direction := Vector2.from_angle(angle)
			var outer_point: Vector2 = center + direction * radius * 1.15
			var tip: Vector2 = center + direction * lerpf(inner, radius * 0.5, rng.randf())
			var side := Vector2(-direction.y, direction.x) * rng.randf_range(6.0, 16.0)
			var color: Color = Color(1.0, 1.0, 1.0, 0.85) if i % 3 != 0 else Color(0.95, 0.15, 0.12, 0.9)
			draw_colored_polygon(PackedVector2Array([outer_point + side, outer_point - side, tip]), color)


## 일러스트 파일이 없을 때 쓰는 대체 그림: 폭발 별 모양 + 공격 기물의 큰 실루엣 + 쾅 글자.
class BurstArt extends Control:
	var attacker: Texture2D = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0
		var points_red := PackedVector2Array()
		var points_gold := PackedVector2Array()
		for i: int in 28:
			var angle: float = TAU * float(i) / 28.0
			var spike: float = 1.0 if i % 2 == 0 else 0.62
			points_red.append(center + Vector2.from_angle(angle) * radius * spike)
			points_gold.append(center + Vector2.from_angle(angle + 0.05) * radius * spike * 0.78)
		draw_colored_polygon(points_red, Color("b3121b"))
		draw_colored_polygon(points_gold, Color("ffc93c"))
		draw_circle(center, radius * 0.42, Color("fff3bf"))
		if attacker != null:
			var side: float = radius * 1.0
			draw_texture_rect(attacker, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(0.12, 0.05, 0.05, 1.0))


var _board: Control = null


## 컷신을 재생한다. board는 글자 만들기·화면 흔들림을 빌려 쓰는 MainBoard, attacker는 공격 기물 그림(없으면 null), pace는 연출 속도 배율.
func play(board: Control, attacker: Texture2D, pace: float = 1.0, seed_value: int = -1) -> void:
	_board = board
	layer = 30
	var k: float = maxf(pace, 0.01)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var root := Control.new()
	root.name = "KillCutInRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # 컷신 동안 아래 화면 클릭을 막는다
	add_child(root)

	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.modulate.a = 0.0
	root.add_child(dim)

	var lines := ImpactLines.new()
	root.add_child(lines)

	# 십자 섬광
	var flash_h := ColorRect.new()
	flash_h.color = Color(1, 1, 1, 0.95)
	flash_h.size = Vector2(screen.x, 10.0)
	flash_h.position = Vector2(0.0, screen.y / 2.0 - 5.0)
	flash_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_h)
	var flash_v := ColorRect.new()
	flash_v.color = Color(1, 1, 1, 0.95)
	flash_v.size = Vector2(10.0, screen.y)
	flash_v.position = Vector2(screen.x / 2.0 - 5.0, 0.0)
	flash_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_v)

	# 일러스트 (파일이 있으면 그것, 없으면 코드로 그린 폭발 그림)
	var art_size := Vector2(minf(screen.x * 0.5, 560.0), minf(screen.y * 0.62, 460.0))
	var art_holder := Control.new()
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_holder.size = art_size
	art_holder.position = Vector2(screen.x / 2.0, screen.y * 0.45) - art_size / 2.0
	art_holder.pivot_offset = art_size / 2.0
	art_holder.scale = Vector2(1.45, 1.45)
	art_holder.modulate.a = 0.0
	root.add_child(art_holder)
	var art_texture: Texture2D = _pick_art(rng)
	if art_texture != null:
		var picture := TextureRect.new()
		picture.texture = art_texture
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_holder.add_child(picture)
	else:
		var burst := BurstArt.new()
		burst.attacker = attacker
		burst.set_anchors_preset(Control.PRESET_FULL_RECT)
		art_holder.add_child(burst)
		var bang: Label = _make_label("쾅!", 120, Color("b3121b"))
		bang.set_anchors_preset(Control.PRESET_FULL_RECT)
		bang.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bang.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bang.add_theme_constant_override("outline_size", 18)
		bang.add_theme_color_override("font_outline_color", Color("fff3bf"))
		bang.visible = attacker == null
		art_holder.add_child(bang)

	# 붓터치 배너 + 패러디 대사
	var banner := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.02, 0.96)
	style.border_color = Color("c0392b")
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.content_margin_left = 40.0
	style.content_margin_right = 40.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 14.0
	banner.add_theme_stylebox_override("panel", style)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: String = LINES[rng.randi() % LINES.size()]
	var gold: bool = rng.randf() < 0.5
	var text: Label = _make_label(line, 40, Color("ffd43b") if gold else Color("ff3b30"))
	text.add_theme_constant_override("outline_size", 10)
	text.add_theme_color_override("font_outline_color", Color("1a0505"))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(text)
	root.add_child(banner)
	banner.size = Vector2(minf(screen.x * 0.9, 900.0), 76.0)
	banner.position = Vector2((screen.x - banner.size.x) / 2.0, screen.y * 0.45 + art_size.y / 2.0 - 8.0)
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.2, 1.0)
	banner.modulate.a = 0.0

	# 시간표: 0.05 암전·집중선 -> 쾅 내리꽂힘 0.08 -> 배너 -> 0.55부터 사라짐 (총 0.65초)
	var tween: Tween = root.create_tween().set_parallel(true)
	tween.tween_property(dim, "modulate:a", 1.0, 0.05 * k)
	tween.tween_property(lines, "progress", 1.0, 0.14 * k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_h, "modulate:a", 0.0, 0.18 * k).set_delay(0.04 * k)
	tween.tween_property(flash_v, "modulate:a", 0.0, 0.18 * k).set_delay(0.04 * k)
	tween.tween_property(art_holder, "modulate:a", 1.0, 0.02 * k).set_delay(0.05 * k)
	tween.tween_property(art_holder, "scale", Vector2.ONE, 0.08 * k).set_delay(0.05 * k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_slam).set_delay(0.13 * k)
	tween.tween_property(banner, "modulate:a", 1.0, 0.04 * k).set_delay(0.14 * k)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.1 * k).set_delay(0.14 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "modulate:a", 0.0, 0.1 * k).set_delay((TOTAL_SECONDS - 0.1) * k)
	tween.chain().tween_callback(queue_free)


## 일러스트가 내리꽂힌 순간: 화면이 크게 흔들리고 묵직한 타격음이 터진다.
func _on_slam() -> void:
	if _board != null and is_instance_valid(_board) and _board.has_method("screen_shake"):
		_board.call("screen_shake", 18.0, 0.35)
	Sfx.play(&"pawn_capture")


## cutins 폴더에 일러스트가 있으면 그중 하나를 무작위로 고른다 (없으면 null = 코드로 그린 그림을 쓴다).
func _pick_art(rng: RandomNumberGenerator) -> Texture2D:
	var found: Array[String] = []
	for art_name: String in ART_NAMES:
		var path: String = "%s/%s.png" % [ART_DIR, art_name]
		if ResourceLoader.exists(path):
			found.append(path)
	if found.is_empty():
		return null
	return TextureCache.fetch(found[rng.randi() % found.size()])


func _make_label(text: String, size_px: int, color: Color) -> Label:
	var label: Label = _board.call("_make_label", text, size_px, color) if _board != null and _board.has_method("_make_label") else Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
