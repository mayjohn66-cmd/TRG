## One neuralizer pulse, driven by the existing card announcement clock.
## Parked/zoomed cards never fire; cancelling the preview removes the light immediately.
extends Node
signal flashed
signal charging_started
const LIGHT=preload("res://scenes/neuralizer_flash.gdshader")
const LAMP_UV:=Vector2(0.306,0.374) # Actual ACT_16_LETHE_MIB_V04 device bulb.
const CHARGE_AT:=0.28
const FIRE_AT:=1.55
const END_AT:=2.22
const NOTICE_SECONDS:=2.35
var time:=0.0
var fired:=false
var flash_count:=0
var charge_count:=0
var _board_ref:WeakRef
var _announcer_ref:WeakRef
var _preview_ref:WeakRef
var _generation:=0
var _layer:CanvasLayer
var _surface:ColorRect
var _paint:ShaderMaterial
var _done:=false
var _charge_started:=false
var _charge_audio:AudioStreamPlayer
var _audio:=PresentationAudio.new()

func setup(board:Node,announcer:EventAnnouncer,preview:Control) -> void:
	name="NeuralizerFlash"
	_board_ref=weakref(board);_announcer_ref=weakref(announcer);_preview_ref=weakref(preview)
	_generation=board._fx_generation
	preview.set_meta("minimum_notice_seconds",NOTICE_SECONDS)
	_audio.start(preview)

func _process(_delta:float) -> void:
	if _done or _preview_ref==null:return
	var board:Node=_board_ref.get_ref()
	var announcer:EventAnnouncer=_announcer_ref.get_ref()
	var preview:Control=_preview_ref.get_ref()
	if board==null or announcer==null or preview==null or board._fx_generation!=_generation:
		cancel();return
	if announcer._current.get("extra")!=preview or not preview.is_visible_in_tree():
		if _layer!=null:cancel()
		return
	var art:TextureRect=preview.find_child("CardArt",true,false)
	if art==null:return
	if _layer==null:
		_layer=CanvasLayer.new();_layer.name="NeuralizerLightLayer";_layer.layer=90;add_child(_layer)
		_surface=ColorRect.new();_surface.name="NeuralizerScreenFlash"
		_surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_paint=ShaderMaterial.new();_paint.shader=LIGHT;_surface.material=_paint
		_layer.add_child(_surface)
	time=announcer._t
	if time>=END_AT:cancel();return
	if not _charge_started and time>=CHARGE_AT and time<FIRE_AT:_start_charge()
	if not fired and time>=FIRE_AT:
		if is_instance_valid(_charge_audio):_charge_audio.stop()
		fired=true;flash_count+=1;flashed.emit()
		_audio.fire(&"neuralizer_flash")
	var buildup:float=smoothstep(CHARGE_AT,FIRE_AT,time)
	var charge:float=buildup*(1.0-smoothstep(FIRE_AT,FIRE_AT+0.06,time))
	var pulse:float=smoothstep(FIRE_AT,FIRE_AT+0.025,time)*(1.0-smoothstep(FIRE_AT+0.07,FIRE_AT+0.21,time))
	var after:float=smoothstep(FIRE_AT+0.07,FIRE_AT+0.12,time)*(1.0-smoothstep(FIRE_AT+0.20,END_AT-0.06,time))
	if is_instance_valid(_charge_audio) and _charge_audio.playing:
		if GameSession.audio_muted or GameSession.sfx_muted:_charge_audio.stop()
		else:_charge_audio.volume_db=lerpf(-12.0,0.0,buildup)-25.0*smoothstep(FIRE_AT-0.035,FIRE_AT,time)
	var view:Vector2=get_viewport().get_visible_rect().size
	_surface.size=view
	_paint.set_shader_parameter("view_size",view)
	_paint.set_shader_parameter("bulb",art.get_global_transform_with_canvas()*(art.size*LAMP_UV))
	_paint.set_shader_parameter("charge",charge)
	_paint.set_shader_parameter("pulse",pulse)
	_paint.set_shader_parameter("afterglow",after)
	_paint.set_shader_parameter("buildup",buildup)

func _start_charge() -> void:
	_charge_started=true;charge_count+=1;charging_started.emit()
	if not Sfx.enabled() or GameSession.audio_muted or GameSession.sfx_muted:return
	Sfx.apply_settings()
	_charge_audio=AudioStreamPlayer.new();_charge_audio.name="NeuralizerChargeTone"
	_charge_audio.bus=Sfx.BUS_SFX;_charge_audio.volume_db=-12.0
	_charge_audio.stream=Sfx._stream_for(&"neuralizer_charge")
	add_child(_charge_audio)
	_charge_audio.play(maxf(0.0,time-CHARGE_AT))

func cancel() -> void:
	_done=true;set_process(false)
	_release_light()

func _release_light() -> void:
	_audio.cancel()
	if is_instance_valid(_charge_audio):_charge_audio.stop()
	if is_instance_valid(_layer):
		_layer.hide();_layer.queue_free()
	_layer=null;_surface=null

func _exit_tree() -> void:
	# Announcer reparents parked extras into the visible stamp. That is not a cancellation.
	_release_light()
