extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	if Sfx.CURATED.FILES.size() != Sfx.EVENTS.size():
		failures.append("Every event must have a curated recording")
	for event: StringName in Sfx.EVENTS:
		var paths: Array[String] = Sfx._files_for(event)
		if paths.is_empty(): failures.append("Missing event: " + String(event))
		for path: String in paths:
			if not path.begins_with("res://assets/sfx/curated/"):
				failures.append("Legacy sound mixed into " + String(event))
			var stream: AudioStream = load(path) as AudioStream
			if stream == null or stream.get_length() <= 0.0 or stream.get_length() > 1.85:
				failures.append("Invalid or excessive duration: " + path)
		if paths.size() > 1:
			var previous: AudioStream = Sfx._stream_for(event)
			for i: int in 12:
				var current: AudioStream = Sfx._stream_for(event)
				if current == previous: failures.append("Repeated variant: " + String(event))
				previous = current
	if not Sfx.has_sound(&"pawn_step"): failures.append("Alias does not resolve")
	# Simulate a custom event variant without touching the user's content files.
	Sfx._index["pawn_step_99"] = Sfx.USER_SFX_DIR + "/pawn_step_99.ogg"
	Sfx._cache.erase(&"hop")
	if Sfx._files_for(&"hop") != [Sfx.USER_SFX_DIR + "/pawn_step_99.ogg"]:
		failures.append("Custom event must replace the entire curated set")
	Sfx._index.erase("pawn_step_99")
	Sfx._cache.erase(&"hop")
	if failures.is_empty():
		print("SFX_ASSETS_OK: %d curated events" % Sfx.EVENTS.size() + ", valid streams, varied impacts, alias and user override")
	else:
		for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
