# File: tests/avatar_pack_smoke.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 웹 본체(index.pck)에서 빠진 아바타 애니메이션이 아바타별 avatars/<id>.pck를 붙이면 그대로 읽히는지 검사한다.
#       CI: (cd build/web && godot --headless --main-pack index.pck -s <이 파일의 절대 경로>)
#       본체에는 정지 그림만 있고(애니메이션은 없음), 묶음을 붙인 뒤에는 감정 프레임·허브 대기 프레임이 실제 텍스처로 읽혀야 한다.
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	for id: StringName in AvatarCatalog.ids():
		var folder: String = AvatarSlot.character_path(id)
		var emotion: String = folder + "/emotion_happy.tres"
		if not ResourceLoader.exists(folder + "/portrait.png") or not ResourceLoader.exists(folder + "/icon.webp"):
			failures.append("%s: 본체에 정지 그림(portrait·icon)이 없다" % id)
		if ResourceLoader.exists(emotion):
			failures.append("%s: 감정 애니메이션이 본체에 남아 있다 (분리되지 않음)" % id)
		if AvatarPacks.is_ready(id):
			failures.append("%s: 묶음을 붙이기 전인데 준비됨으로 나온다" % id)
		var pack: String = "avatars/%s.pck" % id
		if not FileAccess.file_exists(pack):
			failures.append("%s: %s 파일이 없다" % [id, pack])
			continue
		if not ProjectSettings.load_resource_pack(pack, false):
			failures.append("%s: 묶음을 붙이지 못했다" % id)
			continue
		if not AvatarPacks.is_ready(id):
			failures.append("%s: 묶음을 붙였는데 준비되지 않았다" % id)
		var frames: SpriteFrames = load(emotion) as SpriteFrames
		var texture: Texture2D = frames.get_frame_texture(frames.get_animation_names()[0], 0) if frames != null and not frames.get_animation_names().is_empty() else null
		if texture == null or texture.get_width() <= 0:
			failures.append("%s: 감정 프레임 텍스처를 읽지 못했다" % id)
		var hq: String = folder + "/idle_hq.tres"
		if ResourceLoader.exists(hq):
			var idle: SpriteFrames = load(hq) as SpriteFrames
			if idle == null or idle.get_frame_count(&"idle") == 0 or idle.get_frame_texture(&"idle", 0) == null:
				failures.append("%s: 고화질 대기 프레임을 읽지 못했다" % id)
		elif not ResourceLoader.exists(folder + "/idle/idle_00.webp"):
			failures.append("%s: 허브 대기 프레임이 묶음에 없다" % id)
	if failures.is_empty():
		print("AVATAR_PACK_SMOKE_OK %d packs" % AvatarCatalog.ids().size())
	else:
		for failure: String in failures:
			printerr("AVATAR_PACK_SMOKE_FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
