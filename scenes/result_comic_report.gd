## A printed comic report replaces the old modal/podium result sheet.
class_name ResultComicReport
extends Control

const BASE := Vector2(1366,768)
const INK := Color("17131d")
const PAPER := Color("f8efd9")
const FONT = preload("res://assets/fonts/result/bangers.ttf")
const CROP = preload("res://scenes/result_portrait_crop.gdshader")
var canvas: Control
var actions: HBoxContainer
var ranking_labels: Array[Label] = []
var selected_index := -1
var _entries: Array[Dictionary] = []
var _rank_cuts: Array[Cut] = []
var _selectors: Array[Button] = []
var _record_name: Label
var _record_rank: Label
var _kills: Label
var _deaths: Label
var _progress: Label
var _finished: Label
var _remaining: Label
var _progress_bar: ProgressBar

func _init() -> void:
	name = "ResultComicReport"
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout.call_deferred()

func setup(entries: Array[Dictionary], phrase: String, condition: String, rounds: int, preferred_player: int = -1) -> void:
	canvas = Control.new()
	canvas.name = "PrintedPage"
	canvas.size = BASE
	add_child(canvas)
	_cut("Header",[Vector2(24,18),Vector2(1340,18),Vector2(1328,132),Vector2(32,139)],PAPER,1)
	var title := _text("ReportTitle","RESULT REPORT",72,Vector2(58,29),Vector2(850,92),Color("fff6db"),true)
	title.rotation = -0.025
	title.add_theme_color_override("font_outline_color",INK)
	title.add_theme_constant_override("outline_size",8)
	title.add_theme_color_override("font_shadow_color",Color("a42955"))
	title.add_theme_constant_override("shadow_offset_x",5)
	title.add_theme_constant_override("shadow_offset_y",6)
	_text("ReportSubtitle","플레이어를 선택해 기록을 확인하세요",18,Vector2(63,108),Vector2(700,26))
	_cut("RoundCut",[Vector2(1033,33),Vector2(1310,29),Vector2(1293,116),Vector2(1018,121)],INK)
	_text("RoundWord","ROUND",28,Vector2(1041,55),Vector2(110,44),PAPER,true)
	_text("RoundNumber",str(rounds),64,Vector2(1160,35),Vector2(130,80),Color("ffda52"),true)
	_entries=entries.duplicate(true)
	var victory := _text("ReportVictoryPhrase",phrase,32,Vector2(555,52),Vector2(435,47),INK,true)
	_fit_line(victory,435)
	var detail := _text("MatchEndReasonText",condition,16,Vector2(555,102),Vector2(435,28))
	_fit_line(detail,435)
	detail.tooltip_text=condition
	_cut("RecordHeading",[Vector2(25,157),Vector2(611,161),Vector2(594,242),Vector2(25,247)],PAPER,1)
	_text("RecordTitle","PLAYER RECORD",28,Vector2(48,165),Vector2(435,38),INK,true)
	_record_rank=_text("RecordRank","",24,Vector2(523,168),Vector2(66,35),INK,true)
	_record_name=_text("RecordName","",36,Vector2(48,199),Vector2(525,44))
	_cut("KillCut",[Vector2(25,263),Vector2(299,253),Vector2(295,373),Vector2(25,380)],Color("f6afc5"),1)
	_cut("DeathCut",[Vector2(316,254),Vector2(596,249),Vector2(606,372),Vector2(307,378)],Color("a8dce3"),1)
	_text("KillsTitle","KILLS / 킬",20,Vector2(49,270),Vector2(225,30))
	_text("DeathsTitle","DEATHS / 데스",20,Vector2(337,265),Vector2(240,30))
	_kills=_text("RecordKills","0",96,Vector2(50,286),Vector2(225,99),INK,true)
	_deaths=_text("RecordDeaths","0",96,Vector2(337,283),Vector2(240,99),INK,true)
	_kills.tooltip_text="이번 판 실제 처치가 확정된 누적 횟수"
	_deaths.tooltip_text="이번 판 기물이 사출된 누적 횟수"
	_cut("ProgressCut",[Vector2(25,397),Vector2(606,387),Vector2(593,528),Vector2(25,531)],Color("ffdf59"),1)
	_text("ProgressTitle","PROGRESS / 진행률",20,Vector2(48,405),Vector2(470,30))
	_progress=_text("RecordProgress","0%",72,Vector2(48,436),Vector2(203,88),INK,true)
	_progress_bar=ProgressBar.new()
	_progress_bar.name="RecordProgressBar"
	_progress_bar.position=Vector2(263,449);_progress_bar.size=Vector2(298,23)
	_progress_bar.show_percentage=false
	var background:=StyleBoxFlat.new();background.bg_color=INK
	background.set_border_width_all(3);background.border_color=INK
	var fill:=StyleBoxFlat.new();fill.bg_color=Color("46b9b1")
	fill.set_border_width_all(3);fill.border_color=INK
	_progress_bar.add_theme_stylebox_override("background",background)
	_progress_bar.add_theme_stylebox_override("fill",fill)
	canvas.add_child(_progress_bar)
	_finished=_text("RecordFinished","",22,Vector2(263,488),Vector2(155,33))
	_remaining=_text("RecordRemaining","",22,Vector2(425,488),Vector2(160,33))
	var colors: Array[Color] = [Color("ffdf59"),Color("80ded8"),Color("ff9db4"),Color("bea9ef")]
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		var y := 155.0+94.0*index
		var lean := -8.0 if index%2==0 else 8.0
		var cut := _cut("Rank%d"%(index+1),[Vector2(646,y),Vector2(1338,y+lean),Vector2(1324,y+80+lean),Vector2(635,y+82)],colors[index],1)
		cut.set_meta("player",entry.get("player",-1))
		cut.set_meta("finished",entry.get("finished",0))
		cut.set_meta("progress",entry.get("progress",0))
		cut.set_meta("remaining",entry.get("remaining",0))
		cut.set_meta("kills",entry.get("kills",0))
		cut.set_meta("deaths",entry.get("deaths",0))
		_rank_cuts.append(cut)
		_picture(entry.get("face"),Vector2(742,y-(46.0 if index==0 else 28.0)),Vector2(160,160),cut.polygon,"ReportFace%d"%(index+1))
		_text("ReportRank%d"%(index+1),["1ST","2ND","3RD","4TH"][index],44,Vector2(653,y+10),Vector2(99,61),INK,true)
		var label := _text("ReportName%d"%(index+1),str(entry.get("name","")),32,Vector2(922,y+20),Vector2(350,45))
		_fit_line(label,350)
		ranking_labels.append(label)
		var select := Button.new()
		select.name="SelectRecord%d"%(index+1)
		select.position=Vector2(640,y);select.size=Vector2(692,82)
		select.tooltip_text="%s 기록 보기"%str(entry.get("name",""))
		select.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state: String in ["normal","hover","pressed","disabled"]:select.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var focus:=StyleBoxFlat.new();focus.draw_center=false
		focus.set_border_width_all(3);focus.border_color=Color.WHITE
		select.add_theme_stylebox_override("focus",focus)
		select.pressed.connect(select_record.bind(index))
		canvas.add_child(select);_selectors.append(select)
	_cut("FooterPaper",[Vector2(24,540),Vector2(1337,533),Vector2(1341,756),Vector2(24,752)],Color("e5d6bd"),1)
	actions = HBoxContainer.new()
	actions.name = "ReportActions"
	actions.position = Vector2(42,690)
	actions.size = Vector2(1278,58)
	actions.add_theme_constant_override("separation",24)
	canvas.add_child(actions)
	var initial:=0
	for i: int in _entries.size():
		if int(_entries[i].get("player",-1))==preferred_player:initial=i
	select_record(initial)
	_layout()

