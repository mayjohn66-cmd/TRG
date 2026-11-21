## Optional painted lobby icon; loaded with the lobby's artwork pack.
extends TextureRect

const FOLDER := "res://assets/ui/trickcal/lobby/"
var kind: StringName = &"hourglass"
var seat_color := Color.WHITE
var _clock := 0.0

func _init(icon_kind: StringName, color: Color) -> void:
	kind = icon_kind
	seat_color = color

func _ready() -> void:
	set_meta("lobby_icon", kind)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture = load(FOLDER + ("UI_LOBBY_WAIT.png" if kind == &"hourglass" else "UI_LOBBY_CROWN.png"))
	if kind == &"hourglass":
		var palette := ShaderMaterial.new()
		palette.shader = load(FOLDER + "wait_palette.gdshader")
		palette.set_shader_parameter("seat_color", seat_color)
		material = palette
	set_process(kind == &"hourglass")

func _process(delta: float) -> void:
	_clock += delta
	modulate.a = 0.96 + 0.04 * sin(_clock * 2.6)
