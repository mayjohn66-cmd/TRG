# File: res://tests/test_net_game.gd
# Class: class_name TestNetGame
# Role: 온라인 락스텝 검증 - 같은 시드로 각자 규칙 엔진을 돌리고 방장이 정한 순서로 행동을 적용하면 방장·참가자의 판이 끝까지 똑같은지(2인/4인, 사람+봇), 거부·타임아웃·자리 인계·사칭 차단을 가짜 전송으로 확인한다
class_name TestNetGame
extends TestCase


## 좌석마다 TurnManager + NetGame + (자동 플레이용) BotController 한 벌. 전송은 test_peers로 직접 연결한다.
func _build(seats: Array[int], bot_seats: Array[int], autoplay: bool = true, seed_value: int = 777) -> Dictionary:
	var games: Dictionary = {}
	var controllers: Array[BotController] = []
	var humans: Array[int] = []
	for seat: int in seats:
		if not bot_seats.has(seat):
			humans.append(seat)
	for seat: int in humans:
		var manager := TurnManager.new()
		tree.root.add_child(manager)
		manager.set_process(false)
		defer_free(manager)
		var game := NetGame.new()
		game.name = "NetGame"
		tree.root.add_child(game)
		defer_free(game)
		game.test_peers = games
		game.setup(manager, seat == humans[0], seat, seats, bot_seats, {1: "방장", 2: "친구"}, seed_value)
		games[seat] = game
		var driven: Array[int] = []
		if seat == humans[0]:
			driven.assign(bot_seats)
		if autoplay:
			driven.append(seat)
		var controller := BotController.new()
		controller.manager = manager
		controller.bot_players = driven
		controller.instant = true
		controller.enabled = true
		controller.draft_waits_for_humans = false
		controller.wait_for_human_windows = false
		controller.rng.seed = 1000 + seat
		defer_free(controller)
		controllers.append(controller)
		game.started.connect(func(seed_to_use: int, ids: Array, _bots: Array) -> void:
			var typed: Array[int] = []
			typed.assign(ids)
			manager.start_game(typed, seed_to_use))
	return {"games": games, "controllers": controllers}


func _run(parts: Dictionary, max_steps: int = 40000) -> void:
	var games: Dictionary = parts["games"]
	var controllers: Array[BotController] = parts["controllers"]
	for seat: int in games.keys():
		(games[seat] as NetGame).begin()
	var host: NetGame = games[games.keys()[0]]
	for _step: int in range(max_steps):
		for controller: BotController in controllers:
			controller.tick(0.1)
		for seat: int in games.keys():
			(games[seat] as NetGame)._process(0.1)
		if host.manager.is_game_over:
			# 마지막 항목이 모두에게 닿도록 한 번 더 돌린다
			for seat: int in games.keys():
				(games[seat] as NetGame)._process(0.1)
			return


func _all_same(games: Dictionary) -> bool:
	var seats: Array = games.keys()
	var first: TurnManager = (games[seats[0]] as NetGame).manager
	for seat: int in seats:
		var other: TurnManager = (games[seat] as NetGame).manager
		if other.state_hash() != first.state_hash() or other.is_game_over != first.is_game_over or other.state.winner != first.state.winner:
			return false
	return true


func test_two_humans_play_a_full_game_identically_without_bots() -> void:
	var desyncs: Array[String] = []
	var parts: Dictionary = _build([1, 2] as Array[int], [] as Array[int])
	for seat: int in (parts["games"] as Dictionary).keys():
		((parts["games"] as Dictionary)[seat] as NetGame).desynced.connect(func(detail: String) -> void: desyncs.append(detail))
	_run(parts)
	var host: NetGame = (parts["games"] as Dictionary)[1]
	check(host.manager.is_game_over, "2인(봇 없음) 판이 끝까지 진행된다")
	check_eq(host.manager.player_order, [1, 2], "플레이어는 두 명뿐")
	check(_all_same(parts["games"]), "방장과 참가자의 최종 상태가 똑같다")
	check(desyncs.is_empty(), "중간에 어긋남이 한 번도 없다: %s" % str(desyncs))
	check(host.applied_count > 50, "충분히 많은 행동이 오갔다 (%d)" % host.applied_count)


func test_two_humans_plus_two_bots_stay_in_sync() -> void:
	var desyncs: Array[String] = []
	var parts: Dictionary = _build([1, 2, 3, 4] as Array[int], [3, 4] as Array[int])
	for seat: int in (parts["games"] as Dictionary).keys():
		((parts["games"] as Dictionary)[seat] as NetGame).desynced.connect(func(detail: String) -> void: desyncs.append(detail))
	_run(parts)
	var host: NetGame = (parts["games"] as Dictionary)[1]
	check(host.manager.is_game_over, "사람 2 + 봇 2 판이 끝까지 진행된다")
	check(_all_same(parts["games"]), "최종 상태가 똑같다")
	check(desyncs.is_empty(), "어긋남 없음: %s" % str(desyncs))


