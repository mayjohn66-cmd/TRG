## 졸업 컷신 (1.01): 특수 승리(법전) 달성과 완주 피니시를 화면 전체 컷신으로 보여 준다.
## 암전 속 원인 조명 → 사도 전신·법전 그림 → 도장 → 이름·순위 → 법전 이름 → 달성 사유.
## 시계 하나(set_time)로 모든 요소가 움직여 배속·건너뛰기에서도 어긋나지 않는다. 시뮬레이션·RNG는 건드리지 않는다.
## 원인 칸(set_spots)을 주면 컷신 앞에 SPOT_SECONDS 동안 그 자리에 스포트라이트를 비춘다 (마지막 처치·빵집 도착·포위망의 말들).
class_name VictoryCutscene
extends Control

signal impact
signal prelude_impact
signal confirmed
signal completed

const MODE_LAW: StringName = &"law"
const MODE_FINISH: StringName = &"finish"
## 기본 길이(초). 실제 길이는 play()의 pace를 곱한다.
const DURATION: float = 3.2
const IMPACT_AT: float = 0.62
const LEAVE_AT: float = 2.75
const BAR_RATIO: float = 0.12
const SPOT_SECONDS: float = 0.8
const THEMED_DURATION := 4.2
const THEMED_LEAVE_AT := 3.7
const TEXT_LAYER := 100
const TRAP_DURATION := 5.2
const TRAP_HEAD_AT := 1.05
const TRAP_INFO_AT := 1.72
const THEME = preload("res://scenes/law_victory_theme.gd")
const PRELUDE = preload("res://scenes/law_victory_prelude.gd")
const SYMBOL_BACKGROUND = preload("res://scenes/victory_symbol_background.gd")
const CAPTION_PANEL = preload("res://scenes/victory_caption_panel.gd")
const COMIC_SHADOW_BLACK := Color("000000")
const TITLE_GEOMETRY=preload("res://scenes/victory_title_geometry.gd")
const TITLE_FINAL_SCALE:=0.70
const CONFIRM = preload("res://scenes/law_victory_confirm.gd")
const SPOT_GROUND=preload("res://scenes/spotlight_geometry.gd")
var _confirmation: CONFIRM
var _confirm_fired := false

var mode: StringName = MODE_LAW
var accent: Color = Color("ffd43b")
var active: bool = false
var _audio:=PresentationAudio.new()
var _time: float = 0.0
var _length: float = DURATION
var _impact_fired: bool = false
var _actor: TextureRect = null
var _art: TextureRect = null
var _headline: Label = null
var _headline_tail: Label = null
var _title: Label = null
var _subtitle: Label = null
var _name_label: Label = null
## set_time이 마지막으로 그린 시각 (_draw가 같은 시각을 쓴다).
var _time_view: float = 0.0
## 스포트라이트를 비출 화면 좌표와 그 단계의 길이(초, 배율 전). _spot_view는 지금 스포트라이트 단계 시각(-1이면 끝).
var _spots: Array[Vector2] = []
var _spot_len: float = 0.0
var _spot_view: float = -1.0
var _pace: float = 1.0
var _head_icon: TextureRect = null
var _spot_overlay: ColorRect
var _spot_material: ShaderMaterial
var _spot_reference := Vector2.ZERO
var _spot_board:WeakRef
var _spot_tiles:Array[int]=[]
var _art_frame: StyleBoxTexture
var _finish_flag: TextureRect
var _text_language := ""
var headline_style: StringName = &"themed"
var law_id := ""
var _poster: SYMBOL_BACKGROUND
var _actor_shadow: TextureRect
var _rank_label: Label
var _headline_clip: Control
var _caption_panel: CAPTION_PANEL
var _prelude: PRELUDE
var _intro_view := -1.0
var _prelude_fired := false
var _title_rig: Control
var _title_backdrop: ColorRect
var _title_bounds:=Rect2()



func _init() -> void:
	name = "VictoryCutscene"
	mouse_filter = Control.MOUSE_FILTER_STOP  # 컷신 동안 보드 입력을 막고, 누르면 건너뛴다
	set_process(false)
	resized.connect(_on_resized)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spot_overlay = ColorRect.new()
	_spot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spot_material = ShaderMaterial.new()
	_spot_material.shader = preload("res://scenes/law_spotlight.gdshader")
	_spot_overlay.material = _spot_material
	_spot_overlay.hide()
	add_child(_spot_overlay)
	move_child(_spot_overlay,0)
	set_process(active)  # 엔진이 _ready에서 _process를 다시 켜므로, play() 전에는 시계가 돌지 않게 끈다


