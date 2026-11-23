# File: res://scenes/game_pack_overlay.gd
# Class: class_name GamePackOverlay
# Role: 게임 묶음(game.pck)을 아직 받는 중일 때 게임 시작·도감·온라인 입장 위에 덮는 대기 창. 진행 막대와 실패 시 [다시 시도]를 보여 준다.
#       묶음이 붙으면 GamePack.run_when_ready가 이 창을 닫고 원래 하려던 일을 이어 한다.
class_name GamePackOverlay
extends Control

var _bar: ProgressBar = null
var _label: Label = null
var _retry: Button = null
var _pack: GamePack = null


func _init() -> void:
	name = "GamePackOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 기다리는 동안 뒤의 버튼을 누르지 못하게
	z_index = 100
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", LobbyTheme.style(Color("fff6df"), LobbyTheme.TEAL, 4, 26, 8, 24))
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := LobbyTheme.label("게임 데이터를 받는 중", 28, LobbyTheme.TEAL_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_bar = ProgressBar.new()
	_bar.name = "GamePackProgress"
	_bar.custom_minimum_size = Vector2(460, 26)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	box.add_child(_bar)
	_label = LobbyTheme.label("처음 한 번만 받아요. 잠시만 기다려 주세요.", 16, LobbyTheme.INK_SOFT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_label)
	_retry = LobbyTheme.cream_button("다시 시도", _on_retry, 24)
	_retry.name = "GamePackRetry"
	_retry.visible = false
	box.add_child(_retry)


## 받는 노드의 진행·실패 신호를 이 창에 잇는다.
func bind(pack: GamePack) -> void:
	_pack = pack
	pack.progress.connect(_on_progress)
	pack.failed.connect(_on_failed)


func _on_progress(ratio: float) -> void:
	if ratio < 0.0:
		_bar.value = fmod(_bar.value + 0.01, 1.0)  # 크기를 모르면 막대를 천천히 돌린다
		return
	_bar.value = ratio
	_label.text = "%d%%" % int(round(ratio * 100.0))


func _on_failed() -> void:
	_label.text = "게임 데이터를 받지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요."
	_retry.visible = true


func _on_retry() -> void:
	_retry.visible = false
	_label.text = "다시 받는 중..."
	if _pack != null and is_instance_valid(_pack):
		_pack.retry()