## Pure snapshot browsing: selecting a row never changes game counters or standings.
func select_record(index: int) -> void:
	if index<0 or index>=_entries.size():return
	selected_index=index
	var entry:=_entries[index]
	_record_name.text=str(entry.get("name",""));_fit_line(_record_name,525)
	_record_rank.text=["1ST","2ND","3RD","4TH"][index]
	_kills.text=str(int(entry.get("kills",0)));_fit_line(_kills,225)
	_deaths.text=str(int(entry.get("deaths",0)));_fit_line(_deaths,240)
	var progress:=clampi(int(entry.get("progress",0)),0,100)
	_progress.text="%d%%"%progress;_progress_bar.value=progress
	_finished.text="완주 %d/4"%int(entry.get("finished",0))
	_remaining.text="남은 %d칸"%int(entry.get("remaining",0))
	for i: int in _rank_cuts.size():
		_rank_cuts[i].selected=i==index
		_rank_cuts[i].queue_redraw()

func _layout() -> void:
	if canvas==null:return
	var view := size if size.x>1 else BASE
	var factor := minf(view.x/BASE.x,view.y/BASE.y)
	canvas.scale = Vector2.ONE*factor
	canvas.position = (view-BASE*factor)*0.5
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),INK)

func _cut(node_name: String, points: Array, fill: Color, pattern: int = 0) -> Cut:
	var cut := Cut.new()
	cut.name = node_name
	cut.size = BASE
	cut.polygon = PackedVector2Array(points)
	cut.fill = fill
	cut.pattern = pattern
	canvas.add_child(cut)
	return cut

