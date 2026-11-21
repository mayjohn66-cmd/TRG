# File: res://tests/test_trpg_pawns.gd
# Class: class_name TestTrpgPawns
# Role: TRPG 기물 4종(전사·마법사·궁수·도적) - 공통 패시브(처치 → 레벨 업 → 추가 전진)와 필살기 4종 검증
class_name TestTrpgPawns
extends TestCase


func _setup_pawn(unit: int) -> Array:
	var state: GameState = make_state(2, 321)
	var pawn: PlayerPawn = state.pawns_of(1)[0]
	pawn.evolve(GameEnums.PawnKind.TRPG, unit)
	pawn.has_left_start = true
	pawn.current_tile_idx = 5
	return [state, pawn]


func test_catalog_and_augments() -> void:
	check_eq(PawnCatalog.unit_count(GameEnums.PawnKind.TRPG), 4, "TRPG 4호기")
	var skills: Array[StringName] = [&"warrior_slash", &"fireball", &"arrow_shot", &"stealth"]
	for unit: int in 4:
		var sub: GameEnums.PawnSubType = PawnCatalog.sub_type_of(GameEnums.PawnKind.TRPG, unit + 1)
		check_eq(PawnCatalog.skill_of(sub), skills[unit], "skill %d" % (unit + 1))
		check(AugmentRegistry.get_def(StringName("EVO_%d_%d" % [GameEnums.PawnKind.TRPG, unit + 1])) != null, "evolution augment %d" % (unit + 1))
		check(not PawnCatalog.ability_text(GameEnums.PawnKind.TRPG, unit + 1).is_empty(), "passive text")


func test_level_up_on_kill_and_charge_steps() -> void:
	var pair: Array = _setup_pawn(1)
	var state: GameState = pair[0]
	var pawn: PlayerPawn = pair[1]
	var victim: PlayerPawn = state.pawns_of(2)[0]
	victim.has_left_start = true
	victim.current_tile_idx = 9
	check_eq(pawn.trpg_level, 1, "starts at Lv.1")
	check_eq(pawn.trpg_charge_steps(), 2, "next kill advances +2 (new level)")
	state.pawn_captured.emit(pawn.entity_id, victim.entity_id)
	check_eq(pawn.trpg_level, 2, "kill levels up")
	for i: int in 6:
		state.pawn_captured.emit(pawn.entity_id, victim.entity_id)
	check_eq(pawn.trpg_level, PlayerPawn.TRPG_MAX_LEVEL, "level caps")
	check_eq(pawn.trpg_charge_steps(), 3, "bonus caps at +3")
	pawn.reset_to_start()
	check_eq(pawn.trpg_level, 1, "being captured resets the level")
	var plain: PlayerPawn = state.pawns_of(1)[1]
	state.pawn_captured.emit(plain.entity_id, victim.entity_id)
	check_eq(plain.trpg_level, 1, "non-TRPG pawns never level")


func test_level_up_callout_waits_for_defense_and_stops_at_cap() -> void:
	var pair := _setup_pawn(1)
	var state: GameState = pair[0]
	var pawn: PlayerPawn = pair[1]
	var victim: PlayerPawn = state.pawns_of(2)[0]
	var callouts: Array[int] = []
	state.passive_triggered.connect(func(pawn_id: int, passive: StringName) -> void:
		if passive == &"trpg_level":
			callouts.append(pawn_id))
	state.hands[2] = [&"CNT_09"]
	for blocked: bool in [true, false]:
		victim.has_left_start = true
		victim.current_tile_idx = 6
		state.begin_attack({"kind": CardCounter.CAPTURE, "attacker": 1, "attacker_pawn": pawn.entity_id})
		state.send_to_start(victim, 1)
		state.pawn_captured.emit(pawn.entity_id, victim.entity_id)
		state.end_attack()
		var entry: Dictionary = state.attack_log.back()
		check_eq(pawn.trpg_level, 2, "movement can use the provisional level")
		check(callouts.is_empty(), "defense can still undo this level up")
		if blocked:
			state.undo_attack(entry)
			check_eq(pawn.trpg_level, 1, "defense restored the level")
			check(callouts.is_empty(), "blocked kill produced no level up cue")
		else:
			state.commit_attack(entry)
			state.commit_attack(entry)
			check_eq(callouts, [pawn.entity_id], "confirmed kill presents the level once")
	pawn.trpg_level = PlayerPawn.TRPG_MAX_LEVEL
	state.pawn_captured.emit(pawn.entity_id, victim.entity_id)
	check_eq(callouts, [pawn.entity_id], "at cap, no new level up is presented")


func test_skill_geometry() -> void:
	var pair: Array = _setup_pawn(2)
	var state: GameState = pair[0]
	var pawn: PlayerPawn = pair[1]
	var front: PlayerPawn = state.pawns_of(2)[0]
	var back: PlayerPawn = state.pawns_of(2)[1]
	for p: PlayerPawn in [front, back]:
		p.has_left_start = true
	front.current_tile_idx = 20
	back.current_tile_idx = 7
	check_eq(PawnSkills.cannon_tile(state, pawn), 20, "fireball hits the leading pawn")
	check_eq(PawnSkills.rear_tile(state, pawn), 7, "arrow shot hits the rearmost pawn")
	check_eq(PawnSkills.slash_path(state, pawn).size(), 1, "slash advances exactly 1 tile")
