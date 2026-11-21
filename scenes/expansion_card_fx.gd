extends Node2D
## Presentation only. Positions come from the resolved board event.

const PROPS := {
	&"penguin": preload("res://assets/fx/expansion_cards/penguin.png"),
	&"cover": preload("res://assets/fx/expansion_cards/cover.png"),
	&"rations": preload("res://assets/fx/expansion_cards/rations.png"),
	&"cane": preload("res://assets/board/traps/TRP_09.png"),
}
const DURATIONS := {&"penguin":0.85, &"cover":0.62, &"box_break":0.46, &"top":0.74, &"rations":0.92, &"cane":0.70, &"cane_snare":0.70}
const PENGUIN_LAUNCH_AT := 0.13
const PENGUIN_ARRIVAL_AT := 0.67

var kind: StringName
var origin: Vector2
var destination: Vector2
var contacts: PackedVector2Array
var extent := Vector2.ZERO
var elapsed := 0.0
var pace := 1.0
var duration := 1.0
var complete := false
var _audio := PresentationAudio.new()


func play(effect: StringName, start: Vector2, end: Vector2, speed: float, hits: PackedVector2Array = PackedVector2Array()) -> void:
	kind = effect
	origin = start
	destination = end
	contacts = hits
	duration = float(DURATIONS[effect])
	pace = maxf(0.1, speed)
	z_index = 76
	add_to_group("expansion_card_fx")
	var cues: Array[Dictionary] = []
	match kind:
		&"penguin":
			cues.append(PresentationAudio.cue(PENGUIN_LAUNCH_AT, &"penguin_slide", -7.0))
			var impacts: Array[float] = []
			if origin.distance_squared_to(destination) > 0.01:
				for contact: Vector2 in contacts:
					# Invert the smoothstep used for the flight so the hit sounds at contact.
					var phase := 0.5 - sin(asin(1.0 - 2.0 * _penguin_hit_progress(contact)) / 3.0)
					impacts.append(lerpf(PENGUIN_LAUNCH_AT, PENGUIN_ARRIVAL_AT, phase))
			impacts.sort()
			var last_impact := -1.0
			for impact: float in impacts:
				if impact - last_impact >= 0.08:
					cues.append(PresentationAudio.cue(impact, &"penguin_hit", -6.0))
					last_impact = impact
		&"cover":
			cues.append(PresentationAudio.cue(0.39, &"cover_drop", -6.0))
		&"box_break":
			cues.append(PresentationAudio.cue(0.03, &"cover_rip", -5.0))
		&"cane":
			cues.append(PresentationAudio.cue(0.23, &"cucumber_plant", -7.0))
		&"cane_snare":
			cues.append(PresentationAudio.cue(0.23, &"cane_snare", -5.0))
		&"rations":
			cues.append(PresentationAudio.cue(0.32, &"rations_wrap", -6.0))
		&"top":
			cues.append(PresentationAudio.cue(0.03, &"top_hit", -8.0))
			cues.append(PresentationAudio.cue(0.21, &"top_spin", -8.0))
	_audio.start(self, cues)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta / pace
	_audio.advance(elapsed)
	if elapsed >= duration:
		cancel()
	else:
		queue_redraw()


func cancel() -> void:
	_audio.cancel()
	complete = true
	hide()
	set_process(false)


func _exit_tree() -> void:
	_audio.cancel()


func _draw() -> void:
	if complete or kind.is_empty():
		return
	var opacity := 1.0 - smoothstep(duration - 0.23, duration, elapsed)
	match kind:
		&"penguin":
			_draw_penguin(opacity)
		&"cover":
			var drop := pow(smoothstep(0.06, 0.39, elapsed), 1.65)
			var bounce := sin(smoothstep(0.39, 0.54, elapsed) * PI) * 4.0
			_prop(destination + Vector2(0, -61 * (1 - drop) - bounce), 40, smoothstep(0.0, 0.10, elapsed), -0.18 * (1 - drop))
			_burst(destination + Vector2(0, 16), 0.39, Color("f5ce9b"), 51)
		&"box_break":
			_draw_box_break(opacity)
		&"rations":
			var pop := smoothstep(0.05, 0.30, elapsed)
			var nudge := sin(smoothstep(0.31, 0.68, elapsed) * TAU) * 7
			_prop(destination + Vector2(nudge, 14 * (1 - pop)), 63 * lerpf(0.65, 1.0, pop), opacity * pop, nudge * 0.019)
			_burst(destination + Vector2(0, 13), 0.32, Color("ffcf6c"), 64)
		&"cane", &"cane_snare":
			var grow := smoothstep(0.04, 0.38, elapsed)
			var height := 57.0 * grow
			var sway := sin(elapsed * 23.0) * (1.0 - smoothstep(0.27, 0.65, elapsed)) * 0.10
			PaintedFx.stamp(self, PROPS[&"cane"], destination - Vector2(0, height * 0.44), Vector2(61, height), Color(1,1,1,opacity), sway)
			_burst(destination, 0.23, Color("bfe784"), 62)
		&"top":
			_burst(destination, 0.03, Color("ffd36b"), 75)
			_burst(destination, 0.21, Color("fff2b2"), 54)


