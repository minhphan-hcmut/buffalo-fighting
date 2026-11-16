extends SceneTree
## Two real windows: lobby host/join, pause consent, result/disconnect and return to menu.

var host_side := false
var disconnect_case := false
var role := "client"
var suffix := "720"
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func shot(label: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var path := "res://production/qa/evidence/review-lan-%s-%s-%s.png" % [label, role, suffix]
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) == OK, "screenshot " + label)


func press(parent: Node, text: String) -> void:
	for child in parent.find_children("*", "Button", true, false):
		if child.text == text:
			child.pressed.emit()
			return
	check(false, "missing button " + text)


func run() -> void:
	create_timer(60.0).timeout.connect(func(): push_error("LAN window QA timed out"); quit(1))
	host_side = OS.get_cmdline_user_args().has("--host")
	disconnect_case = OS.get_cmdline_user_args().has("--disconnect")
	role = "host" if host_side else "client"
	var large := OS.get_cmdline_user_args().has("--large")
	suffix = "1080" if large else "720"
	root.theme = load("res://assets/ui/festival_theme.tres")
	SessionState.load_settings("user://review_lan_%s.cfg" % role)
	DisplayServer.window_set_size(Vector2i(1920, 1080) if large else Vector2i(1280, 720))
	Engine.max_fps = 60
	change_scene_to_file("res://scenes/lobby.tscn")
	await scene_changed
	var room: Control = current_scene
	room.port_input.value = 47951
	await shot("lobby")
	if host_side:
		room.host_button.pressed.emit()
	else:
		room.address_edit.text = "127.0.0.1"
		room.join_button.pressed.emit()
	await scene_changed
	var arena := current_scene as MatchController
	check(arena != null and arena.mode == &"LAN", "real lobby transitions to LAN arena")
	while arena.phase != &"PLAYING":
		await physics_frame
	check(arena.local_slot == (1 if host_side else 2), "host/client own the correct buffalo")
	await shot("playing")
	if host_side:
		arena.request_pause_from_menu()
	else:
		while not arena.hud.pause_title.text.begins_with("YÊU CẦU"):
			await process_frame
		check(root.gui_get_focus_owner() == arena.hud.pause_actions.get_child(0), "pause consent focuses Accept")
		await shot("consent")
		press(arena.hud.pause_actions, "CHẤP NHẬN")
	while not arena.paused:
		await physics_frame
	await shot("paused")
	var tick := arena.tick
	await create_timer(0.3).timeout
	check(arena.tick == tick, "LAN consent freezes simulation on both peers")
	if host_side:
		arena.resume_from_menu()
	else:
		while not arena.hud.pause_title.text.begins_with("YÊU CẦU"):
			await process_frame
		press(arena.hud.pause_actions, "CHẤP NHẬN")
	while arena.paused:
		await physics_frame
	check(not arena.hud.pause_overlay.visible, "resume consent hides pause menu")
	if host_side:
		await create_timer(1.0).timeout
		if disconnect_case:
			arena.hud._return_to_menu()
		else:
			arena.opponent.spirit = 0.0
	if not (host_side and disconnect_case):
		while not arena.result_ready:
			await physics_frame
		await shot("disconnect" if disconnect_case else "result")
		check(arena.hud.pause_overlay.visible and arena.hud.pause_actions.find_children("*", "Button", true, false).any(func(button: Button): return button.text == "VỀ MENU"), "LAN end keeps its exit button beside rematch")
		check(root.get_visible_rect().encloses(arena.hud.pause_panel.get_global_rect()), "LAN result panel fits window")
		if disconnect_case:
			check(arena.hud.pause_detail.text.contains("MẤT KẾT NỐI") and not arena.hud.pause_detail.text.contains("ÔNG TRÂU XANH"), "mid-match disconnect has an honest message")
		else:
			check(arena.winner_slot == 1 and arena.end_reason == &"FLEE", "both peers keep the host result")
		if host_side:
			await create_timer(1.5).timeout
			check(arena.hud.pause_overlay.visible and arena.hud.pause_title.text == "KẾT QUẢ TRẬN LAN", "peer returning to menu leaves the result panel visible")
			press(arena.hud.pause_actions, "VỀ MENU")
		else:
			var esc := InputEventKey.new()
			esc.keycode = KEY_ESCAPE
			esc.pressed = true
			root.push_input(esc)
	await scene_changed
	check(current_scene is Control and not root.get_node("NetworkManager").connected and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not paused, "LAN exits to an interactive menu with ENet closed")
	await create_timer(0.5).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://review_lan_%s.cfg" % role))
	print("LAN WINDOW ", role, " FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
