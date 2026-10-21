# File: res://scenes/avatar_slot.gd
# Class: class_name AvatarSlot
# Role: 플레이어 아바타 칸. 사도(Spine 2D 캐릭터)의 감정 표현이 들어갈 자리로, 지금은 자리표시자(좌석 글자 + 감정 이름)를 보여 주고 res://content_trickcal/avatars/<캐릭터>/ 에 에셋이 있으면 그것을 쓴다(스프라이트 시트 frames.tres 또는 정지 이미지 portrait.png). 감정 반응은 튕김·떨림·확대 연출로 에셋 없이도 보인다
class_name AvatarSlot
extends PanelContainer

enum Emotion { IDLE, HAPPY, ANGRY, SURPRISED, SAD, CHEER }

## 감정 -> 애니메이션 이름 (frames.tres의 SpriteFrames 애니메이션 이름과 같다).
const ANIMATION_NAMES: Dictionary = {
	Emotion.IDLE: &"idle", Emotion.HAPPY: &"happy", Emotion.ANGRY: &"angry",
	Emotion.SURPRISED: &"surprised", Emotion.SAD: &"sad", Emotion.CHEER: &"cheer",
}
## 자리표시자일 때 보이는 감정 이름.
const CAPTIONS: Dictionary = {
	Emotion.HAPPY: "웃음", Emotion.ANGRY: "분노", Emotion.SURPRISED: "놀람", Emotion.SAD: "낙담", Emotion.CHEER: "환호",
}
const AVATAR_DIR: String = "res://content_trickcal/avatars"
const DEFAULT_CHARACTER: StringName = &"default"

var seat: int = 1
var character_id: StringName = DEFAULT_CHARACTER
var emotion: Emotion = Emotion.IDLE
var base_color: Color = Color("e03131")
## true면 자리표시자 배경색을 캐릭터(AvatarCatalog)의 색으로 칠한다 (아바타 선택 화면용). 게임 화면은 좌석 색을 유지한다.
var catalog_tint: bool = false
## 비어 있지 않으면 자리표시자 글자(기본 "P1" 같은 좌석 표시) 대신 이 글자를 보여 준다.
var placeholder_text: String = ""
## true면 작은 목록용 얼굴 아이콘(icon.webp)이 있을 때 애니메이션 대신 그것을 보여 준다 (선택 목록·방 좌석 등 정적인 자리).
var prefer_icon: bool = false
## 아이콘에 흰 둥근 테두리를 씌울지 (선택 목록 칸처럼 바깥에 이미 테두리가 있으면 끈다).
var icon_border: bool = true
## true면 애니메이션 프레임을 불러오지 않고 고해상도 정지 이미지(portrait.png)만 쓴다 (시작 화면의 큰 아바타처럼 크게 보이는 자리).
var static_only: bool = false
## true면 평소에는 고해상도 정지 이미지를 보여 주고, 감정 반응 동안만 애니메이션 프레임으로 바꾼다 (아바타 선택 미리보기).
var hq_idle: bool = false

var _stage: Control = null
## 둥근 창: 그림은 이 창 모양으로만 보인다 (clip_children). 그림은 창보다 OVERSCAN만큼 크게 그려 들썩여도 가장자리가 드러나지 않는다.
var _mask: Panel = null
## 맨 위 테두리: 그림이 테두리를 덮지 않게 그림 위에 따로 그린다.
var _outline: Panel = null
var _overscan: float = 0.0
var _outline_color: Color = Color.WHITE
var _sprite: AnimatedSprite2D = null
var _portrait: TextureRect = null
var _seat_label: Label = null
var _caption: Label = null
var _has_art: bool = false
var _sprite_is_emotion: bool = false
## 감정 반응 때 애니메이션을 보여 줄지.
var emotion_art: bool = true
var _tween: Tween = null
var _reset_serial: int = 0


## 캐릭터 폴더 경로 (frames.tres / portrait.png가 들어간다).
static func character_path(id: StringName) -> String:
	return "%s/%s" % [AVATAR_DIR, String(id)]


