## User-visible continuity: same prop/card instances survive selection and reveal.
extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func wait(seconds: float) -> void: await create_timer(seconds).timeout
func run() -> void:
	root.size=Vector2i(1366,768)
	L10n.install()
	var host:=Control.new()
	root.add_child(host)
	var gate:=ToolHandGate.new()
	gate.setup(&"DICE_MAHJONG",{"tiles":[0,13,26]})
	host.add_child(gate)
	await wait(.1)
	var table_style:=gate._table_background.get_theme_stylebox("panel") as StyleBoxFlat
	gate.pick(3)
	await wait(.4)
	check(absf(absf(gate._mahjong.tiles[0].rotation.x)-PI)<.01,"First picked 3D tile stays face down")
	gate.pick(8)
	await wait(.4)
	check(not gate.revealed(),"Two picks cannot expose any result")
	gate.pick(11)
	await wait(.2)
	for tile: Node3D in gate._mahjong.tiles:
		check(absf(absf(tile.rotation.x)-PI)<.01,"Third pick lands face down before simultaneous flip")
	await wait(.9)
	for tile: Node3D in gate._mahjong.tiles:
		check(absf(tile.rotation.x)<.01,"All three existing tiles finish their shared flip")
	check(gate.revealed() and gate.is_inside_tree(),"Result is on the same table")
	gate.queue_free()
	await wait(.05)
	gate=ToolHandGate.new()
	gate.setup(&"DICE_COOKIE",{"message":"행운은 준비된 자에게"})
	host.add_child(gate)
	await wait(.1)
	var platter_id:=gate._platter.get_instance_id()
	gate.pick(15)
	await wait(1.8)
	check(gate._platter.get_instance_id()==platter_id,"Cookie opens in the original platter viewport")
	check(gate._platter._opening!=null and gate._platter._paper!=null,"The selected cookie exposes its own paper")
	check(not gate._platter.cookies[15].visible,"The picked shell is replaced exactly once by its halves")
	check(not gate._platter._plate.visible,"Plate is cleared after a cookie is selected")
	var remaining:=0
	for cookie: Node3D in gate._platter.cookies:
		if cookie.visible: remaining+=1
	check(remaining==0,"Unchosen cookies are cleared before the chosen halves open")
	var paper_point:=gate._platter._camera.unproject_position(gate._platter._paper.global_position)
	check(paper_point.distance_to(Vector2(gate._platter._view.size)*.5)<2,"Selected cookie's paper is centered in its viewport")
	var paper_screen:=gate._platter.global_position+gate._platter._display.position+paper_point/Vector2(gate._platter._view.size)*CookiePlatterPick.EXTENT
	check(paper_screen.distance_to(gate.global_position)<2,"Selected cookie is centered in the presentation area")
	gate.queue_free()
	await wait(.05)
	gate=ToolHandGate.new()
	gate.setup(&"DICE_ICECREAM",{"spaces":3})
	host.add_child(gate)
	await wait(.1)
	gate.pick(4)
	await wait(.8)
	var eating:=gate._icebox.eating
	var original_position:=eating.position
	check(eating.visible and eating.in_place,"Unwrapping exposes the eating prop inside the same icebox scene")
	check(gate._icebox._stock_alpha<.01 and not gate._icebox._foreground.visible,"Icebox and ice are cleared after selection")
	var other_packets:=0
	for i: int in gate._icebox.packets.size():
		if i!=4 and gate._icebox.packets[i].visible: other_packets+=1
	check(other_packets==0,"Unchosen wrappers are cleared before unwrapping")
	var wrapper:=gate._icebox.packets[4]
	var wrapper_rect:=Rect2(wrapper.position,wrapper.size)
	var bar_width:=IceCreamView.BODY_HEIGHT*eating._bar.texture.get_width()/eating._bar.texture.get_height()
	var top:=eating.position+(IceCreamView.CENTER-Vector2(bar_width*.5,IceCreamView.BODY_HEIGHT*.5))*.8
	var bottom:=eating.position+Vector2(IceCreamView.CENTER.x+bar_width*.5,251)*.8
	check(wrapper_rect.has_point(top) and wrapper_rect.has_point(bottom),"Wrapper is larger than the complete ice cream and stick")
	check((gate._icebox.global_position+eating.position+IceCreamView.CENTER*.8).distance_to(gate.global_position)<1,"Unwrapped ice cream stays centered")
	await wait(1.5)
	check(gate._icebox.eating==eating and eating.position==original_position,"Eating keeps the unwrapped prop at its original position")
	check(not eating._bar.visible and eating.settled,"Biting exposes the stick at the same position")
	gate.queue_free()
	await wait(.05)
	var table:=HoldemExchangePanel.new()
	table.setup([0,13,5,20,37])
	host.add_child(table)
	var holdem_style:=table.find_child("ExchangePanel",true,false).get_theme_stylebox("panel") as StyleBoxFlat
	check(holdem_style.bg_color==table_style.bg_color and holdem_style.border_color==table_style.border_color,"Mahjong and hold'em share the same table surface")
	check(table.busy,"No card selection before dealer finishes dealing")
	await table.play_deal()
	var kept: Control=table._items[1].get_node("Face")
	var position:=kept.get_global_rect()
	table.toggle(0)
	table.toggle(3)
	await table.play_exchange([1,13,5,2,37],[0,3])
	check(table._items[1].get_node("Face")==kept,"Dealer does not recreate a kept card")
	check(kept.get_global_rect()==position,"Kept card stays in its table slot during the exchange")
	check(table.cards==[1,13,5,2,37],"Replacement cards and final hand agree")
	for item: Control in table._items:
		check(item.get_node("Face").face_up,"Final five cards are visible together")
	table.queue_free()
	await wait(.05)
	var modal:=ToolPickModal.new()
	modal.setup(&"DICE_HWATU")
	host.add_child(modal)
	var hwatu_style:=modal.find_child("PickPanel",true,false).get_theme_stylebox("panel") as StyleBoxFlat
	check(hwatu_style.bg_color==table_style.bg_color and hwatu_style.border_color==table_style.border_color,"Hwatu shares the same table surface")
	await wait(.2)
	modal.pick(0)
	modal.pick(2)
	var first: Control=modal._items[0]
	var last: Control=modal._items[2]
	await modal.reveal_result({"steps":8,"details":{"cards":[0,8],"label":"광땡"}})
	check(modal._items[0]==first and modal._items[2]==last,"Hwatu turns over the original chosen holders")
	check(first.get_node("Face").get_child(0).face_up,"First chosen Hwatu shows its face")
	check(last.get_node("Face").get_child(0).face_up,"Second chosen Hwatu shows its face")
	check(modal._items[1].get_node("Face").get_child_count()>1,"Unchosen Hwatu keeps its original back")
	modal.queue_free()
	await wait(.05)
	gate=ToolHandGate.new()
	gate.setup(&"DICE_OMIKUJI",{"fortune":&"good","label":"길"})
	host.add_child(gate)
	gate.draw()
	gate.set_process(false)
	gate._process(.5)
	check(gate._box.paper_unfold_progress()==0 and not gate.revealed(),"Rolled paper emerges without revealing its result")
	gate._process(.45)
	check(gate._box.paper_unfold_progress()>0 and gate._box.paper_unfold_progress()<1 and not gate.revealed(),"Paper opens gradually before its result is shown")
	gate._process(.3)
	check(gate._box.paper_unfold_progress()==1 and gate.revealed(),"Result is revealed only after the sheet opens")
	gate.queue_free()
	await wait(.05)
	host.queue_free()
	await wait(.05)
	if failures.is_empty():
		print("SEAMLESS_TOOLS_OK: ",checks," checks")
		quit()
	else:
		for failure: String in failures: push_error(failure)
		quit(1)
