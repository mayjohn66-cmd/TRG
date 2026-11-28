## 정령산 LAW_02 「정령 원기옥 (SPIRIT BOMB!)」 도입 무대 (HANDOFF-015, PRESENTATION 5.1).
## 여섯 방향에서 4원소 정령 빛방울이 머리 위 핵으로 모여 원기옥이 6단계로 커지고, 투하돼 착탄 섬광으로 만화 제목에 넘긴다.
## bad_carrot_stage·monatium_cash_stage와 같은 결정론적 Seekable 2D 무대: setup + seek(time, view) + _draw (Timer·_process·randf 없음).
extends Control

const ORB_ART: Texture2D = preload("res://assets/fx/spirit_bomb/v01/energy_orb.png")
const BLAST_ART: Texture2D = preload("res://assets/fx/spirit_bomb/v02/eruption.png")

const COUNT := 6
const GATHER_START := 0.22
const GATHER_INTERVAL := 0.23
const ORB_FLIGHT := 0.26
const DROP_START_AT := 1.88
const IMPACT_AT := 2.26
const INTRO_SECONDS := 2.86
## 이 무대가 도는 동안 배경을 어둡게 하는 정도 (LawVictoryPrelude가 읽는다).
const DIM_TARGET := 0.78
const DIM_RAMP_END := 0.85  ## 어두워지기를 마치는 시각
const FADE_SECONDS := 0.40
## 원기옥이 모이는 높이 (초점 위, 1366×768 기준 px)와 단계별 반지름 (핵 → 6번째 합류).
const HOVER := 165.0
const CORE_RADIUS := 18.0
const RADII: Array[float] = [22.0, 45.0, 68.0, 91.0, 113.0, 136.0]
## 불 · 물 · 땅 · 바람 (빛방울 묶음마다 차례로 돈다).
const ELEMENTS: Array[Color] = [Color("ff7a3d"), Color("38bdf8"), Color("c89b54"), Color("52e5b7")]
const AURA_OUTER := Color("2cc7c2")
const AURA_INNER := Color("aef5ff")
## 빛방울 묶음이 출발하는 방향 (좌상·우상·좌·우·좌하·우하, 원기옥 기준).
const SOURCES: Array[Vector2] = [
	Vector2(-520, -250), Vector2(520, -250), Vector2(-610, 40),
	Vector2(610, 40), Vector2(-470, 310), Vector2(470, 310),
]
const SPARKS := 24

var _focus := Vector2.ZERO
var _source_view := Vector2.ONE
var _time := 0.0


func setup(focus: Vector2, source_view: Vector2) -> void:
	name = "SpiritBombStage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus = focus
	_source_view = source_view


## i번째 빛방울 묶음이 출발하는 시각 (효과음 큐도 이 시각을 쓴다).
static func gather_at(index: int) -> float:
	return GATHER_START + GATHER_INTERVAL * index


## i번째 묶음이 원기옥에 닿는 시각.
static func merge_at(index: int) -> float:
	return gather_at(index) + ORB_FLIGHT


## 지금까지 합류한 묶음 수.
static func merged(time: float) -> int:
	var count := 0
	for index: int in COUNT:
		if time >= merge_at(index):
			count += 1
	return count


## 시각 t의 원기옥 반지름 (1366×768 기준 px): 합류마다 다음 단계로 탄성 있게 부푼다.
static func orb_radius(time: float) -> float:
	var count := merged(time)
	if count == 0:
		return CORE_RADIUS * smoothstep(0.0, GATHER_START, time)
	var from: float = CORE_RADIUS if count == 1 else RADII[count - 2]
	var to: float = RADII[count - 1]
	var since := time - merge_at(count - 1)
	var settle := clampf(since / 0.20, 0.0, 1.0)
	var overshoot := sin(settle * PI) * (to - from) * 0.22 * (1.0 - settle)
	return lerpf(from, to, 1.0 - pow(1.0 - settle, 3.0)) + overshoot


## 시각 t의 원기옥 중심이 초점에서 얼마나 떨어져 있나 (0 = 머리 위 HOVER, 1 = 초점에 착탄). 투하는 ease_in.
static func drop_progress(time: float) -> float:
	var t := clampf(inverse_lerp(DROP_START_AT, IMPACT_AT, time), 0.0, 1.0)
	return t * t