func _picture(texture: Texture2D, at: Vector2, extent: Vector2, polygon: PackedVector2Array, node_name: String) -> void:
	if texture==null:return
	var picture := TextureRect.new()
	picture.name = node_name
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.position = at;picture.size = extent
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crop := ShaderMaterial.new()
	crop.shader = CROP
	var points := polygon.duplicate()
	while points.size()<8:points.append(Vector2.ZERO)
	crop.set_shader_parameter("cut_points",points)
	crop.set_shader_parameter("cut_count",polygon.size())
	crop.set_shader_parameter("image_origin",at)
	crop.set_shader_parameter("ink_inset",5.0)
	picture.material = crop
	canvas.add_child(picture)

func _text(node_name: String, text: String, px: int, at: Vector2, extent: Vector2, color: Color = INK, display: bool = false) -> Label:
	var label := Label.new()
	label.name = node_name;label.text = text
	label.position = at;label.size = extent
	label.add_theme_font_size_override("font_size",FontSizes.snap(px))
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",INK)
	if display:label.add_theme_font_override("font",FONT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(label)
	return label

func _fit_line(label: Label, width: float) -> void:
	label.scale=Vector2.ONE
	var font := label.get_theme_font("font")
	var natural := font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
	if natural>width:label.scale = Vector2.ONE*width/natural

func add_action(button: Button, color: Color) -> void:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0,58)
	skin_button(button,color,26)
	actions.add_child(button)

func set_vote_bar(bar: Control) -> void:
	bar.position = Vector2(46,547)
	bar.size = Vector2(1271,112)
	bar.set_meta("comic_report",true)
	canvas.add_child(bar)
	skin_vote_bar(bar)

static func skin_button(button: Button, color: Color, px: int = 18) -> void:
	button.add_theme_font_size_override("font_size",FontSizes.snap(px))
	button.clip_contents=false
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		var box:=StyleBoxFlat.new()
		box.draw_center=false
		box.content_margin_left=17 if state=="pressed" else (13 if state=="hover" else 14)
		box.content_margin_right=11 if state=="pressed" else (15 if state=="hover" else 14)
		box.content_margin_top=8 if state=="pressed" else (2 if state=="hover" else 4)
		box.content_margin_bottom=0 if state=="pressed" else (6 if state=="hover" else 4)
		button.add_theme_stylebox_override(state,box)
		button.add_theme_color_override("font_color" if state=="normal" else "font_"+state+"_color",INK)
	button.add_theme_constant_override("outline_size",0)
	var face:=button.get_node_or_null("ComicFace") as ComicButtonFace
	if face==null:
		face=ComicButtonFace.new();face.name="ComicFace"
		face.show_behind_parent=true
		face.button_ref=weakref(button)
		button.add_child(face)
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for event: Signal in [button.mouse_entered,button.mouse_exited,button.focus_entered,button.focus_exited,button.button_down,button.button_up,button.draw]:
			event.connect(face.queue_redraw)
		face.resized.connect(face.queue_redraw)
	face.fill=color
	face.kind="vote" if str(button.name).begins_with("Vote_") else String(button.name)
	face.queue_redraw()

static func _prompt_plate(label: Label) -> void:
	if label.get_node_or_null("PromptPlate")!=null:return
	var bubble:=PromptPlate.new();bubble.name="PromptPlate"
	bubble.show_behind_parent=true
	label.add_child(bubble)
	bubble.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble.resized.connect(bubble.queue_redraw)

static func skin_vote_bar(bar: Control) -> void:
	if bar is PanelContainer:bar.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var question:=bar.find_child("VoteQuestion",true,false) as Label
	if question!=null:
		question.add_theme_color_override("font_color",INK)
		if question.text.begins_with("어떤 부분"):question.text="어떤 부분이\n아쉬웠나요?"
		elif question.text=="이번 판 어땠나요?":question.text="이번 판\n어땠나요?"
		question.add_theme_font_size_override("font_size",24)
		question.custom_minimum_size=Vector2(318,96)
		question.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		question.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		_prompt_plate(question)
	var thanks:=bar.find_child("VoteThanks",true,false) as Label
	if thanks!=null:
		thanks.add_theme_color_override("font_color",INK)
		thanks.add_theme_font_size_override("font_size",28)
		thanks.custom_minimum_size.y=96
		thanks.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		_prompt_plate(thanks)
	var details:=bar.find_child("VoteDetails",true,false) as GridContainer
	if details!=null:
		details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		details.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		details.add_theme_constant_override("h_separation",18)
		details.add_theme_constant_override("v_separation",12)
	var row:=bar.find_child("VoteButtons",true,false) as HBoxContainer
	if row!=null:
		row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		row.add_theme_constant_override("separation",22)
	for node: Node in bar.find_children("*","Button",true,false):
		var button:=node as Button
		button.custom_minimum_size.y=44 if details!=null else 76
		skin_button(button,Color("ffda49") if str(button.name).contains("fun") else Color("d9c7ef"),18 if details!=null else 26)

