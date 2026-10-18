## One random user-supplied landscape per lobby scene entry; foreground stays sharp.
extends Control

const BACKGROUNDS: Array[String] = [
	"res://assets/backgrounds/lobby/market.webp",
	"res://assets/backgrounds/lobby/plaza.webp",
	"res://assets/backgrounds/lobby/meadow.webp",
	"res://assets/backgrounds/lobby/farm.webp",
]
const BLUR: Shader = preload("res://scenes/lobby_background_blur.gdshader")
const BLUR_RADIUS_PX: float = 2.0
var selected_index: int = -1
var _image: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_image = TextureRect.new()
	_image.name = "BackgroundImage"
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var blur := ShaderMaterial.new()
	blur.shader = BLUR
	blur.set_shader_parameter("blur_radius_px",BLUR_RADIUS_PX)
	_image.material = blur
	add_child(_image)
	# Cosmetic RNG is private: lobby art cannot change gameplay or match RNG.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	select_background(rng.randi_range(0,BACKGROUNDS.size()-1))


## Also allows deterministic previews of all four original backgrounds.
func select_background(index: int) -> void:
	selected_index = clampi(index,0,BACKGROUNDS.size()-1)
	_image.texture = load(BACKGROUNDS[selected_index]) as Texture2D
