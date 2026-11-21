extends SceneTree
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	BoardSpec.apply(24)
	var probe:=TestProtonBeam.new();probe.tree=self
	for item:Dictionary in probe.get_method_list():
		var method:String=String(item.name)
		if method.begins_with("test_"):
			probe.current_test=method;probe.call(method);probe.cleanup()
	# The burn report must respect the same real defense order as kill statistics.
	probe.current_test="beam_defense_and_immunity"
	var manager:TurnManager=probe._new_manager()
	var state:GameState=manager.state
	var beam:NeutralNPC=probe._summon(manager)
	var foe:int=2 if beam.owner_id==1 else 1
	var target:PlayerPawn=state.pawns_of(foe)[0]
	target.evolve(GameEnums.PawnKind.GO,2);target.shield=true
	probe._place(target,beam.current_tile_idx+1)
	var kills:int=state.stat(beam.owner_id,GameState.TALLY_KILLS)
	var deaths:int=state.stat(foe,GameState.TALLY_DEATHS)
	var run:Dictionary=NpcSweep.burn(state,beam,1,1)
	probe.check(target.has_left_start and not target.shield and (run.ejected as Array).is_empty(),"shield survives and is absent from beam kill report")
	probe.check(state.stat(beam.owner_id,GameState.TALLY_KILLS)==kills and state.stat(foe,GameState.TALLY_DEATHS)==deaths,"blocked beam adds no kill/death tally")
	state.amnesia_round=state.round_number
	probe._place(target,beam.current_tile_idx+1)
	run=NpcSweep.burn(state,beam,1,1)
	probe.check(target.has_left_start and (run.ejected as Array).is_empty(),"amnesia immunity is not reported as an ejection")
	probe._dispose(manager)
	var legacy:=TestRulesAndCards.new();legacy.tree=self
	for method:String in ["test_neutral_npc_bandit_walks_until_the_first_enemy_and_ejects_only_that_one","test_neutral_npc_passes_over_the_start_line_to_reach_the_nearest_enemy"]:
		legacy.current_test=method;legacy.call(method);legacy.cleanup()
	for failure:String in probe.failures:printerr("PROTON_CARD_FAIL ",failure)
	for failure:String in legacy.failures:printerr("PROTON_CARD_FAIL ",failure)
	var count:int=probe.failures.size()+legacy.failures.size()
	print("PROTON_CARD_CORE ",probe.assertions+legacy.assertions," assertions; ",count," failures")
	quit(0 if count==0 else 1)