## 이 캐릭터의 에셋이 있는가 (frames.tres 또는 portrait.png).
static func has_assets(id: StringName) -> bool:
	return ResourceLoader.exists(character_path(id) + "/frames.tres") or ResourceLoader.exists(character_path(id) + "/portrait.png") or has_icon(id)


## 이 캐릭터의 얼굴 아이콘 경로 / 존재 여부.
static func icon_path(id: StringName) -> String:
	return character_path(id) + "/icon.webp"


static func has_icon(id: StringName) -> bool:
	return ResourceLoader.exists(icon_path(id))


func setup(seat_number: int, color: Color, slot_size: Vector2) -> void:
	seat = seat_number
	base_color = color
	custom_minimum_size = slot_size
	size = slot_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_overscan = ceilf(minf(slot_size.x, slot_size.y) * OVERSCAN_RATIO) + 1.0
	_mask = Panel.new()
	_mask.name = "Mask"
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(_mask)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = slot_size + Vector2.ONE * _overscan * 2.0
	_stage.position = _stage_rest()
	_stage.pivot_offset = _stage.size / 2.0
	_mask.add_child(_stage)
	_outline = Panel.new()
	_outline.name = "Outline"
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_outline)
	_apply_frame(color.lightened(0.55))
	_seat_label = Label.new()
	_seat_label.text = "P%d" % seat
	_seat_label.add_theme_font_size_override("font_size", int(slot_size.y * 0.36))
	_seat_label.add_theme_color_override("font_color", Color("0d1018"))
	_seat_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_seat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_seat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.add_child(_seat_label)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", maxi(int(slot_size.y * 0.16), 9))
	_caption.add_theme_color_override("font_color", Color("fff3bf"))
	_caption.add_theme_color_override("font_outline_color", Color("0d1018"))
	_caption.add_theme_constant_override("outline_size", 4)
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.visible = false
	_mask.add_child(_caption)
	set_character(DEFAULT_CHARACTER)


## 캐릭터를 바꾼다. 에셋이 있으면 true, 없으면 자리표시자를 보여 주고 false.
## 평소에는 작은 얼굴 아이콘(icon.webp)을 보여 준다. 큰 자리(static_only/hq_idle)만 512px 상반신 정지 그림(portrait.png)을 쓰고,
## 감정 반응 동안에만 그 감정의 애니메이션(emotion_<감정>.tres)을 불러와 보여 준 뒤 메모리에서 내린다.
func set_character(id: StringName) -> bool:
	character_id = id
	if catalog_tint:
		base_color = AvatarCatalog.color_of(id)
		_apply_frame(base_color.lightened(0.55))
	_has_art = false
	_sprite_is_emotion = false
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	if _portrait != null:
		_portrait.queue_free()
		_portrait = null
	var frames_path: String = character_path(id) + "/frames.tres"
	var portrait_path: String = character_path(id) + "/portrait.png"
	if (static_only or hq_idle) and ResourceLoader.exists(portrait_path):
		var still: Texture2D = TextureCache.fetch(portrait_path)
		if still != null:
			use_portrait(still)
	elif has_icon(id):
		var icon: Texture2D = TextureCache.fetch(icon_path(id))
		if icon != null:
			use_portrait(icon, true)
	elif ResourceLoader.exists(frames_path):
		var frames: SpriteFrames = TextureCache.fetch_frames(frames_path)
		if frames != null:
			use_frames(frames)
	elif ResourceLoader.exists(portrait_path):
		var texture: Texture2D = TextureCache.fetch(portrait_path)
		if texture != null:
			use_portrait(texture)
	_seat_label.text = placeholder_text if placeholder_text != "" else "P%d" % seat
	_seat_label.visible = not _has_art
	_sync_emotion_art()
	return _has_art