func test_several_seeds_all_stay_identical() -> void:
	for seed_value: int in [1, 2, 3, 11, 2024]:
		var parts: Dictionary = _build([1, 2] as Array[int], [] as Array[int], true, seed_value)
		_run(parts)
		check((parts["games"][1] as NetGame).manager.is_game_over and _all_same(parts["games"]), "시드 %d: 끝까지 같은 판" % seed_value)


func test_different_seeds_give_different_games() -> void:
	var first: Dictionary = _build([1, 2] as Array[int], [] as Array[int], true, 5)
	var second: Dictionary = _build([1, 2] as Array[int], [] as Array[int], true, 6)
	_run(first)
	_run(second)
	check((first["games"][1] as NetGame).manager.state_hash() != (second["games"][1] as NetGame).manager.state_hash(), "시드가 다르면 판도 다르다 (락스텝이 시드에 의존)")


func test_guest_cannot_act_for_another_seat() -> void:
	var parts: Dictionary = _build([1, 2] as Array[int], [] as Array[int], false)
	var games: Dictionary = parts["games"]
	for seat: int in games.keys():
		(games[seat] as NetGame).begin()
	var host: NetGame = games[1]
	var guest: NetGame = games[2]
	var rejected: Array = []
	guest.manager.action_rejected.connect(func(player_id: int, action: StringName, reason: StringName) -> void: rejected.append([player_id, action, reason]))
	var before: int = host.applied_count
	# 참가자(2번)가 1번 대신 굴리기를 시도한다
	guest.manager.act(&"proceed", {"player_id": 1})
	check_eq(host.applied_count, before, "사칭한 행동은 방장이 적용하지 않는다")
	check(not rejected.is_empty() and rejected[0][2] == &"not_your_seat", "참가자에게 거부 사유가 돌아온다: %s" % str(rejected))
	check(_all_same(games), "여전히 같은 판")


func test_rejected_action_is_not_broadcast_and_rest_stay_in_sync() -> void:
	var parts: Dictionary = _build([1, 2] as Array[int], [] as Array[int], false)
	var games: Dictionary = parts["games"]
	for seat: int in games.keys():
		(games[seat] as NetGame).begin()
	var host: NetGame = games[1]
	var guest: NetGame = games[2]
	var before: int = host.applied_count
	# 증강 드래프트 단계에서 굴리기: 규칙상 거부된다
	guest.manager.act(&"roll", {"player_id": 2})
	check_eq(host.applied_count, before, "규칙에 맞지 않는 행동은 순서에 올라가지 않는다")
	check_eq((games[2] as NetGame).applied_count, (games[1] as NetGame).applied_count, "참가자도 같은 개수")


func test_timeout_is_applied_once_for_everyone_and_stale_ones_are_ignored() -> void:
	var parts: Dictionary = _build([1, 2] as Array[int], [] as Array[int], false)
	var games: Dictionary = parts["games"]
	for seat: int in games.keys():
		(games[seat] as NetGame).begin()
	var host: NetGame = games[1]
	var guest: NetGame = games[2]
	var serial: int = host.manager.phase_serial
	check_eq(guest.manager.phase_serial, serial, "시작 직후 같은 단계 번호")
	# 두 사람이 같은 단계에서 동시에 타임아웃을 보낸다: 한 번만 적용된다
	host.manager.force_timeout()
	guest.manager.act(TurnManager.ACTION_TIMEOUT, {"serial": serial})
	check(host.manager.phase_serial > serial, "타임아웃으로 단계가 넘어갔다")
	check_eq(guest.manager.phase_serial, host.manager.phase_serial, "참가자도 같은 단계")
	var mid: int = host.manager.phase_serial
	host.manager.act(TurnManager.ACTION_TIMEOUT, {"serial": serial})   # 이미 지난 단계의 타임아웃
	check_eq(host.manager.phase_serial, mid, "지난 단계의 타임아웃은 무시된다")
	check(_all_same(games), "같은 판")


func test_external_timer_expiry_is_decided_by_the_host_only() -> void:
	var parts: Dictionary = _build([1, 2] as Array[int], [] as Array[int], false)
	var games: Dictionary = parts["games"]
	for seat: int in games.keys():
		(games[seat] as NetGame).begin()
	var host: NetGame = games[1]
	var guest: NetGame = games[2]
	var serial: int = host.manager.phase_serial
	var limit: float = host.manager.phase_time_left
	check(limit > GameEnums.PHASE_TIME_DRAFT, "온라인은 제한 시간이 배율만큼 늘어난다 (%.0f초)" % limit)
	# 참가자 쪽 시계가 먼저 0이 되어도 스스로 넘어가지 않는다
	guest.manager.tick(limit + 1.0)
	check_eq(guest.manager.phase_serial, serial, "참가자는 혼자 타임아웃하지 않는다")
	host.manager.tick(limit + 1.0)
	check(host.manager.phase_serial > serial and guest.manager.phase_serial == host.manager.phase_serial, "방장이 정하면 모두 같이 넘어간다")


