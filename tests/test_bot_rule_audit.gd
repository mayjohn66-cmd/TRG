# File: res://tests/test_bot_rule_audit.gd
# Class: class_name TestBotRuleAudit
# Role: 봇 4명이 실제 설정(폭풍 전진 기믹·드래프트 켜짐)으로 여러 판을 끝까지 두는 동안 규칙을 어기지 않는지 감사한다 - 엔진이 거절한 행동, 밴·졸업자의 행동, 칸 설치 제한, 손패 상한
class_name TestBotRuleAudit
extends TestCase

var _rejected: Dictionary = {}
var _violations: Dictionary = {}


func _bad(key: String) -> void:
	_violations[key] = int(_violations.get(key, 0)) + 1


func _on_event(manager: TurnManager, kind: StringName, data: Dictionary) -> void:
	var state: GameState = manager.state
	if kind == &"card_played":
		var player: int = int(data["player_id"])
		if state.is_banned(player):
			_bad("밴 당한 플레이어가 카드를 냈다")
		if state.is_graduated(player):
			_bad("졸업한 플레이어가 카드를 냈다")
		var card: BaseCard = CardRegistry.get_card(data["card_id"])
		var params: Dictionary = data.get("params", {})
		if card.category == GameEnums.CardCategory.TRAP and params.has("tile"):
			var tile: int = int(params["tile"])
			if not card.corner_only and BoardSpec.is_special_tile(tile):
				_bad("일반 함정을 특수 칸(%d번)에 깔았다" % tile)
			if card.corner_only and not BoardSpec.bonus_corner_tiles.has(tile):
				_bad("코너 전용 함정을 코너가 아닌 칸에 깔았다")
		if (state.hands[player] as Array).size() > 7:
			_bad("손패가 7장을 넘었다")
	elif kind == &"roll_resolved":
		if state.is_graduated(manager.current_player_id()):
			_bad("졸업한 플레이어가 굴렸다")


func test_bots_never_break_the_rules_over_whole_games() -> void:
	var games: int = int(OS.get_environment("BOT_AUDIT_GAMES")) if OS.get_environment("BOT_AUDIT_GAMES") != "" else 8
	for seed_value: int in games:
		var manager := TurnManager.new()
		manager.boost_gimmicks = true
		manager.hotseat_mode = true
		manager.draft_enabled = true
		manager.stack_choice_enabled = true
		tree.root.add_child(manager)
		manager.set_process(false)
		manager.start_game([1, 2, 3, 4] as Array[int], seed_value * 977 + 13)
		manager.action_rejected.connect(func(player: int, action: StringName, reason: StringName) -> void:
			var key: String = "P%d %s/%s" % [player, action, reason]
			_rejected[key] = int(_rejected.get(key, 0)) + 1)
		manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: _on_event(manager, kind, data))
		var controller := BotController.new()
		controller.manager = manager
		controller.bot_players = [1, 2, 3, 4] as Array[int]
		controller.instant = true
		controller.enabled = true
		controller.rng.seed = seed_value + 1
		defer_free(controller)
		var ticks: int = 0
		while not manager.is_game_over and ticks < 80000:
			controller.tick(0.0)
			ticks += 1
		check(manager.is_game_over, "시드 %d: 판이 끝까지 진행된다" % seed_value)
		tree.root.remove_child(manager)
		manager.free()
	print("BOT_AUDIT rejected=", _rejected)
	print("BOT_AUDIT violations=", _violations)
	check(_violations.is_empty(), "봇이 규칙을 어긴 일이 없다 %s" % str(_violations))
	check(_rejected.is_empty(), "엔진이 거절한 봇 행동이 없다 %s" % str(_rejected))
