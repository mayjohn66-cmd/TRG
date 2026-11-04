## Touch card reading is separate from the explicit activation button.
extends RefCounted
static func make(card: BaseCard, face: Control, description: String, timing: String, view: Vector2, usable: bool, use: Callable, close: Callable) -> PanelContainer:
	var panel:=PanelContainer.new();panel.name="CardZoom"
	panel.add_theme_stylebox_override("panel",UiSkin.panel("panel",20))
	var area:=Vector2(view.x*0.88,view.y*0.86)
	panel.custom_minimum_size=area;panel.size=area;panel.position=(view-area)*0.5
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);panel.add_child(row)
	var face_scale:=minf((area.y-55)/333.0,area.x*0.27/238.0)
	var art_box:=Control.new();art_box.custom_minimum_size=Vector2(238,333)*face_scale
	art_box.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(art_box)
	face.scale=Vector2.ONE*face_scale;art_box.add_child(face)
	var body:=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10);row.add_child(body)
	# 줄바꿈 글자(Label autowrap)는 가로 폭이 정해지지 않으면 거의 0폭으로 세어 세로로 어마어마하게 길어지고, 그만큼 패널이 늘어나 [사용하기] 버튼이 화면 밖으로 밀린다
	# (2026-11-04 제보: 모바일에서 방해령 사리의 사용 버튼이 가려짐). 글자 칸마다 쓸 수 있는 폭을 미리 정해 준다.
	var text_width:=maxf(160.0,area.x-art_box.custom_minimum_size.x-18.0-60.0)
	var unit:=clampf(view.y/768.0,0.65,1.25)
	var title:=Label.new();title.text=L10n.t(card.display_name);title.name="MobileCardTitle"
	title.add_theme_font_size_override("font_size",maxi(22,roundi(32*unit)))
	title.add_theme_color_override("font_color",UiSkin.INK);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.custom_minimum_size.x=text_width
	body.add_child(title)
	var text:=RichTextLabel.new();text.name="MobileCardDescription";text.text=L10n.t(description)
	text.size_flags_vertical=Control.SIZE_EXPAND_FILL;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size",maxi(20,roundi(34*unit)))
	text.add_theme_constant_override("line_separation",6);text.add_theme_color_override("default_color",UiSkin.INK)
	text.scroll_active=true;body.add_child(text)
	var hint:=Label.new();hint.text=L10n.tf("발동: %s",[timing]);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size",maxi(16,roundi(20*unit)));hint.add_theme_color_override("font_color",UiSkin.SOFT);hint.custom_minimum_size.x=text_width
	body.add_child(hint)
	if HauntCommand.is_haunt(card.card_id):  # 방해령 삼총사: 작은 힌트 한 줄 (데스크톱 확대 보기와 같은 문구)
		var whisper:=Label.new();whisper.name="CardHint";whisper.text=L10n.t(MainBoard.HAUNT_HINT);whisper.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		whisper.add_theme_font_size_override("font_size",maxi(12,roundi(15*unit)));whisper.add_theme_color_override("font_color",Color("7a6a9a"));whisper.custom_minimum_size.x=text_width
		body.add_child(whisper)
	var buttons:=HBoxContainer.new();body.add_child(buttons)
	for action: String in ["사용하기","닫기"]:
		var button:=Button.new();button.text=L10n.t(action);button.name="UseCard" if action=="사용하기" else "CloseCard"
		button.custom_minimum_size=Vector2(130,88)*unit;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",maxi(20,roundi(26*unit)))
		UiSkin.button(button,action=="사용하기")
		button.disabled=action=="사용하기" and not usable;button.pressed.connect(use if action=="사용하기" else close)
		buttons.add_child(button)
	return panel
