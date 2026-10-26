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
	place(state, 21, 3, [2])
	var heard: Array[StringName] = _heard(state)
	MoveExecutor.preview_path(state, state.get_pawn(11), 2)
	check(heard.is_empty(), "미리보기는 알리지 않는다")
	move(state, 11, 2)
	check_eq(heard.count(&"po_jump"), 1, "포가 말을 넘으면 [장기:포] 뛰어넘기 한 번")


func test_knight_passing_an_enemy_trap_is_announced() -> void:
	var state := make_state(2, 1, {1: _units(Kind.CHESS, 2)})
	place(state, 11, 2, [1])
	var trap: TileAttachment = AttachmentRegistry.create("TRP_01")
	trap.owner_id = 2
	state.place_attachment(3, trap)
	var heard: Array[StringName] = _heard(state)
	move(state, 11, 3)
	check(heard.has(&"knight_pass"), "나이트가 적 함정을 뛰어넘으면 [나이트] 함정 관통 (%s)" % str(heard))
	check(state.get_pawn(11).has_left_start, "함정에 걸리지 않았다")


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
	check(dog_heard.has(&"dog_bakery"), "강아지가 빵집을 스치면 [강아지] 빵집 스침 카드+1")
