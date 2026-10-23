# File: res://scenes/roll_presenter.gd
# Class: class_name RollPresenter
# Role: 판정 도구 결과 연출기. 확정된 결과를 D6의 실제 3D 굴림·윷 던지기·룰렛 감속·슬롯 순차 정지·카드 플립으로 표시한다. 연출만 담당하며 결과는 절대 바꾸지 않는다
#       네모난 팝업 상자 없이 보드판 위에 바로 그린다. 기본 주사위·친치로·윷은 던진 사람 프로필에서 보드 한가운데 마당으로 날아와
#       낮아지는 반동과 접지 파문을 남긴다. 눈금 확정 즉시 입력을 풀고 "N칸 전진!" 그림만 잠시 남긴다.
class_name RollPresenter
extends PanelContainer

## 연출이 끝났다 (취소 포함). play()는 이 시그널을 await 한다.
signal finished

const SUPPORTED: Array[StringName] = [&"D6", &"CHINCHIRO", &"YUT", &"LIFE_ROULETTE", &"SLOT_777", &"HOLDEM", &"DICE_HWATU", &"DICE_MAHJONG", &"DICE_TAROT", &"REVOLVER"]
const YUT_NAMES: Dictionary = {0: "낙", 1: "도", 2: "개", 3: "걸", 4: "윷", 5: "모"}
const SLOT_SYMBOLS: Array[String] = ["체리", "레몬", "종", "BAR", "다이아", "7"]
const SUITS: Array[String] = ["♣", "◆", "♥", "♠"]
const RANKS: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
## 연출 시간(초).
const CARD_FLIP_INTERVAL: float = 0.15
const CARD_FLIP_TIME: float = 0.12
const HOLD_TIME: float = 0.35
const CARD_DEAL_TIME: float = 0.20
const ART_CARD_FLIP_TIME: float = 0.22
const TAROT_FOCUS_TIME: float = 0.22
const CARD_RESULT_HOLD: float = 0.50
## 보드 위로 던지는 도구 (팝업 없이 프로필 → 보드 한가운데로 날아온다).
const TOSS_TOOLS: Array[StringName] = [&"D6", &"CHINCHIRO", &"YUT"]
## 주사위가 손을 떠나 착지·눈금 확정까지 (3D 굴림 1초를 이 시간으로 압축한다).
const TOSS_LAND_TIME: float = 0.72
const CHINCHIRO_LAND_TIME: float = 1.12
## 윷 3D 시간 배속: 네 가락이 모두 멈추는 1.12초가 0.8초가 된다.
const YUT_TIME_SCALE: float = 1.4
## 윷 묶음의 이동은 먼저 끝내고, 이후에는 가락별 3D 비행과 착지만 보여 준다.
const YUT_TRAVEL_TIME: float = 0.42
## 큰 비행 → 낮은 튀기 → 잔구름. 화면 이동과 3D 내부 도약을 중복하지 않는다.
const TOSS_HEIGHT: float = 150.0
const TOSS_CONTACTS: Array[float] = [0.60, 0.84, 1.0]
## 결과는 작은 반동만 준다. 입력은 결과 확정 즉시 풀린다.
const PUNCH_TIME: float = 0.14
const PUNCH_SCALE: float = 1.08
const LINGER_TIME: float = 0.5
const FADE_TIME: float = 0.2
## 투척은 보드 마당 한가운데(연출 패널 자리보다 조금 아래)에 떨어진다. 그림자는 주사위 밑면에 붙는다.
const TOSS_LAND_OFFSET: Vector2 = Vector2(0.0, 52.0)
## Dice camera projects its floor origin 44 px below the texture centre.
const SHADOW_DROP: float = 44.0
const SHADOW_SIZE: Vector2 = Vector2(128.0, 46.0)

## true면 모든 연출을 0초로 건너뛴다 (헤드리스 테스트·ui_smoke 자동 진행).
var instant: bool = false
## 연출이 끝난 뒤 화면에 남은 최종 표시 문자열 (테스트가 엔진 결과와 대조한다).
var last_display: String = ""
var active: bool = false
## 연출 패널이 가운데 정렬될 화면 좌표 (창 비율에 따라 MainBoard가 갱신한다).
var center: Vector2 = Vector2(683.0, 308.0)
## 투척 출발점: 굴린 사람 프로필의 화면 좌표 (MainBoard가 굴림마다 넣는다). 모르면 화면 아래쪽에서 던진다.
var toss_from: Vector2 = Vector2(INF, INF)
## Actual projected board outline, refreshed by MainBoard on layout/view changes.
var toss_board_outline := PackedVector2Array()
## 지금(또는 방금 끝난) 연출이 보드 위 투척인가.
var tossing: bool = false
## 투척 중인 주사위가 바닥에서 떠 있는 높이 (화면 px, 테스트용).
var toss_height: float = 0.0

var _mode: StringName = &""
var _t: float = 0.0
var _total: float = 0.0
var _result: Dictionary = {}
var _power: float = 0.5
var _root: VBoxContainer = null
var _title: Label = null
var _stage: Control = null
var _die_label: Label = null
var _wheel: RouletteSpin3D = null
var _reel_stopped: Array[bool] = [false, false, false]
var _cards: Array[PanelContainer] = []
var _card_labels: Array[Label] = []
var _card_faces: Array[String] = []
var _card_flipped: Array[bool] = []
## 카드 줄 연출 공통: 뒤집을 카드 표시(이미 앞면인 카드는 false), 앞면 배경색, 카드별 글자색.
var _card_flip_mask: Array[bool] = []
var _card_front: Color = Color("f8f9fa")
var _card_face_colors: Array[Color] = []
var _settled: bool = false
var _final_face: int = 0
var _dice_3d: DiceRoll3D = null
var _default_style: StyleBoxFlat
var _card_home: Array[Vector2] = []
var _card_result_caption: String = ""
var _mahjong_3d: MahjongSlam3D = null
var _mahjong_names: Array[Label] = []
var _yut_3d: YutThrow3D = null
var _slot_3d: SlotMachine3D = null
var _toy_gun: ToyFlagGun3D = null
var _gun_intro: float = 0.0
var _gun_pull_started: bool = false
## 3D 시간 배속 (투척 도구는 압축한다).
var _speed: float = 1.0
## 결과를 보여 준 뒤 남아 있는 시간 (-1이면 남아 있지 않다). 이 동안 입력은 이미 풀려 있다.
var _linger: float = -1.0
var _ground_shadow: GroundShadow = null
var _contact_fx: ContactFX = null
var _toss_view: Control = null
var _toss_start: Vector2 = Vector2.ZERO
var _last_contact: int = -1


