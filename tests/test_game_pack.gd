# File: res://tests/test_game_pack.gd
# Class: class_name TestGamePack
# Role: 웹 게임 묶음(game.pck) 장치 — 묶음을 나누지 않은 곳(에디터·테스트)에서는 곧바로 준비된 것으로 보고 하려던 일을 바로 한다,
#       묶음을 붙인 뒤 메뉴 때 "없음"으로 기억한 그림·효과음 캐시를 잊는다, 메뉴 스크립트가 도감·게임 보드를 이름으로 끌어오지 않는다.
class_name TestGamePack
extends TestCase


func test_unsplit_builds_are_ready_and_run_actions_at_once() -> void:
	check(GamePack.is_ready(), "모든 리소스가 res://에 있으면 준비된 것으로 본다")
	var ran: Array[bool] = [false]
	GamePack.run_when_ready(Node.new(), func() -> void: ran[0] = true)
	check(ran[0], "준비되어 있으면 기다리지 않고 바로 한다")


func test_refresh_forgets_remembered_misses() -> void:
	var missing: String = "res://assets/__game_pack_test_missing__.png"
	check(TextureCache.fetch(missing) == null, "없는 그림은 null")
	check(TextureCache._texture_cache.has(missing), "없는 그림도 기억해 둔다 (다시 디스크를 뒤지지 않게)")
	GamePack.refresh_caches()
	check(not TextureCache._texture_cache.has(missing), "묶음을 붙이면 없다고 기억한 그림을 잊는다 (묶음에 그 그림이 있을 수 있다)")
	check(not Sfx._scanned, "효과음 목록도 다시 훑는다")


## 메뉴(시작 화면·로비·설정)가 도감·게임 보드를 이름으로 쓰면, 메뉴를 여는 순간 그 스크립트의 preload(3D 모델·연출 그림 수 MB)까지 본체에서 읽게 된다.
func test_menu_scripts_do_not_name_the_rulebook_or_board() -> void:
	for path: String in ["res://scenes/start_menu.gd", "res://scenes/lobby.gd", "res://scenes/lobby_theme.gd", "res://scenes/game_pack.gd", "res://scenes/game_pack_overlay.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		for name: String in ["Rulebook.", ": Rulebook", "MainBoard.", ": MainBoard", "RollPresenter", "JudgmentCardArt.", "MahjongFace.", "AvatarCombatArt."]:
			check(not text.contains(name), "%s는 %s를 이름으로 쓰지 않는다 (열 때 load)" % [path.get_file(), name])