func test_leaving_player_is_taken_over_by_a_bot() -> void:
	var parts: Dictionary = _build([1, 2, 3] as Array[int], [3] as Array[int], false)
	var games: Dictionary = parts["games"]
	for seat: int in games.keys():
		(games[seat] as NetGame).begin()
	var host: NetGame = games[1]
	var guest: NetGame = games[2]
	var taken: Array[int] = []
	host.seat_taken_over.connect(func(seat: int) -> void: taken.append(seat))
	guest.seat_taken_over.connect(func(seat: int) -> void: taken.append(seat))
	host._on_peer_disconnected(2)
	check_eq(taken, [2, 2], "방장과 남은 참가자 모두에게 인계가 알려진다")
	check(host.is_bot(2) and guest.is_bot(2) and not host.humans.has(2), "2번 자리는 봇이 된다")
	check_eq(host.display_name(2), "컴퓨터 2", "이름도 컴퓨터로")
	host._on_peer_disconnected(2)
	check_eq(taken.size(), 2, "이미 인계된 자리는 다시 처리하지 않는다")


func test_host_waits_for_everyone_then_starts_and_drops_absent_players() -> void:
	var parts: Dictionary = _build([1, 2, 3] as Array[int], [] as Array[int], false)
	var games: Dictionary = parts["games"]
	var host: NetGame = games[1]
	var started: Array = [0]
	host.started.connect(func(_seed: int, _ids: Array, _bots: Array) -> void: started[0] += 1)
	host.begin()
	check_eq(started[0], 0, "참가자가 준비되기 전에는 시작하지 않는다")
	(games[2] as NetGame).begin()
	check_eq(started[0], 0, "한 명이 더 남았다")
	# 3번이 끝내 오지 않으면 시간이 다 된 뒤 봇으로 넘기고 시작한다
	host._process(NetGame.READY_TIMEOUT + 1.0)
	check_eq(started[0], 1, "시간이 지나면 시작한다")
	check(host.bots.has(3) and not host.humans.has(3), "오지 않은 사람은 봇이 된다")
	check((games[2] as NetGame).bots.has(3), "참가자에게도 같은 구성이 전달된다")
	check((games[2] as NetGame).running, "참가자도 시작했다")


func test_silent_peer_is_reported_and_recovers() -> void:
	var parts: Dictionary = _build([1, 2] as Array[int], [] as Array[int], false)
	var games: Dictionary = parts["games"]
	for seat: int in games.keys():
		(games[seat] as NetGame).begin()
	var host: NetGame = games[1]
	var guest: NetGame = games[2]
	var host_events: Array = []
	var guest_events: Array = []
	host.peer_silent.connect(func(seat: int, silent: bool) -> void: host_events.append([seat, silent]))
	guest.peer_silent.connect(func(seat: int, silent: bool) -> void: guest_events.append([seat, silent]))
	host._process(0.1)
	check(host_events.is_empty() and guest_events.is_empty(), "막 시작했을 때는 조용해도 멈춘 것이 아니다")
	# 참가자 화면이 멈춘 것처럼: 오래 소식이 없다
	host._heard[2] = Time.get_ticks_msec() - int((NetGame.SILENT_SECONDS + 1.0) * 1000.0)
	host._process(0.1)
	check_eq(host_events, [[2, true]], "방장은 참가자 화면이 멈춘 것을 안다")
	host._process(0.1)
	check_eq(host_events.size(), 1, "같은 상태를 반복해서 알리지 않는다")
	# 참가자가 돌아와 핑을 보내면(참가자 프레임이 한 번 돌면) 곧 복구된다
	guest._ping_left = 0.0
	guest._process(0.1)
	host._process(0.1)
	check_eq(host_events, [[2, true], [2, false]], "소식이 오면 복구를 알린다")
	# 방장이 멈춘 쪽: 참가자 입장
	guest._heard[1] = Time.get_ticks_msec() - int((NetGame.SILENT_SECONDS + 1.0) * 1000.0)
	guest._process(0.1)
	check_eq(guest_events, [[1, true]], "참가자는 방장 화면이 멈춘 것을 안다")
	# 내 화면이 오래 멈췄다 돌아온 첫 프레임(delta가 큼)에는 판단하지 않는다
	guest_events.clear()
	guest._heard[1] = Time.get_ticks_msec() - int((NetGame.SILENT_SECONDS + 1.0) * 1000.0)
	guest._silent[1] = false
	guest._process(5.0)
	check(guest_events.is_empty(), "큰 delta 프레임에는 상대를 멈췄다고 단정하지 않는다")
