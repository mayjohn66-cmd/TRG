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
## 행동 사이 연출 멈춤(턴 알림·이동 뒤 호흡). 설정 화면에서 선택을 없앴다: 항상 켜져 있다 (테스트만 끈다).
static var pacing_enabled: bool = true
## 소리 설정: 전체·효과음·배경음 음량(0~1)과 전체 음소거. 전체 음량은 Master 버스에 걸린다.
static var master_volume: float = 1.0
static var sfx_volume: float = 0.8
static var bgm_volume: float = 0.6
static var audio_muted: bool = false
## 효과음·배경음악을 따로 음소거한다 (설정 화면의 이름 옆 버튼). audio_muted는 위쪽 [소리] 버튼의 전체 음소거다.
static var sfx_muted: bool = false
static var bgm_muted: bool = false
## 연출 속도 배율(1.0 빠름 / 1.7 보통 / 2.5 느림): 이동 걸음·턴 알림 길이·행동 뒤 호흡·봇 대기가 이 배수로 길어진다 (pacing_enabled가 켜져 있을 때).
const PACE_FAST: float = 1.0
const PACE_NORMAL: float = 1.7
const PACE_SLOW: float = 2.5
static var pace_scale: float = PACE_NORMAL
## 화면 흔들림(말 잡기·내리찍기 등의 진동 연출). 끄면 흔들리지 않는다.
static var screen_shake: bool = true
## 배터리 절약: 화면을 초당 30장까지만 그린다 (휴대폰 발열·배터리용).
static var battery_saver: bool = false
const BATTERY_SAVER_FPS: int = 30
## 보드 시점: 0 탑뷰 / 1 기울인 탑뷰 (MainBoard.ViewMode)
static var view_mode: int = 0
## 내가 고른 아바타 id (AvatarCatalog). 시작 화면의 아바타 설정에서 정한다.
static var avatar_id: StringName = &"avatar_01"


static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "master_volume", master_volume)
	config.set_value("game", "screen_shake", screen_shake)
	config.set_value("game", "battery_saver", battery_saver)
	config.set_value("game", "view_mode", view_mode)
	config.set_value("game", "sfx_volume", sfx_volume)
	config.set_value("game", "bgm_volume", bgm_volume)
	config.set_value("game", "audio_muted", audio_muted)
	config.set_value("game", "sfx_muted", sfx_muted)
	config.set_value("game", "bgm_muted", bgm_muted)
	config.set_value("game", "pace_scale", pace_scale)
	config.set_value("game", "avatar", String(avatar_id))
	config.save(SETTINGS_PATH)


static func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = clampf(float(config.get_value("game", "master_volume", 1.0)), 0.0, 1.0)
		screen_shake = bool(config.get_value("game", "screen_shake", true))
		battery_saver = bool(config.get_value("game", "battery_saver", false))
		view_mode = 0  # 설정 화면에서 시점 선택을 없앴다: 저장값과 무관하게 탑뷰
		sfx_volume = clampf(float(config.get_value("game", "sfx_volume", 0.8)), 0.0, 1.0)
		bgm_volume = clampf(float(config.get_value("game", "bgm_volume", 0.6)), 0.0, 1.0)
		audio_muted = bool(config.get_value("game", "audio_muted", false))
		sfx_muted = bool(config.get_value("game", "sfx_muted", false))
		bgm_muted = bool(config.get_value("game", "bgm_muted", false))
		pace_scale = PACE_NORMAL  # 연출 속도 선택을 없앴다: 저장값과 무관하게 보통
		avatar_id = StringName(str(config.get_value("game", "avatar", "avatar_01")))
	apply_frame_limit()


## 설정 화면의 [기본값으로]: 소리·화면 설정을 처음 값으로 되돌린다 (아바타는 그대로).
static func reset_settings() -> void:
	master_volume = 1.0
	sfx_volume = 0.8
	bgm_volume = 0.6
	audio_muted = false
	sfx_muted = false
	bgm_muted = false
	screen_shake = true
	battery_saver = false
	apply_frame_limit()
	save_settings()


## 배터리 절약이면 초당 그리는 장수를 묶고, 아니면 제한을 푼다.
static func apply_frame_limit() -> void:
	Engine.max_fps = BATTERY_SAVER_FPS if battery_saver else 0


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
