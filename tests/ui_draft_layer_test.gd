# Role: 증강 선택 창(보드 위 창)이 떠 있을 때 하단 기물 독·프로필의 배지가 창을 뚫고 보이지 않는지 검사.
#       (2026-11 제보: 대기석 [리벤지 +N칸 대기중] 배지가 z_index 5라 z 0인 증강 선택 창 위에 그려졌다)
#       독·프로필 안의 그림은 z_index를 쓰지 않고 자식 순서로만 겹침을 정한다: 효과 z(조상 z 합)가 창보다 높으면 실패.
extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


## 조상까지 더한 그리기 z (z_as_relative가 꺼진 곳에서 멈춘다).
func _effective_z(item: CanvasItem) -> int:
	var total: int = 0
	var node: Node = item
	while node != null and node is CanvasItem:
		total += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative:
			break
		node = node.get_parent()
	return total


func _run() -> void:
	var saved_start: int = GameEnums.draft_start
	GameEnums.draft_start = 1
	GameSession.mode = GameSession.MODE_AI
	var board: MainBoard = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	board._bot.set_enabled(false)
	# 대기석 말들에 리벤지 부스터 (독 칸과 프로필 작은 칸에 배지가 붙는다), 선동 표적 표시도 켠다
	for pawn: PlayerPawn in board.state.pawns:
		pawn.revenge_boost = true
	board._refresh_all()
	var guard: int = 0
	while (board._draft_overlay == null or not board._draft_overlay.visible) and guard < 3600:
		guard += 1
		await process_frame
	_expect(board._draft_overlay != null and board._draft_overlay.visible, "증강 선택 창이 열린다")
	board._refresh_all()
	await process_frame
	var overlay_z: int = _effective_z(board._draft_overlay)
	var badges: int = 0
	var hosts: Array[Node] = [board._pawn_bar]
	for entry: Variant in board._profiles.values():
		if entry is Dictionary and (entry as Dictionary).get("panel") is Node:
			hosts.append((entry as Dictionary)["panel"])
	for host: Node in hosts:
		for node: Node in host.find_children("*", "CanvasItem", true, false):
			var item := node as CanvasItem
			if not item.is_visible_in_tree():
				continue
			if item.name == "RevengeBadge":
				badges += 1
			_expect(_effective_z(item) <= overlay_z, "%s(%s)가 증강 선택 창(z %d) 위에 그려진다 (z %d)" % [item.name, host.name, overlay_z, _effective_z(item)])
	_expect(badges > 0, "리벤지 배지가 실제로 붙어 있다 (검사 대상이 있다)")
	_expect(board._draft_overlay.get_index() > board._pawn_bar.get_index(), "증강 선택 창은 기물 독보다 나중 자식이라 위에 그린다")
	GameEnums.draft_start = saved_start
	board.queue_free()
	await process_frame
	if _failures.is_empty():
		print("UI_DRAFT_LAYER_OK (badges %d)" % badges)
		quit(0)
	else:
		for failure: String in _failures:
			print("UI_DRAFT_LAYER_FAIL: " + failure)
		quit(1)


func _expect(ok: bool, message: String) -> void:
	if not ok and not _failures.has(message):
		_failures.append(message)
