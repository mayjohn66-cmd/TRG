## Validate actual captured sound requests and their resolvable runtime streams.
extends SceneTree

const REQUIRED := {
	"D6":["dice_roll"], "CHINCHIRO":["dice_roll"], "YUT":["yut_toss","yut_clack"],
	"LIFE_ROULETTE":["roulette_tick","roulette_stop"], "SLOT_777":["slot_spin","slot_stop"],
	"REVOLVER":["toy_click"], "DICE_HWATU":["card_pick"], "DICE_TAROT":["card_pick"],
	"HOLDEM":["card_throw","card_pick"], "DICE_MAHJONG":["mahjong_tap"],
	"DICE_YACHT":["dice_roll","thud"], "DICE_BLACKJACK":["card_throw"],
	"DICE_PINBALL":["pinball_launch","pinball_hit"], "DICE_STOCK":[],
	"DICE_DARTS":["dart_throw","dart_hit"], "DICE_OMIKUJI":["omikuji_draw","paper_unfold"],
	"DICE_ICECREAM":["wrapper_tear","icecream_snap","icecream_reveal"],
	"DICE_COOKIE":["cookie_crack","paper_unfold"], "DICE_CAPSULE":["toy_click","yut_clack"],
	"DICE_PIRATE":["toy_click"], "DICE_SCRATCH":["ticket_rustle"]
}

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder:=OS.get_cmdline_user_args()[0]
	var clips: Array=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("clips.json")))
	var seen: Dictionary={}
	var streams: Dictionary={}
	var failures: Array[String]=[]
	for clip: Dictionary in clips:
		seen[clip.tool_id]=true
		var counts: Dictionary=clip.get("sfx_counts",{})
		if counts.is_empty(): failures.append(str(clip.name)+": no sound requests")
		for event: String in REQUIRED.get(clip.tool_id,[]):
			if int(counts.get(event,0))<1: failures.append(str(clip.name)+": missing "+event)
		for event: String in counts:
			if streams.has(event): continue
			var stream:=Sfx._stream_for(StringName(event))
			if stream==null or stream.get_length()<=0: failures.append("Unresolved/empty audio: "+event)
			else: streams[event]={"seconds":stream.get_length(),"type":stream.get_class()}
	for id: String in REQUIRED:
		if not seen.has(id): failures.append("Uncaptured tool: "+id)
	var report:={"tools":seen.size(),"clips":clips.size(),"streams":streams,"failures":failures,"notes":"Requests are recorded at the call sites; captured MP4 audio is checked separately. Random bonus outcomes are tested in ui_tool_audio_test.gd."}
	var file:=FileAccess.open(folder.path_join("audio-audit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	for failure: String in failures: printerr("AUDIO_AUDIT_FAIL ",failure)
	print("AUDIO_AUDIT ",seen.size()," tools; ",clips.size()," clips; ",streams.size()," streams; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
