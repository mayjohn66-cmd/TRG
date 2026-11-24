# File: res://tests/test_counter_kill_audit.gd
# Class: class_name TestCounterKillAudit
# Role: 방어하면 특수 승리 처치 수가 오르지 않는다 - 봇 4명 전체 판을 돌리며 방어 카드가 나올 때마다
#       방어가 끝난 뒤 공격자의 처치 수가 그 공격 직전 값과 같은지 본다 (2026-10-30·2026-11-24 기물 슬레이어 제보).
class_name TestCounterKillAudit
extends TestCase

var _bad: Array = []
var _offers: Dictionary = {}
var _seen: int = 0


func _on_event(manager: TurnManager, kind: StringName, data: Dictionary) -> void:
	var state: GameState = manager.state
	if kind == &"counter_offer":
		var attacker: int = int(data.get("attacker", -1))
		var entry: Dictionary = state.get_attack(int(data["attack"]))
		var pending: int = int((entry["stats"] as Dictionary).get(&"kills", 0)) if bool(entry.get("stats_committed", true)) else 0
		_offers[int(data["attack"])] = {"attacker": attacker, "pre": state.stat(attacker, &"kills") - pending, "kind": entry["kind"]}
	elif kind == &"counter_resolved":
		var info: Dictionary = _offers.get(int(data["attack"]), {})
		if info.is_empty():
			return
		_seen += 1
		var after: int = state.stat(int(info["attacker"]), &"kills")
		if after != int(info["pre"]):
			info["counter"] = data["card_id"]
			info["after"] = after
			_bad.append(info)


func test_countered_attacks_never_add_kills_over_whole_games() -> void:
	var games: int = int(OS.get_environment("COUNTER_AUDIT_GAMES")) if OS.get_environment("COUNTER_AUDIT_GAMES") != "" else 20
	for seed_value: int in games:
		var manager := TurnManager.new()
		manager.boost_gimmicks = true
		manager.hotseat_mode = true
		manager.draft_enabled = true
		manager.stack_choice_enabled = true
		tree.root.add_child(manager)
		manager.set_process(false)
		manager.start_game([1, 2, 3, 4] as Array[int], seed_value * 7919 + 5)
		manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: _on_event(manager, kind, data))
		var controller := BotController.new()
		controller.manager = manager
		controller.bot_players = [1, 2, 3, 4] as Array[int]
		controller.instant = true
		controller.enabled = true
		controller.rng.seed = seed_value + 3
		defer_free(controller)
		var ticks: int = 0
		while not manager.is_game_over and ticks < 80000:
			controller.tick(0.0)
			ticks += 1
		tree.root.remove_child(manager)
		manager.free()
	check(_seen > 0, "방어 카드가 실제로 쓰였다 (%d번)" % _seen)
	check(_bad.is_empty(), "방어된 공격은 처치 수를 남기지 않는다 %s" % str(_bad.slice(0, 5)))