## mode: MODE_LAW / MODE_FINISH. actor: 사도 전신 그림(없으면 생략). art: 법전 그림(완주는 null → 체크무늬 깃발).
## headline: 큰 도장 글자. title: 법전 이름 또는 순위. subtitle: 조건 또는 완주 설명. player_name: 이름 띠.
func setup(cut_mode: StringName, color: Color, actor: Texture2D, art: Texture2D, headline: String, title: String, subtitle: String, player_name: String, headline_px: int = 64) -> void:
	mode = cut_mode
	accent = color
	if actor != null:
		_actor = _make_picture("CutsceneActor", actor)
	if art != null:
		_art = _make_picture("CutsceneArt", art)
		var rounded := ShaderMaterial.new()
		rounded.shader = preload("res://scenes/law_rounded_art.gdshader")
		_art.material = rounded
		_art_frame = UiSkin.panel("panel",0)
		_art_frame.modulate_color = Color(1.12,0.92,1.08)
	if cut_mode == MODE_FINISH:
		_finish_flag = _make_picture("CutsceneFinishFlag",TextureCache.fetch("res://assets/fx/law_fx/finish_flag_v01.webp"))
		var cloth := ShaderMaterial.new()
		cloth.shader = preload("res://scenes/law_finish_flag.gdshader")
		_finish_flag.material = cloth
	_headline = _make_text("CutsceneHeadline", headline, headline_px, Color.WHITE, 12)
	_name_label = _make_text("CutscenePlayer", player_name, 30, color.lightened(0.35), 6)
	_title = _make_text("CutsceneTitle", title, 40, Color("fff3bf"), 8)
	_subtitle = _make_text("CutsceneSubtitle", subtitle, 22, Color("e9e5d7"), 4)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.max_lines_visible = 2
	_layout()
	set_time(0.0)


## 컷신 앞에 비출 원인 자리 (화면 좌표). 비어 있으면 바로 본 장면.
func set_spots(points: Array[Vector2]) -> void:
	_spot_board=null;_spot_tiles.clear()
	_spots = points.duplicate()
	_spot_reference = _view()
	_spot_len = SPOT_SECONDS if not points.is_empty() else 0.0
	if _prelude!=null:
		_prelude.spots = _spots.duplicate()

## Live board anchors survive aspect/layout offsets and world-only camera moves.
func set_board_spots(board:Node,tiles:Array) -> void:
	var points:Array[Vector2]=[]
	for index:Variant in tiles:points.append(SPOT_GROUND.tile_screen(board,int(index)))
	if points.is_empty():points.append(SPOT_GROUND.center_screen(board))
	set_spots(points)
	_spot_board=weakref(board)
	for index:Variant in tiles:_spot_tiles.append(int(index))

func _update_spotlight_geometry(view:Vector2) -> void:
	if _spot_overlay==null:return
	_spot_overlay.visible=_spot_view>=0.0
	if not _spot_overlay.visible:return
	_spot_overlay.size=view
	var points:=PackedVector2Array()
	var board:Node=_spot_board.get_ref() if _spot_board!=null else null
	var axes:=Transform2D(Vector2(34.93,22.17),Vector2(-34.93,22.17),Vector2.ZERO)
	if board!=null:
		for index:int in _spot_tiles.slice(0,16):points.append(SPOT_GROUND.into_overlay(_spot_overlay,SPOT_GROUND.tile_screen(board,index)))
		if _spot_tiles.is_empty():points.append(SPOT_GROUND.into_overlay(_spot_overlay,SPOT_GROUND.center_screen(board)))
		axes=SPOT_GROUND.floor_axes(board,_spot_overlay)
	else:
		var ratio:=view/_spot_reference if _spot_reference.x>0 and _spot_reference.y>0 else Vector2.ONE
		for point:Vector2 in _spots.slice(0,16):points.append(SPOT_GROUND.into_overlay(_spot_overlay,point*ratio))
		axes=Transform2D(axes.x*ratio,axes.y*ratio,Vector2.ZERO)
	var count:int=points.size()
	while points.size()<16:points.append(Vector2(-9999,-9999))
	_spot_material.set_shader_parameter("view_size",view)
	_spot_material.set_shader_parameter("spots",points)
	_spot_material.set_shader_parameter("spot_count",count)
	_spot_material.set_shader_parameter("floor_axis_x",axes.x)
	_spot_material.set_shader_parameter("floor_axis_y",axes.y)
	_spot_material.set_shader_parameter("strength",_ramp(_spot_view,0.0,0.18)*(1.0-_ramp(_spot_view,_spot_len-0.12,_spot_len)))


