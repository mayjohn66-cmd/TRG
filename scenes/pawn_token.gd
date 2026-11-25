## Shared 38px token, drawn at a ground-contact origin. Scale uniformly in UI.
class_name PawnToken
extends Node2D

const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const INK := Color("25252a")
const IVORY := Color("fff4d6")
const WOOD := Color("e9b875")
const BLIND_GRAY := Color("a1a1a1")
const BODY_BOX := Rect2(-13, -31, 26, 31)
const HIT_BOX := Rect2(-18, -34, 36, 42)
const COLLECTIBLE_BOARD_ART_SCALE := 1.30
const COVER_ART: Texture2D = preload("res://assets/fx/expansion_cards/cover.png")
const TOP_ART: Texture2D = preload("res://assets/fx/expansion_cards/top.png")
const NECKLACE_ART: Texture2D = preload("res://assets/fx/priority/ejection_necklace.png")
const AGITATION_MARK = preload("res://scenes/agitation_mark.gd")
var pawn: PlayerPawn
## 괴상한 멜론 한 단계마다 커지는 비율.
const MELON_GROWTH: float = 0.2
var owner_color: Color = Color("e5484d")
var artwork: Dictionary = {}
var use_art: bool = true
var ground_shadow: bool = true
var is_board_token := false
var npc_behavior: int = -1
var _golden_top := false
var _top_phase := 0.0
var _cover_pending := false
var _signature: String = ""
var _pulse: float = 1.0
var _shield_shell: ShieldShell
var _necklace_signal: float = 0.0
var _necklace_signal_tween: Tween
## Persistent protection remains visible; this switch only skips gain/break motion.
var shield_motion: bool = true
## 눈먼 자의 도시: 회색 기본말과 머리 위 물음표로 표시한다.
var blind: bool = false
## 머리 위 상태 칩.
var peace_mark: bool = false
var agitation_mark: bool = false
var necklace_equipped: bool = false:
	set(value):
		if necklace_equipped != value:
			necklace_equipped = value
			if is_node_ready():
				_update_necklace_signal()
			queue_redraw()
var necklace_offset := 0.0:
	set(value):
		necklace_offset = value
		queue_redraw()
var necklace_warning := 0.0:
	set(value):
		necklace_warning = value
		queue_redraw()
## Only round body artwork rolls; owner base, stack, shield and skill marker stay upright.
var melon_roll_angle: float = 0.0:
	set(value):
		melon_roll_angle = fposmod(value, TAU)
		queue_redraw()


func _ready() -> void:
	set_process(skill_ready() or _golden_top)
	if necklace_equipped:
		_update_necklace_signal()


func configure(value: PlayerPawn, color: Color, images: bool = true) -> void:
	pawn = value
	owner_color = color
	use_art = images
	var art: Dictionary = {}
	if images:
		art = PawnArt.load_sprite([PawnArt.BASIC_PATH]) if blind else PawnArt.sprite(pawn)
	var key: String = "%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s" % [pawn.kind, pawn.unit_no, pawn.slot, pawn.promoted, pawn.carried.size(), pawn.skill_used, pawn.is_finished, color, pawn.revenge_boost, (art.get("texture") as Texture2D).resource_path if not art.is_empty() else "shape", pawn.shield, pawn.ward or pawn.mercury, pawn.turn_guard, pawn.melon_size, pawn.ward_box, pawn.trpg_level if pawn.is_trpg() else 0, blind, agitation_mark, peace_mark]
	key += ":mercury=%s" % pawn.mercury
	if key == _signature:
		return
	# 괴상한 멜론 (v1.1): 함정을 먹을 때마다 한 단계씩 커진다 (최대 3단계 = 1.6배)
	scale = Vector2.ONE if blind else Vector2.ONE * (1.0 + MELON_GROWTH * pawn.melon_size)
	var animate_shield: bool = shield_motion and not blind and is_inside_tree() and _signature != ""
	_signature = key
	artwork = art
	if not is_rolling_body():
		melon_roll_angle = 0.0
	_sync_shield(animate_shield)
	set_process(skill_ready())
	queue_redraw()


