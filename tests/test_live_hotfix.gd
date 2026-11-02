extends TestCase

func manager4() -> TurnManager:
	var m:=TurnManager.new();m.boost_gimmicks=false;m.draft_enabled=false;m.hotseat_mode=true
	tree.root.add_child(m);m.start_game([1,2,3,4],4242);m.set_process(false);defer_free(m);return m

func test_all_home_ai_winner_ends_before_next_turn() -> void:
	var m:=manager4();var s:=m.state
	place(s,11,4);place(s,21,12);place(s,41,7)
	var race:=VictoryChecker.sort_by_race(s,[1,2,4])
	for p: PlayerPawn in s.pawns_of(3):s.finish_stack(p)
	var round_before:=s.round_number;var ended:=[0]
	m.game_over.connect(func(_p: int,_r: StringName)->void:ended[0]+=1)
	check(m._check_victory(null),"AI's fourth finished pawn must terminate the match")
	check(m.is_game_over and s.winner==3,"AI winner is final immediately")
	var order: Array[int]=[3];order.append_array(race)
	check_eq(s.rankings,order,"remaining players ranked from their real race progress")
	m.force_timeout();check_eq(s.round_number,round_before,"no next round after victory")
	check_eq(ended[0],1,"one result event")
	check_eq(m.phase_time_left,0.0,"no running match timer")

func test_pending_defence_never_increments_any_kill_or_death_law() -> void:
	for counter: StringName in [&"CNT_02",&"CNT_04"]:
		var s:=make_state();place(s,11,3);place(s,21,5);s.hands[2]=[counter]
		add_law(s,"LAW_01");add_law(s,"LAW_06");add_law(s,"LAW_08")
		s.begin_attack({"kind":&"capture","attacker":1,"attacker_pawn":11});s.send_to_start(s.get_pawn(21),1);s.end_attack()
		for key: StringName in [&"kills",&"underdog",GameState.TALLY_KILLS]:check_eq(s.stat(1,key),0,"pending counter: no attacker count")
		for key: StringName in [&"ejected",GameState.TALLY_DEATHS]:check_eq(s.stat(2,key),0,"pending counter: no victim count")
		check_eq(SpecialVictory.shown_progress(s,LawRegistry.create("LAW_01") as VictoryLaw,1),0,"no temporary visible achievement")
		var entry: Dictionary=s.attack_log.back();s.undo_attack(entry);s.commit_attack(entry)
		check(s.get_pawn(21).has_left_start and s.get_pawn(21).current_tile_idx==5,"defence restores the actual surviving pawn")
		check_eq(s.stat(1,&"kills"),0,"blocked kill cannot later commit")
		check_eq(s.stat(2,&"ejected"),0,"no negative or positive death count after defence")

func test_normal_finish_still_ends_after_an_earlier_special_graduate() -> void:
	var m:=manager4();var s:=m.state;m.end_when_graduated=[1]
	add_law(s,"LAW_01");s.add_stat(2,&"kills",10)
	m._graduate(2,&"LAW_01")
	check(not m.is_game_over,"special graduation alone keeps the existing watched-seat rule")
	for pawn: PlayerPawn in s.pawns_of(3):s.finish_stack(pawn)
	m._check_victory(null)
	check(m.is_game_over,"an actual normal completion always stops the match")
	check_eq(s.rankings[0],2,"earlier earned special rank remains valid")

func test_accepting_damage_commits_exactly_once() -> void:
	var s:=make_state();place(s,11,3);place(s,21,5);s.hands[2]=[&"CNT_04"]
	s.begin_attack({"kind":&"capture","attacker":1,"attacker_pawn":11});s.send_to_start(s.get_pawn(21),1);s.end_attack()
	var entry: Dictionary=s.attack_log.back();s.commit_attack(entry);s.commit_attack(entry)
	check_eq(s.stat(1,&"kills"),1,"confirmed KO counted once")
	check_eq(s.stat(1,GameState.TALLY_KILLS),1,"confirmed kill tally once")
	check_eq(s.stat(2,&"ejected"),1,"confirmed ejection once")
	check_eq(s.stat(2,GameState.TALLY_DEATHS),1,"confirmed death tally once")

func test_shields_and_wards_block_before_recording_any_hit() -> void:
	for protection: String in ["ward","turn_guard","white"]:
		var s:=make_state();var victim:=place(s,21,5)
		if protection=="white":victim.evolve(GameEnums.PawnKind.GO,2);victim.shield=true
		elif protection=="ward":victim.ward=true
		else:victim.turn_guard=true
		s.begin_attack({"kind":&"card","attacker":1,"card_id":&"ACT_02"});s.send_to_start(victim,1);s.end_attack()
		check(victim.has_left_start and victim.current_tile_idx==5,"protection keeps pawn on board")
		check_eq(s.stat(1,&"kills"),0,"protected target cannot give a kill")
		check_eq(s.stat(2,&"ejected"),0,"protected target cannot give a death law")
		check(s.attack_log.is_empty(),"no reversible damage record for a blocked hit")

func test_special_win_archives_the_whole_board_and_law_before_retirement() -> void:
	var m:=manager4();var s:=m.state;m.end_when_graduated=[1]
	place(s,11,5);place(s,21,9);place(s,31,13);place(s,41,17)
	s.finish_stack(s.get_pawn(12));add_law(s,"LAW_01");s.add_stat(1,&"kills",10)
	check(m._judge_special_victory(),"human law win ends the configured match")
	var archive:=s.diagnostic_before_graduation
	check_eq(archive["finished"][1],1,"real winner finish count preserved")
	for player: int in [2,3,4]:check_eq(archive["finished"][player],0,"other players were not finishers")
	check_eq(archive["pawns"][2][0]["tile"],9,"real opponent tile survives ranking cleanup")
	check_eq(archive["laws"][0]["name"],"투기장의 지배자","achieved law name captured before removal")
	check_eq(archive["laws"][0]["values"][1],10,"achieved progress captured")
	check(s.rulebook.active_laws_queue.is_empty(),"archive survives actual law removal")
	var packed:=TurnSnapshot.capture(s).to_dict();var copy:=make_state(4)
	TurnSnapshot.from_dict(packed).restore(copy,true)
	check_eq(copy.diagnostic_before_graduation,archive,"network/rewind snapshot preserves the frozen report")
