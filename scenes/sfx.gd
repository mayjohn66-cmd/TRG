# File: res://scenes/sfx.gd
# Class: class_name Sfx
# Role: 효과음·배경음 재생기. 사용자 파일 → 큐레이션 목록 → 기존 파일 → 합성 폴백 순서로 찾는다. 음량·음소거는 GameSession 설정을 따른다.
class_name Sfx
extends RefCounted

const SFX_DIR: String = "res://assets/sfx"
const CURATED = preload("res://assets/sfx/curated/catalog.gd")
const BGM_DIR: String = "res://assets/bgm"
## 사용자가 직접 소리 파일을 넣는 폴더 (assets/ 와 똑같이 이름 규칙으로 찾는다). 파일이 있으면 합성음보다 우선한다.
const USER_SFX_DIR: String = "res://content_trickcal/audio/sfx"
const USER_BGM_DIR: String = "res://content_trickcal/audio/bgm"
const LOBBY_TRACK: StringName = &"lobby_daylife"
const BATTLE_TRACK: StringName = &"battle_monatium_night"
const MIX_RATE: int = 22050
const BUS_SFX: StringName = &"SFX"
const BUS_BGM: StringName = &"BGM"
const POOL_SIZE: int = 12

## 이벤트 -> (설명, 파일 이름에 들어 있으면 쓰는 키워드들). 파일 이름이 이벤트 이름으로 시작하면(예: hop_01.ogg) 그것이 우선이고, 없으면 키워드(Kenney 팩 이름 등)로 찾는다.
const EVENTS: Dictionary = {
	&"ui_click": ["버튼 클릭", ["click", "button", "select", "tap"]],
	&"hop": ["말 점프 착지 (톡)", ["chip-lay", "chips-stack", "card-place", "place"]],
	&"slam": ["내리찍기 (잡을 때 쾅)", ["impact", "thud", "slam", "chips-collide"]],
	&"launch": ["잡힌 말 장외 홈런·점프 코너 비행 (위로 솟는 소리)", ["whoosh", "swoosh", "phase-jump", "slide"]],
	&"rocket": ["리벤지 부스터 로켓 출격 (분사 화염)", ["rocket", "thruster"]],
	&"warp": ["옷장 포탈 워프 (빨려 들어감)", ["warp", "portal", "phaser-down"]],
	&"trap_set": ["은신 함정 설치 (조용한 걸쇠)", ["trap-set", "latch"]],
	&"thud": ["출발선에 쿵 떨어짐", ["thud", "chips-handle", "place"]],
	&"dice_roll": ["주사위·친치로 굴림", ["dice-throw", "die-throw", "dice"]],
	&"roll_other": ["기타 도구 보조 넘김음", ["card-fan", "shuffle"]],
	&"card_pick": ["카드 집어 듦", ["card-fan", "card-slide", "card-shove"]],
	&"card_throw": ["카드 던짐", ["card-shove", "card-slide", "whoosh"]],
	&"card_get": ["카드 획득·드로우", ["card-place", "card-fan"]],
	&"card_impact": ["카드 발동 임팩트", ["card-place", "impact", "thud"]],
	&"mahjong_tap": ["마작패 단단한 착지 (탁)", ["mahjong-tap", "tile-clack"]],
	&"yut_clack": ["나무 윷가락 착지 (따닥)", ["yut-clack", "wood-clack"]],
	&"yut_toss": ["네 윷가락을 함께 던지는 바람", ["yut-toss"]],
	&"toy_click": ["장난감 총 빈 약실 (찰칵)", ["toy-click"]],
	&"toy_party_pop": ["스프링 깃발과 색종이 폭죽 (뿅)", ["toy-party-pop"]],
	&"slot_spin": ["슬롯 릴 회전 기계음", ["slot-spin"]],
	&"slot_stop": ["슬롯 릴 정지 (철컥)", ["slot-stop"]],
	&"roulette_tick": ["룰렛 포인터 눈금 클릭", ["roulette-tick"]],
	&"roulette_stop": ["룰렛 정착", ["roulette-stop"]],
	&"augment_show": ["증강 카드 등장", ["card-fan", "card-shuffle", "shuffle"]],
	&"augment_pick": ["증강 선택", ["card-place", "select", "click"]],
	&"law": ["새 교칙 찍힘", ["impact", "stamp", "thud", "chips-collide"]],
	&"law_drop": ["오래된 교칙 밀려남", ["whoosh", "slide"]],
	&"promote": ["승급 반짝임", ["sparkle", "magic", "chime", "powerup"]],
	&"charge": ["돌진 차징", ["charge", "whoosh"]],
	&"dash": ["부스터 발판·처치 컷인 돌진", ["dash", "whoosh", "swoosh", "shot"]],
	&"shot": ["뱅! 장난감 총 발사", ["shot", "gun", "laser"]],
	&"good": ["좋은 일 (나이스/골인)", ["win", "coin", "chime", "success"]],
	&"bad": ["나쁜 일 (억까/으악)", ["lose", "fail", "buzz", "error"]],
	&"game_start": ["GAME START 배너", ["start", "fanfare", "impact"]],
	&"win": ["승리", ["win", "fanfare", "victory"]],
	&"trap": ["함정 발동 (경보·폭발)", ["explosion", "alarm", "trap"]],
	&"ui_hover": ["버튼에 올림", ["hover"]],
}

