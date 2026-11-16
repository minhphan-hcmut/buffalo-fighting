extends SceneTree
## Windowed QA through the actual scenes. Run with -- --large for the 1920x1080 pass.
## Outcomes are staged through the match-end rules so all five rounds can be inspected quickly.

var failures := 0
var suffix := "720"
var shots := 0
var scene_nodes: Array[int] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func wait_view() -> void:
	await create_timer(0.8).timeout


func button(parent: Node, text: String) -> Button:
	for child in parent.find_children("*", "Button", true, false):
		if child.text == text:
			return child as Button
	push_error("Missing button: " + text)
	failures += 1
	return null


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)


func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func shot(label: String, panel: Control = null) -> void:
	await wait_view()
	if panel != null:
		check(root.get_visible_rect().grow(1.0).encloses(panel.get_global_rect()), label + " panel fits viewport: " + str(panel.get_global_rect()))
	await RenderingServer.frame_post_draw
	var path := "res://production/qa/evidence/review-%s-%s.png" % [label, suffix]
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) == OK, "screenshot " + label)
	shots += 1
	var focus := root.gui_get_focus_owner()
	print("SCREEN ", label, " focus=", focus.get_path() if focus != null else "none", " nodes=", root.get_child_count(true), " FPS=", Engine.get_frames_per_second())