## 투척하는 주사위 아래 바닥에 깔리는 반투명 타원 그림자 (높이 뜨면 작고 옅어진다).
class GroundShadow extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_level = true

	func _draw() -> void:
		draw_set_transform(size / 2.0, 0.0, Vector2(1.0, size.y / maxf(size.x, 1.0)))
		for layer: int in 6:
			draw_circle(Vector2.ZERO, size.x * (0.50 - layer * 0.055), Color(0.13, 0.18, 0.09, 0.045))


## 접지한 자리에만 짧은 파문과 먼지를 남긴다. 물체와 함께 움직이지 않고 보드 바닥에 그린다.
class ContactFX extends Control:
	var marks: Array[Dictionary] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_level = true
		z_index = 1

	func _draw() -> void:
		for mark: Dictionary in marks:
			var age: float = mark["age"]
			var strength: float = mark["strength"]
			var progress: float = clampf(age / 0.20, 0.0, 1.0)
			var at: Vector2 = mark["at"]
			var radius: float = lerpf(12.0, 45.0, 1.0 - pow(1.0 - progress, 2.0)) * strength
			var ink := Color(1.0, 0.96, 0.77, (1.0 - progress) * 0.6)
			draw_set_transform(at, 0.0, Vector2(1.0, 0.32))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, ink, 1.5, true)
			draw_set_transform(Vector2.ZERO)
			for index: int in 4:
				var angle: float = PI * (0.15 + index * 0.57)
				var drift := Vector2(cos(angle), sin(angle) * 0.28) * radius
				drift.y -= sin(progress * PI) * 7.0 * strength
				draw_circle(at + drift, (1.0 - progress) * 2.8 * strength, ink, true, -1.0, true)


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101626")
	style.border_color = Color("ffd43b")
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 22
	_default_style = style
	add_theme_stylebox_override("panel", style)


static func supports(tool_id: StringName) -> bool:
	return SUPPORTED.has(tool_id)


## 3D 연출 시간이 화면에서 몇 배로 흐르는가 (투척 도구는 빠르게 압축한다).
static func speed_for(tool_id: StringName) -> float:
	match tool_id:
		&"D6": return DiceRoll3D.ROLL_TIME / TOSS_LAND_TIME
		&"CHINCHIRO": return DiceRoll3D.ROLL_TIME / CHINCHIRO_LAND_TIME
		&"YUT": return YUT_TIME_SCALE
	return 1.0


## 3D 연출의 시각(native)이 화면에서는 몇 초인가 (테스트가 윷 착지 시각 등을 맞출 때 쓴다).
static func real_time(tool_id: StringName, native: float) -> float:
	return native / speed_for(tool_id)


## 결과 연출을 재생한다. 끝나면(또는 cancel()되면) 돌아온다. instant면 아무것도 그리지 않고 바로 돌아온다.
## power: 0~1 파워 게이지 값 - 셔플 속도·회전 수·펀치 크기 같은 '연출'에만 쓰이고 결과(눈금)에는 영향이 없다.
func play(tool_id: StringName, result: Dictionary, power: float = 0.5) -> void:
	cancel()
	modulate = Color.WHITE  # 도박사 과열로 그을린 색을 지운다
	if instant or not supports(tool_id):
		last_display = _final_text(tool_id, result)
		return
	_power = clampf(power, 0.0, 1.0)
	_result = result
	if tool_id in [&"HOLDEM", &"DICE_HWATU", &"DICE_TAROT", &"DICE_MAHJONG", &"YUT", &"LIFE_ROULETTE", &"SLOT_777", &"REVOLVER"]:
		last_display = ""
	_mode = tool_id
	_t = 0.0
	_settled = false
	_speed = speed_for(tool_id)
	tossing = TOSS_TOOLS.has(tool_id)
	_build(tool_id)
	_position_center()
	if tossing:
		_begin_toss()
	active = true
	visible = true
	await finished


## 진행 중인 연출을 즉시 끝내고 숨긴다 (새 게임 등).
func cancel() -> void:
	_end_linger()
	scale = Vector2.ONE
	rotation = 0.0
	if _contact_fx != null:
		_contact_fx.marks.clear()
		_contact_fx.hide()
	modulate.a = 1.0
	if _dice_3d != null:
		_dice_3d.stop_rendering()
	if _mahjong_3d != null:
		_mahjong_3d.stop_rendering()
	if _yut_3d != null:
		_yut_3d.stop_rendering()
	if _wheel != null:
		_wheel.stop_rendering()
	if _slot_3d != null:
		_slot_3d.stop_rendering()
	if _toy_gun != null:
		_toy_gun.stop_rendering()
	if not active:
		visible = false
		return
	active = false
	visible = false
	finished.emit()


## 화면 정중앙(보드 한가운데)으로 위치를 맞춘다.
func _position_center() -> void:
	reset_size()
	position = center - size / 2.0


