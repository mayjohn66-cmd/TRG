## Native audio-only check. Run with --audio-driver Dummy, without --headless.
## Captures actual mixed Vorbis PCM; no speaker or personal settings required.
extends SceneTree

const EVENTS: Array[StringName] = [&"rail_lay", &"train_chug", &"train_whistle", &"chain_pull", &"chain_lock", &"bakery_door", &"bakery_rummage", &"cutin_slash", &"pinball_hit"]
var failures: Array[String] = []
var capture: AudioEffectCapture

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not Sfx.enabled():
		push_error("Use a native display with --audio-driver Dummy for the mixer check")
		quit(1)
		return
	GameSession.audio_muted = false
	GameSession.sfx_muted = false
	GameSession.sfx_volume = 1.0
	Sfx.unlock()
	await process_frame
	capture = AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(0, capture)
	# Optional audited scene gains, exported directly from the production calls.
	var gains: Dictionary = {}
	var gain_file := OS.get_environment("SFX_MIX_GAINS")
	if not gain_file.is_empty():
		gains = JSON.parse_string(FileAccess.get_file_as_string(gain_file))
	for event: StringName in EVENTS:
		for player: AudioStreamPlayer in Sfx._pool:
			player.stop()
		await create_timer(0.12).timeout
		capture.clear_buffer()
		var gain_db := float(gains.get(String(event), -3.0))
		Sfx.play(event, gain_db, 0.0)
		await create_timer(0.45).timeout
		var pcm := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		for sample: Vector2 in pcm:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		if peak < 0.001 or peak >= 0.99:
			failures.append("Silent or clipped mixer output: %s (%f)" % [event, peak])
		print("SFX_PCM %s gain=%.1f peak=%.4f frames=%d" % [event, gain_db, peak, pcm.size()])
	# Many short wheel beats must not steal a still-playing whistle voice.
	for player: AudioStreamPlayer in Sfx._pool:
		player.stop()
	Sfx.play(&"train_whistle", -3.0, 0.0)
	var whistle: AudioStreamPlayer
	for player: AudioStreamPlayer in Sfx._pool:
		if player.playing:
			whistle = player
	var original: AudioStream = whistle.stream if whistle != null else null
	for index: int in 24:
		Sfx.play(&"train_chug", -12.0, 0.0)
		await create_timer(0.065).timeout
	if whistle == null or not whistle.playing or whistle.stream != original:
		failures.append("Short wheel beats interrupted the whistle")
	GameSession.audio_muted = true
	var next_before := Sfx._next
	Sfx.play(&"rail_lay")
	if Sfx._next != next_before:
		failures.append("Master mute allowed a new presentation sound")
	GameSession.audio_muted = false
	for player: AudioStreamPlayer in Sfx._pool:
		player.stop()
	GameSession.sfx_muted = true
	Sfx.apply_settings()
	await create_timer(0.2).timeout
	capture.clear_buffer()
	Sfx.play(&"cutin_slash", -3.0, 0.0)
	await create_timer(0.4).timeout
	for sample: Vector2 in capture.get_buffer(capture.get_frames_available()):
		if sample.length() > 0.00001:
			failures.append("SFX mute leaked into the master output")
			break
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
	capture = null
	original = null
	Sfx._pool.clear()
	Sfx._host.queue_free()
	Sfx._host = null
	Sfx._voice = null
	Sfx._bgm = null
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("SFX_PLAYBACK_OK: nine events emit PCM; whistle survives wheel beats; mute respected")
	else:
		for failure: String in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
