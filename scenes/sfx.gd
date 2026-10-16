# File: res://scenes/sfx.gd
# Class: class_name Sfx
# Role: 효과음·배경음 재생기. 게임은 이벤트 이름(&"hop", &"slam"...)으로 Sfx.play()만 부르고, 실제 소리는 assets/sfx/ 폴더에서 파일 이름으로 찾는다 (파일이 없으면 조용히 건너뜀). 음량·음소거는 GameSession 설정을 따른다
class_name Sfx
extends RefCounted

const SFX_DIR: String = "res://assets/sfx"
const BGM_DIR: String = "res://assets/bgm"
const BUS_SFX: StringName = &"SFX"
const BUS_BGM: StringName = &"BGM"
const POOL_SIZE: int = 12

## 이벤트 -> (설명, 파일 이름에 들어 있으면 쓰는 키워드들). 파일 이름이 이벤트 이름으로 시작하면(예: hop_01.ogg) 그것이 우선이고, 없으면 키워드(Kenney 팩 이름 등)로 찾는다.
const EVENTS: Dictionary = {
	&"ui_click": ["버튼 클릭", ["click", "button", "select", "tap"]],
	&"hop": ["말 점프 착지 (톡)", ["chip-lay", "chips-stack", "card-place", "place"]],
	&"slam": ["내리찍기 (잡을 때 쾅)", ["impact", "thud", "slam", "chips-collide"]],
	&"launch": ["잡힌 말이 날아감", ["whoosh", "swoosh", "card-slide", "slide"]],
	&"thud": ["출발선에 쿵 떨어짐", ["thud", "chips-handle", "place"]],
	&"dice_roll": ["주사위 굴림", ["dice-shake", "die-throw", "dice-throw", "dice"]],
	&"dice_result": ["주사위 결과 확정", ["dice-throw", "die-throw", "dice"]],
	&"card_pick": ["카드 집어 듦", ["card-fan", "card-slide", "card-shove"]],
	&"card_throw": ["카드 던짐", ["card-shove", "card-slide", "whoosh"]],
	&"card_impact": ["카드 발동 임팩트", ["card-place", "impact", "thud"]],
	&"augment_show": ["증강 카드 등장", ["card-fan", "card-shuffle", "shuffle"]],
	&"augment_pick": ["증강 선택", ["card-place", "select", "click"]],
	&"law": ["새 교칙 찍힘", ["impact", "stamp", "thud", "chips-collide"]],
	&"law_drop": ["오래된 교칙 밀려남", ["whoosh", "slide"]],
	&"promote": ["승급 반짝임", ["sparkle", "magic", "chime", "powerup"]],
	&"charge": ["돌진 차징", ["charge", "whoosh"]],
	&"dash": ["초고속 돌진·발사", ["dash", "whoosh", "swoosh", "shot"]],
	&"shot": ["총알 발사", ["shot", "gun", "laser"]],
	&"good": ["좋은 일 (나이스/골인)", ["win", "coin", "chime", "success"]],
	&"bad": ["나쁜 일 (억까/으악)", ["lose", "fail", "buzz", "error"]],
	&"game_start": ["GAME START 배너", ["start", "fanfare", "impact"]],
	&"win": ["승리", ["win", "fanfare", "victory"]],
}

static var _index: Dictionary = {}
static var _scanned: bool = false
static var _cache: Dictionary = {}
static var _pool: Array[AudioStreamPlayer] = []
static var _next: int = 0
static var _host: Node = null
static var _bgm: AudioStreamPlayer = null
static var _bgm_name: StringName = &""


## 소리를 낼 수 있는 환경인가 (헤드리스 테스트에서는 항상 꺼져 있다).
static func enabled() -> bool:
	return DisplayServer.get_name() != "headless"


## 이벤트 소리를 낸다. volume_db는 그 소리만의 보정, pitch_variance는 반복 소리가 지루하지 않게 음높이를 조금 흔드는 폭이다.
static func play(event: StringName, volume_db: float = 0.0, pitch_variance: float = 0.06) -> void:
	if not enabled() or GameSession.audio_muted:
		return
	var stream: AudioStream = _stream_for(event)
	if stream == null or not _ensure_ready():
		return
	var player: AudioStreamPlayer = _pool[_next % _pool.size()]
	_next += 1
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()


