class_name AvatarCombatArt
extends RefCounted

const ROOT: String = "res://content_trickcal/avatars"
static var _cache: Dictionary = {}

## Identity-preserving fallback: never substitute another character's pose.
static func texture(avatar: StringName, pose: StringName) -> Texture2D:
	avatar = AvatarCatalog.sanitize(avatar)
	if pose != &"attack" and pose != &"hit":
		return null
	var key: String = "%s/%s" % [avatar, pose]
	if _cache.has(key):
		return _cache[key]
	for file: String in [String(pose) + ".png", "fullbody.png", "portrait.png"]:
		var path: String = "%s/%s/%s" % [ROOT, avatar, file]
		if ResourceLoader.exists(path):
			var loaded: Texture2D = TextureCache.fetch(path)
			if loaded != null:
				_cache[key] = loaded
				return loaded
	return null


## 이번 판에 앉은 사도의 자세 그림만 남긴다 (다른 판의 사도 그림이 계속 쌓이지 않게).
static func retain(avatars: Array) -> void:
	var keep: Array = avatars.map(func(id: Variant) -> StringName: return AvatarCatalog.sanitize(StringName(str(id))))
	for key: String in _cache.keys():
		if not keep.has(StringName(key.get_slice("/", 0))):
			_cache.erase(key)


static func has_pose(avatar: StringName, pose: StringName) -> bool:
	return ResourceLoader.exists("%s/%s/%s.png" % [ROOT, AvatarCatalog.sanitize(avatar), pose])


static func warm(avatar: StringName) -> void:
	texture(avatar, &"attack")
	texture(avatar, &"hit")


## Normalized points align a weapon/fist with the opponent's cheek.
static func contact(avatar: StringName, pose: StringName) -> Vector2:
	if pose == &"hit":
		match avatar:
			&"avatar_01": return Vector2(0.40, 0.34)
			&"avatar_02": return Vector2(0.37, 0.33)
			&"avatar_03": return Vector2(0.43, 0.29)
			&"avatar_04": return Vector2(0.40, 0.34)
			&"avatar_05": return Vector2(0.40, 0.33)
			&"avatar_06": return Vector2(0.40, 0.33)
			&"avatar_07": return Vector2(0.41, 0.33)
			&"avatar_08": return Vector2(0.40, 0.33)
		return Vector2(0.40, 0.33)
	match avatar:
		&"avatar_01": return Vector2(0.94, 0.45)
		&"avatar_02": return Vector2(0.94, 0.36)
		&"avatar_03": return Vector2(0.95, 0.40)
		&"avatar_04": return Vector2(0.95, 0.43)
		&"avatar_05": return Vector2(0.97, 0.40)
		&"avatar_06": return Vector2(0.96, 0.44)
		&"avatar_07": return Vector2(0.97, 0.50)
		&"avatar_08": return Vector2(0.95, 0.38)
	return Vector2(0.94, 0.43)


static func pose_scale(avatar: StringName, pose: StringName) -> float:
	if pose == &"attack" and (avatar == &"avatar_06" or avatar == &"avatar_07"):
		return 1.12
	return 1.0
