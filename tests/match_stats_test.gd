extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)


func arena() -> MatchController:
	var match_node := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(match_node)
	current_scene = match_node
	match_node.set_physics_process(false)
	match_node.get_node("CameraRig").set_process(false)
	return match_node


func settle() -> void:
	for frame in 10:
		await process_frame


func feed(match_node: MatchController, slot: int) -> void:
	var other := 3 - slot
	for entry in [
		[&"HORN_HIT", slot, other], [&"FLANK_HIT", slot, other],
		[&"DASH_HIT", slot, other], [&"BACK_HIT", slot, other],
		[&"COUNTER_HIT", slot, other], [&"PARRY_SUCCESS", slot, other],
		[&"CLASH_START", 1, 2], [&"CLASH_LOSS", slot, other],
		[&"CLASH_START", 1, 2], [&"CLASH_TIME", 1, 2],
		[&"HORN_HIT", other, slot], [&"FLANK_HIT", other, slot],
		[&"DASH_HIT", other, slot], [&"PARRY_SUCCESS", other, slot],
		[&"COUNTER_HIT", other, slot], [&"GUARD_HIT", slot, other]
	]:
		match_node.combat_event.emit(entry[0], entry[1], entry[2], 0.0)


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.theme = load("res://assets/ui/festival_theme.tres")
	SessionState.return_to_menu()
	SessionState.auto_pause_enabled = false
	SessionState.hud_text_large = false
	var match_node := arena()
	await settle()
	var expected := {"hits": 2, "sides": 2, "parries": 1, "counters": 1, "dashes": 1, "locks": 2, "wins": 1, "received": 2}
	feed(match_node, 1)
	check(match_node.hud.stats.counts == expected, "all local counters count primary hits once and side/counter annotations separately")
	var overlay := Control.new()
	overlay.set_script(load("res://scripts/ui/main_menu.gd"))
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)
	overlay.set_process(false)
	match_node._finish(1, &"TIME")
	overlay._show_result("stats-solo")
	overlay.show()
	await process_frame
	await process_frame
	var block := overlay.find_child("MatchStats", true, false) as GridContainer
	check(block != null and block.columns == 2 and block.get_child_count() == 7, "Solo result contains compact two-column stats block")
	check(block.get_child(0).text == "Trúng đòn: 2" and block.get_child(5).text == "Thắng khóa sừng: 1 / 2" and block.get_child(6).text == "Bị trúng đòn: 2", "result displays collected hit/lock/opponent counts")
	check(root.get_visible_rect().encloses(overlay.result_panel.get_global_rect()), "Solo result and existing buttons fit 1280x720")
	check(overlay.result_actions.get_child(0).text.begins_with("TRẬN TIẾP THEO"), "stats preserve next-round button focus order")
	SessionState.hud_text_large = true
	for card_index in 5:
		SessionState.culture_cards_seen.clear()
		for previous in card_index:
			SessionState.culture_cards_seen.append(StringName(DataFile.load_json("res://data/culture_cards.json").cards[previous].id))
		overlay._show_result("large-card-%d" % card_index)
		await create_timer(0.5).timeout
		check(root.get_visible_rect().encloses(overlay.result_panel.get_global_rect()), "large Solo result fits with culture card %d: %s" % [card_index, overlay.result_panel.get_global_rect()])
		var card: Control = overlay.find_child("CultureCard", true, false)
		block = overlay.find_child("MatchStats", true, false)
		check(block.get_global_rect().end.y <= card.get_global_rect().position.y, "large stats clear culture card %d" % card_index)
		check(card.get_global_rect().end.y <= overlay.result_actions.get_global_rect().position.y, "large culture card clears existing buttons %d" % card_index)
	SessionState.hud_text_large = false
	# Exercise the existing replay path, not a second manually reset collector.
	var replay: Button = overlay.result_actions.get_child(1)
	replay.pressed.emit()
	await scene_changed
	match_node = current_scene as MatchController
	match_node.set_physics_process(false)
	await settle()
	check(match_node.hud.stats.counts.values().all(func(value: int): return value == 0), "Chơi lại creates fresh counters")
	SessionState.free_play = true
	feed(match_node, 1)
	match_node._finish(1, &"TIME")
	overlay._show_result("stats-free")
	check(overlay.find_child("MatchStats", true, false).get_child(0).text == "Trúng đòn: 2", "free-play result uses its own match stats")
	check(overlay.result_actions.get_child(0).text == "CHƠI LẠI", "free-play button order stays unchanged")
	SessionState.hud_text_large = true
	for winner in [1, 2]:
		for reason: StringName in [&"FLEE", &"TIME", &"LOT"]:
			SessionState.last_winner = winner
			SessionState.last_reason = reason
			SessionState.culture_cards_seen.clear()
			overlay._show_result("free-large-%d-%s" % [winner, reason])
			await create_timer(0.5).timeout
			check(root.get_visible_rect().encloses(overlay.result_panel.get_global_rect()), "large free-play result fits win/loss %d %s" % [winner, reason])
	SessionState.hud_text_large = false
	# The LAN client already re-emits reliable COMBAT payloads on this same signal.
	match_node.mode = &"LAN"
	match_node.local_slot = 2
	match_node.hud.stats = MatchStats.new(2)
	match_node.combat_event.connect(match_node.hud.stats.on_combat_event)
	feed(match_node, 2)
	check(match_node.hud.stats.counts == expected, "LAN slot 2 has the same local perspective and lock wins")
	match_node.hud._show_lan_result()
	check(match_node.hud.stats_panel.get_child(0).text == "Trúng đòn: 2", "LAN result panel displays local stats")
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses(match_node.hud.pause_panel.get_global_rect()), "LAN result stats and menu button fit 1280x720")
	match_node.free()
	overlay.free()
	SessionState.begin_training(&"dummy")
	match_node = arena()
	await settle()
	check(match_node.hud.stats == null and match_node.hud.find_child("MatchStats", true, false) == null, "Sân tập keeps its own counters with no match-stats block")
	match_node.free()
	SessionState.return_to_menu()
	await process_frame
	print("MATCH STATS: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)
