extends SceneTree
## Regression checks for the whole-game review: modal navigation, damaged settings and LAN exits.

const SETTINGS := "user://review_regressions_settings.cfg"
const GRAPHICS := "user://review_regressions_graphics.cfg"
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func cancel(joypad := false) -> void:
	var event: InputEvent
	if joypad:
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_B
		button.pressed = true
		event = button
	else:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.pressed = true
		event = key
	root.push_input(event)
	event.pressed = false
	root.push_input(event)


func settle() -> void:
	for frame in 5:
		await process_frame


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.theme = load("res://assets/ui/festival_theme.tres")
	if OS.get_cmdline_user_args().has("--settings-reader"):
		check_saved_settings()
		quit(0 if failures == 0 else 1)
		return
	SessionState.load_settings(SETTINGS)
	SessionState.auto_pause_enabled = false
	await check_navigation()
	check_graphics_file()
	check_settings_restart()
	await check_pause_input()
	await check_training_banner()
	await check_lan_lifetime_and_result()
	SessionState.return_to_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GRAPHICS))
	GraphicsQuality.reset()
	print("REVIEW REGRESSIONS FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func check_navigation() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await settle()
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	root.push_input(accept)
	accept.pressed = false
	root.push_input(accept)
	await settle()
	check(menu.solo_page != null, "gamepad A activates the focused Solo button")
	if menu.solo_page != null:
		cancel(true)
	menu._show_settings()
	var actions: Container = menu.menu_settings_actions
	var opener := actions.find_child("GraphicsButton", true, false) as Button
	opener.pressed.emit()
	await settle()
	var page: Control = actions.get_node("GraphicsPage")
	check(opener.focus_mode == Control.FOCUS_NONE, "graphics modal excludes covered settings from focus")
	var focused := root.gui_get_focus_owner()
	for step in 15:
		focused = focused.find_next_valid_focus()
		check(page.is_ancestor_of(focused), "Tab stays inside graphics modal (%d)" % step)
	cancel()
	await settle()
	check(menu.menu_settings_layer.visible and actions.get_node_or_null("GraphicsPage") == null, "Esc closes graphics before main settings")
	check(root.gui_get_focus_owner() == opener, "closing graphics restores opener focus")
	menu.free()
	await settle()
	menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	menu._show_solo_chooser()
	cancel(true)
	await settle()
	check(menu.solo_page == null and menu.menu_layout.visible, "gamepad B backs out of Solo chooser")
	menu._show_how_to_play()
	cancel(true)
	await settle()
	check(menu.get_node_or_null("HowToPlay") == null and menu.menu_layout.visible, "gamepad B closes how-to-play")
	menu.free()
	await settle()
	var lobby: Control = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	current_scene = lobby
	await settle()
	check(root.gui_get_focus_owner() == lobby.host_button, "LAN lobby focuses Create room on entry")
	cancel()
	await settle()
	check(current_scene != lobby, "Esc leaves LAN lobby for main menu")
	if current_scene != null:
		current_scene.free()
	current_scene = null
	await settle()


func check_graphics_file() -> void:
	for invalid in ["invalid", null, true, 0.5, -1, 999, [], {}]:
		var config := ConfigFile.new()
		for entry in GraphicsQuality.DETAILS:
			config.set_value("graphics", entry[0], invalid)
		config.set_value("graphics", "show_fps", "false")
		config.set_value("graphics", "fps_limit", invalid)
		config.save(GRAPHICS)
		GraphicsQuality.reset(GRAPHICS)
		check(GraphicsQuality.preset() == GraphicsQuality.auto_preset(), "invalid graphics choices fall back to GPU defaults: %s" % str(invalid))
		check(not GraphicsQuality.show_fps() and GraphicsQuality.fps_limit() == 0, "invalid FPS values use safe defaults without coercion: %s" % str(invalid))
	GraphicsQuality.reset()


func check_settings_restart() -> void:
	SessionState.load_settings(SETTINGS)
	SessionState.camera_shake_enabled = false
	SessionState.camera_punch_enabled = false
	SessionState.hitstop_enabled = false
	SessionState.auto_pause_enabled = false
	SessionState.training_unlimited_stamina = true
	SessionState.impact_flash = 2
	SessionState.camera_view = 2
	SessionState.camera_side = 1
	SessionState.fullscreen_enabled = true
	SessionState.mouse_sensitivity = GameBalance.get_number("ui_settings_sensitivity_max")
	for bus in [&"Master", &"Music", &"SFX"]:
		AudioServer.set_bus_volume_linear(FestivalAudio.ensure_bus(bus), 0.4)
	check(SessionState.save_settings() == OK, "save all non-default settings before restarting")
	GraphicsQuality.reset(GRAPHICS)
	GraphicsQuality.set_preset(GraphicsQuality.LOW)
	GraphicsQuality.set_show_fps(true)
	GraphicsQuality.set_fps_limit(GraphicsQuality.FPS_LIMITS.find(90))
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/review_regressions_test.gd", "--", "--settings-reader"], output, true)
	print("SETTINGS RESTART CHILD: ", output)
	check(code == 0, "all settings survive a separate Godot process")
	GraphicsQuality.reset()
	SessionState.hitstop_enabled = true


func check_saved_settings() -> void:
	SessionState.load_settings(SETTINGS)
	check(not SessionState.camera_shake_enabled and not SessionState.camera_punch_enabled and not SessionState.hitstop_enabled and not SessionState.auto_pause_enabled, "comfort toggles survive process restart")
	check(SessionState.training_unlimited_stamina and SessionState.impact_flash == 2 and SessionState.camera_view == 2 and SessionState.camera_side == 1, "training, flash and camera choices survive process restart")
	check(SessionState.fullscreen_enabled, "fullscreen survives process restart")
	check(is_equal_approx(SessionState.mouse_sensitivity, GameBalance.get_number("ui_settings_sensitivity_max")), "sensitivity survives process restart")
	for bus in [&"Master", &"Music", &"SFX"]:
		check(is_equal_approx(AudioServer.get_bus_volume_linear(FestivalAudio.ensure_bus(bus)), 0.4), "volume survives process restart: " + String(bus))
	GraphicsQuality.reset(GRAPHICS)
	check(GraphicsQuality.preset() == GraphicsQuality.LOW and GraphicsQuality.show_fps() and GraphicsQuality.fps_limit() == GraphicsQuality.FPS_LIMITS.find(90), "all graphics choices survive process restart")


func check_pause_input() -> void:
	SessionState.return_to_menu()
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	await settle()
	arena.start_playing()
	arena._set_paused(true)
	Input.action_press("horn")
	Input.action_release("horn")
	(arena.hud.pause_actions.get_child(0) as Button).pressed.emit()
	var frame := arena._read_player_input()
	check(not frame.horn_pressed, "clicking Continue never carries a horn attack into gameplay")
	arena._set_paused(true)
	Input.action_press("guard")
	(arena.hud.pause_actions.get_child(0) as Button).pressed.emit()
	frame = arena._read_player_input()
	check(not frame.guard_held and not frame.guard_pressed, "held mouse buttons must be released after resuming")
	Input.action_release("guard")
	arena._read_player_input()
	await process_frame
	Input.action_press("horn")
	frame = arena._read_player_input()
	check(frame.horn_pressed, "a fresh gameplay click still attacks after resuming")
	Input.action_release("horn")
	arena.clash.enter(0.0)
	arena.hitstop_ticks = 3
	arena._set_paused(true)
	var tick := arena.tick
	arena._physics_process(1.0 / 60.0)
	check(arena.tick == tick and arena.hitstop_ticks == 3 and arena.active_clash.time == 0.0, "pause freezes hitstop, clash and simulation together")
	arena.resume_from_menu()
	arena._physics_process(1.0 / 60.0)
	check(arena.tick == tick + 1 and arena.hitstop_ticks == 2, "resume continues the remaining hitstop")
	arena.free()
	await settle()


func check_training_banner() -> void:
	SessionState.begin_training(&"dummy")
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	await settle()
	for phase: StringName in [&"COUNTDOWN", &"PLAYING"]:
		arena.phase = phase
		arena.hud._process(0.0)
		var banner: Rect2 = arena.hud.center_label.get_global_rect()
		var panel: Rect2 = arena.hud.training_panel.get_global_rect()
		check(not banner.intersects(panel), "training %s banner stays clear of drill panel" % phase)
	arena.free()
	SessionState.return_to_menu()
	await settle()


func check_lan_lifetime_and_result() -> void:
	var manager := root.get_node("NetworkManager")
	var signals := [&"input_received", &"snapshot_received", &"event_received", &"connection_lost", &"pause_request_received", &"pause_state_changed"]
	var counts: Array[int] = []
	for signal_name in signals:
		counts.append(manager.get_signal_connection_list(signal_name).size())
	for replay in 3:
		SessionState.mode = &"LAN"
		SessionState.level_id = &"LAN01"
		var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
		root.add_child(arena)
		arena.set_physics_process(false)
		await settle()
		if replay == 0:
			arena.phase = &"PLAYING"
			arena.hud.show_pause()
			check(not arena.hud.pause_actions.get_children().any(func(child: Node): return child is Button and child.text == "CHƠI LẠI"), "LAN pause never offers a local-only restart that disconnects the peer")
			arena.hud.hide_pause()
			cancel(true)
			check(arena.hud.pause_overlay.visible, "gamepad B opens LAN pause request menu")
			arena._finish(1, &"TIME")
			arena.outro.running = false
			await settle()
			var buttons: Array[Node] = arena.hud.pause_actions.find_children("*", "Button", true, false)
			check(buttons.any(func(button: Button): return button.text == "VỀ MENU"), "finished LAN match offers an exit to menu")
			arena.hud.show_result(0, &"CONNECTION_LOST")
			check(not arena.hud.result_label.text.contains("ÔNG TRÂU XANH"), "disconnect never declares the blue buffalo a winner")
		arena.free()
		await settle()
		for index in signals.size():
			check(manager.get_signal_connection_list(signals[index]).size() == counts[index], "LAN teardown releases %s after replay %d" % [signals[index], replay])
