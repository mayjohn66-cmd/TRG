# File: res://tests/test_avatar_packs.gd
# Class: class_name TestAvatarPacks
# Role: 아바타 애니메이션 분리 다운로더(AvatarPacks)의 순수 로직 - 묶음 주소, 데스크톱·테스트에서는 받지 않음, 분리 대상과 본체 제외 목록이 맞는지
class_name TestAvatarPacks
extends TestCase


func test_pack_url_is_relative_to_the_page_and_busts_cache_per_version() -> void:
	check_eq(AvatarPacks.pack_url("https://trickcal-board.vercel.app/", &"avatar_02", "0.9.0+abc1234"), "https://trickcal-board.vercel.app/avatars/avatar_02.pck?v=0.9.0%2Babc1234", "루트 주소")
	check_eq(AvatarPacks.pack_url("https://mayjohn66-cmd.github.io/TRG/index.html", &"avatar_01", "0.9.0"), "https://mayjohn66-cmd.github.io/TRG/avatars/avatar_01.pck?v=0.9.0", "하위 폴더 + index.html")


func test_desktop_and_tests_have_every_animation_and_never_download() -> void:
	check(not AvatarPacks.downloads_enabled(), "웹이 아니면 따로 받지 않는다")
	for id: StringName in AvatarCatalog.ids():
		check(AvatarPacks.is_ready(id), "%s: 에디터·테스트에서는 애니메이션이 이미 있다" % id)
	AvatarPacks.request(&"avatar_02", true)
	AvatarPacks.request(&"not_an_avatar")
	check(not is_instance_valid(AvatarPacks._node) or AvatarPacks._node._queue.is_empty(), "준비된 아바타·없는 id는 줄을 세우지 않는다")


func test_web_export_excludes_exactly_the_split_animation_files() -> void:
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	for pattern: String in ["content_trickcal/avatars/*/emotion_*.tres", "content_trickcal/avatars/*/frames/*", "content_trickcal/avatars/*/idle/*", "content_trickcal/avatars/*/idle_hq/*", "content_trickcal/avatars/*/idle_lq/*", "content_trickcal/avatars/*/idle_lq.tres", "content_trickcal/avatars/*/idle_hq.tres"]:
		check(presets.contains(pattern), "웹 본체 제외 목록에 %s" % pattern)
	for kept: String in ["portrait.png", "icon.webp", "fullbody.png", "attack.png", "hit.png"]:
		check(not presets.contains("avatars/*/" + kept), "정지 그림 %s는 본체에 남는다" % kept)


func test_every_avatar_has_a_select_voice_kept_in_the_main_pack() -> void:
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	check(not presets.contains("select_voice"), "선택 대사는 본체에 남아 고르는 즉시 나온다")
	for id: StringName in AvatarCatalog.ids():
		var path: String = AvatarCatalog.select_voice_path(id)
		check(path != "", "%s: 선택 대사 파일이 있다" % id)
		check(load(path) is AudioStreamOggVorbis, "%s: 선택 대사를 Ogg로 읽는다" % id)
	check_eq(AvatarCatalog.select_voice_path(&"not_an_avatar"), "", "없는 아바타는 대사가 없다")


func test_uid_is_read_from_an_import_file() -> void:
	var text: String = "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\nuid=\"uid://bbiuerh31fi3h\"\npath=\"res://.godot/imported/happy_0.webp-x.ctex\"\n"
	check_eq(AvatarPacks.uid_from_import_text(text), ResourceUID.text_to_id("uid://bbiuerh31fi3h"), "UID를 읽는다")
	check_eq(AvatarPacks.uid_from_import_text("[remap]\nimporter=\"texture\"\n"), ResourceUID.INVALID_ID, "UID가 없으면 무효")
	check_eq(AvatarPacks.uid_from_import_text(""), ResourceUID.INVALID_ID, "빈 파일")


func test_idle_pack_names_follow_the_quality_setting() -> void:
	check_eq(AvatarPacks.tier_of(&"avatar_02_hq"), "hq", "고화질 묶음 이름")
	check_eq(AvatarPacks.tier_of(&"avatar_02_lq"), "lq", "저화질 묶음 이름")
	check_eq(AvatarPacks.tier_of(&"avatar_02"), "", "감정 묶음은 화질 표시가 없다")
	check_eq(AvatarPacks.avatar_of(&"avatar_08_lq"), &"avatar_08", "묶음 이름에서 아바타 id")
	var saved: bool = GameSession.low_quality
	GameSession.low_quality = false
	check_eq(AvatarPacks.idle_pack_for(&"avatar_03"), &"avatar_03_hq", "기본은 고화질 묶음")
	check(HubKit.idle_frames_path(&"avatar_03").ends_with("/idle_hq.tres"), "고화질이면 idle_hq.tres")
	GameSession.low_quality = true
	check_eq(AvatarPacks.idle_pack_for(&"avatar_03"), &"avatar_03_lq", "저화질이면 640px 묶음")
	check(HubKit.idle_frames_path(&"avatar_03").ends_with("/idle_lq.tres"), "저화질이면 idle_lq.tres")
	GameSession.low_quality = saved
	check_eq(HubKit.idle_frames_path(&"not_an_avatar"), "", "없는 아바타는 빈 글")


func test_both_idle_sets_exist_for_every_avatar_with_matching_framing() -> void:
	for id: StringName in AvatarCatalog.ids():
		var folder: String = AvatarSlot.character_path(id)
		var hq: SpriteFrames = load(folder + "/idle_hq.tres") as SpriteFrames
		var lq: SpriteFrames = load(folder + "/idle_lq.tres") as SpriteFrames
		check(hq != null and lq != null, "%s: 두 화질 모두 있다" % id)
		if hq == null or lq == null:
			continue
		check_eq(lq.get_frame_count(&"idle"), hq.get_frame_count(&"idle"), "%s: 프레임 수가 같다" % id)
		var a: AtlasTexture = hq.get_frame_texture(&"idle", 0) as AtlasTexture
		var b: AtlasTexture = lq.get_frame_texture(&"idle", 0) as AtlasTexture
		check_eq(b.atlas.get_size(), Vector2(640, 640), "%s: 저화질은 640px" % id)
		check_eq(a.atlas.get_size(), Vector2(1024, 1024), "%s: 고화질은 1024px" % id)
		# 같은 구도: 화면에서 같은 크기·위치로 그려지려면 영역 비율이 같아야 한다
		check(absf(b.region.size.y / 640.0 - a.region.size.y / 1024.0) < 0.002, "%s: 두 화질의 구도가 같다" % id)