## The winner keeps their own victory portrait; each law owns the stage and typeface.
func set_law_context(id: String, board_center: Vector2, avatar: StringName, winner_name: String, rank_no: int) -> void:
	if THEME.of(id).is_empty(): return
	law_id = id
	if id.begins_with("LAW_"):
		_spot_len = CONFIRM.DURATION
		if _spot_reference == Vector2.ZERO: _spot_reference = _view()
		_confirmation = CONFIRM.new()
		_confirmation.name = "LawConditionConfirmed"
		add_child(_confirmation)
		_confirmation.setup(THEME.law_label(id),Color(str(THEME.of(id)["accent"])),Color(str(THEME.of(id)["ink"])))
	clip_contents = true
	var words := THEME.headline(id).split("\n")
	_headline.text = words[0]
	if words.size()>1:
		_headline_tail = _make_text("CutsceneHeadlineTail",words[1],100,Color.WHITE,0)
	_headline.set_meta("cutscene_font",100)
	_headline.set_meta("cutscene_outline",0)
	if id!="FINISH": _title.text = THEME.law_label(id)
	_name_label.text = winner_name
	set_meta("winner_rank",rank_no)
	_rank_label = _make_text("CutsceneRank","",24,Color.WHITE,0)
	_rank_label.hide()
	_rank_label.set_meta("cutscene_outline",0)
	_poster = SYMBOL_BACKGROUND.new()
	add_child(_poster)
	_poster.setup(id)
	move_child(_poster,0)
	var portrait := AvatarCombatArt.texture(avatar,&"victory")
	if _actor==null: _actor = _make_picture("CutsceneActor",portrait)
	else: _actor.texture = portrait
	var actor_material := ShaderMaterial.new()
	actor_material.shader = preload("res://scenes/victory_actor.gdshader")
	actor_material.set_shader_parameter("pop_art",true)
	actor_material.set_shader_parameter("backdrop_mix",0.0)
	if id!="FINISH":
		actor_material.set_shader_parameter("scene_blend",0.80)
		actor_material.set_shader_parameter("paper_tone",Color(str(THEME.PAPERS[id])))
		actor_material.set_shader_parameter("ink_tone",Color(str(THEME.of(id)["ink"])))
	_actor.material = actor_material
	_actor_shadow = _make_picture("VictoryPortraitSilhouette",portrait)
	var shadow := actor_material.duplicate() as ShaderMaterial
	shadow.set_shader_parameter("silhouette",true)
	shadow.set_shader_parameter("ink",Color(str(THEME.of(id)["accent" if id=="FINISH" else "ink"])))
	_actor_shadow.material = shadow
	move_child(_actor_shadow,_actor.get_index())
	_prelude = PRELUDE.new()
	add_child(_prelude)
	move_child(_prelude,0)
	_prelude.setup(id,board_center,_view(),_spots)
	if id == "LAW_09" and _spot_board != null:
		var board: Node = _spot_board.get_ref()
		if board != null:
			_prelude._hurricane.set_board_context(board)
	_prelude.set_scene_palette(Color(str(THEME.PAPERS[id])),Color(str(THEME.of(id)["ink"])))
	var poster_ink:=_poster._pattern.material as ShaderMaterial
	poster_ink.set_shader_parameter("paper_tone",Color(str(THEME.PAPERS[id])))
	poster_ink.set_shader_parameter("ink_tone",Color(str(THEME.of(id)["ink"])))
	poster_ink.set_shader_parameter("scene_blend",0.70 if id!="FINISH" else 0.0)
	if id in ["LAW_01","LAW_02","LAW_03","LAW_06","LAW_07","LAW_08","LAW_09"]: move_child(_prelude,_poster.get_index()+1)
	_prelude.hide()
	if id=="LAW_03":
		_caption_panel=CAPTION_PANEL.new();add_child(_caption_panel)
		_headline_clip=Control.new();_headline_clip.name="TrapHeadlineWindow";_headline_clip.clip_contents=true;_headline_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(_headline_clip);_headline.reparent(_headline_clip);_headline_tail.reparent(_headline_clip)
		_actor.z_index=20;_actor_shadow.z_index=19
	_title_rig=Control.new();_title_rig.name="VictoryTitleRig";_title_rig.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_title_rig)
	_headline.reparent(_title_rig)
	if _headline_tail!=null:_headline_tail.reparent(_title_rig)
	_title_backdrop=ColorRect.new();_title_backdrop.name="TitleRadialBackdrop";_title_backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_title_backdrop.z_index=TEXT_LAYER-1
	var backdrop_material:=ShaderMaterial.new();backdrop_material.shader=preload("res://scenes/victory_title_backdrop.gdshader")
	_title_backdrop.material=backdrop_material;_title_rig.add_child(_title_backdrop)
	_layout()
	set_time(0.0)

func set_finish_context(avatar: StringName, winner_name: String, rank_no: int) -> void:
	set_law_context("FINISH",Vector2.ZERO,avatar,winner_name,rank_no)

## Retired local paper previews also resolve to the original dedicated headline fonts.
func set_headline_style(_style: StringName) -> void:
	headline_style=&"themed"
	if _headline!=null and law_id!="":
		_layout();set_time(_time_view)

func _refresh_comic_shadows() -> void:
	var ratio:=minf(_view().x/1366.0,_view().y/768.0)
	var palette: Dictionary=THEME.COMIC_TITLES.get(law_id,{})
	for label: Label in [_headline,_headline_tail]:
		if label==null:continue
		label.self_modulate=Color.WHITE
		var block:=label.get_node_or_null("ComicBlockShadow") as Control
		if palette.is_empty():
			if block!=null:block.free()
			continue
		if block==null:
			block=Control.new();block.name="ComicBlockShadow"
			block.mouse_filter=Control.MOUSE_FILTER_IGNORE;block.show_behind_parent=true
			label.add_child(block)
			# Overlapping native glyph silhouettes form two solid, unblurred extrusions.
			# The whole subtree is behind its real Label, inheriting the same fade/rotation.
			for layer: int in 2:
				for step: int in range(4,0,-1):
					var silhouette:=Label.new();silhouette.mouse_filter=Control.MOUSE_FILTER_IGNORE
					silhouette.name=("Black" if layer==0 else "ThemeColor")+str(step)
					block.add_child(silhouette)
		block.size=label.size
		for i: int in block.get_child_count():
			var silhouette:=block.get_child(i) as Label
			var layer:=i/4;var step:=4-i%4
			var distance:=10.0+float(step)*2.0 if layer==0 else float(step)*2.5
			var color:=COMIC_SHADOW_BLACK if layer==0 else Color(str(palette["shadow"]))
			silhouette.text=label.text;silhouette.size=label.size
			silhouette.position=Vector2(distance,distance*1.1)*ratio
			silhouette.add_theme_font_override("font",label.get_theme_font("font"))
			silhouette.add_theme_font_size_override("font_size",label.get_theme_font_size("font_size"))
			silhouette.add_theme_constant_override("outline_size",label.get_theme_constant("outline_size"))
			silhouette.add_theme_color_override("font_color",color)
			silhouette.add_theme_color_override("font_outline_color",color)
			silhouette.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)

