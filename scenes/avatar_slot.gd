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

var _stage: Control = null
var _sprite: AnimatedSprite2D = null
var _portrait: TextureRect = null
var _seat_label: Label = null
var _caption: Label = null
var _has_art: bool = false
var _tween: Tween = null
var _reset_serial: int = 0


## 캐릭터 폴더 경로 (frames.tres / portrait.png가 들어간다).
static func character_path(id: StringName) -> String:
	return "%s/%s" % [AVATAR_DIR, String(id)]


## 이 캐릭터의 에셋이 있는가 (frames.tres 또는 portrait.png).
static func has_assets(id: StringName) -> bool:
	return ResourceLoader.exists(character_path(id) + "/frames.tres") or ResourceLoader.exists(character_path(id) + "/portrait.png")


func setup(seat_number: int, color: Color, slot_size: Vector2) -> void:
	seat = seat_number
	base_color = color
	custom_minimum_size = slot_size
	size = slot_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	add_theme_stylebox_override("panel", _frame_style(color.lightened(0.55)))
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.custom_minimum_size = slot_size
	_stage.pivot_offset = slot_size / 2.0
	add_child(_stage)
	_seat_label = Label.new()
	_seat_label.text = "P%d" % seat
	_seat_label.add_theme_font_size_override("font_size", int(slot_size.y * 0.36))
	_seat_label.add_theme_color_override("font_color", Color("0d1018"))
	_seat_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_seat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_seat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_seat_label)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", maxi(int(slot_size.y * 0.16), 9))
	_caption.add_theme_color_override("font_color", Color("fff3bf"))
	_caption.add_theme_color_override("font_outline_color", Color("0d1018"))
	_caption.add_theme_constant_override("outline_size", 4)
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.visible = false
	_stage.add_child(_caption)
	set_character(DEFAULT_CHARACTER)


## 캐릭터를 바꾼다. 에셋이 있으면 true, 없으면 자리표시자를 보여 주고 false.
func set_character(id: StringName) -> bool:
	character_id = id
	_has_art = false
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	if _portrait != null:
		_portrait.queue_free()
		_portrait = null
	var frames_path: String = character_path(id) + "/frames.tres"
	var portrait_path: String = character_path(id) + "/portrait.png"
	if ResourceLoader.exists(frames_path):
		var frames: SpriteFrames = load(frames_path) as SpriteFrames
		if frames != null:
			use_frames(frames)
	elif ResourceLoader.exists(portrait_path):
		var texture: Texture2D = load(portrait_path) as Texture2D
		if texture != null:
			use_portrait(texture)
	_seat_label.visible = not _has_art
	return _has_art


## 스프라이트 시트(SpriteFrames)로 표시한다. 애니메이션 이름은 ANIMATION_NAMES (없는 감정은 idle로 대신).
func use_frames(frames: SpriteFrames) -> void:
	if _sprite != null:
		_sprite.queue_free()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_stage.add_child(_sprite)
	_has_art = true
	_fit_sprite()
	_seat_label.visible = false
	_play_animation(Emotion.IDLE)


## 정지 이미지 한 장으로 표시한다 (감정은 튕김·떨림 연출로만 보인다).
func use_portrait(texture: Texture2D) -> void:
	if _portrait != null:
		_portrait.queue_free()
	_portrait = TextureRect.new()
	_portrait.texture = texture
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_portrait)
	_stage.move_child(_portrait, 0)
	_has_art = true
	_seat_label.visible = false


func has_art() -> bool:
	return _has_art


## 감정을 보여 준다. seconds 뒤에 IDLE로 돌아간다 (0이면 그대로 둔다).
func react(new_emotion: Emotion, seconds: float = 1.4) -> void:
	emotion = new_emotion
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
	var fit: float = size.y / maxf(texture.get_height(), 1.0)
	_sprite.scale = Vector2.ONE * fit
	_sprite.position = size / 2.0


## 감정에 맞는 짧은 몸짓과 테두리 번쩍임 (에셋이 있든 없든 보인다).
func _perform(new_emotion: Emotion) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_stage.position = Vector2.ZERO
	_stage.scale = Vector2.ONE
	_stage.modulate = Color.WHITE
	if not is_inside_tree() or new_emotion == Emotion.IDLE:
		add_theme_stylebox_override("panel", _frame_style(base_color.lightened(0.55)))
		return
	_tween = create_tween()
	match new_emotion:
		Emotion.HAPPY:
			_tween.tween_property(_stage, "position:y", -6.0, 0.12)
			_tween.tween_property(_stage, "position:y", 0.0, 0.14)
		Emotion.CHEER:
			for _i: int in 2:
				_tween.tween_property(_stage, "position:y", -9.0, 0.11)
				_tween.tween_property(_stage, "position:y", 0.0, 0.11)
		Emotion.ANGRY:
			for _i: int in 3:
				_tween.tween_property(_stage, "position:x", 4.0, 0.05)
				_tween.tween_property(_stage, "position:x", -4.0, 0.05)
			_tween.tween_property(_stage, "position:x", 0.0, 0.05)
		Emotion.SURPRISED:
			_tween.tween_property(_stage, "scale", Vector2(1.12, 1.12), 0.1)
			_tween.tween_property(_stage, "scale", Vector2.ONE, 0.2)
		Emotion.SAD:
			_stage.modulate = Color(0.72, 0.74, 0.85)
			_tween.tween_property(_stage, "position:y", 4.0, 0.25)
	var flash: Color = {Emotion.HAPPY: Color("ffe066"), Emotion.CHEER: Color("ffd43b"), Emotion.ANGRY: Color("ff6b6b"), Emotion.SURPRISED: Color("74c0fc"), Emotion.SAD: Color("868e96")}.get(new_emotion, Color.WHITE)
	add_theme_stylebox_override("panel", _frame_style(flash))


func _frame_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = base_color.darkened(0.05)
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(0)
	return style