## 기획서의 사운드 이름 -> 실제 이벤트 이름 (어느 이름으로 불러도 같은 소리가 난다).
const ALIASES: Dictionary = {
	&"pawn_step": &"hop", &"pawn_capture": &"slam", &"card_slam": &"card_impact", &"trap_trigger": &"trap",
	&"skill_ult": &"promote", &"law_enact": &"law", &"fanfare_win": &"win", &"dice_charge": &"charge",
}

## 파일이 없는 이벤트를 코드로 합성하는 방법. 마디(segment)마다 [시작초, 길이초, 시작Hz, 끝Hz, 파형, 음량, 잡음비율(0~1)] 이고,
## 파형은 sine/tri/square/noise. 소리 크기는 마디 안에서 지수로 줄어든다 (decay는 클수록 빨리 사라짐).
const SYNTH: Dictionary = {
	&"ui_click": [[0.0, 0.05, 800.0, 1200.0, "sine", 0.6, 0.0, 5.0]],
	&"ui_hover": [[0.0, 0.03, 1000.0, 1300.0, "sine", 0.25, 0.0, 6.0]],
	&"charge": [[0.0, 0.35, 300.0, 1100.0, "tri", 0.45, 0.05, 1.2]],
	&"dice_roll": [[0.0, 0.03, 1800.0, 900.0, "square", 0.35, 0.5, 6.0], [0.07, 0.03, 1500.0, 800.0, "square", 0.35, 0.5, 6.0], [0.13, 0.03, 2000.0, 1000.0, "square", 0.35, 0.5, 6.0], [0.2, 0.03, 1600.0, 900.0, "square", 0.3, 0.5, 6.0], [0.28, 0.04, 1900.0, 700.0, "square", 0.3, 0.5, 6.0]],
	&"roll_other": [[0.0, 0.03, 1400.0, 700.0, "square", 0.3, 0.6, 6.0], [0.09, 0.03, 1700.0, 800.0, "square", 0.3, 0.6, 6.0], [0.17, 0.04, 1500.0, 700.0, "square", 0.3, 0.6, 6.0]],
	&"hop": [[0.0, 0.1, 300.0, 650.0, "sine", 0.65, 0.0, 3.0]],
	&"slam": [[0.0, 0.25, 150.0, 40.0, "sine", 0.9, 0.0, 4.0], [0.0, 0.18, 0.0, 0.0, "noise", 0.6, 1.0, 7.0]],
	&"thud": [[0.0, 0.16, 110.0, 45.0, "sine", 0.85, 0.0, 5.0]],
	# Fast hard-resin click plus a short table-body resonance; separate from paper/card SFX.
	&"mahjong_tap": [[0.0,0.024,2700.0,1650.0,"tri",0.60,0.22,9.0], [0.0,0.014,0.0,0.0,"noise",0.32,1.0,9.0], [0.002,0.075,620.0,270.0,"sine",0.67,0.0,6.5], [0.005,0.095,185.0,120.0,"sine",0.21,0.0,7.0]],
	&"yut_clack": [[0.0,0.018,1700.0,950.0,"tri",0.42,0.18,8.0], [0.001,0.082,460.0,235.0,"sine",0.76,0.0,6.5], [0.003,0.058,820.0,590.0,"sine",0.20,0.0,8.0], [0.0,0.012,0.0,0.0,"noise",0.22,1.0,9.0]],
	&"yut_toss": [[0.0,0.20,360.0,650.0,"tri",0.11,0.85,3.2]],
	&"toy_click": [[0.0,0.020,1300.0,800.0,"tri",0.42,0.10,8.0],[0.002,0.045,330.0,190.0,"sine",0.35,0.0,8.0]],
	&"toy_party_pop": [[0.0,0.025,0.0,0.0,"noise",0.10,1.0,9.0],[0.0,0.13,350.0,460.0,"tri",0.24,0.0,2.0],[0.10,0.13,466.0,466.0,"tri",0.22,0.0,2.0],[0.20,0.15,587.0,587.0,"tri",0.22,0.0,2.0],[0.32,0.34,698.0,660.0,"tri",0.25,0.0,3.0],[0.32,0.32,349.0,330.0,"sine",0.17,0.0,3.0]],
	&"slot_spin": [[0.0,0.17,130.0,140.0,"tri",0.18,0.35,0.5]],
	&"slot_stop": [[0.0,0.018,1600.0,700.0,"tri",0.35,0.22,8.0],[0.002,0.075,240.0,110.0,"sine",0.65,0.0,8.0]],
	&"roulette_tick": [[0.0,0.017,2500.0,1200.0,"tri",0.48,0.10,8.0],[0.001,0.032,700.0,430.0,"sine",0.30,0.0,7.0]],
	&"roulette_stop": [[0.0,0.045,640.0,290.0,"tri",0.44,0.08,7.0],[0.008,0.085,290.0,180.0,"sine",0.50,0.0,8.0]],
	&"card_impact": [[0.0, 0.2, 240.0, 90.0, "square", 0.45, 0.2, 5.0], [0.0, 0.12, 0.0, 0.0, "noise", 0.45, 1.0, 8.0]],
	&"card_throw": [[0.0, 0.16, 500.0, 1000.0, "tri", 0.25, 0.7, 3.5]],
	&"card_pick": [[0.0, 0.06, 500.0, 760.0, "sine", 0.5, 0.0, 5.0]],
	&"card_get": [[0.0, 0.05, 520.0, 780.0, "sine", 0.5, 0.0, 4.0], [0.05, 0.08, 780.0, 1040.0, "sine", 0.5, 0.0, 4.0]],
	&"augment_show": [[0.0, 0.18, 400.0, 900.0, "tri", 0.35, 0.15, 3.0]],
	&"augment_pick": [[0.0, 0.07, 660.0, 880.0, "sine", 0.5, 0.0, 4.0], [0.07, 0.12, 880.0, 1320.0, "sine", 0.5, 0.0, 4.0]],
	&"trap": [[0.0, 0.14, 880.0, 880.0, "square", 0.35, 0.0, 2.0], [0.14, 0.14, 620.0, 620.0, "square", 0.35, 0.0, 2.0], [0.0, 0.3, 0.0, 0.0, "noise", 0.55, 1.0, 5.0]],
	&"shot": [[0.0, 0.12, 900.0, 200.0, "square", 0.45, 0.4, 6.0], [0.0, 0.1, 0.0, 0.0, "noise", 0.5, 1.0, 8.0]],
	&"dash": [[0.0, 0.22, 400.0, 1500.0, "tri", 0.3, 0.7, 3.0]],
	&"launch": [[0.0, 0.25, 1400.0, 300.0, "tri", 0.3, 0.7, 3.0]],
	&"promote": [[0.0, 0.14, 660.0, 660.0, "sine", 0.5, 0.0, 3.0], [0.09, 0.14, 880.0, 880.0, "sine", 0.5, 0.0, 3.0], [0.18, 0.3, 1320.0, 1320.0, "sine", 0.5, 0.0, 3.0]],
	&"law": [[0.0, 0.28, 130.0, 55.0, "sine", 0.95, 0.0, 4.0], [0.0, 0.06, 0.0, 0.0, "noise", 0.55, 1.0, 12.0]],
	&"law_drop": [[0.0, 0.22, 900.0, 250.0, "tri", 0.3, 0.7, 4.0]],
	&"good": [[0.0, 0.1, 523.0, 523.0, "sine", 0.5, 0.0, 3.0], [0.09, 0.1, 659.0, 659.0, "sine", 0.5, 0.0, 3.0], [0.18, 0.24, 784.0, 784.0, "sine", 0.5, 0.0, 3.0]],
	&"bad": [[0.0, 0.14, 392.0, 392.0, "tri", 0.5, 0.0, 3.0], [0.13, 0.3, 311.0, 247.0, "tri", 0.5, 0.0, 3.0]],
	&"game_start": [[0.0, 0.12, 392.0, 392.0, "square", 0.3, 0.0, 2.0], [0.12, 0.12, 523.0, 523.0, "square", 0.3, 0.0, 2.0], [0.24, 0.45, 784.0, 784.0, "square", 0.3, 0.0, 2.0], [0.0, 0.2, 100.0, 50.0, "sine", 0.7, 0.0, 4.0]],
	&"win": [[0.0, 0.16, 523.0, 523.0, "sine", 0.5, 0.0, 2.0], [0.16, 0.16, 659.0, 659.0, "sine", 0.5, 0.0, 2.0], [0.32, 0.16, 784.0, 784.0, "sine", 0.5, 0.0, 2.0], [0.48, 0.6, 1047.0, 1047.0, "sine", 0.55, 0.0, 2.0]],
}