## 감정 애니메이션은 반응하는 동안에만 메모리에 올린다 (캐릭터당 감정 하나가 약 3MB).
func _sync_emotion_art() -> void:
	if _sprite != null and not _sprite_is_emotion:
		return  # frames.tres로 직접 넣은 스프라이트 시트는 그대로 둔다
	if emotion == Emotion.IDLE or not emotion_art or _portrait == null:
		_drop_emotion_art()
		return
	var path: String = "%s/emotion_%s.tres" % [character_path(character_id), String(ANIMATION_NAMES.get(emotion, &"idle"))]
	if not ResourceLoader.exists(path):
		_drop_emotion_art()
		return
	var frames: SpriteFrames = load(path) as SpriteFrames
	if frames == null:
		_drop_emotion_art()
		return
	if _sprite != null:
		_sprite.queue_free()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.material = _round_material()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_stage.add_child(_sprite)
	_sprite_is_emotion = true
	_fit_sprite()
	_portrait.visible = false
	_play_animation(emotion)


func _drop_emotion_art() -> void:
	if _sprite_is_emotion and _sprite != null:
		_sprite.stop()
		_sprite.sprite_frames = null
		_sprite.queue_free()
		_sprite = null
	_sprite_is_emotion = false
	if _portrait != null:
		_portrait.visible = true


## 스프라이트 시트(SpriteFrames)로 표시한다. 애니메이션 이름은 ANIMATION_NAMES (없는 감정은 idle로 대신).
func use_frames(frames: SpriteFrames) -> void:
	if _sprite != null:
		_sprite.queue_free()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.material = _round_material()  # 그림 모서리를 둥글게 깎아 칸 모양과 맞춘다
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 칸보다 큰 그림을 줄여 그려도 흐려지거나 깜빡이지 않게
	_stage.add_child(_sprite)
	_has_art = true
	_fit_sprite()
	_seat_label.visible = false
	_play_animation(Emotion.IDLE)


## 정지 이미지 한 장으로 표시한다 (감정은 튕김·떨림 연출로만 보인다).
func use_portrait(texture: Texture2D, as_icon: bool = false) -> void:
	if _portrait != null:
		_portrait.queue_free()
	_portrait = TextureRect.new()
	_portrait.texture = texture
	_portrait.material = _round_material()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_portrait)
	_stage.move_child(_portrait, 0)
	if as_icon and icon_border:
		_frame_icon()
	_has_art = true
	_seat_label.visible = false


const ART_RADIUS: float = 0.18
## 그림을 칸보다 크게 그리는 비율 (들썩임·흔들림 폭보다 넉넉하게).
const OVERSCAN_RATIO: float = 0.05
const ROUND_SHADER: Shader = preload("res://scenes/avatar_round.gdshader")


## 얼굴 아이콘은 정사각형 그림이 잘린 모양이라, 모서리를 둥글게 깎고 테두리를 둘러 목록 칸에 어울리게 한다.
func _round_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ROUND_SHADER
	material.set_shader_parameter("radius", ART_RADIUS)
	return material


## 얼굴 아이콘은 흰 둥근 테두리를 쓴다 (맨 위 테두리 색만 바꾼다).
func _frame_icon() -> void:
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_frame(Color.WHITE)


func has_art() -> bool:
	return _has_art


## 감정을 보여 준다. seconds 뒤에 IDLE로 돌아간다 (0이면 그대로 둔다).
func react(new_emotion: Emotion, seconds: float = 1.4) -> void:
	emotion = new_emotion
	_sync_emotion_art()
	_reset_serial += 1
	var serial: int = _reset_serial
	_play_animation(new_emotion)
	_caption.text = String(CAPTIONS.get(new_emotion, ""))
	_caption.visible = not _has_art and new_emotion != Emotion.IDLE
	_perform(new_emotion)
	if seconds > 0.0 and is_inside_tree() and new_emotion != Emotion.IDLE:
		get_tree().create_timer(seconds).timeout.connect(func() -> void:
			if serial == _reset_serial:
				react(Emotion.IDLE, 0.0))


func _play_animation(new_emotion: Emotion) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = _sprite.sprite_frames
	var wanted: StringName = ANIMATION_NAMES.get(new_emotion, &"idle")
	if not frames.has_animation(wanted):
		wanted = &"idle" if frames.has_animation(&"idle") else (frames.get_animation_names()[0] if frames.get_animation_names().size() > 0 else &"")
	if wanted != &"":
		_sprite.play(wanted)