## 투척 준비: 던진 사람 프로필에서 출발한다. 3D 판 안의 그림자 대신 보드 바닥에 타원 그림자를 깐다.
func _begin_toss() -> void:
	var dice: bool = _mode != &"YUT"
	_last_contact = -1
	_toss_view = _dice_3d if dice else _yut_3d
	if dice and _dice_3d.shadow != null:
		_dice_3d.shadow.visible = _mode == &"CHINCHIRO"
	_toss_start = toss_from if toss_from.is_finite() else center + Vector2(0.0, 260.0)
	if _ground_shadow == null:
		_ground_shadow = GroundShadow.new()
		add_child(_ground_shadow)
	_ground_shadow.visible = _mode == &"D6"  # 친치로 그릇·윷은 3D 공간에서 깊이를 판정한다.
	# top_level은 형제 순서와 별개로 그려진다. 명시적인 z로 면 위에 그림자가 덮이지 않게 한다.
	_ground_shadow.z_index = 0
	_root.z_index = 2
	if _contact_fx == null:
		_contact_fx = ContactFX.new()
		add_child(_contact_fx)
	_contact_fx.visible = _mode != &"CHINCHIRO"
	# Result captions are screen-space overlays, not VBox layout participants.
	# Otherwise a text resize can move the label back into the die on the next sort.
	_die_label.reparent(self, false)
	_die_label.top_level = true
	_die_label.z_index = 3
	_die_label.pivot_offset = Vector2.ZERO
	if _mode == &"CHINCHIRO":
		_dice_3d.set_bowl_entry(_toss_start - center - TOSS_LAND_OFFSET)
	if _mode == &"YUT" and _yut_3d.result_value == 0:
		_configure_yut_nak()
	modulate.a = 0.0
	_update_toss(0.0)


func _configure_yut_nak() -> void:
	var origin: Vector2 = center+TOSS_LAND_OFFSET
	var direction := Vector2(1.0,0.60).normalized()
	var rim: Vector2 = origin+direction*300.0
	for index: int in toss_board_outline.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(origin,origin+direction*2000.0,toss_board_outline[index],toss_board_outline[(index+1)%toss_board_outline.size()])
		if hit != null:
			rim = hit
			break
	var end: Vector2 = rim+direction*110.0
	var start: Vector2 = origin+Vector2(YutThrow3D.FINAL_X[3]*YutThrow3D.VIEW_SIZE.y/YutThrow3D.CAMERA_SIZE,0)
	var fraction: float = start.distance_to(rim)/maxf(start.distance_to(end),1.0)
	_yut_3d.set_nak_exit(end-origin,fraction)


func _toss_ground(u: float) -> Vector2:
	var target: Vector2 = center + TOSS_LAND_OFFSET
	var direction: Vector2 = (target - _toss_start).normalized()
	var eased: float = 1.0 - pow(1.0 - u, 2.0)
	var curve: Vector2 = direction.orthogonal() * 18.0 * sin(PI * u) * (1.0 - u)
	return _toss_start.lerp(target, eased) + curve


## 실제 렌더 영역의 중심을 맞춘다. 결과 글자로 컨테이너 크기가 바뀌어도 착지한 물체는 움직이지 않는다.
func _place_toss_body(view_center: Vector2) -> void:
	pivot_offset = size / 2.0
	position = view_center - size / 2.0
	global_position += view_center - _toss_view.get_global_transform() * (_toss_view.size / 2.0)


func _update_contacts(t: float) -> void:
	_contact_fx.marks.clear()
	if _mode != &"YUT":
		for index: int in TOSS_CONTACTS.size():
			var contact: float = TOSS_CONTACTS[index]
			var age: float = t - contact * TOSS_LAND_TIME
			if age >= 0.0 and age < 0.20:
				_contact_fx.marks.append({"at": _toss_ground(contact) + Vector2(0, SHADOW_DROP), "age": age, "strength": [1.0, 0.65, 0.35][index]})
	else:
		for index: int in 4:
			var age: float = t - real_time(&"YUT", YutThrow3D.impact_time(index))
			if age >= 0.0 and age < 0.20:
				var pixel: Vector2 = _yut_3d.ground_pixel_at(index)
				var render_size := Vector2(_yut_3d.render_view.size)
				var fit: float = minf(_yut_3d.size.x / render_size.x, _yut_3d.size.y / render_size.y)
				var local: Vector2 = (_yut_3d.size - render_size * fit) / 2.0 + pixel * fit
				_contact_fx.marks.append({"at": _yut_3d.get_global_transform() * local, "age": age, "strength": 0.48})
	_contact_fx.queue_redraw()


## 포물선과 접지 시각을 공유한다. 남은 수평 속도로 조금 더 굴러간 뒤 멈춘다.
func _update_toss(t: float) -> void:
	if _mode == &"CHINCHIRO":
		_update_bowl_toss(t)
		return
	var travel: float = TOSS_LAND_TIME if _mode != &"YUT" else YUT_TRAVEL_TIME
	var u: float = clampf(t / travel, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - u, 2.0)
	var ground: Vector2 = _toss_ground(u)
	var height: float = 0.0
	var compression: float = 0.0
	if _mode != &"YUT":
		var start: float = 0.0
		for index: int in TOSS_CONTACTS.size():
			var end: float = TOSS_CONTACTS[index]
			if u <= end:
				var arc: float = clampf((u - start) / (end - start), 0.0, 1.0)
				height = 4.0 * arc * (1.0 - arc) * TOSS_HEIGHT * lerpf(0.75, 1.05, _power) * [1.0, 0.24, 0.065][index]
				break
			start = end
		for contact: float in TOSS_CONTACTS:
			var since: float = t - contact * travel
			if since >= 0.0 and since < 0.055:
				compression = maxf(compression, sin(PI * since / 0.055) * 0.045)
	toss_height = height
	var lift: float = clampf(height / TOSS_HEIGHT, 0.0, 1.0)
	var grow: float = lerpf(0.68 if _mode != &"YUT" else 0.58, 1.0, eased)
	scale = Vector2(1.0 + compression, 1.0 - compression) * grow
	var direction: Vector2 = (center + TOSS_LAND_OFFSET - _toss_start).normalized()
	rotation = direction.x * 0.10 * sin(PI * u) * (1.0 - u)
	_place_toss_body(ground + Vector2(0.0, -height))
	modulate.a = clampf(u * 6.0, 0.0, 1.0)
	if _ground_shadow != null and _ground_shadow.visible:
		var shadow_size: Vector2 = SHADOW_SIZE * grow * (1.0 - 0.5 * lift)
		_ground_shadow.size = shadow_size
		_ground_shadow.position = ground + Vector2(0.0, SHADOW_DROP * grow) - shadow_size / 2.0
		_ground_shadow.modulate.a = 1.0 - 0.7 * lift
		_ground_shadow.queue_redraw()
	_place_toss_label(ground + Vector2(0.0, -height))
	_update_contacts(t)
	if _mode != &"YUT":
		for index: int in TOSS_CONTACTS.size():
			var since: float = t - TOSS_CONTACTS[index] * travel
			if since >= 0.0 and index > _last_contact:
				_last_contact = index
				if since < 0.10 and index < 2:
					Sfx.play(&"thud", -5.0 - index * 7.0, 0.0, 1.05 + index * 0.08)