static var _synth_cache: Dictionary = {}
static var _index: Dictionary = {}
static var _scanned: bool = false
static var _cache: Dictionary = {}
static var _last_variant: Dictionary = {}
static var _last_play_ms: Dictionary = {}
## Only repetitive controls/ticks are gated; tile and Yut landings stay independent.
const MIN_INTERVAL_MS: Dictionary = {&"ui_click": 45, &"ui_hover": 90, &"roulette_tick": 24, &"slot_spin": 120}
static var _pool: Array[AudioStreamPlayer] = []
static var _next: int = 0
static var _host: Node = null
static var _bgm: AudioStreamPlayer = null
static var _bgm_name: StringName = &""


## 소리를 낼 수 있는 환경인가 (헤드리스 테스트에서는 항상 꺼져 있다).
static func enabled() -> bool:
	return DisplayServer.get_name() != "headless"


## 이벤트 소리를 낸다. volume_db는 그 소리만의 보정, pitch_variance는 반복 소리가 지루하지 않게 음높이를 조금 흔드는 폭이다.
## pitch는 기본 음높이 배율이다 (말이 연달아 걸을 때 한 칸마다 조금씩 높여 다다다닥 달리는 느낌을 낸다).
static func play(event: StringName, volume_db: float = 0.0, pitch_variance: float = 0.06, pitch: float = 1.0) -> void:
	if not enabled() or GameSession.audio_muted:
		return
	event = ALIASES.get(event, event)
	var now: int = Time.get_ticks_msec()
	if MIN_INTERVAL_MS.has(event) and now - int(_last_play_ms.get(event, -10000)) < int(MIN_INTERVAL_MS[event]):
		return
	var stream: AudioStream = _stream_for(event)
	if stream == null or not _ensure_ready():
		return
	_last_play_ms[event] = now
	var player: AudioStreamPlayer = _pool[_next % _pool.size()]
	_next += 1
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch * (1.0 + randf_range(-pitch_variance, pitch_variance))
	player.play()


