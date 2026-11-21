## One private cosmetic draw per match. Only the landscape receives blur.
extends TextureRect

const BACKGROUNDS: Array[String] = [
	"res://assets/backgrounds/match/cozy_tree_room.webp",
	"res://assets/backgrounds/match/pink_bedroom.webp",
	"res://assets/backgrounds/match/block_workshop.webp",
	"res://assets/backgrounds/match/blue_bedroom.webp",
	"res://assets/backgrounds/match/fireplace_room.webp",
	"res://assets/backgrounds/match/wooden_study.webp",
]
const BLUR: Shader = preload("res://scenes/lobby_background_blur.gdshader")
const BLUR_RADIUS_PX: float = 2.0
var selected_index: int = -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var blur := ShaderMaterial.new()
	blur.shader = BLUR
	blur.set_shader_parameter("blur_radius_px",BLUR_RADIUS_PX)
	material = blur
	_rng.randomize()
	choose_random()


func choose_random() -> void:
	select_background(_rng.randi_range(0,BACKGROUNDS.size()-1))


## Deterministic preview helper; refresh/layout/view changes never call this.
func select_background(index: int) -> void:
	selected_index = clampi(index,0,BACKGROUNDS.size()-1)
	texture = load(BACKGROUNDS[selected_index]) as Texture2D