func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This harness requires a real window")
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--large"):
		suffix = "1080"
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	else:
		DisplayServer.window_set_size(Vector2i(1280, 720))
	root.theme = load("res://assets/ui/festival_theme.tres")
	SessionState.load_settings("user://review_window_settings.cfg")
	SessionState.auto_pause_enabled = false
	GraphicsQuality.reset("user://review_window_graphics.cfg")
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	GraphicsQuality.set_fps_limit(GraphicsQuality.FPS_LIMITS.find(60))
	change_scene_to_file("res://scenes/main_menu.tscn")
	await scene_changed
	await menus()
	await season()
	await free_matches()
	await training()
	await lobby()
	check(not paused and Engine.time_scale == 1.0, "leaving every flow preserves tree pause and time scale")
	for path in ["user://review_window_settings.cfg", "user://review_window_graphics.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("WINDOW REVIEW: %d screenshots, %d failures; arena nodes=%s" % [shots, failures, str(scene_nodes)])
	quit(0 if failures == 0 else 1)


func menus() -> void:
	var menu: Control = current_scene
	await shot("menu", menu.menu_layout)
	click(menu.menu_layout.get_node("SettingsButton"))
	await wait_view()
	check(menu.menu_settings_layer.visible, "mouse opens settings")
	var settings: SettingsScreen = menu.menu_settings_layer
	await shot("settings", settings.panel)
	settings.tabs[3].pressed.emit()
	await shot("graphics", settings.panel)
	key(KEY_ESCAPE)
	check(not settings.visible and menu.menu_layout.visible, "graphics Esc returns to the main menu")
	menu._show_settings()
	settings.tabs[4].pressed.emit()
	await shot("comfort", settings.panel)
	key(KEY_ESCAPE)
	check(menu.menu_layout.visible, "Esc returns from effects to main menu")
	click(menu.menu_layout.get_node("HowToPlayButton"))
	await wait_view()
	var howto := menu.get_node("HowToPlay") as HowToPlay
	await shot("howto-rules", howto.panel)
	howto.tabs[1].pressed.emit()
	await wait_view()
	for move in MoveDemo.MOVES:
		howto.demo.select_move(move.id)
		await shot("howto-" + String(move.id), howto.panel)
	howto.tabs[2].pressed.emit()
	await shot("howto-controls", howto.panel)
	key(KEY_ESCAPE)
	await wait_view()
	check(menu.menu_layout.visible and menu.get_node_or_null("HowToPlay") == null, "how-to closes and frees demo")
	click(menu.menu_layout.get_node("SoloButton"))
	await shot("solo", menu.solo_page.find_children("*", "PanelContainer", true, false)[0])
	(menu.solo_page.find_child("SoloBack", true, false) as Button).pressed.emit()


func rites(menu: Control) -> void:
	while is_instance_valid(menu.ceremony_layer) and not menu.ceremony_layer.done:
		var rite := menu.ceremony_layer as CeremonyView
		await shot("rite-" + String(rite.variant), rite.get_node("Caption"))
		rite.continue_button.pressed.emit()
		await process_frame


func enter_match() -> MatchController:
	await scene_changed
	var arena := current_scene as MatchController
	arena.set_physics_process(false)
	await wait_view()
	scene_nodes.append(arena.find_children("*", "", true, false).size())
	check(not arena.paused and not paused and Engine.time_scale == 1.0, "new arena has clean pause/time state")
	return arena


func result(arena: MatchController, reason: StringName, win := true) -> void:
	arena.start_playing()
	arena.player.spirit = 100.0 if win else 0.0
	arena.opponent.spirit = 0.0 if win and reason == &"FLEE" else 50.0
	if reason == &"TIME":
		arena.remaining_time = 0.0
	elif reason == &"LOT":
		arena.remaining_time = 0.0
		arena.player.spirit = 80.0
		arena.opponent.spirit = 80.0
		# Pick a deterministic draw winner for this QA path, without changing game data.
		var rng := RandomNumberGenerator.new()
		for seed_value in 20:
			rng.seed = seed_value
			if rng.randi_range(0, 1) == (0 if win else 1):
				arena.match_seed = seed_value
				break
	arena._check_match_end()
	check(arena.finished and arena.end_reason == reason and arena.winner_slot == (1 if win else 2), "end rule " + String(reason))
	arena.outro.time = GameBalance.get_number("result_skip_grace_s")
	key(KEY_SPACE)
	arena.set_physics_process(true)
	await wait_view()
	check(arena.result_ready, "outro skip opens locked result")


func season() -> void:
	var menu: Control = current_scene
	menu._show_solo_chooser()
	(menu.solo_page.find_child("SeasonButton", true, false) as Button).pressed.emit()
	await rites(menu)
	var arena := await enter_match()
	for index in 5:
		check(arena.level_id == SessionState.SOLO_LEVELS[index], "season enters round " + str(index + 1))
		if index == 0:
			await shot("countdown")
			arena._set_paused(true)
			await shot("countdown-pause", arena.hud.pause_panel)
			arena.resume_from_menu()
			await result(arena, &"FLEE", false)
			var lost: Control = root.get_node("SoloSessionOverlay")
			await shot("season-loss", lost.result_panel)
			button(lost.result_actions, "CHƠI LẠI TRẬN NÀY").pressed.emit()
			arena = await enter_match()
			check(arena.level_id == &"L01", "retry after loss returns to the same round")
		await result(arena, [&"FLEE", &"TIME", &"LOT", &"FLEE", &"TIME"][index])
		var overlay: Control = root.get_node("SoloSessionOverlay")
		if index == 4:
			var closing := overlay.get_node("Ceremony") as CeremonyView
			await shot("rite-closing", closing.get_node("Caption"))
			closing.continue_button.pressed.emit()
			await wait_view()
		await shot("season-l0" + str(index + 1), overlay.result_panel)
		if index < 4:
			(overlay.result_actions.get_child(0) as Button).pressed.emit()
			await rites(overlay)
			arena = await enter_match()
		else:
			button(overlay.result_actions, "VỀ MENU").pressed.emit()
			await scene_changed
	check(SessionState.unlocked_level == 1 and SessionState.rites_seen.is_empty(), "leaving completed season resets it")


func free_matches() -> void:
	var menu: Control = current_scene
	menu._show_free_play()
	await shot("freeplay", menu.solo_page.find_children("*", "PanelContainer", true, false)[0])
	(menu.solo_page.find_child("L05", true, false) as Button).pressed.emit()
	var arena := await enter_match()
	await result(arena, &"FLEE")
	var overlay: Control = root.get_node("SoloSessionOverlay")
	await shot("freeplay-result", overlay.result_panel)
	check(overlay.get_node_or_null("Ceremony") == null and SessionState.unlocked_level == 1, "freeplay final has no closing rite or season unlock")
	button(overlay.result_actions, "CHƠI LẠI").pressed.emit()
	arena = await enter_match()
	await result(arena, &"TIME")
	button(overlay.result_actions, "ĐỔI TRẬN").pressed.emit()
	await scene_changed
	menu = current_scene as Control
	check(menu.solo_page != null and menu.solo_page.find_child("L01", true, false) != null, "change freeplay match returns to list")
	(menu.solo_page.find_child("SoloBack", true, false) as Button).pressed.emit()
	(menu.solo_page.find_child("SoloBack", true, false) as Button).pressed.emit()


func training() -> void:
	var menu: Control = current_scene
	menu._show_training()
	await shot("training", menu.solo_page.find_children("*", "PanelContainer", true, false)[0])
	for drill in DataFile.load_json("res://data/training.json").drills:
		(menu.solo_page.find_child(drill.id, true, false) as Button).pressed.emit()
		var arena := await enter_match()
		arena.start_playing()
		await shot("training-" + String(drill.id), arena.hud.training_panel)
		key(KEY_ESCAPE)
		check(arena.paused, "training pauses")
		if drill.id == "dummy":
			await shot("pause", arena.hud.pause_panel)
			button(arena.hud.pause_actions, "CÀI ĐẶT").pressed.emit()
			arena.hud.settings_screen.select_tab(1)
			var slider := arena.hud.settings_screen.find_child("Sensitivity", true, false) as HSlider
			slider.value = 0.7
			check(is_equal_approx(arena.get_node("CameraRig").mouse_sensitivity, SessionState.mouse_sensitivity), "pause sensitivity applies live")
			arena.hud.settings_screen.tabs[3].pressed.emit()
			await shot("pause-graphics")
			key(KEY_ESCAPE)
			check(arena.paused and not arena.hud.showing_settings, "pause graphics Esc returns to pause")
			arena.hud.show_settings()
			key(KEY_ESCAPE)
			check(arena.paused and not arena.hud.showing_settings, "pause settings Esc returns to pause")
		if drill.id != "hook":
			button(arena.hud.pause_actions, "ĐỔI BÀI TẬP").pressed.emit()
		else:
			button(arena.hud.pause_actions, "VỀ MENU").pressed.emit()
		await scene_changed
		menu = current_scene as Control
		check(not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "training exit releases mouse and pause")


func lobby() -> void:
	var menu: Control = current_scene
	button(menu.menu_layout, "LAN").pressed.emit()
	await scene_changed
	var room: Control = current_scene
	await shot("lobby", room.host_button.get_parent().get_parent())
	room.address_edit.text = ""
	room.join_button.pressed.emit()
	check(not room.join_button.disabled and room.status_label.text.contains("Hãy nhập"), "empty address stays usable with error")
	room.host_button.pressed.emit()
	check(room.host_button.disabled and root.get_node("NetworkManager").is_host, "host opens room")
	await shot("lobby-host")
	key(KEY_ESCAPE)
	await scene_changed
	check(not root.get_node("NetworkManager").connected, "Esc leaves host lobby and closes ENet")
