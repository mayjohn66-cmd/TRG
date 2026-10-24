# File: res://tests/test_player_save.gd
# Class: class_name TestPlayerSave
# Role: 영구 기록(PlayerSave) 검사 - 태그 유지, 옛 저장 이전, 두 저장소 합치기, 법전·불닭 기록, 기록 코드 왕복
class_name TestPlayerSave
extends TestCase

const PATH: String = "user://test_player_save.json"

var _saved_path: String = ""
var _saved_browser: bool = false


func setup() -> void:
	_saved_path = PlayerSave.storage_path
	_saved_browser = PlayerSave.use_browser
	PlayerSave.storage_path = PATH
	PlayerSave.use_browser = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	PlayerSave.reset_cache()


func cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	PlayerSave.storage_path = _saved_path
	PlayerSave.use_browser = _saved_browser
	PlayerSave.reset_cache()
	super()


func test_record_survives_a_reload() -> void:
	setup()
	PlayerSave.set_value("player_tag", "AB23")
	PlayerSave.set_value("nickname", "말랑")
	PlayerSave.set_value("lang", "ja")
	PlayerSave.reset_cache()  # 새로고침
	check_eq(str(PlayerSave.get_value("player_tag")), "AB23", "태그를 다시 읽는다")
	check_eq(str(PlayerSave.get_value("nickname")), "말랑", "닉네임을 다시 읽는다")
	check_eq(str(PlayerSave.get_value("lang")), "ja", "언어를 다시 읽는다")
	cleanup()


func test_laws_and_buldak_records() -> void:
	setup()
	check(PlayerSave.mark_law("LAW_04"), "처음 달성한 법전은 기록한다")
	check(not PlayerSave.mark_law("LAW_04"), "같은 법전은 두 번 세지 않는다")
	check(not PlayerSave.mark_law("NOT_A_LAW"), "모르는 법전은 무시한다")
	PlayerSave.mark_law("LAW_01")
	check_eq(PlayerSave.law_count(), 2, "법전 2/8")
	check(PlayerSave.record_buldak(4, 18), "첫 클리어는 최단 기록")
	check(not PlayerSave.record_buldak(4, 22), "더 늦은 클리어는 최단 기록이 아니다")
	check(PlayerSave.record_buldak(4, 15), "더 빠른 클리어는 최단 기록을 고친다")
	check_eq(PlayerSave.buldak_record(4), {"clears": 3, "best_round": 15}, "클리어 3회, 최고 15라운드")
	check(not PlayerSave.buldak_cleared(5), "핵불닭은 아직 미정복")
	PlayerSave.reset_cache()
	check(PlayerSave.has_law("LAW_04") and PlayerSave.buldak_cleared(4), "새로고침 뒤에도 남는다")
	cleanup()


func test_merge_keeps_progress_from_both_stores() -> void:
	var a: Dictionary = PlayerSave.blank()
	a.merge({"player_tag": "AAAA", "cleared_laws": ["LAW_02"], "cleared_buldak": {"1": {"clears": 2, "best_round": 20}}, "win_count": 3}, true)
	var b: Dictionary = PlayerSave.blank()
	b.merge({"player_tag": "BBBB", "nickname": "교주", "cleared_laws": ["LAW_05", "LAW_02"], "cleared_buldak": {"1": {"clears": 1, "best_round": 12}, "3": {"clears": 1, "best_round": 25}}, "win_count": 1}, true)
	var merged: Dictionary = PlayerSave.merge(a, b)
	check_eq(str(merged["player_tag"]), "AAAA", "태그는 앞쪽을 쓴다")
	check_eq(str(merged["nickname"]), "교주", "비어 있으면 다른 쪽으로 채운다")
	check_eq(merged["cleared_laws"], ["LAW_02", "LAW_05"], "법전은 합집합")
	check_eq(merged["cleared_buldak"]["1"], {"clears": 2, "best_round": 12}, "불닭은 큰 횟수·작은 라운드")
	check_eq(int(merged["win_count"]), 3, "판 수는 큰 쪽")
	check(merged["cleared_buldak"].has("3"), "한쪽에만 있는 난이도도 남는다")


func test_save_code_round_trip() -> void:
	setup()
	PlayerSave.set_value("player_tag", "K7PQ")
	PlayerSave.set_value("nickname", "모바일")
	PlayerSave.mark_law("LAW_08")
	PlayerSave.record_buldak(2, 19)
	var code: String = PlayerSave.export_code()
	check(code.begins_with(PlayerSave.CODE_PREFIX) and code.length() < 400, "짧은 기록 코드 (%d자)" % code.length())
	# 다른 기기: 다른 태그와 다른 진행
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	PlayerSave.reset_cache()
	PlayerSave.set_value("player_tag", "ZZZZ")
	PlayerSave.mark_law("LAW_03")
	check(not PlayerSave.import_code("엉뚱한 글"), "잘못된 코드는 거절한다")
	check(not PlayerSave.import_code(PlayerSave.CODE_PREFIX + "%%%"), "깨진 코드는 거절한다")
	check(PlayerSave.import_code("  " + code + "\n"), "붙여 넣은 코드를 불러온다 (앞뒤 공백 허용)")
	check_eq(str(PlayerSave.get_value("player_tag")), "K7PQ", "원래 기기의 태그를 쓴다")
	check_eq(str(PlayerSave.get_value("nickname")), "모바일", "원래 기기의 닉네임을 쓴다")
	check_eq(PlayerSave.cleared_laws(), ["LAW_03", "LAW_08"], "법전은 합친다")
	check(PlayerSave.buldak_cleared(2), "불닭 기록도 옮겨진다")
	cleanup()


func test_legacy_profile_is_migrated_once() -> void:
	setup()
	var legacy := ConfigFile.new()
	var legacy_existed: bool = legacy.load(PlayerSave.LEGACY_PROFILE) == OK
	var backup: String = legacy.encode_to_text() if legacy_existed else ""
	var config := ConfigFile.new()
	config.set_value("profile", "nickname", "옛교주")
	config.set_value("stats", "tag", "OLD2")
	config.set_value("stats", "win_count", 4)
	config.save(PlayerSave.LEGACY_PROFILE)
	PlayerSave.reset_cache()
	check_eq(str(PlayerSave.get_value("player_tag")), "OLD2", "옛 태그를 그대로 옮긴다 (새로 뽑지 않는다)")
	check_eq(str(PlayerSave.get_value("nickname")), "옛교주", "옛 닉네임을 옮긴다")
	check_eq(int(PlayerSave.get_value("win_count")), 4, "옛 1위 횟수를 옮긴다")
	check(FileAccess.file_exists(PATH), "옮긴 뒤 새 저장 파일을 만든다")
	if legacy_existed:
		var restore := ConfigFile.new()
		restore.parse(backup)
		restore.save(PlayerSave.LEGACY_PROFILE)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerSave.LEGACY_PROFILE))
	cleanup()
