# File: res://core_engine/game_session.gd
# Class: class_name GameSession
# Role: 시작 메뉴에서 정한 값(닉네임·게임 모드)을 게임 화면으로 넘기는 정적 세션 데이터. 닉네임은 user://profile.cfg에 저장해 다음 접속 때 미리 채운다
class_name GameSession
extends RefCounted

const PROFILE_PATH: String = "user://profile.cfg"
const MAX_NICKNAME_LENGTH: int = 10
const MODE_AI: StringName = &"ai"
const MODE_MULTIPLAYER: StringName = &"multiplayer"
const DEFAULT_NICKNAME: String = "플레이어 1"

static var nickname: String = ""
static var mode: StringName = MODE_AI


## 닉네임 검사: 앞뒤 공백을 뺀 뒤 1~10자여야 한다. 문제가 없으면 빈 문자열, 있으면 안내 문구를 돌려준다.
static func validate_nickname(raw: String) -> String:
	var text: String = raw.strip_edges()
	if text.is_empty():
		return "닉네임을 입력해 주세요."
	if text.length() > MAX_NICKNAME_LENGTH:
		return "닉네임은 %d자 이하로 입력해 주세요." % MAX_NICKNAME_LENGTH
	return ""


## 화면에 쓸 내 이름 (아직 정하지 않았으면 기본값).
static func display_nickname() -> String:
	return nickname if nickname != "" else DEFAULT_NICKNAME


static func set_nickname(raw: String) -> bool:
	if validate_nickname(raw) != "":
		return false
	nickname = raw.strip_edges()
	save()
	return true


static func save() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "nickname", nickname)
	config.save(PROFILE_PATH)


## 저장된 닉네임을 불러온다 (없으면 빈 문자열).
static func load_saved() -> String:
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return ""
	var saved: String = str(config.get_value("profile", "nickname", ""))
	return saved if validate_nickname(saved) == "" else ""
