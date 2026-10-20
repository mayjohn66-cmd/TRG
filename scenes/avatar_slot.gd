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
## 평소에는 작은 얼굴 아이콘(icon.webp)을 보여 준다. 큰 자리(static_only/hq_idle)만 512px 상반신 정지 그림(portrait.png)을 쓰고,
## 감정 반응 동안에만 그 감정의 애니메이션(emotion_<감정>.tres)을 불러와 보여 준 뒤 메모리에서 내린다.
func set_character(id: StringName) -> bool:
	character_id = id
	if catalog_tint:
		base_color = AvatarCatalog.color_of(id)
		add_theme_stylebox_override("panel", _frame_style(base_color.lightened(0.55)))
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
const ROUND_SHADER: Shader = preload("res://scenes/avatar_round.gdshader")


## 얼굴 아이콘은 정사각형 그림이 잘린 모양이라, 모서리를 둥글게 깎고 테두리를 둘러 목록 칸에 어울리게 한다.
func _round_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ROUND_SHADER
	material.set_shader_parameter("radius", ART_RADIUS)
	return material


func _frame_icon() -> void:
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # 칸 자체 테두리는 끄고 아래 둥근 테두리 하나만 쓴다
	var border := Panel.new()
	border.name = "IconBorder"
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color.WHITE
	style.set_border_width_all(maxi(2, int(minf(size.x, size.y) / 22.0)))
	style.set_corner_radius_all(maxi(6, int(minf(size.x, size.y) * ART_RADIUS)))
	border.add_theme_stylebox_override("panel", style)
	_stage.add_child(border)


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
	style.set_corner_radius_all(maxi(8, int(minf(size.x, size.y) * ART_RADIUS)))
	style.set_content_margin_all(0)
	return style
