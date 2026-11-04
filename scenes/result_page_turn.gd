## Next page drops a complete comic report onto the screen with a single impact clock.
class_name ResultPageTurn
extends Control
signal impact
const OUT_SECONDS := 0.22
const ENTER_DELAY := 0.16
const DROP_SECONDS := 0.30
const IMPACT_AT := ENTER_DELAY+DROP_SECONDS
const HOLD_SECONDS := 0.055
const SETTLE_SECONDS := 0.30
const IN_SECONDS := DROP_SECONDS+HOLD_SECONDS+SETTLE_SECONDS
const DURATION := ENTER_DELAY+IN_SECONDS
var _comic: Control
var _detail: Control
var _elapsed := 0.0
var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE
var _base_pivot := Vector2.ZERO
var _base_rotation := 0.0
var _base_modulate := Color.WHITE
var _impact_fired := false
var _buttons: Array[Button] = []
var _disabled: Array[bool] = []
var _bam: Label

func _init() -> void:
	name="ResultPageTurn";mouse_filter=Control.MOUSE_FILTER_STOP
	set_process(false)

func begin(comic: Control, detail: Control) -> void:
	_comic=comic;_detail=detail
	_base_position=detail.position;_base_scale=detail.scale
	_base_pivot=detail.pivot_offset;_base_rotation=detail.rotation;_base_modulate=detail.modulate
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail.visible=true
	_comic.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for node: Node in detail.find_children("*","Button",true,false):
		var button := node as Button
		_buttons.append(button);_disabled.append(button.disabled);button.disabled=true
	_bam=Label.new();_bam.text="BAM!";_bam.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_bam.add_theme_font_override("font",ResultComicReport.FONT)
	_bam.add_theme_font_size_override("font_size",96)
	_bam.add_theme_color_override("font_color",Color("ffdf59"))
	_bam.add_theme_color_override("font_outline_color",ResultComicReport.INK)
	_bam.add_theme_constant_override("outline_size",12)
	add_child(_bam)
	seek(0.0);set_process(true)

func _process(delta: float) -> void:
	if not is_instance_valid(_comic) or not is_instance_valid(_detail):queue_free();return
	seek(_elapsed+delta)
	if _elapsed>=DURATION:
		_restore_detail();_comic.queue_free();queue_free()

func _restore_detail() -> void:
	if not is_instance_valid(_detail):return
	_detail.position=_base_position;_detail.scale=_base_scale
	_detail.pivot_offset=_base_pivot;_detail.rotation=_base_rotation;_detail.modulate=_base_modulate
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i: int in _buttons.size():
		if is_instance_valid(_buttons[i]):_buttons[i].disabled=_disabled[i]

func _exit_tree() -> void:_restore_detail()

func seek(seconds: float) -> void:
	_elapsed=clampf(seconds,0.0,DURATION)
	if not is_instance_valid(_comic) or not is_instance_valid(_detail):return
	var view := size if size.x>1.0 else get_viewport_rect().size
	var exit := clampf(_elapsed/OUT_SECONDS,0.0,1.0)
	_comic.position=Vector2(-view.x*0.07*exit*exit,0)
	_comic.modulate=Color(1,1,1,1.0-exit)
	var drop := clampf((_elapsed-ENTER_DELAY)/DROP_SECONDS,0.0,1.0)
	_detail.pivot_offset=view*Vector2(0.5,0.96)
	_detail.position=_base_position+Vector2(0,-view.y*1.2*(1.0-drop*drop*drop))
	_detail.rotation=_base_rotation-0.025*(1.0-drop)
	_detail.scale=_base_scale
	if _elapsed>=IMPACT_AT:
		var settle := clampf((_elapsed-IMPACT_AT-HOLD_SECONDS)/SETTLE_SECONDS,0.0,1.0)
		var rest := pow(1.0-settle,3.0)
		_detail.scale=_base_scale*Vector2(1.0+0.028*rest,1.0-0.050*rest)
		_detail.position=_base_position+Vector2(sin(settle*TAU*2.0)*view.x*0.003*rest,-sin(settle*PI)*view.y*0.013)
		_detail.rotation=_base_rotation
		if not _impact_fired:_impact_fired=true;impact.emit()
	_detail.modulate=_base_modulate
	if _bam!=null:
		var pop := clampf((_elapsed-IMPACT_AT)/0.05,0.0,1.0)
		var fade := 1.0-clampf((_elapsed-IMPACT_AT-0.12)/0.16,0.0,1.0)
		_bam.position=view*Vector2(0.76,0.64)
		_bam.rotation=-0.16
		_bam.scale=Vector2.ONE*(view.y/768.0)*lerpf(1.35,1.0,pop)
		_bam.modulate.a=pop*fade

func _gui_input(_event: InputEvent) -> void:accept_event()