## 지금 이 이벤트에 연결된 소리 파일이 있는가 (설정 화면 시험 버튼 등에서 쓴다).
static func has_sound(event: StringName) -> bool:
	return _files_for(event).size() > 0


## 배경음 재생 (assets/bgm/<이름>.ogg). 같은 곡이 이미 나오면 그대로 둔다. 파일이 없으면 아무것도 하지 않는다.
static func bgm_play(track: StringName) -> void:
	if not enabled() or not _ensure_ready():
		return
	if track == _bgm_name and _bgm != null and _bgm.playing:
		return
	var path: String = _find_bgm(track)
	if path == "":
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_bgm_name = track
	_bgm.stream = stream
	_bgm.play()


static func bgm_stop() -> void:
	if _bgm != null:
		_bgm.stop()
	_bgm_name = &""


## GameSession의 음량·음소거 설정을 오디오 버스에 적용한다 (설정을 바꿀 때마다 부른다).
static func apply_settings() -> void:
	if not enabled():
		return
	_ensure_buses()
	var sfx_index: int = AudioServer.get_bus_index(BUS_SFX)
	var bgm_index: int = AudioServer.get_bus_index(BUS_BGM)
	AudioServer.set_bus_volume_db(sfx_index, linear_to_db(maxf(GameSession.sfx_volume, 0.0001)))
	AudioServer.set_bus_volume_db(bgm_index, linear_to_db(maxf(GameSession.bgm_volume, 0.0001)))
	AudioServer.set_bus_mute(sfx_index, GameSession.audio_muted)
	AudioServer.set_bus_mute(bgm_index, GameSession.audio_muted)


# --- 내부 -----------------------------------------------------------------------

static func _ensure_buses() -> void:
	for bus_name: StringName in [BUS_SFX, BUS_BGM]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")


static func _ensure_ready() -> bool:
	if _host != null and is_instance_valid(_host) and _host.is_inside_tree():
		return true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	if _host == null or not is_instance_valid(_host):
		_ensure_buses()
		_host = Node.new()
		_host.name = "SfxHost"
		_pool.clear()
		for i: int in POOL_SIZE:
			var player := AudioStreamPlayer.new()
			player.bus = BUS_SFX
			_host.add_child(player)
			_pool.append(player)
		_bgm = AudioStreamPlayer.new()
		_bgm.bus = BUS_BGM
		_host.add_child(_bgm)
		tree.root.add_child.call_deferred(_host)
		apply_settings()
	return _host.is_inside_tree()


static func _scan() -> void:
	_scanned = true
	_index.clear()
	_scan_dir(SFX_DIR)


static func _scan_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan_dir("%s/%s" % [path, sub])
	for file_name: String in dir.get_files():
		# 내보낸 빌드에서는 파일이 *.ogg.import / *.ogg.remap 이름으로 보인다
		var clean: String = file_name.trim_suffix(".import").trim_suffix(".remap")
		var lower: String = clean.to_lower()
		if not (lower.ends_with(".ogg") or lower.ends_with(".wav") or lower.ends_with(".mp3")):
			continue
		var full: String = "%s/%s" % [path, clean]
		_index[lower.get_basename()] = full


static func _files_for(event: StringName) -> Array[String]:
	if not _scanned:
		_scan()
	if _cache.has(event):
		return _cache[event]
	var found: Array[String] = []
	var prefix: String = String(event).to_lower()
	for base: String in _index.keys():
		if base.begins_with(prefix):
			found.append(_index[base])
	if found.is_empty() and EVENTS.has(event):
		for keyword: String in (EVENTS[event] as Array)[1]:
			for base: String in _index.keys():
				if base.contains(keyword.to_lower()):
					found.append(_index[base])
			if not found.is_empty():
				break
	found.sort()
	_cache[event] = found
	return found


static func _stream_for(event: StringName) -> AudioStream:
	var files: Array[String] = _files_for(event)
	if files.is_empty():
		return null
	return load(files[randi() % files.size()]) as AudioStream


static func _find_bgm(track: StringName) -> String:
	for extension: String in ["ogg", "mp3", "wav"]:
		var path: String = "%s/%s.%s" % [BGM_DIR, track, extension]
		if ResourceLoader.exists(path):
			return path
	return ""
