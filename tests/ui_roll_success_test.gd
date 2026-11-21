## Only the six successful extra-roll trophies and their presentation lifecycle.
extends SceneTree
var history: RollSuccessHistory
var failures: Array[String] = []
var checks := 0
var serial := 1

func _initialize() -> void: run.call_deferred()
func frames(n: int = 2) -> void:
	for i: int in n: await process_frame
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures.append(note)
func tool(id: StringName) -> void:
	serial += 1
	history.arm(serial,1,id)
func show_result(result: RollResult) -> void:
	history.reveal(serial,1,result.to_dict())

func run() -> void:
	history = RollSuccessHistory.new()
	root.add_child(history)
	await frames()
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	var clock := Engine.time_scale
	tool(&"YUT")
	for face: int in [4,5,4]:
		var yut := RollResult.make(&"YUT",face,{"face":face})
		yut.reroll = true
		show_result(yut)
	check(history._rows.get_child_count()==3 and (history._rows.get_child(1) as Label).text==L10n.t("모"),"Yut Mo use word stamps in order")
	check(not history._footer.visible and history._footer.text.is_empty(),"Yut bonus caption is removed")
	tool(&"REVOLVER")
	var gun := ToolRussianRoulette.new()
	gun.load_chamber(5)
	show_result(gun.roll(rng))
	check(history._success._score.text=="+3" and history._success._vp==null and history._success._props.is_empty(),"safe pull shows +3 with no casing or 3D world")
	history._success._process(0.7)
	check(history._success._score.scale.is_equal_approx(Vector2.ONE),"current score settles")
	show_result(gun.roll(rng))
	check(history._success._score.text=="+6" and history._success.get_child_count()==1,"second success replaces the single number with +6")
	show_result(gun.cash_out())
	check(history._success._score.text=="+6","cash out preserves +6 without another increment")
	tool(&"REVOLVER")
	gun.load_chamber(5)
	for pull: int in 5:
		show_result(gun.roll(rng))
		check(history._success._score.text=="+%d" % ((pull+1)*3),"number progresses through +3 +6 +9 +12 +15")
	tool(&"REVOLVER")
	gun.load_chamber(1)
	show_result(gun.roll(rng))
	show_result(gun.roll(rng))
	check(history.success_count==1 and history._success._score.text=="+0" and history._footer.text==L10n.t("턴 종료"),"fired shot shows +0 and turn end without an award")
	tool(&"LIFE_ROULETTE")
	var seven := RollResult.make(&"LIFE_ROULETTE",7,{"face":7})
	seven.reroll = true
	for i: int in 8: show_result(seven)
	check(history.success_count==8 and history._success._stamps.size()==6,"long streak retains total with six visible stamps")
	check(history._success._stamps.back().scale.x>1.0,"new stamp begins above its impact size")
	history._success._process(0.7)
	check(history._success._stamps.back().scale.is_equal_approx(Vector2.ONE),"stamp lands once and stops")
	check(not history._success.is_processing(),"settled stamps stop processing")
	var last := history.success_count
	history.reveal(serial-1,1,seven.to_dict())
	check(history.success_count==last,"stale reveal cannot add a star")
	show_result(RollResult.make(&"LIFE_ROULETTE",4,{"face":4}))
	check(history.success_count==last,"ordinary roulette face adds no star")
	show_result(seven)
	check(not history._footer.visible and history._footer.text.is_empty(),"success trophy has no extra-roll text")
	tool(&"DICE_MAHJONG")
	var mahjong := ToolMahjong.new()
	show_result(mahjong.roll_category(&"pinfu",rng))
	check(history.success_count==0 and not history.visible,"ordinary Mahjong hides empty trophy tray")
	show_result(mahjong.roll_category(&"yakuman",rng))
	check(history.success_count==1 and history._success._props.size()==1,"yakuman adds one 3D score stick")
	tool(&"DICE_TAROT")
	var tarot := ToolTarot.new()
	show_result(tarot.roll_fate(&"chariot",rng))
	check(history.success_count==0,"ordinary tarot card adds no moon")
	show_result(tarot.roll_fate(&"wheel",rng))
	check(history.success_count==1 and history._success._stamps.size()==1,"wheel awards moon stamp")
	tool(&"DICE_YACHT")
	var yacht := ToolYacht.new()
	show_result(yacht.roll(rng))
	check(history.success_count==0,"Yacht pending roll adds no thumbs up")
	yacht.dice = [6,6,6,6,6]
	show_result(yacht.cash_out())
	check(history.success_count==1 and history._success._stamps.size()==1,"confirmed Yacht earns a stamp despite no extra history row")
	tool(&"DICE_BLACKJACK")
	var blackjack := ToolBlackjack.new()
	blackjack.cards = [10,7]
	blackjack._started = true
	show_result(blackjack._after_draw([7],true))
	check(history.success_count==0 and not history.visible,"ordinary blackjack deal stays compact")
	show_result(blackjack.cash_out())
	check(history.success_count==0,"stand adds no chip")
	blackjack.cards = [1,13]
	blackjack._started = true
	show_result(blackjack._after_draw([13],true))
	check(history.success_count==1 and history.visible and history._success._props.size()==1,"21 earns a visible 3D betting chip")
	blackjack.cards = [10,8,9]
	blackjack._started = true
	show_result(blackjack._after_draw([9],false))
	check(history.success_count==1,"bust does not add a chip")
	var state := rng.state
	history._refresh(false)
	check(rng.state==state and Engine.time_scale==clock,"display does not change gameplay RNG or time scale")
	history.clear()
	check(history.success_count==0 and history._success._vp==null and not history.visible,"turn reset clears objects and viewport")
	history.queue_free()
	await frames()
	for failure: String in failures: printerr("ROLL_SUCCESS_FAIL ",failure)
	if failures.is_empty(): print("ROLL_SUCCESS_OK ",checks)
	quit(0 if failures.is_empty() else 1)