func _draw_penguin(opacity: float) -> void:
	var travel := smoothstep(PENGUIN_LAUNCH_AT, PENGUIN_ARRIVAL_AT, elapsed)
	var path := destination - origin
	var arc_height := minf(18.0, path.length() * 0.22)
	var at := _penguin_point(travel, arc_height)
	# The art faces right with the bill slightly above the body axis.
	var tangent := path - Vector2(0, cos(travel * PI) * PI * arc_height)
	var facing := -1.0 if path.x < 0.0 else 1.0
	var pitch := (atan2(tangent.y, absf(tangent.x)) + 0.22) * facing
	if travel > 0.0:
		var tail := _penguin_point(maxf(0.0, travel - 0.25), arc_height)
		PaintedFx.streak(self, tail, at, 17, Color(0.66,0.92,1,opacity * 0.78))
	var region := PaintedFx.region(PROPS[kind])
	var size := region.size * (52.0 / maxf(region.size.x, region.size.y))
	draw_set_transform(at, pitch, Vector2(facing, 1.0))
	draw_texture_rect_region(PROPS[kind], Rect2(-size / 2, size), region, Color(1,1,1,opacity))
	draw_set_transform(Vector2.ZERO)
	var distance_squared := origin.distance_squared_to(destination)
	if distance_squared > 0.01:
		for contact: Vector2 in contacts:
			var hit_progress := _penguin_hit_progress(contact)
			var flash := (1.0 - smoothstep(0.0, 0.19, travel - hit_progress)) if travel >= hit_progress else 0.0
			PaintedFx.stamp(self, PaintedFx.IMPACT, contact - Vector2(0, 12), Vector2(39,38), Color(0.78,0.94,1,flash * opacity))


func _penguin_hit_progress(contact: Vector2) -> float:
	var path := destination - origin
	return clampf((contact - origin).dot(path) / path.length_squared(), 0.0, 1.0)


func _penguin_point(progress: float, arc_height: float) -> Vector2:
	return origin.lerp(destination, progress) - Vector2(0, 16.0 + sin(progress * PI) * arc_height)


func _draw_box_break(opacity: float) -> void:
	var art: Texture2D = PROPS[&"cover"]
	var region := PaintedFx.region(art)
	var travel := smoothstep(0, duration, elapsed)
	var half_source := Vector2(region.size.x * 0.5, region.size.y)
	var half_extent := Vector2(extent.x * 0.5, extent.y)
	for index: int in 2:
		var side := -1.0 if index == 0 else 1.0
		var piece_at := destination + Vector2(side * (half_extent.x * 0.5 + travel * 24), -sin(travel * PI) * 17)
		var piece := Rect2(region.position + Vector2(half_source.x * index, 0), half_source)
		draw_set_transform(piece_at, side * travel * 0.8)
		draw_texture_rect_region(art, Rect2(-half_extent * 0.5, half_extent), piece, Color(1,1,1,opacity))
	draw_set_transform(Vector2.ZERO)
	_burst(destination + Vector2(0, 12), 0, Color("f5ce9b"), 52)


func _prop(at: Vector2, width: float, opacity: float, angle: float = 0.0) -> void:
	var texture: Texture2D = PROPS[kind]
	var region := PaintedFx.region(texture)
	var size := extent if extent != Vector2.ZERO else region.size * (width / region.size.x)
	PaintedFx.stamp(self, texture, at, size, Color(1,1,1,opacity), angle)


func _burst(at: Vector2, start: float, tint: Color, width: float) -> void:
	var progress := (elapsed - start) / 0.43
	if progress < 0 or progress >= 1:
		return
	tint.a *= 1 - progress
	PaintedFx.stamp(self, PaintedFx.RIPPLE, at, Vector2(width, width * 0.38) * lerpf(0.48, 1.12, progress), tint)
	for index: int in 4:
		var side := -1.0 if index % 2 == 0 else 1.0
		var offset := Vector2(side * (8 + index * 5) * progress, -sin(progress * PI) * (10 + index * 3))
		PaintedFx.stamp(self, PaintedFx.FLECK, at + offset, Vector2(8,12) * (1 - progress * 0.6), tint, side * 0.42)