func _layout_title_rig() -> void:
	var ratio:=minf(_view().x/1366.0,_view().y/768.0)
	for label: Label in [_headline,_headline_tail]:
		if label!=null:label.scale=Vector2.ONE
	var first:=TITLE_GEOMETRY.ink_bounds(_headline,law_id+":0")
	_headline.position=Vector2.ZERO;_headline.pivot_offset=Vector2.ZERO
	if _headline_tail!=null:
		var second:=TITLE_GEOMETRY.ink_bounds(_headline_tail,law_id+":1")
		_headline_tail.position=Vector2(_view().x*0.08,first.end.y-second.position.y+14.0*ratio)
		_headline_tail.pivot_offset=Vector2.ZERO
	var have_bounds:=false
	for label: Label in [_headline,_headline_tail]:
		if label==null:continue
		var key:=law_id+(":0" if label==_headline else ":1")
		var ink:=TITLE_GEOMETRY.ink_bounds(label,key).grow(float(label.get_theme_constant("outline_size")))
		ink.size+=Vector2(18,20)*ratio
		var transform:=label.get_transform()
		var a:=transform*ink.position;var b:=a
		for point: Vector2 in [Vector2(ink.end.x,ink.position.y),ink.end,Vector2(ink.position.x,ink.end.y)]:
			var p:=transform*point;a=a.min(p);b=b.max(p)
		var box:=Rect2(a,b-a)
		_title_bounds=_title_bounds.merge(box) if have_bounds else box;have_bounds=true
		if law_id in ["FINISH","LAW_05"]:
			var solid:=label.get_node_or_null("SolidCounterFill") as TITLE_GEOMETRY
			if solid==null:solid=TITLE_GEOMETRY.new();label.add_child(solid)
			solid.configure(label,key)
	for label: Label in [_headline,_headline_tail]:
		if label!=null:label.position-=_title_bounds.position
	_title_bounds.position=Vector2.ZERO
	_title_rig.size=_title_bounds.size
	_title_backdrop.position=-Vector2(32,24)*ratio
	_title_backdrop.size=_title_bounds.size+Vector2(64,48)*ratio

func _pose_title(t: float, before: bool, leave: float) -> void:
	var view:=_view()
	var final_scale:=minf(TITLE_FINAL_SCALE,minf(view.x*0.60/_title_bounds.size.x,view.y*0.34/_title_bounds.size.y))
	_title_rig.scale=Vector2.ONE*final_scale
	_title_rig.position=view*Vector2(0.105 if law_id=="LAW_04" else 0.035,0.08 if _headline_tail==null else 0.025)
	_title_rig.visible=not before
	_headline.modulate.a=_ease_out(_ramp(t,0.06,0.22))*(1-leave)
	if _headline_tail!=null:_headline_tail.modulate.a=_ease_out(_ramp(t,0.12,0.28))*(1-leave)
	_title_backdrop.modulate.a=_headline.modulate.a

func title_screen_bounds() -> Rect2:
	return Rect2(_title_rig.position,_title_bounds.size*_title_rig.scale)

func headline_text() -> String:
	return _headline.text+("\n"+_headline_tail.text if _headline_tail!=null else "")


func _duration() -> float:
	return TRAP_DURATION if law_id=="LAW_03" else (THEMED_DURATION if law_id!="" else DURATION)


func _intro_duration() -> float:
	return PRELUDE.duration_for(law_id) if _prelude!=null else 0.0

func _finale_impact_at() -> float:
	if law_id=="LAW_03":return TRAP_HEAD_AT+0.20
	return PRELUDE.MOCHI.HANDOFF_SECONDS if law_id=="LAW_01" else IMPACT_AT


## 도장 위에 띄울 아이콘 (법전 성립의 두루마리 등).
func set_head_icon(texture: Texture2D) -> void:
	if texture == null:
		return
	_head_icon = _make_picture("CutsceneHeadIcon", texture)
	_layout()
	set_time(0.0)