func _update_bowl_toss(t: float) -> void:
	# The dish stays on the board; only the 3D die travels into its cavity.
	toss_height = 0.0
	scale = Vector2.ONE
	rotation = 0.0
	var landed: Vector2 = center + TOSS_LAND_OFFSET
	_place_toss_body(landed)
	_place_toss_label(landed)
	modulate.a = clampf(t / 0.10, 0.0, 1.0)
	for index: int in DiceRoll3D.BOWL_CONTACTS.size():
		var since: float = t - DiceRoll3D.BOWL_CONTACTS[index] * CHINCHIRO_LAND_TIME
		if since >= 0.0 and index > _last_contact:
			_last_contact = index
			if since < 0.10:
				Sfx.play(&"mahjong_tap", -4.0-index*6.0, 0.0, 1.12+index*0.10)


## "N칸 전진!"은 주사위(윷 묶음) 바로 위에 뜬다.
func _place_toss_label(view_center: Vector2) -> void:
	if _die_label == null:
		return
	_die_label.reset_size()
	var above: float = (140.0 if _mode == &"CHINCHIRO" else (96.0 if _mode == &"YUT" else 82.0)) * scale.y
	_die_label.position = view_center + Vector2(-_die_label.size.x * _die_label.scale.x / 2.0, -above - _die_label.size.y * _die_label.scale.y)


## 결과 글자만 톡 띄우고 물체의 반동은 작게 마감한다. 입력은 이미 풀려 있다.
func _update_linger(t: float) -> void:
	var peak: float = PUNCH_SCALE if _mode == &"D6" else 1.0
	var p: float = clampf(t / PUNCH_TIME, 0.0, 1.0)
	var squash := Vector2(1.04, 0.97) if _mode == &"D6" else Vector2.ONE
	var k: Vector2
	if p < 0.3:
		k = Vector2.ONE.lerp(squash, p / 0.3)
	elif p < 0.65:
		k = squash.lerp(Vector2.ONE * peak, (p - 0.3) / 0.35)
	else:
		k = (Vector2.ONE * peak).lerp(Vector2.ONE, (p - 0.65) / 0.35)
	pivot_offset = size / 2.0
	scale = k
	rotation = 0.0
	var landed: Vector2 = center + TOSS_LAND_OFFSET
	_place_toss_body(landed - Vector2(0.0, SHADOW_DROP * (k.y - 1.0)))
	if _ground_shadow != null and _ground_shadow.visible:
		_ground_shadow.size = SHADOW_SIZE * k.x
		_ground_shadow.position = landed + Vector2(0.0, SHADOW_DROP) - _ground_shadow.size / 2.0
		_ground_shadow.modulate.a = 1.0
	if _die_label != null:
		var pop: float = clampf(t / 0.14, 0.0, 1.0)
		_die_label.scale = Vector2.ONE * Tween.interpolate_value(0.6, 0.4, pop, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT)
		_die_label.modulate.a = 1.0
	_place_toss_label(landed)
	if _mode != &"CHINCHIRO":
		_update_contacts(_total + t)
	modulate.a = 1.0 if t < LINGER_TIME else clampf(1.0 - (t - LINGER_TIME) / FADE_TIME, 0.0, 1.0)
	if t >= LINGER_TIME + FADE_TIME:
		_end_linger()


func _end_linger() -> void:
	if _linger < 0.0:
		return
	_linger = -1.0
	scale = Vector2.ONE
	modulate.a = 1.0
	if not active:
		visible = false


func _outline(label: Label, width: int) -> void:
	label.add_theme_constant_override("outline_size", width)
	label.add_theme_color_override("font_outline_color", Color("1b1f2b"))


func _process(delta: float) -> void:
	if _linger >= 0.0 and not active:
		_linger += delta
		_update_linger(_linger)
		return
	if not active:
		return
	_t += delta
	_update(_t)
	if _t >= _total:
		active = false
		# 투척은 결과를 띄운 채 잠깐 남는다 (말 이동이 바로 시작된다). 그 밖의 연출은 바로 사라진다.
		if tossing:
			_linger = 0.0
			_update_linger(0.0)
		else:
			visible = false
		if _dice_3d != null:
			_dice_3d.stop_rendering()
		if _mahjong_3d != null:
			_mahjong_3d.stop_rendering()
		if _yut_3d != null:
			_yut_3d.stop_rendering()
		if _wheel != null:
			_wheel.stop_rendering()
		if _slot_3d != null:
			_slot_3d.stop_rendering()
		if _toy_gun != null:
			_toy_gun.stop_rendering()
		finished.emit()


# ---------------------------------------------------------------------------
# 화면 구성
# ---------------------------------------------------------------------------

