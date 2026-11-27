# File: res://tests/test_passive_callouts.gd
# Class: class_name TestPassiveCallouts
# Role: 기물 고유 능력이 발동하면 엔진이 passive_triggered(말, 키)를 알려 보드가 원인 뱃지([장기:포] 뛰어넘기 +3칸!)를 띄울 수 있는지,
#       엔진이 쓰는 키마다 뱃지 문구가 있는지 검사한다. 미리보기(경로 예상)는 알리지 않는다.
class_name TestPassiveCallouts
extends TestCase

const Kind := GameEnums.PawnKind


func _units(kind: GameEnums.PawnKind, unit: int) -> Array:
	return [Vector2i(kind, unit), 0, 0, 0]


func _heard(state: GameState) -> Array[StringName]:
	var heard: Array[StringName] = []
	state.passive_triggered.connect(func(_pawn_id: int, passive: StringName) -> void: heard.append(passive))
	return heard


func test_every_engine_key_has_callout_text() -> void:
	var regex := RegEx.create_from_string("passive(?:s\\.append\\(|_triggered\\.emit\\([^,]+, )&\"(\\w+)\"")
	var keys: Dictionary = {}
	for path: String in ["res://core_engine/move_executor.gd", "res://scenes/main_board.gd"]:
		for match: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			keys[match.get_string(1)] = true
	for extra: String in ["straight_ryuo", "straight_hisha", "straight_rook", "corner_ryuma", "corner_kaku", "keima_pass", "queen_pass", "knight_pass", "shield_block", "sweeper_defuse"]:
		keys[extra] = true
	check(keys.size() >= 20, "엔진이 쓰는 원인 키를 찾았다 (%d개)" % keys.size())
	for key: String in keys:
		check(PassiveCallout.text(StringName(key)).begins_with("["), "%s 뱃지 문구" % key)


func test_cannon_jump_is_announced_once_on_the_real_move_only() -> void:
	var state := make_state(2, 1, {1: _units(Kind.JANGGI, 1)})
	place(state, 11, 2, [1])
	place(state, 12, 3, [2])
	var heard: Array[StringName] = _heard(state)
	MoveExecutor.preview_path(state, state.get_pawn(11), 2)
	check(heard.is_empty(), "미리보기는 알리지 않는다")
	move(state, 11, 2)
	check_eq(heard.count(&"po_jump"), 1, "포가 내 말을 넘으면 [장기:포] 뛰어넘기 한 번")


func test_knight_corner_leap_is_announced() -> void:
	var state := make_state(2, 1, {1: _units(Kind.CHESS, 2)})
	place(state, 11, 2, [1])
	var heard: Array[StringName] = _heard(state)
	move(state, 11, 3)  # 5번 = 6번 코너 바로 앞
	check(heard.has(&"knight_corner"), "나이트가 코너 앞에 멈추면 [나이트] 코너 도약 (%s)" % str(heard))
	check_eq(state.get_pawn(11).current_tile_idx, 7, "+2칸")


func test_checker_king_kills_in_passing_and_dog_sniffs_a_bakery() -> void:
	var state := make_state(2, 1, {1: _units(Kind.ARCADE, 1)})
	place(state, 11, 2, [1])
	place(state, 21, 3, [2])
	var heard: Array[StringName] = _heard(state)
	move(state, 11, 3)
	check(heard.has(&"checker_slide"), "킹 체커가 지나가며 처치하면 [킹 체커] 스침 처치")
	var bakery: int = BoardSpec.bakery_tiles[0]
	var dog_state := make_state(2, 1, {1: _units(Kind.MONOPOLY, 4)})
	place(dog_state, 11, bakery - 1, [bakery - 2])
	var dog_heard: Array[StringName] = _heard(dog_state)
	move(dog_state, 11, 2)
	check(dog_heard.has(&"dog_pad"), "강아지가 빵집을 스치면 [강아지] 특수 발판 스침 카드+1")


func test_badge_shows_only_the_effect_next_to_the_piece_chip() -> void:
	# 1.3.1 글 줄이기: 배지 앞의 기물 글자 칩이 누구인지 보여 주므로 [이름]은 떼고 효과만 띄운다
	check_eq(MainBoard.callout_effect_text("[퀸] 이동 +2칸!"), "이동 +2칸!", "이름을 뗀다")
	check_eq(MainBoard.callout_effect_text("[Queen] Move +2!"), "Move +2!", "번역된 문구도 같은 꼴")
	check_eq(MainBoard.callout_effect_text("[업기]"), "[업기]", "떼면 비는 문구는 그대로")
	check_eq(MainBoard.callout_effect_text("함정 해체!"), "함정 해체!", "괄호가 없으면 그대로")
	for passive: StringName in PassiveCallout.TEXTS.keys():
		check(MainBoard.callout_effect_text(PassiveCallout.text(passive)) != "", "%s 배지 문구가 비지 않는다" % passive)


func test_dog_card_is_drawn_from_the_pawn() -> void:
	# 1.3.1 연출: 말 능력으로 얻은 카드는 화면이 그 말에서 날린다 (state.draw_source_pawn 힌트, 결과와 무관)
	var bakery: int = BoardSpec.bakery_tiles[0]
	var state := make_state(2, 1, {1: _units(Kind.MONOPOLY, 4)})
	place(state, 11, bakery - 1, [bakery - 2])
	var sources: Array[int] = []
	state.card_drawn.connect(func(_player: int, _card: StringName) -> void: sources.append(state.draw_source_pawn))
	move(state, 11, 2)
	check(sources.has(11), "강아지 카드는 강아지 말(11)에서 나온다 (%s)" % str(sources))
	check_eq(state.draw_source_pawn, -1, "뽑은 뒤 힌트는 지워진다")
	check(MainBoard.CARD_FROM_PAWN_PASSIVES.has(&"dog_pad"), "강아지 카드+1은 글 배지 대신 카드가 날아간다")