## 재생을 시작한다. pace: 연출 시간 배율 (1.0 = DURATION초).
func play(pace: float = 1.0) -> void:
	_pace = maxf(pace, 0.1)
	_length = (_duration()+_intro_duration()+_spot_len) * _pace
	_time = 0.0
	_spot_view = 0.0 if _spot_len > 0.0 else -1.0
	_impact_fired = false
	_prelude_fired = false
	_confirm_fired = false
	_intro_view = 0.0 if _prelude!=null and _spot_len==0 else -1.0
	active = true
	visible = true
	_audio.start(self,PresentationAudio.victory_plan(law_id,_spot_len,_intro_duration()+_finale_impact_at(),_confirmation!=null))
	set_time(0.0)
	set_process(true)


func skip() -> void:
	if not active:
		return
	if not _impact_fired:
		_impact_fired = true
		impact.emit()
	_finish()


func _gui_input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (_main_time()>IMPACT_AT or _intro_view>=PRELUDE.impact_at(law_id)):
		accept_event()
		skip()


## 본 장면 시각 (스포트라이트 단계를 뺀 배율 전 초).
func _main_time() -> float:
	return _time / _pace - _spot_len - _intro_duration()


func _process(delta: float) -> void:
	_time += delta
	_audio.advance(_time/_pace)
	if _confirmation != null and not _confirm_fired and _time/_pace >= CONFIRM.HIT_AT:
		_confirm_fired = true
		confirmed.emit()
	if _prelude!=null and not _prelude_fired and _time/_pace>=_spot_len+PRELUDE.impact_at(law_id):
		_prelude_fired = true
		prelude_impact.emit()
	var t: float = _main_time()
	if t < 0.0:
		var elapsed := _time/_pace
		_spot_view = elapsed if elapsed<_spot_len else -1.0
		_intro_view = elapsed-_spot_len if elapsed>=_spot_len else -1.0
		set_time(0.0)
		return
	_spot_view = -1.0
	_intro_view = -1.0
	if not _impact_fired and t >= _finale_impact_at():
		_impact_fired = true
		impact.emit()
	set_time(t)
	if t >= _duration():
		_finish()


## Reset/cancel releases the presentation queue without inventing an impact.
func cancel() -> void:
	if active: _finish()


func _finish() -> void:
	_audio.cancel()
	active = false
	set_process(false)
	visible = false
	completed.emit()


func _make_picture(node_name: String, texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _make_text(node_name: String, text: String, font_size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.z_index = TEXT_LAYER
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FontSizes.snap(font_size))
	label.set_meta("cutscene_font",FontSizes.snap(font_size))
	label.set_meta("cutscene_outline",outline)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("15111c"))
	label.add_theme_constant_override("outline_size", outline)
	add_child(label)
	return label


func _view() -> Vector2:
	var view: Vector2 = size
	if view.x < 2.0 or view.y < 2.0:
		view = get_viewport_rect().size
	return view


func _on_resized() -> void:
	if _headline == null: return
	_layout()
	set_time(_time_view)

func _layout() -> void:
	if law_id!="":
		_layout_themed()
		return
	var view: Vector2 = _view()
	var text_ratio := minf(1.0,minf(view.x/1366.0,view.y/768.0))
	var side: float = minf(view.y * 0.62, view.x * 0.36)
	if _actor != null:
		_actor.size = Vector2(side, side)
		_actor.pivot_offset = _actor.size * 0.5
	if _art != null:
		_art.size = Vector2(side * 0.72, side * 0.72)
		_art.pivot_offset = _art.size * 0.5
		(_art.material as ShaderMaterial).set_shader_parameter("frame_size",_art.size)
	if _head_icon != null:
		_head_icon.size = Vector2.ONE * 72.0 * text_ratio
		_head_icon.pivot_offset = _head_icon.size * 0.5
	if _finish_flag != null:
		_finish_flag.size = Vector2.ONE * side * 0.82
		_finish_flag.pivot_offset = _finish_flag.size * 0.5
	for label: Label in [_headline, _name_label, _title, _subtitle]:
		label.size = Vector2(view.x * 0.62, 0.0)
		var base := int(label.get_meta("cutscene_font",22))
		var px := maxi(12,floori(float(base)*text_ratio))
		var font := label.get_theme_font("font")
		var text := L10n.t(label.text)
		if label!=_subtitle:
			while px>12 and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x+2.0*maxi(1,roundi(float(label.get_meta("cutscene_outline",4))*float(px)/float(base)))+4.0>label.size.x:
				px = maxi(12,px-2)
		label.add_theme_font_size_override("font_size",px)
		if label==_subtitle:
			while px>12 and label.get_line_count()>2:
				px = maxi(12,px-2)
				label.add_theme_font_size_override("font_size",px)
		label.reset_size()
		label.size.x = view.x * 0.62
		label.add_theme_constant_override("outline_size",maxi(1,roundi(float(label.get_meta("cutscene_outline",4))*float(px)/float(base))))
		label.pivot_offset = label.size * 0.5
	_text_language = L10n.current_lang
	if _spot_overlay != null: _spot_overlay.size = view


