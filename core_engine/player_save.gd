# File: res://core_engine/player_save.gd
# Class: class_name PlayerSave
# Role: 로그인 없이 같은 브라우저에서 이어지는 영구 기록 (익명 #태그·닉네임·언어·누적 판 수·특수 승리 법전 달성·불닭 난이도별 클리어).
#       user://player_save.json(웹은 IndexedDB)과 브라우저 localStorage["trg_player_save_v1"] 두 곳에 같은 JSON을 쓰고,
#       읽을 때는 둘을 합친다 (한쪽이 지워져도 다른 쪽에서 살린다). 옛 저장(user://profile.cfg·settings.cfg)은 처음 한 번 옮긴다.
#       기록 코드(TRG1.<Base64>)로 다른 기기·브라우저에 옮길 수 있다. 게임 규칙에는 영향이 없다 (표시용 기록).
class_name PlayerSave
extends RefCounted

const STORAGE_KEY: String = "trg_player_save_v1"
const VERSION: int = 1
const CODE_PREFIX: String = "TRG1."
const LEGACY_PROFILE: String = "user://profile.cfg"
const LEGACY_SETTINGS: String = "user://settings.cfg"

## 저장 파일 경로 (검사는 다른 경로를 쓴다).
static var storage_path: String = "user://player_save.json"
## 브라우저 localStorage에도 쓰는가 (웹에서만, 검사는 끈다).
static var use_browser: bool = OS.has_feature("web")

static var _data: Dictionary = {}
static var _loaded: bool = false


## 비어 있는 기록.
static func blank() -> Dictionary:
	return {
		"v": VERSION,
		"player_tag": "",
		"nickname": "",
		"lang": "",
		"match_count": 0,
		"finished_count": 0,
		"win_count": 0,
		"cleared_laws": [],
		"cleared_buldak": {},
		"saved_at": 0,
	}


static func data() -> Dictionary:
	_ensure_loaded()
	return _data


static func get_value(key: String, fallback: Variant = null) -> Variant:
	return data().get(key, fallback)


## 값을 바꾸고 바로 저장한다.
static func set_value(key: String, value: Variant) -> void:
	_ensure_loaded()
	if _data.get(key) == value:
		return
	_data[key] = value
	save()