func _clear() -> void:
	# Keep one viewport/mesh set across rolls; it does not render when idle.
	if _dice_3d != null:
		_dice_3d.stop_rendering()
		_dice_3d.hide()
		if _dice_3d.get_parent() != self:
			_dice_3d.reparent(self)
	if _mahjong_3d != null:
		_mahjong_3d.stop_rendering()
		_mahjong_3d.hide()
		if _mahjong_3d.get_parent() != self:
			_mahjong_3d.reparent(self)
	if _yut_3d != null:
		_yut_3d.stop_rendering()
		_yut_3d.hide()
		if _yut_3d.get_parent() != self:
			_yut_3d.reparent(self)
	if _wheel != null:
		_wheel.stop_rendering()
		_wheel.hide()
		if _wheel.get_parent() != self:
			_wheel.reparent(self)
	if _slot_3d != null:
		_slot_3d.stop_rendering()
		_slot_3d.hide()
		if _slot_3d.get_parent() != self:
			_slot_3d.reparent(self)
	if _toy_gun != null:
		_toy_gun.stop_rendering()
		_toy_gun.hide()
		if _toy_gun.get_parent() != self:
			_toy_gun.reparent(self)
	for child: Node in get_children():
		if child == _dice_3d or child == _mahjong_3d or child == _yut_3d or child == _wheel or child == _slot_3d or child == _toy_gun or child == _ground_shadow or child == _contact_fx:
			continue
		remove_child(child)
		child.queue_free()
	_cards.clear()
	_card_labels.clear()
	_card_faces.clear()
	_card_flipped.clear()
	_card_flip_mask.clear()
	_card_face_colors.clear()
	_card_home.clear()
	_mahjong_names.clear()
	_reel_stopped = [false, false, false]


func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _box(bg: Color, border: Color, radius: int, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = min_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _build(tool_id: StringName) -> void:
	_clear()
	var illustrated: bool = tool_id in [&"HOLDEM", &"DICE_HWATU", &"DICE_TAROT", &"DICE_MAHJONG", &"YUT", &"LIFE_ROULETTE", &"SLOT_777", &"REVOLVER"]
	# 네모난 팝업 상자 없이 보드판 위에 바로 그린다 (글자는 굵은 외곽선으로 보드 위에서도 읽힌다)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if _ground_shadow != null:
		_ground_shadow.visible = false
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 8)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_title = _label("", 14, Color("adb5bd"))
	if illustrated:
		_title.add_theme_font_size_override("font_size", 18)
		_title.add_theme_color_override("font_color", Color("fff3bf"))
	_outline(_title, 6)
	_title.visible = not TOSS_TOOLS.has(tool_id)  # 던지는 도구는 이름표 없이 주사위만 날아온다
	_root.add_child(_title)
	_stage = CenterContainer.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)
	match tool_id:
		&"D6", &"CHINCHIRO":
			_title.text = "기본 주사위" if tool_id == &"D6" else "지하노역장 친치로"
			_total = CHINCHIRO_LAND_TIME if tool_id == &"CHINCHIRO" else TOSS_LAND_TIME
			if _dice_3d == null:
				_dice_3d = DiceRoll3D.new()
				_stage.add_child(_dice_3d)
			else:
				_dice_3d.reparent(_stage)
			_dice_3d.show()
			_final_face = int((_result.get("details", {}) as Dictionary).get("face", _result.get("steps", 1)))
			_dice_3d.begin(_final_face, _power, tool_id)
			_die_label = _label("", 34, Color("fff3bf"))
			_outline(_die_label, 10)
			_root.add_child(_die_label)
		&"YUT":
			_title.text = "전통 박달나무 윷"
			if _yut_3d == null:
				_yut_3d = YutThrow3D.new()
				_stage.add_child(_yut_3d)
			else:
				_yut_3d.reparent(_stage)
			_yut_3d.show()
			_yut_3d.set_mat_visible(false)  # 보드 마당이 곧 윷판이다
			var face: int = int((_result.get("details", {}) as Dictionary).get("face",_result.get("steps",1)))
			_total = real_time(&"YUT", YutThrow3D.result_time(face)) + 0.02
			_yut_3d.begin(face,_power)
			var caption: String = "%s · %s" % [YUT_NAMES[face],"0칸, 턴 종료" if bool(_result.get("ends_turn",false)) else _card_move_text()]
			if bool(_result.get("reroll",false)):
				caption += " · 한 번 더"
			if not bool(_result.get("ends_turn",false)):
				caption += "!"  # 보드 위로 던진 윷: "걸 · 3칸 전진!"
			_make_card_result(caption)
		&"LIFE_ROULETTE":
			_title.text = "인생게임 회전 룰렛"
			_total = RouletteSpin3D.TOTAL_TIME
			if _wheel == null:
				_wheel = RouletteSpin3D.new()
				_stage.add_child(_wheel)
			else:
				_wheel.reparent(_stage)
			_wheel.show()
			_final_face = int((_result.get("details",{}) as Dictionary).get("face",_result.get("steps",1)))
			_wheel.begin(_final_face,_power)
			var caption: String = "%d · %s" % [_final_face,_card_move_text()]
			if bool(_result.get("reroll",false)):
				caption += " · 한 번 더"
			_make_card_result(caption)
		&"REVOLVER":
			_title.text = "러시안 룰렛 · 폭죽 리볼버"
			var details: Dictionary = _result.get("details",{})
			var fired: bool = bool(details.get("fired",false))
			var progress: int = int(details.get("lost",0)) if fired else maxi(0,int(details.get("accumulated",0))-3)
			_gun_intro = ToyFlagGun3D.PREP_TIME if progress==0 and not instant else 0.0
			_gun_pull_started = _gun_intro==0.0
			_total = ToyFlagGun3D.total_time(fired)+_gun_intro
			if _toy_gun == null:
				_toy_gun = ToyFlagGun3D.new()
				_stage.add_child(_toy_gun)
			else:
				_toy_gun.reparent(_stage)
			_toy_gun.show()
			_toy_gun.begin(fired,int(details.get("accumulated",0)),int(details.get("lost",0)))
			if _gun_intro>0.0:
				_toy_gun.begin_preparation()
			_make_card_result(ToyFlagGun3D.result_caption(fired,int(details.get("accumulated",0)),int(details.get("lost",0)),bool(_result.get("can_continue",false))))
		&"SLOT_777":
			_title.text = "777 슬롯머신"
			_total = SlotMachine3D.TOTAL_TIME
			if _slot_3d == null:
				_slot_3d = SlotMachine3D.new()
				_stage.add_child(_slot_3d)
			else:
				_slot_3d.reparent(_stage)
			_slot_3d.show()
			_slot_3d.begin((_result.get("details",{}) as Dictionary).get("reels",[0,0,0]),_power)
			_make_card_result("%s · %s" % [SlotMachine3D.result_title(_slot_3d.result_values),_card_move_text()])
		&"HOLDEM":
			_build_holdem()
		&"DICE_HWATU": _build_hwatu()
		&"DICE_MAHJONG": _build_mahjong()
		&"DICE_TAROT": _build_tarot()
	pivot_offset = Vector2.ZERO


