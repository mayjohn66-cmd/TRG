## The result UI is isolated from the existing gameplay controllers.
extends "res://scenes/main_board.gd"

class ResultPresenter extends RollPresenter:
	func _make_card_result(caption: String) -> void:
		super._make_card_result(caption.replace(" · 한 번 더",""))

class ResultPad extends RollPad:
	func _process(delta: float) -> void:
		super._process(delta)
		if _hint_label != null:
			_hint_label.text = _hint_label.text.replace(" · 한 번 더!","")

class ResultBlackjack extends BlackjackStage:
	func _apply_result_text(confirmed: bool, bust: bool, blackjack: bool, steps: int, total: int) -> void:
		super._apply_result_text(confirmed,bust,blackjack,steps,total)
		_result_summary = _result_summary.replace("\n한 번 더","")

class ResultYacht extends YachtStage:
	func _refresh() -> void:
		super._refresh()
		if _status != null:
			_status.text = _status.text.replace("  (+한 번 더!)","")

func _build_action_bar() -> void:
	super._build_action_bar()
	var old: RollPad = _roll_pad
	var at := old.position
	remove_child(old)
	old.queue_free()
	_roll_pad = ResultPad.new()
	_roll_pad.position = at
	_roll_pad.spin_released.connect(_on_pad_spin_released)
	_roll_pad.trigger_pulled.connect(_on_pad_trigger_pulled)
	_roll_pad.preparation_finished.connect(_refresh_controls)
	add_child(_roll_pad)

func _build_roll_fx() -> void:
	super._build_roll_fx()
	remove_child(_presenter)
	_presenter.queue_free()
	_presenter = ResultPresenter.new()
	add_child(_presenter)
	remove_child(_roll_history)
	_roll_history.queue_free()
	_roll_history = preload("res://scenes/roll_success_history.gd").new()
	add_child(_roll_history)

func _build_tool_stages() -> void:
	super._build_tool_stages()
	var yacht_at := _stage_yacht.position
	remove_child(_stage_yacht)
	_stage_yacht.queue_free()
	_stage_yacht = ResultYacht.new()
	_stage_yacht.position = yacht_at
	_stage_yacht.visible = false
	_stage_yacht.z_index = 5
	_stage_yacht.start_pressed.connect(_on_stage_start)
	_stage_yacht.reroll_pressed.connect(_on_yacht_reroll)
	_stage_yacht.confirm_pressed.connect(_on_stage_stand)
	add_child(_stage_yacht)
	var blackjack_at := _stage_blackjack.position
	remove_child(_stage_blackjack)
	_stage_blackjack.queue_free()
	_stage_blackjack = ResultBlackjack.new()
	_stage_blackjack.position = blackjack_at
	_stage_blackjack.visible = false
	_stage_blackjack.z_index = 5
	_stage_blackjack.start_pressed.connect(_on_stage_start)
	_stage_blackjack.hit_pressed.connect(_on_blackjack_hit)
	_stage_blackjack.stand_pressed.connect(_on_stage_stand)
	add_child(_stage_blackjack)

func _place_roll_history() -> void:
	if _roll_history==null or not _roll_history.visible: return
	var stage := _stage_for(_roll_history.tool_id)
	if stage==null or not _roll_history.uses_success_markers():
		super._place_roll_history()
		return
	_roll_history.set_width(RollHistory.WIDTH)
	var at := stage.position+Vector2(-RollHistory.WIDTH-14,(stage.size.y-_roll_history.size.y)*0.5)
	if at.x<12: at.x = stage.position.x+stage.size.x+14
	_roll_history.position = at.clamp(Vector2(12,12),get_viewport_rect().size-_roll_history.size-Vector2(12,12))

func _show_center_banner(text: String, color: Color) -> void:
	var clean := text.replace(" · "+L10n.t("한 번 더"),"").trim_suffix("  ★ 재굴림!")
	super._show_center_banner(clean,color)