static func save() -> void:
	_ensure_loaded()
	_data["saved_at"] = int(Time.get_unix_time_from_system())
	var text: String = JSON.stringify(_data)
	var file: FileAccess = FileAccess.open(storage_path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
	if use_browser:
		JavaScriptBridge.eval("try { window.localStorage.setItem(%s, %s); } catch (e) {}" % [JSON.stringify(STORAGE_KEY), JSON.stringify(text)], true)


## 다시 읽게 한다 (검사·기록 코드 불러오기 뒤).
static func reset_cache() -> void:
	_data = {}
	_loaded = false


# --- 특수 승리 법전 -----------------------------------------------------------------------------

static func cleared_laws() -> Array:
	return (data().get("cleared_laws", []) as Array).duplicate()


static func law_count() -> int:
	return cleared_laws().size()


static func has_law(law_id: String) -> bool:
	return cleared_laws().has(law_id)


## 이 법전으로 졸업했다: 처음이면 기록하고 true.
static func mark_law(law_id: String) -> bool:
	if not LawRegistry.ALL_IDS.has(law_id) or has_law(law_id):
		return false
	var laws: Array = cleared_laws()
	laws.append(law_id)
	laws.sort()
	_data["cleared_laws"] = laws
	save()
	return true


# --- 불닭 난이도 ------------------------------------------------------------------------------

## 난이도의 기록: {"clears": 1위 횟수, "best_round": 가장 빨리 1위한 라운드} (없으면 빈 사전).
static func buldak_record(level: int) -> Dictionary:
	var records: Dictionary = data().get("cleared_buldak", {})
	return (records.get(str(level), {}) as Dictionary).duplicate()


static func buldak_cleared(level: int) -> bool:
	return int(buldak_record(level).get("clears", 0)) > 0


## 놀이터에서 1위: 클리어 횟수를 올리고 최단 라운드를 고친다. 최단 기록을 새로 세웠으면 true.
static func record_buldak(level: int, round_number: int) -> bool:
	if not BotTemper.ALL.has(level) or round_number <= 0:
		return false
	var records: Dictionary = (data().get("cleared_buldak", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = records.get(str(level), {})
	var best: int = int(entry.get("best_round", 0))
	var improved: bool = best <= 0 or round_number < best
	entry["clears"] = int(entry.get("clears", 0)) + 1
	entry["best_round"] = round_number if improved else best
	records[str(level)] = entry
	_data["cleared_buldak"] = records
	save()
	return improved


# --- 기록 코드 --------------------------------------------------------------------------------

## 다른 기기로 옮기는 짧은 코드: TRG1.<JSON Base64>.
static func export_code() -> String:
	var shared: Dictionary = data().duplicate(true)
	shared.erase("saved_at")
	return CODE_PREFIX + Marshalls.utf8_to_base64(JSON.stringify(shared))


## 기록 코드를 읽는다 (잘못되면 빈 사전).
static func decode(code: String) -> Dictionary:
	var text: String = code.strip_edges().replace(" ", "").replace("\n", "")
	if not text.begins_with(CODE_PREFIX):
		return {}
	var raw: String = Marshalls.base64_to_utf8(text.substr(CODE_PREFIX.length()))
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary or not GameSession.is_valid_tag(str((parsed as Dictionary).get("player_tag", ""))):
		return {}
	return parsed


## 기록 코드를 불러온다: 그 코드의 #태그·닉네임을 쓰고, 진행(법전·불닭·판 수)은 지금 기록과 합친다. 성공하면 true.
static func import_code(code: String) -> bool:
	var incoming: Dictionary = decode(code)
	if incoming.is_empty():
		return false
	_ensure_loaded()
	var merged: Dictionary = merge(_data, incoming)
	merged["player_tag"] = str(incoming["player_tag"])
	if GameSession.validate_nickname(str(incoming.get("nickname", ""))) == "":
		merged["nickname"] = str(incoming["nickname"])
	_data = merged
	save()
	return true


## 두 기록을 합친다: 태그·닉네임·언어는 a를 우선(비어 있으면 b), 판 수는 큰 쪽, 법전은 합집합, 불닭은 클리어 횟수 큰 쪽·최단 라운드 작은 쪽.
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var result: Dictionary = blank()
	for key: String in ["player_tag", "nickname", "lang"]:
		var first: String = str(a.get(key, ""))
		result[key] = first if first != "" else str(b.get(key, ""))
	for key: String in ["match_count", "finished_count", "win_count"]:
		result[key] = maxi(int(a.get(key, 0)), int(b.get(key, 0)))
	var laws: Array = []
	for source: Dictionary in [a, b]:
		for law: Variant in source.get("cleared_laws", []):
			if LawRegistry.ALL_IDS.has(str(law)) and not laws.has(str(law)):
				laws.append(str(law))
	laws.sort()
	result["cleared_laws"] = laws
	var buldak: Dictionary = {}
	for source: Dictionary in [a, b]:
		var records: Variant = source.get("cleared_buldak", {})
		if not records is Dictionary:
			continue
		for level: Variant in records:
			var entry: Variant = records[level]
			if not entry is Dictionary or not BotTemper.ALL.has(int(str(level))):
				continue
			var key: String = str(int(str(level)))
			var current: Dictionary = buldak.get(key, {"clears": 0, "best_round": 0})
			var best_now: int = int(current["best_round"])
			var best_new: int = int(entry.get("best_round", 0))
			current["clears"] = maxi(int(current["clears"]), int(entry.get("clears", 0)))
			current["best_round"] = best_new if best_now <= 0 else (best_now if best_new <= 0 else mini(best_now, best_new))
			buldak[key] = current
	result["cleared_buldak"] = buldak
	result["saved_at"] = maxi(int(a.get("saved_at", 0)), int(b.get("saved_at", 0)))
	return result


# --- 읽기 -------------------------------------------------------------------------------------

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var from_file: Dictionary = _read_json(_read_file())
	var from_browser: Dictionary = _read_json(_read_browser())
	if from_file.is_empty() and from_browser.is_empty():
		_data = _from_legacy()
		save()
		return
	# 더 최근에 저장한 쪽의 태그·닉네임·언어를 우선하고 진행은 합친다
	var newer_first: bool = int(from_file.get("saved_at", 0)) >= int(from_browser.get("saved_at", 0))
	_data = merge(from_file, from_browser) if newer_first else merge(from_browser, from_file)
	if from_file.is_empty() or from_browser.is_empty():
		save()  # 한쪽이 지워졌으면 다시 채운다


static func _read_file() -> String:
	if not FileAccess.file_exists(storage_path):
		return ""
	var file: FileAccess = FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


static func _read_browser() -> String:
	if not use_browser:
		return ""
	var value: Variant = JavaScriptBridge.eval("(function () { try { return window.localStorage.getItem(%s) || ''; } catch (e) { return ''; } })()" % JSON.stringify(STORAGE_KEY), true)
	return str(value) if value != null else ""


static func _read_json(text: String) -> Dictionary:
	if text.strip_edges().is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	return merge(parsed, blank())  # 빠진 항목을 채우고 값을 정리한다


## 예전 저장(profile.cfg의 닉네임·태그·판 수, settings.cfg의 언어)을 옮긴다.
static func _from_legacy() -> Dictionary:
	var result: Dictionary = blank()
	var profile := ConfigFile.new()
	if profile.load(LEGACY_PROFILE) == OK:
		result["nickname"] = str(profile.get_value("profile", "nickname", ""))
		result["player_tag"] = str(profile.get_value("stats", "tag", ""))
		result["match_count"] = maxi(int(profile.get_value("stats", "match_count", 0)), 0)
		result["finished_count"] = maxi(int(profile.get_value("stats", "finished_count", 0)), 0)
		result["win_count"] = maxi(int(profile.get_value("stats", "win_count", 0)), 0)
	var settings := ConfigFile.new()
	if settings.load(LEGACY_SETTINGS) == OK:
		result["lang"] = str(settings.get_value("game", "language", ""))
	return result
