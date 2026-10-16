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
## 훈련(컴퓨터 대전)에서 고른 AI 상대 수 (1~3).
static var ai_opponents: int = 3
## 시작 메뉴에서 로비로 넘어갈 때의 목적: &"secret"(비밀 결투: 방 코드 입력/방 만들기) / &"quick"(진지 승부: 빠른 매칭).
static var lobby_intent: StringName = &"secret"

## 게임 설정(메뉴 > 게임 설정): user://settings.cfg에 저장된다.
const SETTINGS_PATH: String = "user://settings.cfg"
static var pacing_enabled: bool = true
## 보드 시점: 0 탑뷰 / 1 기울인 탑뷰 (MainBoard.ViewMode)
static var view_mode: int = 0
## 내가 고른 아바타 id (AvatarCatalog). 시작 화면의 아바타 설정에서 정한다.
static var avatar_id: StringName = &"avatar_01"


static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "pacing_enabled", pacing_enabled)
	config.set_value("game", "view_mode", view_mode)
	config.set_value("game", "avatar", String(avatar_id))
	config.save(SETTINGS_PATH)


static func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		pacing_enabled = bool(config.get_value("game", "pacing_enabled", true))
		view_mode = clampi(int(config.get_value("game", "view_mode", 0)), 0, 1)
		avatar_id = StringName(str(config.get_value("game", "avatar", "avatar_01")))


## 온라인 대전 설정: 로비가 시작 때 채우고 메인 보드가 읽는다 (net_active가 false면 기존 컴퓨터 대전/핫시트).
static var net_active: bool = false
static var net_is_host: bool = false
static var net_local_seat: int = 1
static var net_players: Array[int] = []
static var net_bots: Array[int] = []
static var net_names: Dictionary = {}
## 온라인 대전의 좌석별 아바타 id.
static var net_avatars: Dictionary = {}
static var net_seed: int = 0
## 테스트용: 내 자리를 봇 두뇌가 대신 플레이한다 (자동 플레이).
static var net_autoplay: bool = false


## 로비가 보낸 시작 설정(config)을 채운다. config: {"players": [좌석], "bots": [좌석], "names": {좌석: 이름}, "seed": int}
static func set_net(is_host: bool, local_seat: int, config: Dictionary) -> void:
	net_active = true
	net_is_host = is_host
	net_local_seat = local_seat
	net_players.assign(config["players"])
	net_bots.assign(config["bots"])
	net_names = (config["names"] as Dictionary).duplicate()
	net_avatars = (config.get("avatars", {}) as Dictionary).duplicate()
	net_seed = int(config["seed"])
	mode = MODE_MULTIPLAYER


static func clear_net() -> void:
	net_active = false
	net_is_host = false
	net_local_seat = 1
	net_players = []
	net_bots = []
	net_names = {}
	net_avatars = {}
	net_seed = 0


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
