## A soft theatre beam: dim the scene, keep one pawn in the opening.
## Only the target is temporarily above the dimmer; no colour or gameplay change.
extends ColorRect

const LIGHT_SHADER := preload("res://assets/fx/pawn_stage_spotlight.gdshader")
var _board_ref: WeakRef
var _pawn_ref: WeakRef
var _generation := 0
var _saved_z := 0
const FOCUS_Z := 26

func illuminate(board: Node, pawn: Node2D, tint: Color, hold_time: float) -> void:
	name = "PawnStageSpotlight"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 24
	_board_ref = weakref(board)
	_pawn_ref = weakref(pawn)
	_saved_z = pawn.z_index
	pawn.z_index = FOCUS_Z
	_generation = board._fx_generation
	var light := ShaderMaterial.new()
	light.shader = LIGHT_SHADER
	light.set_shader_parameter("light_tint",tint)
	material = light
	modulate.a = 0.0
	_update_light()
	var fade := create_tween()
	fade.tween_property(self,"modulate:a",1.0,0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_interval(hold_time)
	fade.tween_property(self,"modulate:a",0.0,0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.tween_callback(queue_free)

func _exit_tree() -> void:
	if _pawn_ref!=null:
		var pawn: Node2D = _pawn_ref.get_ref()
		# A subsequent flight/ejection may already own a different draw order.
		if pawn!=null and pawn.z_index==FOCUS_Z:
			pawn.z_index = _saved_z

func _process(_delta: float) -> void:
	_update_light()

func _update_light() -> void:
	if _board_ref==null or _pawn_ref==null:
		return
	var board: Node = _board_ref.get_ref()
	var pawn: Node2D = _pawn_ref.get_ref()
	if board==null or pawn==null or board._fx_generation!=_generation:
		queue_free()
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var foot := get_global_transform().affine_inverse()*pawn.global_position
	var light := material as ShaderMaterial
	light.set_shader_parameter("frame_size",size)
	light.set_shader_parameter("foot",foot)
	# An off-screen overhead fixture, angled slightly across the stage.
	light.set_shader_parameter("source",Vector2(foot.x-135.0,minf(-45.0,foot.y-350.0)))