## 홀덤: 엔진이 뽑은 다섯 장을 순서대로 공개한다.
func _build_holdem() -> void:
	_title.text = "텍사스 홀덤 딜러"
	var details: Dictionary = _result.get("details", {})
	var models: Array[Dictionary] = []
	var mask: Array[bool] = []
	for card: Variant in details.get("cards", []):
		models.append(JudgmentCardArt.poker(int(card)))
		_card_faces.append(card_text(int(card)))
		mask.append(true)
	_build_illustrated_row(models, mask, Vector2(96, 144))
	_make_card_result("%s · %s" % [MainBoard.HAND_NAMES.get(details.get("hand", &"high_card"), "족보"), _card_move_text()])


## 화투: 기존 공개 패는 그대로 두고 새 패만 뒤집는다.
func _build_hwatu() -> void:
	var details: Dictionary = _result["details"]
	var all_cards: Array = details.get("cards", [])
	var fresh: Array = details.get("new_cards", [])
	_title.text = "화투 패"
	var models: Array[Dictionary] = []
	var mask: Array[bool] = []
	for card: Variant in all_cards:
		models.append(JudgmentCardArt.hwatu(int(card)))
		_card_faces.append(ToolHwatu.card_name(int(card)))
		mask.append(fresh.has(card))
	_build_illustrated_row(models, mask, Vector2(104, 148))
	_make_card_result("%s · %s" % [details.get("label", ""), _card_move_text()])


## 마작: 고정된 세 패를 0.24초 간격으로 탁, 탁, 탁 내려놓는다.
func _build_mahjong() -> void:
	var details: Dictionary = _result["details"]
	_title.text = "리치 마작 만리장성"
	_total = MahjongSlam3D.TOTAL_TIME
	if _mahjong_3d == null:
		_mahjong_3d = MahjongSlam3D.new()
		_stage.add_child(_mahjong_3d)
	else:
		_mahjong_3d.reparent(_stage)
	_mahjong_3d.show()
	_mahjong_3d.begin(details.get("tiles", []))
	var names := HBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation",0)
	_root.add_child(names)
	for tile: Variant in details.get("tiles", []):
		_card_faces.append(ToolMahjong.tile_name(int(tile)))
		_card_flipped.append(false)
		var name_label: Label = _label("",16,UiSkin.INK)
		name_label.custom_minimum_size = Vector2(118,24)
		names.add_child(name_label)
		_mahjong_names.append(name_label)
	var caption: String = "%s · %s" % [details.get("label", ""),_card_move_text()]
	if bool(_result.get("reroll",false)):
		caption += " · 한 번 더"
	_make_card_result(caption)


static func _mahjong_color(tile: int) -> Color:
	if tile >= ToolMahjong.HONOR_START:
		return [Color("495057"), Color("2b8a3e"), Color("c92a2a")][tile - ToolMahjong.HONOR_START]
	return [Color("c92a2a"), Color("1c7ed6"), Color("2b8a3e")][tile / 9]


## 타로: 뒷면 카드 5장이 놓이고 그중 한 장만 뒤집혀 운명이 드러난다.
const TAROT_SHORT: Dictionary = {&"fool": "0\n광대", &"chariot": "VII\n전차", &"wheel": "X\n수레바퀴", &"hanged": "XII\n매달린 남자", &"world": "XXI\n세계"}


func _build_tarot() -> void:
	var details: Dictionary = _result["details"]
	_title.text = "점성술사의 타로 덱"
	var flipped: int = int(details.get("flipped", 0))
	var fate: StringName = details.get("fate", &"chariot")
	var models: Array[Dictionary] = []
	var mask: Array[bool] = []
	for index: int in 5:
		models.append(JudgmentCardArt.tarot(fate if index == flipped else &""))
		_card_faces.append(str(TAROT_SHORT[fate]) if index == flipped else "?")
		mask.append(index == flipped)
	_build_illustrated_row(models, mask, Vector2(96, 156), true)
	var text: String = "%s · %s" % [JudgmentCardArt.TAROT[fate][1], "0칸, 턴 종료" if bool(_result.get("ends_turn", false)) else _card_move_text()]
	if bool(_result.get("reroll", false)):
		text += " · 한 번 더"
	if details.has("blessing_booked"):
		text += " · 다음 굴림 +%d" % int(details.blessing_booked)
	_make_card_result(text)


func _card_move_text() -> String:
	var steps: int = int(_result.get("steps", 0))
	if steps == 0:
		return "이동 없음"
	return "%d칸 전진" % maxi(steps, 0)


