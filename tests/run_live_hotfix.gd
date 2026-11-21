extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	BoardSpec.apply(24)
	var count:=0;var failures: Array=[]
	var script:=load("res://tests/test_live_hotfix.gd")
	if script==null or not script.can_instantiate():quit(1);return
	var probe: TestCase=script.new()
	for method: Dictionary in probe.get_method_list():
		var name:=str(method["name"])
		if not name.begins_with("test_"):continue
		var test: TestCase=script.new();test.tree=self;test.current_test=name;test.call(name)
		count+=test.assertions;failures.append_array(test.failures);test.cleanup()
	var related: Dictionary={
		"test_turn_manager":["test_first_normal_finisher_ends_and_ranks_the_remaining_race","test_capture_opens_a_counter_offer_and_mirror_force_ejects_the_attacker","test_defending_never_counts_as_a_kill_for_special_victory","test_uno_reverse_ejection_is_not_a_kill","test_graduation_keeps_the_real_board_and_the_achieved_law","test_passing_a_counter_offer_keeps_the_damage","test_counter_cards_only_work_inside_the_victims_offer","test_trap_counters_cyclone_destroys_and_advances","test_bites_the_dust_rewinds_the_attackers_turn_and_ends_it"],
		"test_special_victory":["test_kills_and_ejections_are_counted_from_captures","test_arena_master_graduates_the_killer_and_removes_the_law","test_underdog_counts_kills_on_the_leader_only_with_no_finished_pawns"],
		"test_snapshot":["test_snapshot_restores_positions_stacks_attachments_and_laws","test_snapshot_is_deep_copy","test_snapshot_dict_roundtrip_for_network"]}
	for file: String in related:
		for name: String in related[file]:
			var test: TestCase=load("res://tests/"+file+".gd").new();test.tree=self;test.current_test=name;test.call(name)
			count+=test.assertions;failures.append_array(test.failures);test.cleanup()
	for failure: String in failures:printerr("HOTFIX_CORE_FAIL ",failure)
	print("HOTFIX_CORE ",count," assertions; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
