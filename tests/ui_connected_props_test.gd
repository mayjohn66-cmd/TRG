extends SceneTree

var failures: Array[String] = []
var count := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failures.append(message)
func frames(n: int = 4) -> void:
	for i: int in n: await process_frame

func run() -> void:
	L10n.install()
	root.size = Vector2i(1366,768)
	var host := Control.new()
	host.size = Vector2(1366,768)
	root.add_child(host)
	for language: String in ["ko","en","ja"]:
		L10n.set_language(language)
		for id: StringName in [&"DICE_COOKIE",&"DICE_ICECREAM"]:
			var gate := ToolHandGate.new()
			gate.setup(id,{})
			host.add_child(gate)
			gate.position = Vector2(683,384)
			await create_timer(0.3).timeout
			check(root.get_visible_rect().encloses(gate._column.get_global_rect()),"Gate fits viewport "+str(id)+language)
			if id == &"DICE_COOKIE":
				check(gate.item_count()==16,"Sixteen real cookie candidates")
				check(gate._platter.cookies.size()==16,"Existing heaped scene loaded")
				var hits := 0
				for i: int in 16:
					if gate._platter.index_at(gate._platter.screen_position(i))>=0: hits+=1
				check(hits>10,"Camera ray finds cookie candidates")
				gate.pick(15)
				check(gate._platter._chosen==15,"Picked existing model moves")
			else:
				check(gate.item_count()==7,"Seven individually selectable wrappers")
				check(gate._icebox._foreground.z_index>gate._icebox.packets[0].z_index,"Ice occludes packet bottoms")
				gate.pick(0)
				check(gate.selected_flavor=="mint","Chosen wrapper preserves flavor")
				check(gate._icebox.packets[0].z_index>gate._icebox._foreground.z_index,"Picked packet emerges over ice")
			gate.pick(1)
			check(gate.picks().size()==1,"Repeated press cannot choose twice")
			await create_timer(0.9).timeout
			check(not gate.complete(),"Selection does not close the scene before its in-place result")
			await create_timer(3.5).timeout
			check(gate.complete() and gate.revealed(),"Same scene reveals and holds its result")
			gate.queue_free()
			await frames()
	var presenter := RollPresenter.new()
	host.add_child(presenter)
	presenter.interactive=true
	var rng := RandomNumberGenerator.new()
	rng.seed=42
	presenter.play(&"DICE_OMIKUJI",ToolRegistry.create(&"DICE_OMIKUJI").roll(rng).to_dict())
	presenter.set_process(false)
	presenter._process(7.9)
	presenter.hand_gate().shake()
	presenter._process(0.2)
	check(presenter.hand_gate()!=null and presenter.hand_gate().waiting(),"Shaking resets the inactivity deadline")
	presenter._process(8.0)
	check(presenter.hand_gate()!=null and not presenter.hand_gate().waiting(),"Idle auto draw enters the same result scene")
	presenter.hand_gate()._process(4.1)
	presenter._process(.01)
	check(presenter.hand_gate()==null,"Same scene finishes after its draw result")
	presenter.cancel()
	var exchange := HoldemExchangePanel.new()
	exchange.setup([0,13,5,20,37])
	host.add_child(exchange)
	exchange.set_busy(false)
	var touch := InputEventScreenTouch.new()
	touch.pressed=true
	exchange._items[0].gui_input.emit(touch)
	var emulated := InputEventMouseButton.new()
	emulated.button_index=MOUSE_BUTTON_LEFT
	emulated.pressed=true
	emulated.device=InputEvent.DEVICE_ID_EMULATION
	exchange._items[0].gui_input.emit(emulated)
	check(exchange.marked_count()==1,"Touch plus emulated mouse toggles the exchange card only once")
	exchange.queue_free()
	for flavor: String in IceCreamView.FLAVORS:
		var ice := IceCreamView.new()
		host.add_child(ice)
		ice.set_flavor(flavor)
		ice.begin({"spaces":3})
		check(ice._bar.texture==IceCreamView.FLAVORS[flavor],"Eating scene retains "+flavor)
		ice.queue_free()
	await frames()
	host.queue_free()
	await frames()
	if failures.is_empty():
		print("CONNECTED_PROPS_OK: ",count," checks")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
