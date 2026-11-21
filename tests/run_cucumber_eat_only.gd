## Edible cucumber: real play validation and no game effect beyond card consumption.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	BoardSpec.apply(24)
	var probe := TestV11Content.new()
	probe.tree = self
	probe.current_test = "cucumber_install_and_recharge"
	probe.test_mob_kyui_cucumber_is_edible_and_trap_cards_recharge()
	probe.current_test = "edible_card_no_effect"
	var manager: TurnManager = probe._new_manager()
	var state: GameState = manager.state
	var owner: int = manager.current_player_id()
	var other: int = 2 if owner == 1 else 1
	state.hands[owner] = [&"JNK_CUKE", &"JNK_CUKE", &"ACT_12"]
	var card: BaseCard = CardRegistry.get_card(&"JNK_CUKE")
	probe.check(card.could_play(state, owner) and card.can_play(state, owner, {}), "cucumber is edible without a target")
	probe.check(not card.needs_tile(), "no tile selection")
	probe.check_eq(card.playable_phases, [TurnManager.State.PHASE_TURN_BEGIN] as Array[int], "normal turn-begin timing only")
	probe.check_eq(MainBoard.card_summary(&"JNK_CUKE"), "먹을수 있는 오이다. 맛있다.", "exact user-requested description")
	probe.check_eq(GameData.text("cards", &"JNK_CUKE", "parody_quote"), "", "no additional flavor description")
	probe.check_eq(GameData.text("cards", &"JNK_CUKE", "icon_file"), "res://assets/board/structures/CUCUMBER_V01.png", "card reuses actual cucumber art")
	var events: Array = probe._events(manager)
	var before: Dictionary = TurnSnapshot.capture(state).data
	var rng_before: int = state.rng.state
	var other_hand: Array = state.hands[other].duplicate()
	manager.act(&"play_card", {"player_id": owner, "card_id": &"JNK_CUKE"})
	probe.check_eq(state.hands[owner], [&"JNK_CUKE", &"ACT_12"], "exactly one cucumber is consumed")
	probe.check_eq(TurnSnapshot.capture(state).data, before, "no board, law, attack, buff, stat or turn changes")
	probe.check_eq(state.rng.state, rng_before, "eating consumes no RNG")
	probe.check_eq(state.hands[other], other_hand, "no cards given or stolen")
	probe.check(manager.card_played_this_turn(), "normal one-card-per-turn rule remains")
	probe.check_eq(events.filter(func(event: Dictionary) -> bool: return event.kind == &"card_played").size(), 1, "one authoritative play event for animation")
	manager.act(&"play_card", {"player_id": owner, "card_id": &"JNK_CUKE"})
	probe.check_eq(state.hands[owner], [&"JNK_CUKE", &"ACT_12"], "duplicate play in same turn cannot consume another")
	probe.check_eq(TurnSnapshot.capture(state).data, before, "rejected repeat has no effects")
	probe._dispose(manager)
	var stage := preload("res://scenes/cucumber_eat_fx.gd").new()
	root.add_child(stage)
	stage.begin(PawnArt.load_sprite(["res://assets/board/structures/CUCUMBER_V01.png"]), Vector2(1000, 660), Vector2(683, 384), 140)
	stage.set_process(false)
	probe.check(stage.busy() and stage.mouse_filter == Control.MOUSE_FILTER_IGNORE, "short non-interactive cosmetic stage")
	for i: int in 4:
		stage.sample([0.30, 0.55, 0.90, 1.20][i])
		probe.check_eq(stage.bite_count, i, "whole fruit then three cumulative bites")
	stage.cancel()
	probe.check(not stage.busy() and not stage.visible and not stage.is_processing(), "cancel removes visual and releases processing")
	stage.queue_free()
	await process_frame
	for failure: String in probe.failures: printerr("CUCUMBER_EAT_FAIL ", failure)
	print("CUCUMBER_EAT_CORE ", probe.assertions, " assertions; ", probe.failures.size(), " failures")
	quit(0 if probe.failures.is_empty() else 1)
