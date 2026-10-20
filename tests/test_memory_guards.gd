# File: res://tests/test_memory_guards.gd
# Class: class_name TestMemoryGuards
# Role: 메모리 보호 장치 검사 - 액션 로그 링 버퍼(최대 100줄)·미니/펼침 모드, 전역 텍스처 캐시 재사용·초고해상도 축소
class_name TestMemoryGuards
extends TestCase


func test_action_log_keeps_only_the_latest_hundred_lines() -> void:
	var panel := ActionLogPanel.new()
	for i: int in 250:
		panel.add_entry("줄 %d" % i)
	check_eq(panel.line_count(), ActionLogPanel.MAX_LOG_LINES, "100줄만 보관한다")
	var kept: Array[String] = panel.lines()
	check_eq(kept[0], "줄 150", "넘치면 가장 오래된 줄부터 버린다")
	check_eq(kept[-1], "줄 249", "가장 최근 줄이 맨 아래")
	panel.add_entry("   ")
	check_eq(panel.line_count(), ActionLogPanel.MAX_LOG_LINES, "빈 줄은 기록하지 않는다")
	panel.clear_entries()
	check_eq(panel.line_count(), 0, "새 게임이면 비운다")
	panel.free()


func test_action_log_mini_shows_recent_lines_and_expands() -> void:
	var panel := ActionLogPanel.new()
	for i: int in 10:
		panel.add_entry("줄 %d" % i)
	check(not panel.expanded, "평소에는 미니 모드")
	check_eq(panel.visible_line_count(), ActionLogPanel.MINI_LINES, "미니 모드는 최근 몇 줄만")
	panel.place(Vector2(12, 466))
	var mini_bottom: float = panel.position.y + panel.size.y
	panel.toggle()
	check(panel.expanded and panel.visible_line_count() == 10, "펼치면 전체 내역")
	check(panel.size.y > ActionLogPanel.MINI_SIZE.y and is_equal_approx(panel.position.y + panel.size.y, mini_bottom), "펼치면 아래 끝은 그대로 두고 위로 커진다")
	panel.toggle()
	check(not panel.expanded and is_equal_approx(panel.position.y, 466.0), "다시 누르면 접힌다")
	panel.free()


func test_texture_cache_reuses_the_same_texture() -> void:
	var path: String = "res://assets/board/traps/TRP_03.png"
	var first: Texture2D = TextureCache.fetch(path)
	var second: Texture2D = TextureCache.fetch(path)
	check(first != null and first == second, "같은 경로는 같은 텍스처를 돌려준다")
	check(TextureCache.fetch("res://assets/no_such_file.png") == null, "없는 파일은 null")


func test_texture_cache_shrinks_huge_sources() -> void:
	var image := Image.create(3000, 1500, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var huge := ImageTexture.create_from_image(image)
	var shrunk: Texture2D = TextureCache._shrink_if_huge(huge)
	check(maxi(shrunk.get_width(), shrunk.get_height()) <= TextureCache.RESIZE_TO, "2048px를 넘는 원본은 1280px 이하로 줄인다 (%dx%d)" % [shrunk.get_width(), shrunk.get_height()])
	check_eq(shrunk.get_width() * 1500, shrunk.get_height() * 3000, "비율은 그대로")
	var small := ImageTexture.create_from_image(Image.create(512, 256, false, Image.FORMAT_RGBA8))
	check(TextureCache._shrink_if_huge(small) == small, "작은 그림은 그대로 쓴다")


func test_texture_cache_drops_least_recently_used_over_budget() -> void:
	TextureCache.clear()
	var half: int = TextureCache.BUDGET_BYTES / 2
	TextureCache._remember("a", half)
	TextureCache._remember("b", half)
	TextureCache._touch("a")  # a를 다시 썼다: 이제 b가 가장 오래 안 쓴 것
	TextureCache._remember("c", half)
	check(TextureCache._sizes.has("a") and TextureCache._sizes.has("c") and not TextureCache._sizes.has("b"), "예산을 넘으면 가장 오래 안 쓴 b부터 놓는다 (%s)" % str(TextureCache._sizes.keys()))
	check(TextureCache.total_bytes() <= TextureCache.BUDGET_BYTES, "추정 합계가 예산 안")
	TextureCache.clear()
	check_eq(TextureCache.total_bytes(), 0, "비우면 0")