## 첫 프레임 크기에 맞춰 스프라이트를 칸 안에 꽉 채워(높이 기준) 가운데에 둔다.
func _fit_sprite() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	var names: PackedStringArray = frames.get_animation_names()
	if names.is_empty() or frames.get_frame_count(names[0]) == 0:
		return
	var texture: Texture2D = frames.get_frame_texture(names[0], 0)
	if texture == null:
		return
	var fit: float = art_height() / maxf(texture.get_height(), 1.0)
	_sprite.scale = Vector2.ONE * fit
	_sprite.position = _stage.size / 2.0


## 감정에 맞는 짧은 몸짓과 테두리 번쩍임 (에셋이 있든 없든 보인다).
func _perform(new_emotion: Emotion) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var rest: Vector2 = _stage_rest()
	_stage.position = rest
	_stage.scale = Vector2.ONE
	_stage.modulate = Color.WHITE
	if not is_inside_tree() or new_emotion == Emotion.IDLE:
		_set_outline_color(_outline_color)
		return
	# 들썩임 폭은 칸 크기에 비례하고 항상 OVERSCAN보다 작다: 그림 가장자리가 둥근 창 안으로 들어오지 않는다.
	var hop: float = _overscan * 0.85
	var shake: float = _overscan * 0.4
	_tween = create_tween()
	match new_emotion:
		Emotion.HAPPY:
			_tween.tween_property(_stage, "position:y", rest.y - hop * 0.66, 0.12)
			_tween.tween_property(_stage, "position:y", rest.y, 0.14)
		Emotion.CHEER:
			for _i: int in 2:
				_tween.tween_property(_stage, "position:y", rest.y - hop, 0.11)
				_tween.tween_property(_stage, "position:y", rest.y, 0.11)
		Emotion.ANGRY:
			for _i: int in 3:
				_tween.tween_property(_stage, "position:x", rest.x + shake, 0.05)
				_tween.tween_property(_stage, "position:x", rest.x - shake, 0.05)
			_tween.tween_property(_stage, "position:x", rest.x, 0.05)
		Emotion.SURPRISED:
			_tween.tween_property(_stage, "scale", Vector2(1.12, 1.12), 0.1)
			_tween.tween_property(_stage, "scale", Vector2.ONE, 0.2)
		Emotion.SAD:
			_stage.modulate = Color(0.72, 0.74, 0.85)
			_tween.tween_property(_stage, "position:y", rest.y + hop * 0.45, 0.25)
	var flash: Color = {Emotion.HAPPY: Color("ffe066"), Emotion.CHEER: Color("ffd43b"), Emotion.ANGRY: Color("ff6b6b"), Emotion.SURPRISED: Color("74c0fc"), Emotion.SAD: Color("868e96")}.get(new_emotion, Color.WHITE)
	_set_outline_color(flash, false)


## 그림을 그리는 높이 (칸 + 위아래 OVERSCAN).
func art_height() -> float:
	return _stage.size.y if _stage != null else size.y


func _stage_rest() -> Vector2:
	return -Vector2.ONE * _overscan


func _corner_radius() -> int:
	return maxi(8, int(minf(custom_minimum_size.x, custom_minimum_size.y) * ART_RADIUS))


## 테두리 굵기: 큰 칸일수록 조금 두껍게 (240px 칸 = 5px, 작은 칸도 최소 4px).
func outline_width() -> int:
	return maxi(4, int(round(minf(custom_minimum_size.x, custom_minimum_size.y) * 0.022)))


## 둥근 창(배경)과 맨 위 테두리를 함께 칠한다. color는 평소 테두리 색이다.
func _apply_frame(color: Color) -> void:
	var window := StyleBoxFlat.new()
	window.bg_color = base_color.darkened(0.05)
	window.set_corner_radius_all(_corner_radius())
	window.anti_aliasing = true
	_mask.add_theme_stylebox_override("panel", window)
	_outline_color = color
	_set_outline_color(color)


func _set_outline_color(color: Color, remember: bool = true) -> void:
	if remember:
		_outline_color = color
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(outline_width())
	style.set_corner_radius_all(_corner_radius())
	style.anti_aliasing = true
	_outline.add_theme_stylebox_override("panel", style)