## 한 시계로 모든 요소의 위치·투명도를 정한다 (t: 0~DURATION초).
func set_time(t: float) -> void:
	_time_view = t
	if _text_language!=L10n.current_lang: _layout()
	if law_id!="":
		_set_themed_time(t)
		return
	var view := _view()
	var leave := _ease_in(_ramp(t,LEAVE_AT,DURATION))
	var center := view*0.5
	_update_spotlight_geometry(view)
	if _actor != null:
		var enter := _ease_out(_ramp(t,0.14,0.48))
		_actor.position = Vector2(lerpf(-_actor.size.x,view.x*0.04,enter)-leave*view.x*0.3,center.y-_actor.size.y*0.5+view.y*0.03)
		_actor.modulate.a = enter*(1.0-leave)
		_actor.scale = Vector2.ONE*(1.0+0.025*sin(_ramp(t,IMPACT_AT,IMPACT_AT+0.24)*PI))
	if _art != null:
		var pop := _ease_back(_ramp(t,0.28,0.62))
		_art.position = Vector2(view.x*0.96-_art.size.x+(1.0-pop)*view.x*0.25+leave*view.x*0.3,center.y-_art.size.y*0.5-view.y*0.06)
		_art.rotation = lerpf(0.18,0.035,pop)
		_art.scale = Vector2.ONE*maxf(pop,0.01)
		_art.modulate.a = clampf(pop*2.0,0.0,1.0)*(1.0-leave)
	if _finish_flag != null:
		var pop := _ease_back(_ramp(t,0.28,0.62))
		_finish_flag.position = Vector2(view.x*0.96-_finish_flag.size.x+(1.0-pop)*view.x*0.25+leave*view.x*0.3,center.y-_finish_flag.size.y*0.5+view.y*0.04)
		_finish_flag.scale = Vector2.ONE * maxf(pop,0.01)
		_finish_flag.rotation = lerpf(0.12,0.0,pop)
		_finish_flag.modulate.a = clampf(pop*2.0,0.0,1.0)*(1.0-leave)
		(_finish_flag.material as ShaderMaterial).set_shader_parameter("motion",t)
	var slam := _ramp(t,IMPACT_AT-0.12,IMPACT_AT)
	var settle := sin(_ramp(t,IMPACT_AT,IMPACT_AT+0.18)*PI)*0.045
	_headline.position = Vector2(center.x-_headline.size.x*0.5,center.y-view.y*0.20-_headline.size.y*0.5)
	_headline.scale = Vector2.ONE*(lerpf(1.7,1.0,slam*slam)+settle)
	_headline.rotation = -0.045
	_headline.modulate.a = clampf(slam*3.0,0.0,1.0)*(1.0-leave)
	if _head_icon != null:
		_head_icon.position = Vector2(center.x-_head_icon.size.x*0.5,_headline.position.y-_head_icon.size.y*0.98)
		_head_icon.scale = _headline.scale
		_head_icon.modulate.a = _headline.modulate.a
	var labels: Array[Label] = [_name_label,_title,_subtitle]
	var starts: Array[float] = [0.84,1.08,1.34]
	var rows: Array[float] = [-0.055,0.035,0.135]
	for i: int in labels.size():
		var label := labels[i]
		var info := _ease_out(_ramp(t,starts[i],starts[i]+0.20))
		label.position = Vector2(center.x-label.size.x*0.5,center.y+view.y*rows[i]+(1.0-info)*12)
		label.modulate.a = info*(1.0-leave)
	queue_redraw()

func _draw() -> void:
	if law_id!="": return
	if _spot_view>=0.0:
		return
	var t := _time_view
	var view := _view()
	var leave := _ease_in(_ramp(t,LEAVE_AT,DURATION))
	var open := _ease_out(_ramp(t,0.0,0.25))*(1.0-leave)
	draw_rect(Rect2(Vector2.ZERO,view),Color(0.025,0.022,0.035,0.74*open))
	var bar := view.y*BAR_RATIO*open
	draw_rect(Rect2(0,0,view.x,bar),Color("080a0d"))
	draw_rect(Rect2(0,view.y-bar,view.x,bar),Color("080a0d"))
	var sweep := _ease_out(_ramp(t,0.08,0.42))
	if sweep>0.0:
		# Reuse the painted wake as a restrained, soft-edged strip.
		var at := Vector2(lerpf(-view.x*0.5,view.x*0.5,sweep),view.y*0.51)
		PaintedFx.stamp(self,PaintedFx.WAKE,at,Vector2(view.x*1.10,view.y*0.42),Color(accent.lightened(0.15),0.23*open),-0.025)
	if _art!=null and _art.modulate.a>0.01:
		var frame := Rect2(_art.position-Vector2(11,11),_art.size+Vector2(22,22))
		draw_set_transform(frame.get_center(),_art.rotation,_art.scale)
		_art_frame.modulate_color.a = _art.modulate.a
		draw_style_box(_art_frame,Rect2(-frame.size*0.5,frame.size))
		draw_set_transform(Vector2.ZERO)
	var impact := 1.0-_ramp(t,IMPACT_AT,IMPACT_AT+0.20)
	var hub := Vector2(view.x*0.5,view.y*0.30)
	if t>=IMPACT_AT and impact>0.0:
		PaintedFx.stamp(self,PaintedFx.IMPACT,hub,Vector2(view.x*0.52,view.y*0.22),Color(1.0,0.93,0.68,0.25*impact))
	var sparks := _ramp(t,IMPACT_AT,IMPACT_AT+0.36)
	if sparks>0.0 and sparks<1.0:
		for i: int in 6:
			var angle := float(i)*TAU/6.0+0.2
			var point := hub+Vector2(cos(angle)*view.x*0.19,sin(angle)*view.y*0.15)*sparks
			PaintedFx.stamp(self,PaintedFx.FLECK,point,Vector2.ONE*lerpf(22,8,sparks),Color(1.0,0.92,0.63,(1.0-sparks)*0.7),angle)

