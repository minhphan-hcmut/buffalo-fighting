extends SceneTree
## UI review fixes (2026-11-22): loss wording, training pause text, how-to tab focus,
## Vietnamese LAN lobby on the festival backdrop.

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	var theme: Theme = load("res://assets/ui/festival_theme.tres")
	root.theme = theme
	# An unselected tab with focus or hover must not look like the selected tab.
	var active := theme.get_stylebox("normal", &"PrimaryTab") as StyleBoxFlat
	for state in ["focus", "hover"]:
		var quiet := theme.get_stylebox(state, &"QuietTab") as StyleBoxFlat
		check(quiet != active and quiet.border_width_bottom < active.border_width_bottom, "QuietTab %s underline is thinner than the selected tab" % state)

	await result_and_pause()
	await lobby()
	await howto_controls_fit()
	print("UI review fixes: %d failures" % failures)
	quit(0 if failures == 0 else 1)


func result_and_pause() -> void:
	SessionState.return_to_menu()
	SessionState.begin_solo()
	SessionState.level_id = &"L01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	arena.hud.set_process(false)
	await process_frame
	arena.hud.show_pause()
	check(arena.hud.pause_detail.text == "Trận solo đã dừng.", "Solo pause says the match stopped")
	arena.training = {"profile": "DRILL_HORN"}
	arena.hud.show_pause()
	check(arena.hud.pause_detail.text == "Buổi tập đã dừng.", "training pause says the drill stopped, not the solo match")
	arena.training = {}

	arena._finish(2, &"FLEE")
	SessionState.last_winner = 2
	SessionState.last_reason = &"FLEE"
	var overlay := Control.new()
	overlay.set_script(load("res://scripts/ui/main_menu.gd"))
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)
	overlay.set_process(false)
	overlay.show()
	overlay._show_result("loss")
	var loss: String = overlay.result_detail.text
	check(loss.contains("Ông trâu số 09") and loss.contains("trâu của bạn lui sới"), "loss names the winning rival and that the player's buffalo fled: '%s'" % loss)
	check(not loss.contains("đối phương lui sới"), "loss no longer says the opponent fled")
	SessionState.last_winner = 1
	overlay._show_result("win")
	var win: String = overlay.result_detail.text
	check(win.begins_with("Ông trâu số 06") and win.contains("trâu số 09 lui sới"), "win names the fleeing rival: '%s'" % win)
	overlay.free()
	arena.free()
	await process_frame


func lobby() -> void:
	var room: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(room)
	await process_frame
	check(room.get_node_or_null("Backdrop") is SubViewportContainer, "lobby shows the festival backdrop")
	var words := PackedStringArray()
	for node in room.find_children("*", "Control", true, false):
		if node is Button or node is Label:
			words.append(node.text)
	var all := " ".join(words)
	check(not all.contains("Join") and not all.contains("Host"), "lobby text is Vietnamese: '%s'" % all)
	check(room.join_button.text == "VÀO PHÒNG" and room.port_input.prefix.strip_edges() == "Cổng", "join button and port prefix are Vietnamese")
	var address: String = root.get_node("NetworkManager").local_ipv4()
	check(address.is_empty() or address.split(".").size() == 4, "local_ipv4 returns an IPv4 or empty")
	room.free()
	await process_frame


func howto_controls_fit() -> void:
	# At 1280x720 the Controls page used to run under "QUAY LẠI" (found 2026-11-22).
	root.size = Vector2i(1280, 720)
	var howto := HowToPlay.new()
	root.add_child(howto)
	howto.select_tab(2)
	for frame in 3:
		await process_frame
	var back := howto.find_child("Back", true, false) as Control
	var clash := howto.find_child("ClashControls", true, false) as Control
	check(not back.get_global_rect().intersects(clash.get_global_rect()), "how-to Controls page ends above QUAY LẠI: back %s, clash %s" % [back.get_global_rect(), clash.get_global_rect()])
	howto.free()
	await process_frame
