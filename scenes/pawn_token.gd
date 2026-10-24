## Shared 38px token, drawn at a ground-contact origin. Scale uniformly in UI.
class_name PawnToken
extends Node2D

const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const INK := Color("25252a")
const IVORY := Color("fff4d6")
const WOOD := Color("e9b875")
const BODY_BOX := Rect2(-13, -31, 26, 31)
const HIT_BOX := Rect2(-18, -34, 36, 42)
var pawn: PlayerPawn
var owner_color: Color = Color("e5484d")
var artwork: Dictionary = {}
var use_art: bool = true
var ground_shadow: bool = true
var npc_behavior: int = -1
var _signature: String = ""
var _pulse: float = 1.0


func configure(value: PlayerPawn, color: Color, images: bool = true) -> void:
	pawn = value
	owner_color = color
	use_art = images
	var art: Dictionary = PawnArt.sprite(pawn) if images else {}
	var key: String = "%s:%s:%s:%s:%s:%s:%s:%s:%s:%s" % [pawn.kind, pawn.unit_no, pawn.slot, pawn.promoted, pawn.carried.size(), pawn.skill_used, pawn.is_finished, color, pawn.revenge_boost, (art.get("texture") as Texture2D).resource_path if not art.is_empty() else "shape"]
	if key == _signature:
		return
	_signature = key
	artwork = art
	set_process(skill_ready())
	queue_redraw()


func skill_ready() -> bool:
	return pawn != null and PawnSkills.has_skill(pawn) and not pawn.skill_used and not pawn.is_finished


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_pulse = 0.7 + 0.3 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * TAU / 1400.0))
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
	# Ground shadow, thick side wall, top ring, and inset make owner color visible.
	if ground_shadow:
		_ellipse(Vector2(0, 5 + 4 * mini(pawn.carried.size(), 3)), Vector2(17, 6), Color(0, 0, 0, 0.28))
	# 업은 말은 글자(x2) 대신 받침 원판을 아래로 겹겹이 쌓아 보여 준다 (최대 3장).
	for layer: int in range(mini(pawn.carried.size(), 3), 0, -1):
		_ellipse(Vector2(0, 3 + 4 * layer), Vector2(15, 6), owner_color.darkened(0.6), INK)
		_ellipse(Vector2(0, 4 * layer), Vector2(15, 6), owner_color.darkened(0.15), INK, 1.0)
	_ellipse(Vector2(0, 3), Vector2(15, 6), owner_color.darkened(0.48), INK)
	_ellipse(Vector2.ZERO, Vector2(15, 6), owner_color, owner_color.lightened(0.5), 1.5)
	_ellipse(Vector2.ZERO, Vector2(11, 3.5), owner_color.darkened(0.3))
	if not artwork.is_empty():
		var texture: Texture2D = artwork.texture
		var region: Rect2 = artwork.region
		var factor: float = minf(BODY_BOX.size.x / region.size.x, BODY_BOX.size.y / region.size.y)
		var size: Vector2 = region.size * factor
		var rect := Rect2(Vector2(-size.x / 2.0, -size.y), size)
		if pawn.is_promoted_shogi():
			for offset: Vector2 in [Vector2(-1.4,0),Vector2(1.4,0),Vector2(0,-1.4),Vector2(0,1.4)]:
				draw_texture_rect_region(texture,Rect2(rect.position+offset,rect.size),region,Color("ff5e50"))
		for offset: Vector2 in [Vector2(-0.7, 0), Vector2(0.7, 0), Vector2(0, -0.7), Vector2(0, 0.7)]:
			draw_texture_rect_region(texture, Rect2(rect.position + offset, rect.size), region, owner_color.lightened(0.2))
		# Basic tokens use the owner's color; chess/evolved pieces retain their material.
		var body_color: Color = owner_color if pawn.kind == GameEnums.PawnKind.BASIC else Color.WHITE
		draw_texture_rect_region(texture, rect, region, body_color)
	else:
		_draw_shape()
	if pawn.is_promoted_shogi() and artwork.is_empty():
		_poly(PackedVector2Array([Vector2(0,-32),Vector2(13,-23),Vector2(11,-2),Vector2(-11,-2),Vector2(-13,-23)]), Color.TRANSPARENT, Color("ff5e50"), 2.0)
	# 슬롯 번호 배지는 그리지 않는다 (기물 그림을 가려 거슬린다는 피드백). 몇 번 말인지는 고르기 카드의 [N번 말]이 알려 준다.
	# 리벤지 부스터는 말 옆 불꽃 대신 프로필 칸이 불타는 것으로만 보여 준다 (main_board._paint_revenge_glow)
	if skill_ready():
		var bolt := PackedVector2Array([Vector2(13,-29),Vector2(8,-20),Vector2(12,-20),Vector2(10,-13),Vector2(18,-23),Vector2(14,-23)])
		_poly(bolt, Color(1,0.88,0.25,_pulse), INK, 0.9)


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
			# A meeple has arms and two feet; it stays distinct from a chess pawn.
			_poly(PackedVector2Array([Vector2(-4,-21),Vector2(4,-21),Vector2(11,-16),Vector2(9,-12),Vector2(5,-15),Vector2(6,-7),Vector2(9,-2),Vector2(3,-2),Vector2(0,-8),Vector2(-3,-2),Vector2(-9,-2),Vector2(-6,-7),Vector2(-5,-15),Vector2(-9,-12),Vector2(-11,-16)]),owner_color)
			draw_circle(Vector2(0,-26),6,INK)
			draw_circle(Vector2(0,-26),4.5,owner_color)


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


func configure_npc(behavior: int) -> void:
	npc_behavior = behavior
	var filename: String = "NPC_ROBBER.png" if behavior == GameEnums.NpcBehavior.CHASE_NEAREST else "NPC_GHOST.png"
	artwork = PawnArt.load_sprite([PawnArt.ROOT + filename])
	queue_redraw()


func _draw_npc() -> void:
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
	_draw_npc_label()


## NPC 토큰 아래 이동 방향 라벨: 사료스탕스(▶3~6칸) / 와구와구 유령(◀3~6칸).
func _draw_npc_label() -> void:
	var robber: bool = npc_behavior != GameEnums.NpcBehavior.PATROL_REVERSE
	var text: String = L10n.t("사료스탕스(▶3~6칸)" if robber else "와구와구(◀3~6칸)")
	var color: Color = Color("ffe3e3") if robber else Color("d0f4ff")
	var width: float = 76.0
	var origin := Vector2(-width / 2.0, 20.0)
	draw_rect(Rect2(origin + Vector2(0.0, -11.0), Vector2(width, 15.0)), Color(0.08, 0.02, 0.04, 0.78))
	draw_string(FONT, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, 11, color)