func is_rolling_melon() -> bool:
	return pawn != null and pawn.sub_type() == GameEnums.PawnSubType.ODD_MELON

func is_rolling_body() -> bool:
	return pawn != null and pawn.sub_type() in [GameEnums.PawnSubType.ODD_MELON,GameEnums.PawnSubType.POOL_8BALL]


func artwork_rect() -> Rect2:
	if artwork.is_empty():
		return BODY_BOX
	var region: Rect2 = artwork.region
	var factor: float = minf(BODY_BOX.size.x / region.size.x, BODY_BOX.size.y / region.size.y)
	if is_board_token and not blind and pawn != null and pawn.kind == GameEnums.PawnKind.COLLECTIBLE:
		factor *= COLLECTIBLE_BOARD_ART_SCALE
	var size: Vector2 = region.size * factor
	return Rect2(Vector2(-size.x / 2.0, -size.y), size)


## Shared round-body pivot. The melon's short stem extends above this center.
func melon_roll_center() -> Vector2:
	var rect: Rect2 = artwork_rect()
	return Vector2(0, -minf(rect.size.x, rect.size.y) * 0.5)


func melon_roll_radius() -> float:
	return -melon_roll_center().y * scale.x


func has_protection() -> bool:
	return pawn != null and not blind and not pawn.is_finished and (pawn.ward or pawn.mercury or pawn.turn_guard or (pawn.shield and pawn.sub_type() == GameEnums.PawnSubType.BADUK_WHITE))


func _sync_shield(animate: bool) -> void:
	if _shield_shell == null and not has_protection():
		return
	if _shield_shell == null:
		_shield_shell = ShieldShell.new()
		_shield_shell.name = "ProtectionShell"
		add_child(_shield_shell)
	var height: float = BODY_BOX.size.y
	if not artwork.is_empty():
		height = artwork_rect().size.y
	elif pawn.kind == GameEnums.PawnKind.GO or pawn.kind == GameEnums.PawnKind.YUT or pawn.kind == GameEnums.PawnKind.JANGGI:
		height = 20.0
	_shield_shell.fit_body(height, mini(pawn.carried.size(), 3), float(pawn.entity_id))
	_shield_shell.set_mercury(pawn.mercury, has_protection())
	_shield_shell.set_active(has_protection(), animate and not pawn.is_finished)
	if blind:
		_shield_shell.hide()
	_sync_cover_box(height)


func set_cover_pending(pending: bool) -> void:
	_cover_pending = pending
	var box := get_node_or_null("CoverBox") as Sprite2D
	if box != null:
		box.visible = not pending


## 긴급 엄폐 상자는 방어가 소모될 때까지 말에 붙어 있다.
func _sync_cover_box(height: float) -> void:
	var box := get_node_or_null("CoverBox") as Sprite2D
	if pawn == null or not pawn.ward_box or not has_protection():
		if box != null:
			remove_child(box)
			box.queue_free()
		return
	if box == null:
		box = PaintedFx.sprite(COVER_ART)
		box.name = "CoverBox"
		box.z_index = 3
		add_child(box)
	var width := clampf(height * 1.38, 34.0, 60.0)
	box.scale = Vector2.ONE * (width / box.region_rect.size.x)
	box.position = Vector2(0, 1 - box.region_rect.size.y * box.scale.y * 0.5)
	box.visible = not _cover_pending


## When a white stone has two protections, consuming one flashes the surviving shell.
func shield_hit() -> void:
	if _shield_shell != null and has_protection() and shield_motion:
		_shield_shell.flash_hit()