## 웹 브라우저의 소리 자동 재생 차단 해제: 사용자가 처음 클릭할 때 호출한다 (오디오 장치와 버스를 미리 깨워 둔다).
static func unlock() -> void:
	if enabled():
		_ensure_ready()
		apply_settings()


## 지금 이 이벤트에 연결된 소리 파일이 있는가 (설정 화면 시험 버튼 등에서 쓴다).
static func has_sound(event: StringName) -> bool:
	return _files_for(ALIASES.get(event, event)).size() > 0


## 이미지 스킨을 다시 입혀도 클릭음은 한 번만 연결한다.
static func bind_button(button: BaseButton) -> void:
	var callback: Callable = play.bind(&"ui_click")
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


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
	AudioServer.set_bus_mute(sfx_index, GameSession.audio_muted or GameSession.sfx_muted)
	AudioServer.set_bus_mute(bgm_index, GameSession.audio_muted or GameSession.bgm_muted)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(GameSession.master_volume, 0.0001)))


# --- 내부 -----------------------------------------------------------------------

static func _ensure_buses() -> void:
	for bus_name: StringName in [BUS_SFX, BUS_BGM]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index: int = AudioServer.get_bus_count()
			# Web Sample playback: add_bus() forwards append as -1 and the
			# 4.7 JS bridge reorders Master, disconnecting every sample.
			# Growing the count appends without that buggy bus-move path.
			# https://github.com/godotengine/godot/issues/119026
			AudioServer.set_bus_count(index + 1)
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
	_scan_dir(USER_SFX_DIR)  # 나중에 스캔하므로 같은 이름이면 사용자가 넣은 파일이 이긴다


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
	# 기획서 이름(pawn_step.ogg 등)으로 넣은 파일도 같은 이벤트로 찾는다.
	var prefixes: Array[String] = [String(event).to_lower()]
	for alias: Variant in ALIASES.keys():
		if ALIASES[alias] == event:
			prefixes.append(String(alias).to_lower())
	for base: String in _index.keys():
		# law 와 law_drop 처럼 이름이 겹치는 이벤트가 섞이지 않게, 이벤트 이름 뒤에는 번호만 올 수 있다 (law_01, law-2 ...).
		for prefix: String in prefixes:
			if base == prefix or _is_numbered_variant(base, prefix):
				found.append(_index[base])
				break
	# An event override replaces the whole curated set, even with a different
	# variant suffix. Legacy random candidates never mix with curated effects.
	var overrides: Array[String] = []
	for path: String in found:
		if path.begins_with(USER_SFX_DIR + "/"):
			overrides.append(path)
	if not overrides.is_empty():
		found = overrides
	elif CURATED.FILES.has(event):
		found.assign(CURATED.FILES[event])
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