func _make_card_result(caption: String) -> void:
	_card_result_caption = caption
	var px: int = 30 if TOSS_TOOLS.has(_mode) else 22
	_die_label = _label("", px, Color("fff3bf"))
	_outline(_die_label, 10)
	_root.add_child(_die_label)
	var font: Font = _die_label.get_theme_font("font")
	_die_label.custom_minimum_size = Vector2(font.get_string_size(L10n.t(caption), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 24.0, px + 14.0)
	_die_label.modulate.a = 0.0


func _build_illustrated_row(models: Array[Dictionary], mask: Array[bool], card_size: Vector2, hidden_rest: bool = false) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var flips: int = 0
	for index: int in models.size():
		var card := JudgmentCard.new()
		card.configure(models[index], card_size)
		row.add_child(card)
		var already_front: bool = not mask[index] and not hidden_rest
		card.set_face_up(already_front)
		_cards.append(card)
		_card_flipped.append(already_front)
		_card_flip_mask.append(mask[index])
		_card_home.append(Vector2(index * (card_size.x + 8.0), 0.0))
		if mask[index]:
			flips += 1
	var stride: float = CARD_FLIP_INTERVAL * (1.0 if _mode == &"HOLDEM" else 2.0)
	_total = CARD_DEAL_TIME + (TAROT_FOCUS_TIME if hidden_rest else 0.0) + stride * maxi(flips - 1, 0) + ART_CARD_FLIP_TIME + CARD_RESULT_HOLD
	Sfx.play(&"card_throw")


## 카드 줄 한 벌을 만든다. mask가 true인 카드만 뒤집히고 false인 카드는 처음부터 앞면(faces)이다. hidden_rest면 false 카드는 뒷면 그대로 둔다.
func _build_flip_row(faces: Array[String], colors: Array[Color], mask: Array[bool], card_size: Vector2, back: Color, border: Color, font_px: int, hidden_rest: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(row)
	var flips: int = 0
	for index: int in faces.size():
		var flips_now: bool = mask[index]
		var already_front: bool = not flips_now and not hidden_rest
		var card: PanelContainer = _box(_card_front if already_front else back, border, 10, card_size)
		var label: Label = _label(faces[index] if already_front else "?", font_px, colors[index] if already_front else Color("f8f9fa"))
		card.add_child(label)
		row.add_child(card)
		_cards.append(card)
		_card_labels.append(label)
		_card_flipped.append(already_front or hidden_rest and not flips_now)
		_card_faces.append(faces[index])
		_card_flip_mask.append(flips_now)
		_card_face_colors.append(colors[index])
		if flips_now:
			flips += 1
	_total = CARD_FLIP_INTERVAL * maxi(flips - 1, 0) * 2.0 + CARD_FLIP_TIME + HOLD_TIME + 0.35


## 카드 번호(0~51)의 표시 문자열: 문양 + 숫자 (예: ♠A).
static func card_text(card: int) -> String:
	return "%s%s" % [SUITS[card / 13], RANKS[card % 13]]


# ---------------------------------------------------------------------------
# 시간 경과에 따른 갱신
# ---------------------------------------------------------------------------

func _update(t: float) -> void:
	match _mode:
		&"D6", &"CHINCHIRO":
			_update_toss(t)
			# Snap the endpoint exactly; multiplying the shortened timeline can
			# otherwise leave native time a float epsilon below the result frame.
			_update_3d_die(DiceRoll3D.ROLL_TIME if t >= _total else t * _speed)
		&"YUT":
			_update_toss(t)
			_update_yut(t * _speed)
		&"LIFE_ROULETTE": _update_wheel(t)
		&"SLOT_777": _update_slot(t)
		&"REVOLVER":
			if t<_gun_intro:
				_toy_gun.apply_preparation(t)
				return
			if not _gun_pull_started:
				_gun_pull_started = true
				var details: Dictionary = _result.get("details",{})
				_toy_gun.begin(bool(details.get("fired",false)),int(details.get("accumulated",0)),int(details.get("lost",0)))
			_toy_gun.apply_time(t-_gun_intro)
			if _toy_gun.settled:
				_die_label.text = _card_result_caption
				_die_label.modulate.a = 1.0
				last_display = _final_text(_mode,_result)
		&"HOLDEM", &"DICE_HWATU", &"DICE_TAROT": _update_illustrated_cards(t)
		&"DICE_MAHJONG": _update_mahjong(t)


func _update_3d_die(t: float) -> void:
	if _mode == &"CHINCHIRO":
		_dice_3d.apply_time(t)
	else:
		_dice_3d.apply_board_time(t, toss_height)
	if t >= DiceRoll3D.ROLL_TIME and not _settled:
		_settled = true
		var steps: int = int(_result.get("steps", _final_face))
		last_display = str(steps)
		var oops: bool = bool((_result.get("details", {}) as Dictionary).get("oops", false))
		_die_label.text = "삐끗! 이번 이동 0칸" if oops else "%d칸 전진!" % steps
		if oops:
			_die_label.add_theme_color_override("font_color", Color("ff8787"))


func _update_yut(t: float) -> void:
	_yut_3d.apply_time(t)
	if _yut_3d.settled:
		_die_label.text = _card_result_caption
		_die_label.modulate.a = 1.0
		last_display = str(YUT_NAMES[_yut_3d.result_value])
		if _yut_3d.result_value == 0:
			_die_label.add_theme_color_override("font_color",Color("ff8787"))


## The same physical rotor is used by the direct pad and this remote reveal.
func _update_wheel(t: float) -> void:
	_wheel.apply_time(t)
	if _wheel.settled:
		_die_label.text = _card_result_caption
		_die_label.modulate.a = 1.0
		last_display = str(_final_face)


## Three textured cylinders brake and lock one by one on the actual symbols.
func _update_slot(t: float) -> void:
	_slot_3d.apply_time(t)
	_reel_stopped = _slot_3d.stopped.duplicate()
	if _slot_3d.settled:
		_die_label.text = _card_result_caption
		_die_label.modulate.a = 1.0
		last_display = _final_text(_mode,_result)


func _update_illustrated_cards(t: float) -> void:
	var order: int = 0
	var complete: bool = true
	var is_tarot: bool = _mode == &"DICE_TAROT"
	var stride: float = CARD_FLIP_INTERVAL * (1.0 if _mode == &"HOLDEM" else 2.0)
	for index: int in _cards.size():
		var card: JudgmentCard = _cards[index] as JudgmentCard
		var dealing: float = clampf(t / CARD_DEAL_TIME, 0.0, 1.0)
		if _mode == &"DICE_HWATU" and not _card_flip_mask[index]:
			dealing = 1.0
		var remaining: float = pow(1.0 - dealing, 3.0)
		card.position = _card_home[index] + Vector2(((_cards.size() - 1) * 0.5 - index) * card.size.x * 0.7, 18.0) * remaining
		card.pivot_offset = card.size / 2.0
		card.rotation = (index - (_cards.size() - 1) * 0.5) * 0.08 * remaining
		card.modulate.a = clampf(dealing * 2.0, 0.0, 1.0)
		if not _card_flip_mask[index]:
			if is_tarot and t >= CARD_DEAL_TIME:
				card.modulate = Color(0.85, 0.85, 0.85, 1.0)
			continue
		var start: float = CARD_DEAL_TIME + (TAROT_FOCUS_TIME if is_tarot else 0.0) + order * stride
		order += 1
		if is_tarot:
			card.position.y -= 8.0 * clampf((t - CARD_DEAL_TIME) / TAROT_FOCUS_TIME, 0.0, 1.0)
		var phase: float = clampf((t - start) / ART_CARD_FLIP_TIME, 0.0, 1.0)
		card.scale.x = maxf(absf(cos(phase * PI)), 0.015)
		card.position.y -= sin(phase * PI) * 6.0
		if phase >= 0.5 and not _card_flipped[index]:
			_card_flipped[index] = true
			card.set_face_up(true)
			Sfx.play(&"card_pick")
		if phase < 1.0:
			complete = false
	if complete:
		_die_label.text = _card_result_caption
		_die_label.modulate.a = 1.0
		last_display = _final_text(_mode, _result)


func _update_mahjong(t: float) -> void:
	_mahjong_3d.apply_time(t)
	for index: int in 3:
		_card_flipped[index] = _mahjong_3d.landed[index]
		if _card_flipped[index]:
			_mahjong_names[index].text = _card_faces[index]
	if t >= MahjongSlam3D.RESULT_TIME:
		_die_label.text = _card_result_caption
		_die_label.modulate.a = 1.0
		last_display = _final_text(_mode,_result)


## Legacy flat flip renderer; current judgment tools use their own presenters.
func _update_cards(t: float) -> void:
	var order: int = 0
	for index: int in _cards.size():
		var card: PanelContainer = _cards[index]
		card.pivot_offset = card.size / 2.0
		if index < _card_flip_mask.size() and not _card_flip_mask[index]:
			continue
		var start: float = order * CARD_FLIP_INTERVAL * (2.0 if _mode != &"HOLDEM" else 1.0)
		order += 1
		if t < start:
			card.scale.x = 1.0
			continue
		var phase: float = clampf((t - start) / CARD_FLIP_TIME, 0.0, 1.0)
		if phase < 0.5:
			card.scale.x = 1.0 - phase * 2.0
		else:
			if not _card_flipped[index]:
				_card_flipped[index] = true
				_card_labels[index].text = _card_faces[index]
				var red: bool = _card_faces[index].begins_with("♥") or _card_faces[index].begins_with("◆")
				if index < _card_face_colors.size() and _mode != &"HOLDEM":
					_card_labels[index].add_theme_color_override("font_color", _card_face_colors[index])
				else:
					_card_labels[index].add_theme_color_override("font_color", Color("e03131") if red else Color("212529"))
				var style := StyleBoxFlat.new()
				style.bg_color = _card_front
				style.border_color = Color("adb5bd")
				style.set_border_width_all(3)
				style.set_corner_radius_all(10)
				style.set_content_margin_all(4)
				card.add_theme_stylebox_override("panel", style)
			card.scale.x = (phase - 0.5) * 2.0
	# 족보·결과 이름은 모든 패가 뒤집힌 뒤에야 보인다 (뒤집히기 전에 결과를 미리 알려 주지 않는다).
	var all_flipped: bool = true
	for flipped: bool in _card_flipped:
		all_flipped = all_flipped and flipped
	if all_flipped and _die_label != null and _mode in [&"DICE_HWATU", &"DICE_MAHJONG", &"DICE_TAROT"]:
		_die_label.modulate.a = 1.0
	last_display = " ".join(PackedStringArray(_card_faces)) if _mode == &"HOLDEM" else _final_text(_mode, _result)


## 연출을 건너뛰었을 때 last_display에 담을 최종 표시 문자열.
func _final_text(tool_id: StringName, result: Dictionary) -> String:
	var details: Dictionary = result.get("details", {})
	match tool_id:
		&"D6", &"CHINCHIRO": return str(int(result.get("steps", 0)))
		&"YUT": return str(YUT_NAMES.get(int(details.get("face", result.get("steps", 0))), "?"))
		&"LIFE_ROULETTE": return str(int(details.get("face", result.get("steps", 0))))
		&"REVOLVER": return "뿅!" if bool(details.get("fired",false)) else "찰칵"
		&"SLOT_777":
			var reels: Array = details.get("reels", [0, 0, 0])
			return "|".join(PackedStringArray([SLOT_SYMBOLS[int(reels[0])], SLOT_SYMBOLS[int(reels[1])], SLOT_SYMBOLS[int(reels[2])]]))
		&"HOLDEM":
			var faces: Array[String] = []
			for card: Variant in details.get("cards", []):
				faces.append(card_text(int(card)))
			return " ".join(PackedStringArray(faces))
		&"DICE_HWATU":
			var names: Array[String] = []
			for card: Variant in details.get("cards", []):
				names.append(ToolHwatu.card_name(int(card)))
			return " ".join(PackedStringArray(names))
		&"DICE_MAHJONG":
			var tile_names: Array[String] = []
			for tile: Variant in details.get("tiles", []):
				tile_names.append(ToolMahjong.tile_name(int(tile)))
			return " ".join(PackedStringArray(tile_names))
		&"DICE_TAROT": return str(details.get("name", ""))
	return ""
