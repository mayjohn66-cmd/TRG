## Actual MainBoard interaction demos. Movie Maker records SFX only via Dummy.
## --write-movie <folder>/direct-tools.avi --fixed-fps 30 -s res://tools/capture_connected_tools.gd -- out=<folder>
extends SceneTree

var board: MainBoard
var folder := ""
var tick := 0
var clips: Array[Dictionary] = []
var failed := false
var include_all := false
var observed_rolls: Array[Dictionary] = []
var audio_requests: Array[Dictionary] = []

func _initialize() -> void:
	Sfx.test_event_observer=func(event: StringName, db: float) -> void:
		audio_requests.append({"frame":tick,"event":str(event),"db":db})
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="): folder=arg.substr(4)
		if arg == "all=true": include_all=true
	run.call_deferred()
func _process(_delta: float) -> bool:
	tick+=1
	return false
func frames(n: int) -> void:
	for i: int in n: await process_frame
func seconds(value: float) -> void: await frames(roundi(value*30.0))

func fixture(id: StringName) -> void:
	if board!=null:
		board.queue_free()
		await frames(3)
	board=(load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	board.instant_roll_for_test=true
	root.add_child(board)
	board.visible=false
	await frames(3)
	GameSession.audio_muted=false
	GameSession.sfx_muted=false
	GameSession.bgm_muted=true
	GameSession.voice_muted=true
	Sfx.apply_settings()
	board._bot.set_enabled(false)
	board.manager.set_process(false)
	board.pacing_enabled=false
	board._close_opening()
	board._on_draft_auto_pressed()
	await frames(3)
	board._reset_presentation()
	board._close_draft_overlay()
	board._close_augment_review()
	board._announcer.cancel()
	board._fx_busy=false
	var roller:=board.manager.current_player_id()
	board.local_player_id=roller
	board.state.tools[roller]=ToolRegistry.create(id)
	board.state.rng.seed=42
	observed_rolls.clear()
	board.manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved": observed_rolls.append(data["result"]))
	board.instant_roll_for_test=false
	board._refresh_all()
	await frames(4)
	board.visible=true

func start_clip(name: String) -> void:
	clips.append({"name":name,"start_frame":tick})
	print("CAPTURE_START ",name," frame=",tick)
func end_clip() -> void:
	clips[-1]["end_frame"]=tick
	clips[-1]["tool_id"]=str(board.state.tools[board.local_player_id].tool_id)
	clips[-1]["resolved_rolls"]=observed_rolls.size()
	var counts: Dictionary = {}
	for request: Dictionary in audio_requests:
		if int(request.frame)>=int(clips[-1].start_frame) and int(request.frame)<=tick:
			counts[request.event]=int(counts.get(request.event,0))+1
	clips[-1]["sfx_counts"]=counts
	var trace:=FileAccess.open(folder.path_join("audio-requests.json"),FileAccess.WRITE)
	trace.store_string(JSON.stringify(audio_requests,"  "))
	if observed_rolls.is_empty():
		failed=true
		push_error("CAPTURE: no resolved roll for "+str(clips[-1].name))
	var file:=FileAccess.open(folder.path_join("clips.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(clips,"  "))
	print("CAPTURE_END ",clips[-1].name," frame=",tick)

func click_at(at: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=at
		event.global_position=at
		root.push_input(event)
		await frames(2)
func click(control: Control) -> void: await click_at(control.get_global_rect().get_center())

func pull_slot_handle() -> void:
	var slot:=board._presenter._slot_3d
	var grip:=slot.lever_grip_position()
	var transform:=slot.get_global_transform_with_canvas()
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=transform*grip
	press.global_position=press.position
	root.push_input(press,true)
	await frames(3)
	for step: int in 8:
		var drag:=InputEventMouseMotion.new()
		drag.position=transform*(grip+Vector2(0,(step+1)*10))
		drag.global_position=drag.position
		drag.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.push_input(drag,true)
		await frames(2)
	press.pressed=false
	press.position=transform*(grip+Vector2(0,80))
	press.global_position=press.position
	root.push_input(press,true)
	await frames(3)

## Find a visible part of a tilted packet instead of clicking through its neighbor.
func click_packet(packet: Control) -> bool:
	for y: float in [.1,.2,.35,.5,.65]:
		for x: float in [.5,.3,.7]:
			var at:=packet.get_global_transform()*(packet.size*Vector2(x,y))
			var motion:=InputEventMouseMotion.new()
			motion.position=at
			motion.global_position=at
			root.push_input(motion)
			await process_frame
			if root.gui_get_hovered_control()==packet:
				await click_at(at)
				return true
	return false

func gate_for() -> ToolHandGate:
	for i: int in 240:
		if board._presenter.hand_gate()!=null: return board._presenter.hand_gate()
		await process_frame
	failed=true
	push_error("CAPTURE: hand gate did not open")
	return null
func wait_result() -> void:
	# ToolPickModal waits for its selection lift before emitting the roll.
	await seconds(0.5)
	var saved := false
	for i: int in 360:
		if not board._presenter.active and not board._fx_busy: break
		if not saved and (board._presenter._t >= 1.4 or (board._presenter.hand_gate()!=null and board._presenter.hand_gate().revealed())):
			saved=true
			await snapshot(str(clips[-1].name)+"-result")
		elif not saved and i>=24 and (board.holdem_exchange_panel()!=null or (board.tool_pick_modal()!=null and board.tool_pick_modal().revealing)):
			saved=true
			await snapshot(str(clips[-1].name)+"-result")
		await process_frame
	await seconds(0.8)

func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))

func food(id: StringName, name: String, index: int) -> void:
	await fixture(id)
	start_clip(name)
	await seconds(0.4)
	await click(board._roll_button)
	var gate:=await gate_for()
	if gate==null: return
	await seconds(1.1)
	await snapshot(name+"-selection")
	if id==&"DICE_COOKIE":
		var at:=gate._platter.screen_position(index)
		var hit:=gate._platter.index_at(at)
		if hit<0:
			failed=true
			push_error("CAPTURE: cookie hit test failed")
		else:
			await click_at(gate._platter.get_global_transform()*at)
	else:
		var packet:=gate._icebox.packets[index]
		var pressed:=await click_packet(packet)
		if not pressed or gate.selected_flavor!=gate._icebox.flavor_at(index):
			failed=true
			push_error("CAPTURE: requested flavor was not selected")
	if gate.picks().size()!=1:
		failed=true
		push_error("CAPTURE: food press did not choose exactly one item")
	await seconds(0.4)
	await snapshot(name+"-pickup")
	await wait_result()
	end_clip()

func run() -> void:
	root.size=Vector2i(1366,768)
	L10n.install()
	L10n.set_language("ko")
	await food(&"DICE_COOKIE","01-fortune-cookie",15)
	await food(&"DICE_ICECREAM","02-icecream-strawberry",1)
	await food(&"DICE_ICECREAM","03-icecream-chocolate",4)
	await food(&"DICE_ICECREAM","04-icecream-mint",0)
	await fixture(&"DICE_OMIKUJI")
	start_clip("05-omikuji")
	await click(board._roll_button)
	var gate:=await gate_for()
	if gate!=null:
		await seconds(.7)
		for i: int in 2:
			await click(gate.find_child("ShakeButton",true,false))
			await seconds(1.1)
		await snapshot("05-omikuji-shake")
		await click(gate.find_child("DrawButton",true,false))
		await seconds(.4)
		await snapshot("05-omikuji-scroll")
		await seconds(.5)
		await snapshot("05-omikuji-unfold")
		await wait_result()
	end_clip()
	await fixture(&"DICE_CAPSULE")
	start_clip("06-capsule-gacha")
	await click(board._roll_button)
	for i: int in 180:
		if board._presenter.capsule_gate_open(): break
		await process_frame
	await seconds(.6)
	await snapshot("06-capsule-lever")
	for i: int in 48:
		var event:=InputEventScreenDrag.new()
		event.relative=Vector2(5.5,1)
		board._presenter._gui_input(event)
		await process_frame
	await wait_result()
	end_clip()
	await fixture(&"DICE_MAHJONG")
	start_clip("07-mahjong")
	await click(board._roll_button)
	gate=await gate_for()
	if gate!=null:
		await seconds(.8)
		for i: int in [3,8,11]:
			await click_at(gate._mahjong.get_global_transform()*gate._mahjong.screen_position(i))
			await seconds(.55)
		if gate.picks().size()!=3:
			failed=true
			push_error("CAPTURE: the three physical Mahjong picks did not register")
		await snapshot("07-mahjong-reveal")
		await wait_result()
	end_clip()
	await fixture(&"HOLDEM")
	start_clip("08-holdem-exchange")
	await click(board._roll_button)
	for i: int in 360:
		if board.holdem_exchange_panel()!=null: break
		await process_frame
	var exchange:=board.holdem_exchange_panel()
	if exchange!=null:
		for _wait: int in 180:
			if not exchange.busy: break
			await process_frame
		await seconds(.7)
		for i: int in [0,3]:
			await click(exchange._items[i])
			await seconds(.4)
		await snapshot("08-holdem-exchange")
		await click(exchange.find_child("ExchangeButton",true,false))
		await wait_result()
	else:
		failed=true
		push_error("CAPTURE: holdem exchange missing")
	end_clip()
	await fixture(&"DICE_HWATU")
	start_clip("09-hwatu")
	await click(board._roll_button)
	await seconds(.8)
	var modal:=board.tool_pick_modal()
	if modal!=null:
		await click(modal.find_child("PickItem0",true,false))
		await seconds(.5)
		await click(modal.find_child("PickItem2",true,false))
		await snapshot("09-hwatu-selected")
		await wait_result()
	else:
		failed=true
		push_error("CAPTURE: hwatu selection missing")
	end_clip()
	await fixture(&"DICE_PIRATE")
	(board.state.tools[board.manager.current_player_id()] as ToolPirateRoulette).arm(2)
	start_clip("10-pirate-roulette")
	for i: int in 3:
		await seconds(.6)
		await click(board._roll_button)
		await wait_result()
	end_clip()
	await fixture(&"DICE_SCRATCH")
	start_clip("11-scratch-ticket")
	await click(board._roll_button)
	for i: int in 180:
		if board._presenter._scratch_gate: break
		await process_frame
	await seconds(.5)
	var ticket:=board._presenter._scratch_view
	for cell: int in 3:
		var rect:=ScratchTicketView.TicketPrint.cell_rect(cell)
		for step: int in 24:
			var at:=rect.get_center()+Vector2(sin(step*1.6)*rect.size.x*.35,cos(step*.8)*rect.size.y*.3)
			var point: Vector2=(at-ScratchTicketView.TicketPrint.SIZE*.5)*ScratchTicketView.VIEW_PER_PRINT+ScratchTicketView.SIZE*.5
			ticket.scratch_at(point,10.0)
			await process_frame
	await wait_result()
	end_clip()
	if include_all: await remaining_tools()
	if board!=null: board.queue_free()
	await frames(3)
	print("CONNECTED_CAPTURE_DONE clips=",clips.size()," failed=",failed)
	quit(1 if failed else 0)

func remaining_tools() -> void:
	for entry: Array in [[&"D6","12-standard-dice"],[&"CHINCHIRO","13-chinchiro"],[&"YUT","14-yut"]]:
		await fixture(entry[0])
		start_clip(entry[1])
		await seconds(.6)
		await click(board._roll_button)
		await wait_result()
		end_clip()
	await fixture(&"LIFE_ROULETTE")
	start_clip("15-life-roulette")
	await seconds(.8)
	var pad:=board._roll_pad
	var wheel_center: Vector2=pad.get_global_transform()*(pad._wheel.position+pad._wheel.size*.5)
	await click_at(wheel_center)
	await wait_result()
	end_clip()
	await fixture(&"SLOT_777")
	start_clip("16-slot-machine")
	await seconds(.5)
	await click(board._roll_button)
	await seconds(.6)
	await pull_slot_handle()
	await seconds(.8)
	for reel: int in 3:
		board._presenter.manual_tap()
		await seconds(.4)
	await wait_result()
	end_clip()
	await fixture(&"REVOLVER")
	start_clip("17-revolver")
	await seconds(3.3)
	await click(board._roll_button)
	await wait_result()
	if board._stop_button.is_visible_in_tree() and not board._stop_button.disabled:
		await seconds(.6)
		await click(board._stop_button)
		await seconds(1)
	end_clip()
	await fixture(&"DICE_DARTS")
	start_clip("18-darts")
	await seconds(.8)
	await click(board._roll_button)
	await wait_result()
	end_clip()
	await fixture(&"DICE_TAROT")
	start_clip("19-tarot")
	await click(board._roll_button)
	await seconds(.9)
	var modal:=board.tool_pick_modal()
	if modal!=null:
		await click(modal.find_child("PickItem2",true,false))
	else:
		failed=true
		push_error("CAPTURE: tarot selection missing")
	await wait_result()
	end_clip()
	await fixture(&"DICE_STOCK")
	start_clip("20-stock-chart")
	await seconds(.6)
	await click(board._roll_button)
	await wait_result()
	end_clip()
	await fixture(&"DICE_YACHT")
	start_clip("21-yacht-dice")
	await seconds(.7)
	await click(board._stage_yacht._start_button)
	await seconds(1.8)
	await click(board._stage_yacht.dice_views[1])
	await click(board._stage_yacht.dice_views[3])
	await seconds(.6)
	await click(board._stage_yacht._reroll_button)
	await seconds(1.8)
	await snapshot("21-yacht-kept-rerolled")
	await click(board._stage_yacht._confirm_button)
	await seconds(2)
	end_clip()
	await fixture(&"DICE_BLACKJACK")
	start_clip("22-blackjack")
	await seconds(.7)
	await click(board._stage_blackjack._start_button)
	await seconds(1.3)
	if board._stage_blackjack.can_act:
		await click(board._stage_blackjack._hit_button)
		await seconds(1.3)
	if board._stage_blackjack.can_act:
		await click(board._stage_blackjack._stand_button)
		await seconds(1.5)
	await snapshot("22-blackjack-result")
	end_clip()
	await fixture(&"DICE_PINBALL")
	start_clip("23-pinball")
	await seconds(.6)
	await click(board._roll_button)
	await seconds(.8)
	await snapshot("23-pinball-ready")
	await click(board._roll_button)
	for i: int in 450:
		if observed_rolls.size()>0 and not board._stage_pinball.active and not board._fx_busy: break
		await process_frame
	await seconds(.8)
	end_clip()