func seek(time: float, view: Vector2) -> void:
	if time == _time and view == size:
		return
	_time = time
	size = view
	queue_redraw()


func _ratio() -> float:
	return minf(size.x / 1366.0, size.y / 768.0)


func _target() -> Vector2:
	return _focus * size / _source_view


## 원기옥 중심 (화면 좌표).
func orb_center() -> Vector2:
	var ratio := _ratio()
	var target := _target()
	var hover := target - Vector2(0.0, HOVER) * ratio
	# Keep the painted wisps inside the viewport even on a high board focus.
	hover.y = maxf(hover.y, orb_radius(_time) * 1.4 * ratio + 20.0 * ratio)
	var center := hover.lerp(target, drop_progress(_time))
	if _time >= merged_end() and _time < DROP_START_AT:
		# 임계 팽창: 미세 진동 (시각만으로 정해진다)
		center += Vector2(sin(_time * 71.0), cos(_time * 53.0)) * 2.2 * ratio
	return center


static func merged_end() -> float:
	return merge_at(COUNT - 1)


func _draw() -> void:
	var ratio := _ratio()
	var target := _target()
	var handoff := 1.0 - smoothstep(INTRO_SECONDS, INTRO_SECONDS + FADE_SECONDS, _time)
	if handoff <= 0.0:
		return
	var impact := maxf(_time - IMPACT_AT, 0.0)
	var center := orb_center()
	var radius := orb_radius(_time) * ratio
	var burst := smoothstep(0.0, 0.18, impact)
	# 바닥 그림자: 원기옥이 클수록, 가까울수록 진해진다
	var near := 0.35 + 0.65 * drop_progress(_time)
	var shadow := Color(0.02, 0.12, 0.16, 0.42 * near * (1.0 - burst) * handoff)
	_draw_ellipse(target + Vector2(0.0, 22.0) * ratio, Vector2(radius * 1.25 + 14.0 * ratio, (radius * 0.30 + 6.0 * ratio)), shadow)
	# 빛방울 묶음: 곡선 궤적으로 원기옥에 빨려 든다
	for index: int in COUNT:
		_draw_bundle(index, center, ratio, handoff)
	if impact <= 0.0:
		if _time >= DROP_START_AT:
			_draw_tail(center, radius, ratio, handoff)
		_draw_orb(center, radius, ratio, handoff)
		if _time >= merged_end():
			_draw_arcs(center, radius, ratio, handoff)
	else:
		_draw_impact(target, impact, ratio, handoff)


func _draw_bundle(index: int, center: Vector2, ratio: float, alpha: float) -> void:
	var start_at := gather_at(index)
	var t := clampf((_time - start_at) / ORB_FLIGHT, 0.0, 1.0)
	if _time < start_at or t >= 1.0:
		return
	var color: Color = ELEMENTS[index % ELEMENTS.size()]
	var source := center + SOURCES[index] * ratio
	var bend := Vector2(-SOURCES[index].y, SOURCES[index].x).normalized() * 140.0 * ratio * (1.0 if index % 2 == 0 else -1.0)
	var control := source.lerp(center, 0.5) + bend
	for trail: int in 6:
		var u := clampf(t - trail * 0.06, 0.0, 1.0)
		var eased := u * u * (3.0 - 2.0 * u)
		var at := _bezier(source, control, center, eased)
		var fade := (1.0 - trail / 6.0) * alpha * smoothstep(0.0, 0.12, t)
		var size_px := (15.0 - trail * 1.9) * ratio
		var next := _bezier(source, control, center, minf(eased + 0.015, 1.0))
		PaintedFx.stamp(self, PaintedFx.IMPACT, at, Vector2(size_px * 4.6, size_px * 2.4), Color(color.lightened(0.3), fade * 0.75), at.angle_to_point(next))
		if trail == 0:
			PaintedFx.stamp(self, PaintedFx.FLECK, at, Vector2.ONE * 30.0 * ratio, Color(1, 1, 1, fade))


static func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


func _draw_orb(center: Vector2, radius: float, ratio: float, alpha: float) -> void:
	var charged := smoothstep(merged_end(), DROP_START_AT, _time)
	var pulse := 1.0 + sin(_time * 22.0) * 0.035 * charged
	# One painted turbulent silhouette replaces stacked geometric discs.
	PaintedFx.stamp(self, ORB_ART, center, Vector2.ONE * radius * 2.8 * pulse, Color(1, 1, 1, alpha), sin(_time * 2.0) * 0.035)
	for index: int in merged(_time):
		var angle := _time * 3.2 + index * TAU / COUNT
		var at := center + Vector2(cos(angle), sin(angle)) * radius * 0.70
		PaintedFx.stamp(self, PaintedFx.IMPACT, at, Vector2(0.42, 0.14) * radius, Color(ELEMENTS[index % ELEMENTS.size()], 0.55 * alpha), angle + PI * 0.5)