## The back glass sits behind the pawn; the clear front and reflections sit above it.
## No per-frame CPU drawing or gameplay timers are needed for an idle shield.
class ShieldShell extends Node2D:
	const GLASS: Shader = preload("res://assets/fx/pawn_shield.gdshader")
	var active: bool = false
	var _layers: Array[ColorRect] = []
	var _materials: Array[ShaderMaterial] = []
	var _transition: Tween
	var _flash: Tween
	func set_mercury(value: bool, remains_active: bool) -> void:
		# Keep the silver material while a consumed mercury shell disperses.
		if not value and active and not remains_active:
			return
		_parameter(&"mercury", 1.0 if value else 0.0)

	func _init() -> void:
		for front: bool in [false, true]:
			var layer := ColorRect.new()
			layer.name = "GlassFront" if front else "GlassBack"
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.z_index = 1 if front else -1
			var glass := ShaderMaterial.new()
			glass.shader = GLASS
			glass.set_shader_parameter("front_layer", 1.0 if front else 0.0)
			glass.set_shader_parameter("strength", 0.0)
			layer.material = glass
			add_child(layer)
			_layers.append(layer)
			_materials.append(glass)
		visible = false

	func fit_body(height: float, stack_count: int, seed_value: float) -> void:
		var top: float = -height - 6.0
		var bottom: float = 9.0 + stack_count * 4.0
		var radius := Vector2(21.0, (bottom - top) * 0.5)
		for layer: ColorRect in _layers:
			layer.position = Vector2(0.0, (top + bottom) * 0.5) - radius * 1.14
			layer.size = radius * 2.28
		for glass: ShaderMaterial in _materials:
			glass.set_shader_parameter("phase", seed_value * 0.71)

	func _parameter(key: StringName, value: float) -> void:
		for glass: ShaderMaterial in _materials:
			glass.set_shader_parameter(key, value)

	func _animate_parameter(value: float, key: StringName) -> void:
		_parameter(key, value)

	func set_active(value: bool, animate: bool) -> void:
		if active == value:
			return
		active = value
		if _transition != null: _transition.kill()
		if _flash != null: _flash.kill()
		_parameter(&"hit_flash", 0.0)
		_parameter(&"fracture", 0.0)
		if not animate:
			visible = value
			scale = Vector2.ONE
			_parameter(&"strength", 1.0 if value else 0.0)
			return
		visible = true
		_transition = create_tween().set_parallel(true)
		if value:
			scale = Vector2.ONE * 0.82
			_parameter(&"strength", 0.0)
			_transition.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_transition.tween_method(_animate_parameter.bind(&"strength"), 0.0, 1.0, 0.24)
		else:
			scale = Vector2.ONE
			_parameter(&"strength", 1.0)
			_transition.tween_property(self, "scale", Vector2.ONE * 1.12, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_transition.tween_method(_animate_parameter.bind(&"fracture"), 0.0, 1.0, 0.32)
			_transition.tween_method(_animate_parameter.bind(&"strength"), 1.0, 0.0, 0.32)
			_transition.chain().tween_callback(hide)

	func flash_hit() -> void:
		if _flash != null: _flash.kill()
		_parameter(&"hit_flash", 1.0)
		_flash = create_tween()
		_flash.tween_method(_animate_parameter.bind(&"hit_flash"), 1.0, 0.0, 0.25)


func skill_ready() -> bool:
	return pawn != null and not blind and PawnSkills.has_skill(pawn) and not pawn.skill_used and not pawn.is_finished


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_pulse = 0.7 + 0.3 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * TAU / 1400.0))
	if _golden_top:
		_top_phase = fposmod(_top_phase + delta * 31.0, TAU)
	queue_redraw()


func _ellipse(center: Vector2, radii: Vector2, color: Color, edge: Color = Color.TRANSPARENT, width: float = 1.0) -> void:
	var points := PackedVector2Array()
	for i: int in 32:
		var angle: float = TAU * i / 32.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	_poly(points, color, edge, width)


func _poly(points: PackedVector2Array, color: Color, edge: Color = INK, width: float = 1.4) -> void:
	draw_colored_polygon(points, color)
	if edge.a > 0:
		var closed: PackedVector2Array = points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, edge, width, true)