static func _is_numbered_variant(base: String, prefix: String) -> bool:
	if not base.begins_with(prefix) or base.length() == prefix.length():
		return false
	var rest: String = base.substr(prefix.length()).lstrip("_-")
	return rest.is_valid_int()


static func _stream_for(event: StringName) -> AudioStream:
	var files: Array[String] = _files_for(event)
	if files.is_empty():
		return synth(event)  # 소리 파일이 아직 없으면 코드로 만든 합성음을 쓴다
	var index: int = randi() % files.size()
	if files.size() > 1 and index == int(_last_variant.get(event, -1)):
		index = (index + 1 + randi() % (files.size() - 1)) % files.size()
	_last_variant[event] = index
	return load(files[index]) as AudioStream


## 파일 없이 코드로 만든 효과음(16비트 PCM). 이벤트마다 한 번만 만들어 캐시한다. 합성법이 없는 이벤트는 null.
static func synth(event: StringName) -> AudioStreamWAV:
	event = ALIASES.get(event, event)
	if _synth_cache.has(event):
		return _synth_cache[event]
	if not SYNTH.has(event):
		return null
	var segments: Array = SYNTH[event]
	var length: float = 0.0
	for segment: Array in segments:
		length = maxf(length, float(segment[0]) + float(segment[1]))
	var count: int = int(length * MIX_RATE) + 1
	var mix: PackedFloat32Array = PackedFloat32Array()
	mix.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(event))  # 같은 이벤트는 늘 같은 잡음
	for segment: Array in segments:
		_render_segment(mix, segment, rng)
	var peak: float = 0.0001
	for value: float in mix:
		peak = maxf(peak, absf(value))
	var data := PackedByteArray()
	data.resize(count * 2)
	var gain: float = minf(1.0, 0.9 / peak)
	for i: int in count:
		data.encode_s16(i * 2, int(clampf(mix[i] * gain, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	_synth_cache[event] = stream
	return stream


static func _render_segment(mix: PackedFloat32Array, segment: Array, rng: RandomNumberGenerator) -> void:
	var start: int = int(float(segment[0]) * MIX_RATE)
	var samples: int = int(float(segment[1]) * MIX_RATE)
	var f0: float = segment[2]
	var f1: float = segment[3]
	var wave: String = segment[4]
	var volume: float = segment[5]
	var noise_mix: float = segment[6]
	var decay: float = segment[7]
	var phase: float = 0.0
	for i: int in samples:
		var index: int = start + i
		if index >= mix.size():
			break
		var progress: float = float(i) / float(maxi(samples - 1, 1))
		phase += TAU * lerpf(f0, f1, progress) / MIX_RATE
		var tone: float = 0.0
		match wave:
			"sine": tone = sin(phase)
			"tri": tone = asin(sin(phase)) * 2.0 / PI
			"square": tone = 1.0 if sin(phase) >= 0.0 else -1.0
		var noise: float = rng.randf_range(-1.0, 1.0)
		var sample: float = lerpf(tone, noise, noise_mix) if wave != "noise" else noise
		var envelope: float = exp(-decay * progress) * minf(1.0, float(i) / 90.0)  # 첫 몇 ms는 서서히 켜 '딱' 소리를 막는다
		mix[index] += sample * volume * envelope


static func _find_bgm(track: StringName) -> String:
	for folder: String in [USER_BGM_DIR, BGM_DIR]:
		for extension: String in ["ogg", "mp3", "wav"]:
			var path: String = "%s/%s.%s" % [folder, track, extension]
			if ResourceLoader.exists(path):
				return path
	return ""