## The native button retains hit testing/focus; this child supplies only printed ink.
class ComicButtonFace extends Control:
	var fill:=Color.WHITE
	var kind: String
	var button_ref: WeakRef
	func _init() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var button:=button_ref.get_ref() as Button
		if button==null or size.x<20 or size.y<16:return
		var w:=size.x;var h:=size.y
		var points:=PackedVector2Array([Vector2(8,5),Vector2(w-15,0),Vector2(w-2,h*0.24),Vector2(w-8,h-5),Vector2(w*0.48,h),Vector2(1,h-5)])
		if kind=="vote":
			points=PackedVector2Array([Vector2(12,1),Vector2(w-14,3),Vector2(w,h*0.36),Vector2(w-8,h-5),Vector2(7,h-4),Vector2(0,h*0.44)])
		elif kind=="CopyRecordButton":
			points=PackedVector2Array([Vector2(2,3),Vector2(w-2,0),Vector2(w-10,h*0.48),Vector2(w-2,h-3),Vector2(3,h),Vector2(10,h*0.5)])
		elif kind=="ReviewFeedbackButton":
			points=PackedVector2Array([Vector2(5,1),Vector2(w*0.34,4),Vector2(w*0.41,0),Vector2(w-12,3),Vector2(w-2,h*0.28),Vector2(w-8,h*0.47),Vector2(w-1,h-3),Vector2(w*0.56,h-1),Vector2(w*0.48,h+2),Vector2(7,h-3),Vector2(1,h*0.61),Vector2(7,h*0.4)])
		var pressed:=button.is_pressed() and not button.disabled
		var offset:=Vector2(3,4) if pressed else (Vector2(-1,-2) if button.is_hovered() and not button.disabled else Vector2.ZERO)
		var shadow:=PackedVector2Array()
		for point: Vector2 in points:shadow.append(point+Vector2(6,7))
		draw_colored_polygon(shadow,INK)
		for i: int in points.size():points[i]+=offset
		var color:=fill.darkened(0.13) if button.disabled else (fill.lightened(0.09) if button.is_hovered() else fill)
		draw_colored_polygon(points,color)
		for row: int in range(1,4):
			for column: int in range(3):
				var at:=Vector2(w-16-column*9,10+row*9)+offset
				if Geometry2D.is_point_in_polygon(at,points):draw_circle(at,1.5,Color(INK,0.14))
		points.append(points[0]);draw_polyline(points,INK,4.0,true)
		if button.has_focus():draw_polyline(points,Color("b82e5a"),2.5,true)

class PromptPlate extends Control:
	func _init() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w:=minf(size.x,560.0);var h:=size.y
		if w<20 or h<20:return
		var origin:=Vector2((size.x-w)*0.5,0)
		var points:=PackedVector2Array([origin+Vector2(9,5),origin+Vector2(w-8,1),origin+Vector2(w-2,h-7),origin+Vector2(2,h-3)])
		var shadow:=PackedVector2Array()
		for point: Vector2 in points:shadow.append(point+Vector2(5,7))
		draw_colored_polygon(shadow,INK)
		draw_colored_polygon(points,Color("fff9ea"))
		points.append(points[0]);draw_polyline(points,INK,4.5,true)

class Cut extends Control:
	var polygon: PackedVector2Array
	var fill := Color.WHITE
	var pattern := 0
	var selected := false
	func _init() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_colored_polygon(polygon,fill)
		if pattern!=0:
			for y: int in range(0,768,20):
				for x: int in range(0,1366,20):
					var at := Vector2(x+(10 if (y/20)%2==0 else 0),y)
					if Geometry2D.is_point_in_polygon(at,polygon):draw_circle(at,2.0,Color(INK,0.09))
		var loop := polygon.duplicate();loop.append(polygon[0])
		draw_polyline(loop,INK,9.0,true)
		if selected:
			draw_polyline(loop,Color("fff8e7"),3.0,true)
			var center:=Vector2(1295,(polygon[1].y+polygon[2].y)*0.5)
			draw_colored_polygon(PackedVector2Array([center+Vector2(-7,-10),center+Vector2(8,0),center+Vector2(-7,10)]),INK)