func _caption(text: String, center: Vector2, size: int, color: Color) -> void:
	text = L10n.t(text)
	var width: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(FONT, center + Vector2(-width / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw() -> void:
	if pawn == null:
		if npc_behavior >= 0:
			_draw_npc()
		return
	var color: Color = BLIND_GRAY if blind else owner_color
	var stack: int = 0 if blind else mini(pawn.carried.size(), 3)
	# Ground shadow, thick side wall, top ring, and inset make owner color visible.
	if ground_shadow:
		_ellipse(Vector2(0, 5 + 4 * stack), Vector2(17, 6), Color(0, 0, 0, 0.28))
	# 업은 말은 글자(x2) 대신 받침 원판을 아래로 겹겹이 쌓아 보여 준다 (최대 3장).
	for layer: int in range(stack, 0, -1):
		_ellipse(Vector2(0, 3 + 4 * layer), Vector2(15, 6), owner_color.darkened(0.6), INK)
		_ellipse(Vector2(0, 4 * layer), Vector2(15, 6), owner_color.darkened(0.15), INK, 1.0)
	_ellipse(Vector2(0, 3), Vector2(15, 6), color.darkened(0.48), INK)
	_ellipse(Vector2.ZERO, Vector2(15, 6), color, color.lightened(0.5), 1.5)
	_ellipse(Vector2.ZERO, Vector2(11, 3.5), color.darkened(0.3))
	var show_necklace: bool = not blind and (necklace_equipped or necklace_warning > 0.0)
	if show_necklace:
		_draw_necklace_part(false)
	if not artwork.is_empty():
		var texture: Texture2D = artwork.texture
		var region: Rect2 = artwork.region
		var rect: Rect2 = artwork_rect()
		if not blind and is_rolling_body():
			var center: Vector2 = melon_roll_center()
			draw_set_transform(center, melon_roll_angle)
			rect.position -= center
		if not blind and pawn.is_promoted_shogi():
			for offset: Vector2 in [Vector2(-1.4,0),Vector2(1.4,0),Vector2(0,-1.4),Vector2(0,1.4)]:
				draw_texture_rect_region(texture,Rect2(rect.position+offset,rect.size),region,Color("ff5e50"))
		for offset: Vector2 in [Vector2(-0.7, 0), Vector2(0.7, 0), Vector2(0, -0.7), Vector2(0, 0.7)]:
			draw_texture_rect_region(texture, Rect2(rect.position + offset, rect.size), region, color.lightened(0.2))
		# Basic tokens use the owner's color; chess/evolved pieces retain their material.
		var body_color: Color = color if blind or pawn.kind == GameEnums.PawnKind.BASIC else Color.WHITE
		draw_texture_rect_region(texture, rect, region, body_color)
		draw_set_transform(Vector2.ZERO)
	elif blind:
		_draw_basic_shape(color)
	else:
		_draw_shape()
	if show_necklace:
		_draw_necklace_part(true)
	if blind:
		var top := Vector2(0.0, artwork_rect().position.y - 7.0)
		var width := FONT.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var origin := top - Vector2(width * 0.5, 0.0)
		draw_string_outline(FONT, origin, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, INK)
		draw_string(FONT, origin, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		return
	if pawn.is_promoted_shogi() and artwork.is_empty():
		_poly(PackedVector2Array([Vector2(0,-32),Vector2(13,-23),Vector2(11,-2),Vector2(-11,-2),Vector2(-13,-23)]), Color.TRANSPARENT, Color("ff5e50"), 2.0)
	# 슬롯 번호 배지는 그리지 않는다 (기물 그림을 가려 거슬린다는 피드백). 몇 번 말인지는 고르기 카드의 [N번 말]이 알려 준다.
	# 리벤지 부스터는 말 옆 불꽃 대신 프로필 칸이 불타는 것으로만 보여 준다 (main_board._paint_revenge_glow)
	_draw_status_chips()
	if skill_ready():
		var bolt := PackedVector2Array([Vector2(13,-29),Vector2(8,-20),Vector2(12,-20),Vector2(10,-13),Vector2(18,-23),Vector2(14,-23)])
		_poly(bolt, Color(1,0.88,0.25,_pulse), INK, 0.9)


## The rear of the collar sits behind the pawn, with the lock over its chest.
func _draw_necklace_part(front: bool) -> void:
	var art_rect := artwork_rect()
	var center := Vector2(0.0, art_rect.position.y * 0.72 + necklace_offset)
	var src := PaintedFx.region(NECKLACE_ART)
	var width := clampf(art_rect.size.x * 0.98, 20.0, 27.0)
	var size := Vector2(width, width * src.size.y / src.size.x)
	var dst := Rect2(center - size * 0.5, size)
	var split := 0.46  # The front rim begins below the opening in the source.
	if front:
		src.position.y += src.size.y * split
		src.size.y *= 1.0 - split
		dst.position.y += dst.size.y * split
		dst.size.y *= 1.0 - split
	else:
		src.size.y *= split
		dst.size.y *= split
	draw_texture_rect_region(NECKLACE_ART, dst, src)
	if front and necklace_warning > 0.0:
		var light := center + Vector2(0.0, size.y * 0.30)
		PaintedFx.stamp(self, PaintedFx.IMPACT, light, Vector2(14.0, 8.0), Color(1.0, 0.24, 0.15, necklace_warning))


## 머리 위 칩들: TRPG 레벨 위에 상태 칩(목걸이·평화·표적)을 쌓는다.
func _draw_status_chips() -> void:
	var lifted: float = 0.0
	if pawn != null and pawn.is_trpg() and not pawn.is_finished and pawn.has_left_start:
		_draw_trpg_level()
		lifted = 17.0
	if pawn == null or pawn.is_finished:
		return
	var top: float = (artwork_rect().position.y if not artwork.is_empty() else -34.0) - lifted
	if necklace_equipped:
		var region := PaintedFx.region(NECKLACE_ART)
		var icon_size := Vector2(42.0, 42.0 * region.size.y / region.size.x)
		var icon := Rect2(Vector2(-icon_size.x * 0.5, top - icon_size.y - 4.0), icon_size)
		draw_texture_rect_region(NECKLACE_ART, Rect2(icon.position + Vector2(0.0, 2.0), icon_size), region, Color(0.0, 0.0, 0.0, 0.55))
		draw_texture_rect_region(NECKLACE_ART, icon, region)
		if _necklace_signal > 0.0:
			var light := icon.position + icon.size * Vector2(0.50, 0.80)
			PaintedFx.stamp(self, PaintedFx.IMPACT, light, Vector2(15.0, 8.0), Color(1.0, 0.10, 0.06, _necklace_signal))
			draw_rect(Rect2(light - Vector2(2.6, 0.65), Vector2(5.2, 1.3)), Color(1.0, 0.44, 0.27, _necklace_signal))
	elif peace_mark:
		_draw_peace_mark(Vector2(0.0, top - 13.0))
	if agitation_mark:
		var center := Vector2(0.0, top - 12.0)
		if necklace_equipped or peace_mark:
			center = Vector2(artwork_rect().end.x + 11.0, artwork_rect().position.y + 5.0)
		AGITATION_MARK.draw_mark(self, center, 10.5)


func _update_necklace_signal() -> void:
	if _necklace_signal_tween != null:
		_necklace_signal_tween.kill()
		_necklace_signal_tween = null
	_set_necklace_signal(0.0)
	if necklace_equipped:
		_necklace_signal_tween = create_tween().set_loops()
		_necklace_signal_tween.tween_interval(2.10)
		_necklace_signal_tween.tween_method(_set_necklace_signal, 0.0, 1.0, 0.05)
		_necklace_signal_tween.tween_method(_set_necklace_signal, 1.0, 0.0, 0.18)


func _set_necklace_signal(strength: float) -> void:
	_necklace_signal = strength
	if not blind:
		queue_redraw()


func _draw_peace_mark(center: Vector2) -> void:
	var mint := Color("b3ffd8")
	draw_circle(center + Vector2(0.0, 1.0), 12.0, Color("101d1b"), true, -1.0, true)
	draw_circle(center, 11.0, Color("21483c"), true, -1.0, true)
	draw_arc(center, 10.1, 0.0, TAU, 32, Color("76cda3"), 1.35, true)
	draw_set_transform(center, -0.33)
	draw_polyline(PackedVector2Array([Vector2(-6.3, 6.6), Vector2(-3.0, 3.3), Vector2(0.8, 0.6), Vector2(5.6, -4.8)]), mint, 1.65, true)
	# Solid leaves keep their silhouette when scaled down with the board.
	var leaves: Array[Vector4] = [
		Vector4(-3.7, 4.0, -5.3, -0.5), Vector4(-3.0, 3.3, 2.4, 5.2),
		Vector4(-0.5, 1.4, -1.6, -4.1), Vector4(1.1, 0.0, 6.0, 2.2),
		Vector4(3.3, -2.5, 5.3, -7.4),
	]
	for leaf: Vector4 in leaves:
		var from := Vector2(leaf.x, leaf.y)
		var tip := Vector2(leaf.z, leaf.w)
		var side := from.direction_to(tip).orthogonal() * 1.55
		var near := from.lerp(tip, 0.34)
		var far := from.lerp(tip, 0.68)
		draw_colored_polygon(PackedVector2Array([from, near - side, far - side, tip, far + side, near + side]), mint)
	draw_set_transform(Vector2.ZERO)


## TRPG 기물의 레벨 표시: 머리 위에 [Lv.N] 칩이 떠 있어 처치로 올라간 레벨이 한눈에 보인다 (최대 레벨은 금색 [MAX]).
func _draw_trpg_level() -> void:
	if pawn == null or not pawn.is_trpg() or pawn.is_finished or not pawn.has_left_start:
		return
	var maxed: bool = pawn.trpg_level >= PlayerPawn.TRPG_MAX_LEVEL
	var text: String = "MAX" if maxed else "Lv.%d" % pawn.trpg_level
	var top: float = artwork_rect().position.y if not artwork.is_empty() else -34.0
	var size_px: int = 11
	var width: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x + 10.0
	var chip := Rect2(Vector2(-width / 2.0, top - 17.0), Vector2(width, 15.0))
	var fill: Color = Color("ffd43b") if maxed else Color(0.07, 0.08, 0.12, 0.92)
	var edge: Color = owner_color.lightened(0.25)
	var ink: Color = Color("2b2100") if maxed else Color.WHITE
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(7)
	draw_style_box(box, chip)
	draw_string(FONT, Vector2(chip.position.x + 5.0, chip.position.y + 11.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, ink)


func _draw_shape() -> void:
	var sub: GameEnums.PawnSubType = pawn.sub_type()
	match pawn.kind:
		GameEnums.PawnKind.YUT, GameEnums.PawnKind.GO:
			var color: Color = WOOD if pawn.kind == GameEnums.PawnKind.YUT else (Color("292b37") if sub == GameEnums.PawnSubType.BADUK_BLACK else Color("fff9e9"))
			_ellipse(Vector2(0,-8),Vector2(12,7),color.darkened(0.3),INK)
			_ellipse(Vector2(0,-11),Vector2(12,8),color,INK)
			_ellipse(Vector2(-4,-14),Vector2(4,1.7),Color(1,1,1,0.65))
		GameEnums.PawnKind.JANGGI:
			var octagon := PackedVector2Array()
			for i: int in 8:
				var angle: float = TAU * (i + 0.5) / 8
				octagon.append(Vector2(cos(angle)*13,sin(angle)*9-12))
			var side: PackedVector2Array = octagon.duplicate()
			for i: int in side.size(): side[i] += Vector2(0,4)
			_poly(side,WOOD.darkened(0.35))
			_poly(octagon,WOOD)
			_caption(pawn.letter(),Vector2(0,-12),12,Color("8d332d"))
		GameEnums.PawnKind.SHOGI:
			_poly(PackedVector2Array([Vector2(0,-29),Vector2(12,-21),Vector2(10,-1),Vector2(-10,-1),Vector2(-12,-21)]),WOOD.darkened(0.3))
			_poly(PackedVector2Array([Vector2(0,-31),Vector2(12,-23),Vector2(10,-5),Vector2(-10,-5),Vector2(-12,-23)]),WOOD)
			_caption(pawn.letter(),Vector2(0,-17),12,Color("d43a32") if pawn.promoted else INK)
		GameEnums.PawnKind.CHESS:
			_draw_chess(sub)
		GameEnums.PawnKind.MONOPOLY:
			_draw_monopoly(sub)
		_:
			_draw_basic_shape(owner_color)


func _draw_basic_shape(color: Color) -> void:
	# A meeple has arms and two feet; it stays distinct from a chess pawn.
	_poly(PackedVector2Array([Vector2(-4,-21),Vector2(4,-21),Vector2(11,-16),Vector2(9,-12),Vector2(5,-15),Vector2(6,-7),Vector2(9,-2),Vector2(3,-2),Vector2(0,-8),Vector2(-3,-2),Vector2(-9,-2),Vector2(-6,-7),Vector2(-5,-15),Vector2(-9,-12),Vector2(-11,-16)]), color)
	draw_circle(Vector2(0,-26),6,INK)
	draw_circle(Vector2(0,-26),4.5,color)


func _draw_chess(sub: GameEnums.PawnSubType) -> void:
	var points: PackedVector2Array
	match sub:
		GameEnums.PawnSubType.CHESS_KNIGHT:
			points = PackedVector2Array([Vector2(-9,-4),Vector2(-3,-14),Vector2(-10,-17),Vector2(-9,-24),Vector2(-3,-27),Vector2(-3,-32),Vector2(2,-29),Vector2(6,-30),Vector2(11,-20),Vector2(8,-4)])
		GameEnums.PawnSubType.CHESS_ROOK:
			points = PackedVector2Array([Vector2(-10,-28),Vector2(-4,-28),Vector2(-4,-23),Vector2(2,-23),Vector2(2,-28),Vector2(9,-28),Vector2(9,-19),Vector2(6,-17),Vector2(6,-4),Vector2(-7,-4),Vector2(-7,-17),Vector2(-10,-19)])
		GameEnums.PawnSubType.CHESS_BISHOP:
			points = PackedVector2Array([Vector2(0,-32),Vector2(8,-22),Vector2(5,-17),Vector2(3,-15),Vector2(5,-5),Vector2(-6,-5),Vector2(-3,-15),Vector2(-8,-22)])
		GameEnums.PawnSubType.CHESS_QUEEN:
			points = PackedVector2Array([Vector2(-10,-29),Vector2(-5,-24),Vector2(0,-33),Vector2(5,-24),Vector2(10,-29),Vector2(7,-17),Vector2(4,-15),Vector2(7,-4),Vector2(-7,-4),Vector2(-4,-15),Vector2(-7,-17)])
		_:
			points = PackedVector2Array([Vector2(-4,-20),Vector2(4,-20),Vector2(4,-13),Vector2(8,-4),Vector2(-8,-4),Vector2(-4,-13)])
	_poly(points,IVORY)
	if sub == GameEnums.PawnSubType.CHESS_PAWN:
		draw_circle(Vector2(0,-25),6,INK)
		draw_circle(Vector2(0,-25),4.5,IVORY)
	elif sub == GameEnums.PawnSubType.CHESS_KNIGHT:
		draw_circle(Vector2(-3,-23),1.3,INK)
	elif sub == GameEnums.PawnSubType.CHESS_BISHOP:
		draw_line(Vector2(1,-28),Vector2(-3,-22),INK,1.8,true)
	_ellipse(Vector2(0,-3),Vector2(11,3),Color("d9d9cf"),INK)


func _draw_monopoly(sub: GameEnums.PawnSubType) -> void:
	match sub:
		GameEnums.PawnSubType.MONO_PLANE:
			_poly(PackedVector2Array([Vector2(0,-31),Vector2(4,-24),Vector2(4,-18),Vector2(14,-12),Vector2(14,-8),Vector2(3,-12),Vector2(3,-5),Vector2(7,-3),Vector2(-7,-3),Vector2(-3,-5),Vector2(-3,-12),Vector2(-14,-8),Vector2(-14,-12),Vector2(-4,-18),Vector2(-4,-24)]),Color("a7dce4"))
		GameEnums.PawnSubType.MONO_SHIP:
			_poly(PackedVector2Array([Vector2(-14,-12),Vector2(13,-12),Vector2(8,-3),Vector2(-8,-3)]),Color("b6d5df"))
			draw_rect(Rect2(-7,-20,13,8),IVORY)
			draw_rect(Rect2(-2,-27,5,8),Color("dc6554"))
		GameEnums.PawnSubType.MONO_DOG:
			_poly(PackedVector2Array([Vector2(-12,-11),Vector2(-11,-18),Vector2(-5,-17),Vector2(2,-17),Vector2(3,-26),Vector2(7,-24),Vector2(10,-27),Vector2(11,-17),Vector2(7,-14),Vector2(6,-4),Vector2(2,-4),Vector2(1,-11),Vector2(-5,-11),Vector2(-6,-4),Vector2(-10,-4)]),Color("bec4c9"))
		_:
			draw_circle(Vector2(-8,-6),4,INK)
			draw_circle(Vector2(8,-6),4,INK)
			_poly(PackedVector2Array([Vector2(-13,-10),Vector2(-11,-18),Vector2(-5,-18),Vector2(-2,-24),Vector2(6,-24),Vector2(10,-18),Vector2(13,-15),Vector2(13,-7),Vector2(-13,-7)]),Color("e36255"))
			draw_line(Vector2(-1,-21),Vector2(5,-21),IVORY,3,true)


func configure_npc(behavior: int, display_id: StringName = &"") -> void:
	npc_behavior = behavior
	_golden_top = display_id == NpcSweep.TOP_ID
	var filename: String = "NPC_ROBBER.png" if behavior == GameEnums.NpcBehavior.CHASE_NEAREST else "NPC_GHOST.png"
	if _golden_top:
		artwork = {"texture":TOP_ART, "region":PaintedFx.region(TOP_ART)}
	else:
		artwork = PawnArt.load_sprite([PawnArt.ROOT + filename])
	set_process(_golden_top)
	queue_redraw()


func _draw_npc() -> void:
	if _golden_top:
		_ellipse(Vector2(0,2), Vector2(17,5), Color(0,0,0,0.27))
		var region: Rect2 = artwork.region
		var size := region.size * (44.0 / region.size.y)
		draw_set_transform(Vector2.ZERO, sin(_top_phase) * 0.07, Vector2(0.81 + 0.19 * absf(cos(_top_phase)), 1))
		draw_texture_rect_region(TOP_ART, Rect2(Vector2(-size.x * 0.5, -size.y), size), region)
		draw_set_transform(Vector2.ZERO)
		return
	_ellipse(Vector2(0,4),Vector2(16,6),Color(0,0,0,0.3))
	_ellipse(Vector2(0,2),Vector2(14,6),Color("493567"),INK)
	_ellipse(Vector2.ZERO,Vector2(14,5),Color("8566ac"),Color("cfb2ff"))
	if not artwork.is_empty():
		var region: Rect2 = artwork.region
		var factor: float = minf(28.0/region.size.x,32.0/region.size.y)
		var size: Vector2 = region.size*factor
		draw_texture_rect_region(artwork.texture,Rect2(Vector2(-size.x/2,-size.y),size),region)
	elif npc_behavior == GameEnums.NpcBehavior.PATROL_REVERSE:
		_poly(PackedVector2Array([Vector2(-12,-5),Vector2(-12,-21),Vector2(-8,-29),Vector2(0,-32),Vector2(8,-29),Vector2(12,-21),Vector2(12,-5),Vector2(6,-9),Vector2(0,-5),Vector2(-6,-9)]),Color("74e0e7"),Color("bc73ce"),2)
		for x: int in [-4,4]:
			_ellipse(Vector2(x,-21),Vector2(3,4),Color.WHITE)
			draw_circle(Vector2(x+1,-21),1.4,INK)
	else:
		_poly(PackedVector2Array([Vector2(-10,-4),Vector2(-9,-20),Vector2(-6,-29),Vector2(0,-33),Vector2(7,-28),Vector2(10,-20),Vector2(8,-4)]),Color("514865"))
		_ellipse(Vector2(0,-21),Vector2(7,6),Color("ebc5a3"),INK)
		draw_line(Vector2(-6,-22),Vector2(6,-22),INK,5,true)
		for x: int in [-3,3]: draw_circle(Vector2(x,-22),1,IVORY)
		_ellipse(Vector2(9,-9),Vector2(6,7),WOOD,INK)
