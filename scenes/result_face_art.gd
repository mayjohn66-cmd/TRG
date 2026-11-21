## Result-only head cutouts; lobby/profile source portraits keep their original presentation.
class_name ResultFaceArt
extends RefCounted

const DIRECTORY := "res://assets/fx/result_faces/v1"
static func path_for(avatar: StringName) -> String:
	return DIRECTORY.path_join(String(AvatarCatalog.sanitize(avatar)) + ".png")

static func texture(avatar: StringName) -> Texture2D:
	var path := path_for(avatar)
	if ResourceLoader.exists(path):return TextureCache.fetch(path)
	return TextureCache.fetch(AvatarSlot.character_path(AvatarCatalog.sanitize(avatar)) + "/portrait.png")