func _layout_themed() -> void:
	var view := _view()
	var ratio := minf(view.x/1366.0,view.y/768.0)
	var theme := THEME.of(law_id)
	var comic: Dictionary=THEME.COMIC_TITLES[law_id]
	var ink := Color(str(theme["ink"]))
	var paper := Color(str(THEME.PAPERS[law_id]))
	_poster.size = view
	if _spot_overlay!=null: _spot_overlay.size = view
	var side := minf(view.y*1.02,view.x*0.59)
	for portrait: TextureRect in [_actor_shadow,_actor]:
		portrait.size = Vector2.ONE*side
		portrait.pivot_offset = portrait.size*0.5
		(portrait.material as ShaderMaterial).set_shader_parameter("outline_pixels",12.0 if law_id=="FINISH" else 2.0)
		(portrait.material as ShaderMaterial).set_shader_parameter("print_scale",ratio)
	_headline.add_theme_font_override("font",THEME.font_for(law_id,L10n.current_lang))
	var labels: Array[Label] = [_headline,_name_label,_rank_label,_title,_subtitle]
	var widths: Array[float] = [0.84,0.38,0.16,0.68,0.72]
	if law_id=="LAW_03":
		widths=[0.84,0.30,0.12,0.47,0.48]
		_headline_clip.size=Vector2(view.x,view.y*0.72)
	var bases: Array[int] = [176,36,24,34,24]
	if law_id=="LAW_02": bases[0]=132 # Tall script remains large across the illustration.
	if law_id=="LAW_03": bases[0]=128 # Keep both words readable while allowing a light portrait overlap.
	for i: int in labels.size():
		var label := labels[i]
		var width := view.x*widths[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if i==4 else TextServer.AUTOWRAP_OFF
		label.max_lines_visible = 2 if i==4 else 1
		label.add_theme_constant_override("outline_size",maxi(1,roundi(((12 if law_id=="LAW_03" else 9) if i==0 else 3)*ratio)))
		if law_id=="LAW_03" and i>0:label.add_theme_constant_override("outline_size",maxi(1,roundi(3*ratio)))
		label.add_theme_color_override("font_outline_color",ink)
		label.add_theme_color_override("font_color",Color("fff6dc") if i==0 else Color("f8efd9"))
		if i==0:
			label.add_theme_color_override("font_color",Color(str(comic["upper"])))
			label.add_theme_color_override("font_outline_color",COMIC_SHADOW_BLACK)
			label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		label.size = Vector2(width,0)
		var px := maxi(12,roundi(float(bases[i])*ratio))
		var font := label.get_theme_font("font")
		var translated := THEME.headline(law_id) if i==0 else L10n.t(label.text)
		if i!=4:
			var longest := 0.0
			for line: String in translated.split("\n"):
				longest = maxf(longest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x)
			while px>12 and longest>width-12*ratio:
				px = maxi(12,px-2)
				longest = 0
				for line: String in translated.split("\n"):
					longest = maxf(longest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x)
		label.add_theme_font_size_override("font_size",px)
		if i==4:
			while px>12 and label.get_line_count()>2:
				px = maxi(12,px-2)
				label.add_theme_font_size_override("font_size",px)
		label.reset_size()
		label.size.x = width
		label.pivot_offset = label.size*0.5
	_headline.rotation = float(theme["tilt"])
	if _headline_tail!=null:
		_headline_tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_headline_tail.add_theme_font_override("font",_headline.get_theme_font("font"))
		_headline_tail.add_theme_font_size_override("font_size",_headline.get_theme_font_size("font_size"))
		_headline_tail.add_theme_font_size_override("font_size",roundi(_headline.get_theme_font_size("font_size")*1.10))
		_headline_tail.add_theme_color_override("font_color",Color(str(comic["lower"])))
		_headline_tail.add_theme_color_override("font_outline_color",_headline.get_theme_color("font_outline_color"))
		_headline_tail.add_theme_constant_override("outline_size",_headline.get_theme_constant("outline_size"))
		_headline_tail.add_theme_color_override("font_shadow_color",_headline.get_theme_color("font_shadow_color"))
		for key: String in ["shadow_offset_x","shadow_offset_y","shadow_outline_size"]:
			_headline_tail.add_theme_constant_override(key,_headline.get_theme_constant(key))
		_headline_tail.reset_size()
		_headline_tail.size.x = _headline.size.x
		_headline_tail.pivot_offset = _headline_tail.size*0.5
		_headline_tail.rotation = _headline.rotation
	_refresh_comic_shadows()
	_layout_title_rig()
	_text_language = L10n.current_lang

func _set_themed_time(t: float) -> void:
	var view := _view()
	if _confirmation != null: _confirmation.seek(_spot_view,view)
	var before := _spot_view>=0 or _intro_view>=0
	var leave := _ease_in(_ramp(t,_duration()-0.50,_duration()))
	_poster.visible = not before and law_id!="LAW_03"
	_poster.seek(t,leave,view)
	_update_spotlight_geometry(view)
	if _prelude!=null:
		_prelude.set_scene_blend(0.70*_ease_out(_ramp(t,0.0,0.55)) if not before and law_id!="FINISH" else 0.0)
		_prelude.set_backdrop_mix(_ease_out(_ramp(t,0.0,0.75)) if not before and law_id!="FINISH" else 0.0)
		var carry := law_id=="LAW_05"
		var dice_carry := law_id in ["FINISH","LAW_01","LAW_02","LAW_03","LAW_06","LAW_07","LAW_08","LAW_09"]
		var overlap := PRELUDE.ALCHEMY.FADE_SECONDS if carry else 0.26
		_prelude.visible = _intro_view>=0 or (not before and (dice_carry or t<overlap))
		_prelude.modulate.a = 1.0-leave if dice_carry else 1.0
		if _prelude.visible:
			_prelude.seek(_intro_view if _intro_view>=0 else _intro_duration()+(maxf(t,0.0) if carry or dice_carry else 0.0),view)
	var enter := _ease_out(_ramp(t,0.32,0.92))
	var portrait_position := Vector2(view.x*(0.63 if law_id=="LAW_03" else 0.52)+(1-enter)*view.x*0.45-leave*view.x*0.15,view.y*(0.08 if law_id=="LAW_03" else 0.04))
	if law_id=="LAW_03":portrait_position=Vector2(view.x*0.53,view.y*0.14)
	var kick := 0.0 if law_id in ["LAW_01","LAW_03"] else sin(_ramp(t,IMPACT_AT,IMPACT_AT+0.16)*PI)*0.016
	_actor.position = portrait_position
	_actor.rotation = -0.025
	_actor.scale = Vector2.ONE*(1+kick)
	_actor.modulate.a = 0.0 if before else enter*(1-leave)
	_actor_shadow.position = portrait_position+(Vector2(-22,12) if law_id=="FINISH" else Vector2(-5,4))*(view.y/768.0)
	_actor_shadow.rotation = _actor.rotation
	_actor_shadow.scale = _actor.scale
	_actor_shadow.modulate.a = _actor.modulate.a*(0.75 if law_id=="FINISH" else 0.20)
	if _art!=null: _art.hide()
	if _finish_flag!=null: _finish_flag.hide()
	if _head_icon!=null: _head_icon.hide()
	var labels: Array[Label] = [_headline,_name_label,_rank_label,_title,_subtitle]
	var starts: Array[float] = [0.36,0.84,0.95,1.08,1.34]
	if law_id=="LAW_03":starts=[TRAP_HEAD_AT,TRAP_INFO_AT,TRAP_INFO_AT+0.12,TRAP_INFO_AT+0.24,TRAP_INFO_AT+0.38]
	# Japanese glyphs have taller line metrics. Stack the measured rows instead of
	# fixed y fractions; winner and rank share one row with separate horizontal areas.
	var gap := 4.0*view.y/768.0
	var preferred_y := view.y*(0.80 if law_id=="FINISH" else 0.705)
	var block_height := _name_label.size.y+_title.size.y+_subtitle.size.y+gap*2.0
	var first_y := minf(preferred_y,view.y-18.0*view.y/768.0-block_height-5.0*view.y/768.0)
	var title_y := first_y+_name_label.size.y+gap
	var rows: Array[float] = [view.y*0.09,first_y,first_y,title_y,title_y+_title.size.y+gap]
	for i: int in range(1,labels.size()):
		if i==2:continue
		var label := labels[i]
		var progress := _ease_out(_ramp(t,starts[i],starts[i]+0.20))
		var margin := 0.045 if law_id=="LAW_03" else 0.07
		var x := view.x*((0.40 if law_id=="LAW_03" else 0.49) if i==2 else margin)
		label.position = Vector2(x,rows[i])
		label.modulate.a = 0.0 if before else progress*(1-leave)
		label.scale = Vector2.ONE
	_pose_title(t,before,leave)
	var info_bounds:=_name_label.get_rect().merge(_title.get_rect()).merge(_subtitle.get_rect())
	var padding:=Vector2(24,14)*view.y/768.0
	var bounds:=Rect2(info_bounds.position-padding,info_bounds.size+padding*2.0)
	bounds=bounds.intersection(Rect2(Vector2(8,8)*view.y/768.0,view-Vector2(16,16)*view.y/768.0))
	if _caption_panel!=null:_caption_panel.seek(t,before,leave,view,bounds,Color(str(THEME.of(law_id)["ink"])),Color(str(THEME.of(law_id)["accent"])))
	queue_redraw()


static func _ramp(t: float, start: float, end: float) -> float:
	return clampf((t - start) / maxf(end - start, 0.001), 0.0, 1.0)


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func _ease_in(x: float) -> float:
	return x * x


static func _ease_back(x: float) -> float:
	if x <= 0.0:
		return 0.0
	var c1: float = 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