func _draw_arcs(center: Vector2, radius: float, ratio: float, alpha: float) -> void:
	var flicker := 0.55 + 0.45 * absf(sin(_time * 37.0))
	for arc: int in 6:
		var base := arc * TAU / 6.0 + _time * 1.6
		var points := PackedVector2Array()
		for step: int in 6:
			var reach := radius * (1.02 + 0.09 * step)
			var wobble := sin(_time * 48.0 + arc * 3.1 + step * 1.9) * 0.16
			points.append(center + Vector2(cos(base + wobble), sin(base + wobble)) * reach)
		draw_polyline(points, Color(AURA_INNER, 0.9 * flicker * alpha), 2.4 * ratio, true)


func _draw_tail(center: Vector2, radius: float, ratio: float, alpha: float) -> void:
	for echo: int in range(1, 5):
		var past := maxf(_time - echo * 0.035, DROP_START_AT)
		var hover := _target() - Vector2(0.0, HOVER) * ratio
		hover.y = maxf(hover.y, orb_radius(_time) * 1.4 * ratio + 20.0 * ratio)
		var at := hover.lerp(_target(), drop_progress(past))
		PaintedFx.stamp(self, ORB_ART, at, Vector2.ONE * radius * 2.8 * (1.0 - echo * 0.08), Color(AURA_OUTER, 0.13 * (1.0 - echo / 5.0) * alpha))


func _draw_impact(target: Vector2, impact: float, ratio: float, alpha: float) -> void:
	var span := INTRO_SECONDS - IMPACT_AT
	var t := clampf(impact / span, 0.0, 1.0)
	var flash := 1.0 - smoothstep(0.0, 0.16, impact)
	# A grounded cel-animation eruption: fast ignition, rising lobes, then a held cloud.
	# Its lower edge stays planted; the cloud remains through the poster crossfade.
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.76, 0.32, flash * 0.65 * alpha))
	var rise := 1.0 - pow(1.0 - clampf(impact / 0.22, 0.0, 1.0), 3.0)
	var swell := smoothstep(0.12, span + FADE_SECONDS, impact)
	var extent := Vector2(lerpf(190.0, 850.0, rise) + 110.0 * swell, lerpf(80.0, 630.0, rise) + 30.0 * swell) * ratio
	var base := Vector2(target.x, maxf(target.y + 145.0 * ratio, size.y * 0.88))
	var shake := Vector2(sin(impact * 69.0), 0.0) * 5.0 * (1.0 - t) * ratio
	PaintedFx.stamp(self, BLAST_ART, base - Vector2(0.0, extent.y * 0.5) + shake, extent, Color(1, 1, 1, alpha))
	PaintedFx.stamp(self, PaintedFx.RIPPLE, base, Vector2(1080.0, 180.0) * (0.4 + t) * ratio, Color(1.0, 0.69, 0.20, (1.0 - t) * 0.7 * alpha))
	# 4원소 불티: 정해진 각도로 방사 (시각만으로 정해진다)
	for spark: int in SPARKS:
		var angle := spark * TAU / SPARKS + 0.13 * sin(spark * 2.3)
		var reach := (120.0 + 430.0 * (0.6 + 0.4 * absf(sin(spark * 1.7)))) * (1.0 - pow(1.0 - t, 2.2)) * ratio
		var at := target + Vector2(cos(angle), sin(angle) * 0.62) * reach + Vector2(0.0, 90.0 * t * t) * ratio
		var color: Color = ELEMENTS[spark % ELEMENTS.size()]
		PaintedFx.stamp(self, PaintedFx.FLECK, at, Vector2.ONE * (26.0 * (1.0 - t) + 6.0) * ratio, Color(color.lightened(0.2), (1.0 - t) * alpha), angle)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	if color.a <= 0.0 or radii.x <= 0.0:
		return
	var points := PackedVector2Array()
	for step: int in 40:
		var angle := step * TAU / 40.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
