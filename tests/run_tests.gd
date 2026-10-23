# File: res://tests/run_tests.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 헤드리스 테스트 러너. `godot --headless --path . -s res://tests/run_tests.gd` 로 모든 test_*.gd의 test_* 메서드를 실행한다
extends SceneTree

const SUITES: Array[String] = [
	"res://tests/test_data_tables.gd",
	"res://tests/test_avatar_packs.gd",
	"res://tests/test_board_graph.gd",
	"res://tests/test_move_executor.gd",
	"res://tests/test_rules_and_cards.gd",
	"res://tests/test_tools.gd",
	"res://tests/test_snapshot.gd",
	"res://tests/test_turn_manager.gd",
	"res://tests/test_augments_and_victory.gd",
	"res://tests/test_pawn_abilities.gd",
	"res://tests/test_sub_types.gd",
	"res://tests/test_active_skills.gd",
	"res://tests/test_bot.gd",
	"res://tests/test_bot_rule_audit.gd",
	"res://tests/test_match_telemetry.gd",
	"res://tests/test_bot_temper.gd",
	"res://tests/test_lobby.gd",
	"res://tests/test_room_signaling.gd",
	"res://tests/test_quick_match.gd",
	"res://tests/test_net_game.gd",
	"res://tests/test_classics.gd",
	"res://tests/test_duel.gd",
	"res://tests/test_bottle_cap_physics.gd",
	"res://tests/test_sfx.gd",
	"res://tests/test_new_tools.gd",
	"res://tests/test_super_augments.gd",
	"res://tests/test_boost_gimmicks.gd",
	"res://tests/test_board_32.gd",
	"res://tests/test_pawn_art.gd",
	"res://tests/test_augment_art.gd",
	"res://tests/test_dice_roll_3d.gd",
	"res://tests/test_pinball_3d.gd",
	"res://tests/test_judgment_card_art.gd",
	"res://tests/test_mahjong_slam.gd",
	"res://tests/test_yut_throw.gd",
	"res://tests/test_roulette_spin.gd",
	"res://tests/test_slot_machine.gd",
	"res://tests/test_toy_flag_gun.gd",
	"res://tests/test_capture_cutin.gd",
	"res://tests/test_tempo_up.gd",
	"res://tests/test_font_glyphs.gd",
	"res://tests/test_round_pipeline.gd",
	"res://tests/test_utility_augments.gd",
	"res://tests/test_l10n.gd",
	"res://tests/test_special_victory.gd",
	"res://tests/test_pawn_renewal.gd",
	"res://tests/test_cards_v4.gd",
	"res://tests/test_memory_guards.gd",
]


var _ran: bool = false


## 씬 트리가 완전히 시작된 첫 프레임에 실행한다 (Node 기반 TurnManager가 multiplayer API를 쓰려면 필요).
func _process(_delta: float) -> bool:
	if not _ran:
		_ran = true
		_run_all()
	return false


func _run_all() -> void:
	BoardSpec.apply(24)  # 기존 규칙 테스트는 옛 24칸 배치로 검증한다 (32칸 배치는 test_board_32.gd가 따로 켠다)
	var total_failures: int = 0
	var total_assertions: int = 0
	var total_tests: int = 0
	var only: String = OS.get_environment("TEST_ONLY")  # 예: TEST_ONLY=test_l10n 이면 그 묶음만 (빠른 확인용)
	for path: String in SUITES:
		if only != "" and not path.contains(only):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			printerr("FAIL  %s: 스크립트를 불러오지 못했다 (파싱 오류)" % path.get_file())
			total_failures += 1
			continue
		var probe: TestCase = script.new()
		for method: Dictionary in probe.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var suite: TestCase = script.new()
			suite.tree = self
			suite.current_test = "%s::%s" % [path.get_file(), method_name]
			await suite.call(method_name)
			suite.cleanup()
			total_tests += 1
			total_assertions += suite.assertions
			total_failures += suite.failures.size()
			for failure: String in suite.failures:
				printerr("FAIL  " + failure)
	print("== %d tests, %d assertions, %d failures ==" % [total_tests, total_assertions, total_failures])
	quit(1 if total_failures > 0 else 0)
