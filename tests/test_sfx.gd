# File: res://tests/test_sfx.gd
# Class: class_name TestSfx
# Role: 파일 없이도 소리가 나는 합성 효과음(Sfx.synth)과 이름 별칭을 검사한다 (헤드리스에서는 재생 자체는 건너뛴다)
class_name TestSfx
extends TestCase


func test_every_synth_event_makes_a_sound() -> void:
	for event: StringName in Sfx.SYNTH.keys():
		var stream: AudioStreamWAV = Sfx.synth(event)
		check(stream != null and stream.data.size() > 200, "%s 합성음이 만들어진다" % event)
		check(stream != null and stream.mix_rate == Sfx.MIX_RATE and stream.format == AudioStreamWAV.FORMAT_16_BITS, "%s 16비트 PCM" % event)


func test_spec_names_alias_to_events() -> void:
	for alias: StringName in [&"pawn_step", &"pawn_capture", &"card_slam", &"trap_trigger", &"skill_ult", &"law_enact", &"fanfare_win", &"dice_charge"]:
		check(Sfx.synth(alias) != null, "%s 이름으로도 합성음이 있다" % alias)
	check(Sfx.synth(&"pawn_step") == Sfx.synth(&"hop"), "별칭은 같은 소리를 가리킨다")
	check(Sfx.synth(&"no_such_event") == null, "모르는 이름은 소리가 없다")


func test_sounds_are_distinct_and_cached() -> void:
	check(Sfx.synth(&"hop") == Sfx.synth(&"hop"), "한 번 만든 합성음은 캐시된다")
	check(Sfx.synth(&"hop").data != Sfx.synth(&"slam").data, "이벤트마다 다른 파형")
	check(Sfx.synth(&"slam").data.size() > Sfx.synth(&"ui_click").data.size(), "묵직한 타격음이 클릭보다 길다")


func test_headless_play_is_silent_and_safe() -> void:
	Sfx.play(&"hop")
	Sfx.play(&"pawn_capture", 0.0, 0.0, 1.2)
	check(not Sfx.enabled(), "헤드리스에서는 오디오가 꺼져 있다")


func test_repeated_play_spaces_the_sounds_and_stays_safe_without_audio() -> void:
	# 템포 업 경고음: 기존 소리를 4번 되풀이 (헤드리스에서는 재생을 건너뛰지만 간격만큼은 기다린다)
	check_eq(MainBoard.TEMPO_WARNING_REPEATS, 4, "템포 업 경고음은 4번")
	check(MainBoard.TEMPO_WARNING_GAP >= 0.55, "한 번이 약 0.53초라 간격이 그보다 길어 겹치지 않는다")
	Sfx.play_repeated(&"tempo_warning", 0, 0.1)  # 0번은 1번으로 본다: 터지지 않는다
	Sfx.play_repeated(&"tempo_warning", 3, 0.05, 0.0, 0.03)
	check(not Sfx.enabled(), "헤드리스에서는 조용히 지나간다")
