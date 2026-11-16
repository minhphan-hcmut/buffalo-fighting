extends SceneTree

const SETTINGS := "user://rumble_hud_screenshot_test.cfg"
var checks := 0
var failures := 0
var vibrations: Array = []
var stops: Array = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)


func settle() -> void:
	for frame in 4:
		await process_frame


func arena() -> MatchController:
	var node := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(node)
	current_scene = node
	node.set_physics_process(false)
	node.get_node("CameraRig").set_process(false)
	return node


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.theme = load("res://assets/ui/festival_theme.tres")
	var original_path := SessionState.settings_path
	settings()
	SessionState.return_to_menu()
	SessionState.auto_pause_enabled = false
	SessionState.hud_text_large = false
	var menu_pad := InputEventJoypadButton.new()
	menu_pad.pressed = true
	menu_pad.device = 5
	root.get_node("JoyRumble")._input(menu_pad)
	var node := arena()
	check(node.rumble.joy_device == 5, "joypad last used in menu survives entering match")
	var keyboard := InputEventKey.new()
	keyboard.pressed = true
	keyboard.keycode = KEY_W
	node.rumble._input(keyboard)
	await settle()
	rumble(node)
	await hud_scale(node)
	node.rumble.on_combat_event(&"HORN_HIT", 1, 2, 0.0)
	var stop_count := stops.size()
	node.free()
	check(stops.size() == stop_count + 1 and root.get_node("JoyRumble").controller == null, "leaving match stops vibration and detaches gameplay")
	SessionState.begin_training(&"hook")
	node = arena()
	await settle()
	check(node.hud.training_panel.get_global_rect().end.y < node.hud.clash_panel.position.y, "large training panel clears the clash/countdown area")
	check_panels(node, "training")
	node.hud._training_success("NHẢ ĐÚNG LÚC!")
	await settle()
	check(node.hud.training_panel.get_global_rect().end.y < node.hud.clash_panel.position.y, "large training popup also clears clash")
	node.free()
	await screenshots()
	SessionState.return_to_menu()
	SessionState.load_settings(original_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	await settle()
	print("RUMBLE HUD SCREENSHOT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)


func settings() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	SessionState.load_settings(SETTINGS)
	check(SessionState.rumble_enabled and not SessionState.hud_text_large, "missing settings default to rumble on / text normal")
	for enabled: bool in [false, true]:
		SessionState.rumble_enabled = enabled
		SessionState.hud_text_large = enabled
		check(SessionState.save_settings() == OK, "new settings save")
		SessionState.rumble_enabled = not enabled
		SessionState.hud_text_large = not enabled
		SessionState.load_settings(SETTINGS)
		check(SessionState.rumble_enabled == enabled and SessionState.hud_text_large == enabled, "rumble and HUD choice round-trip")
	for invalid in [0, 1, 1.0, "true", null, [], {}]:
		var config := ConfigFile.new()
		config.set_value("settings", "rumble", invalid)
		config.set_value("settings", "hud_text_large", invalid)
		config.save(SETTINGS)
		SessionState.load_settings(SETTINGS)
		check(SessionState.rumble_enabled and not SessionState.hud_text_large, "invalid new settings use defaults: %s" % str(invalid))


func rumble(node: MatchController) -> void:
	var feedback := node.rumble
	feedback.vibrate = func(device: int, weak: float, strong: float, duration: float): vibrations.append([device, weak, strong, duration])
	feedback.stop_vibration = func(device: int): stops.append(device)
	feedback.on_combat_event(&"HORN_HIT", 1, 2, 0.0)
	check(vibrations.is_empty(), "keyboard-only player never calls vibration")
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	pad.device = 3
	feedback._input(pad)
	for entry in [[&"HORN_HIT", 1, 2, "hit"], [&"HORN_HIT", 2, 1, "hit"], [&"DASH_HIT", 1, 2, "heavy"], [&"COUNTER_HIT", 1, 2, "heavy"], [&"PARRY_SUCCESS", 1, 2, "parry"], [&"CLASH_START", 1, 2, "lock_start"], [&"CLASH_LOSS", 2, 1, "lock_end"], [&"CLASH_TIME", 1, 2, "lock_end"]]:
		node.combat_event.emit(entry[0], entry[1], entry[2], 0.0)
		check(vibrations.back() == [3, GameBalance.get_number("rumble_%s_weak" % entry[3]), GameBalance.get_number("rumble_%s_strong" % entry[3]), GameBalance.get_number("rumble_%s_s" % entry[3])], "local %s uses the data preset %s" % [entry[0], entry[3]])
	check(GameBalance.get_number("rumble_heavy_strong") > GameBalance.get_number("rumble_hit_strong"), "heavy hits have stronger vibration")
	var before := vibrations.size()
	feedback.on_combat_event(&"PARRY_SUCCESS", 2, 1, 0.0)
	feedback.on_combat_event(&"HORN_START", 2, 2, 0.0)
	feedback.on_combat_event(&"HORN_HIT", 2, 2, 0.0)
	check(vibrations.size() == before, "remote parry/AI-only events do not vibrate")
	SessionState.rumble_enabled = false
	feedback.on_combat_event(&"DASH_HIT", 1, 2, 0.0)
	feedback._process(0.0)
	check(vibrations.size() == before and stops.back() == 3, "off suppresses vibration and stops an active pulse")
	SessionState.rumble_enabled = true
	feedback.on_combat_event(&"HORN_HIT", 1, 2, 0.0)
	node.request_pause_from_menu()
	check(feedback.active_device == -1 and stops.back() == 3, "pause stops vibration immediately")
	before = vibrations.size()
	feedback.on_combat_event(&"HORN_HIT", 1, 2, 0.0)
	check(vibrations.size() == before, "no new vibration while paused")
	node.resume_from_menu()
	node.local_slot = 2
	feedback.on_combat_event(&"PARRY_SUCCESS", 2, 1, 0.0)
	check(vibrations.size() == before + 1, "LAN local slot 2 receives its own feedback")
	node.local_slot = 1
	var keyboard := InputEventKey.new()
	keyboard.pressed = true
	keyboard.keycode = KEY_W
	feedback._input(keyboard)
	before = vibrations.size()
	feedback.on_combat_event(&"HORN_HIT", 1, 2, 0.0)
	check(vibrations.size() == before and feedback.joy_device == -1, "switching to keyboard stops joypad feedback")
	feedback._input(pad)
	feedback.on_combat_event(&"HORN_HIT", 1, 2, 0.0)
	node.match_ended.emit(1, &"TIME")
	check(feedback.active_device == -1, "result stops vibration")


func check_panels(node: MatchController, phase: String) -> void:
	var hud: CanvasLayer = node.hud
	for panel: Control in [hud.top_bar, hud.timer_label, hud.center_label, hud.clash_panel, hud.tutorial_label, hud.announcer_label]:
		check(root.get_visible_rect().encloses(panel.get_global_rect()), "large %s HUD stays inside 1280x720: %s" % [phase, panel.get_class()])
	if hud.training_panel != null:
		check(root.get_visible_rect().encloses(hud.training_panel.get_global_rect()), "large training panel fits viewport")
	for child: Control in hud.clash_panel.get_children():
		if child.visible:
			check(hud.clash_panel.get_global_rect().encloses(child.get_global_rect()), "large clash text/bar stays in its panel")
	check(hud.clash_title.get_rect().end.y <= hud.clash_bar.position.y and hud.clash_time_label.get_rect().end.y <= hud.clash_keys_label.position.y, "large clash rows do not overlap: title %s bar %s time %s keys %s" % [hud.clash_title.get_rect(), hud.clash_bar.get_rect(), hud.clash_time_label.get_rect(), hud.clash_keys_label.get_rect()])


func hud_scale(node: MatchController) -> void:
	var hud: CanvasLayer = node.hud
	var normal: int = hud.spirit_labels[0].get_theme_font_size("font_size")
	var normal_name := (hud.top_bar.find_children("*", "Label", true, false)[0] as Label).get_theme_font_size("font_size")
	node.request_pause_from_menu()
	var pause_font: int = hud.pause_actions.get_child(0).get_theme_font_size("font_size")
	hud.show_settings()
	hud.settings_screen.select_tab(4)
	var size_option := hud.settings_screen.find_child("HudTextSize", true, false) as SettingsSelector
	size_option.select(1)
	size_option.item_selected.emit(1)
	await settle()
	check(SessionState.hud_text_large and hud.spirit_labels[0].get_theme_font_size("font_size") == roundi(normal * GameBalance.get_number("hud_text_scale_large")), "pause choice enlarges HUD text live")
	check((hud.top_bar.find_children("*", "Label", true, false)[0] as Label).get_theme_font_size("font_size") > normal_name, "buffalo name text grows")
	var comfort_panel: Control = hud.settings_screen.panel
	check(root.get_visible_rect().encloses(comfort_panel.get_global_rect()), "Hiệu ứng with both new rows fits 720p")
	hud.settings_screen.close()
	check(hud.pause_actions.get_child(0).get_theme_font_size("font_size") == roundi(pause_font * GameBalance.get_number("hud_text_scale_large")), "closing settings applies text size to retained pause buttons")
	hud.show_pause()
	await settle()
	check(root.get_visible_rect().encloses(hud.pause_panel.get_global_rect()), "large pause text and buttons fit viewport")
	check(hud.pause_title.get_theme_font_size("font_size") == roundi(30 * GameBalance.get_number("hud_text_scale_large")), "pause title is scaled")
	node.resume_from_menu()
	node.phase = &"COUNTDOWN"
	await settle()
	check_panels(node, "countdown")
	node.start_playing()
	await settle()
	check_panels(node, "playing")
	check(hud.center_label.get_global_rect().position.y >= hud.spirit_labels[0].get_global_rect().end.y, "large fight banner clears the top text")
	check(hud.center_label.get_theme_font_size("font_size") == roundi(GameBalance.get_int("ui_countdown_font_size") * GameBalance.get_number("hud_text_scale_large")), "dynamic countdown/fight banner stays scaled")
	node.active_clash = {"time": 0.0, "lock_balance": 0.0, "a": node.player, "b": node.opponent}
	await settle()
	check_panels(node, "clash")
	for hooks in [[true, false], [false, true], [true, true]]:
		node.player.clash_hooked = hooks[0]
		node.opponent.clash_hooked = hooks[1]
		await settle()
		check(hud.clash_panel.get_global_rect().encloses(hud.clash_title.get_global_rect()), "large hook announcement fits: %s" % hud.clash_title.text)
	check(not hud.center_label.visible, "fight banner yields to clash panel")
	node.player.clash_hooked = false
	node.opponent.clash_hooked = false
	node.active_clash = {}
	SessionState.hud_text_large = false
	await settle()
	check(hud.spirit_labels[0].get_theme_font_size("font_size") == normal, "switching back restores original size without compounding")
	SessionState.hud_text_large = true
	await settle()
	node.mode = &"LAN"
	hud.show_result(1, &"TIME")
	hud._show_lan_result()
	await settle()
	check(root.get_visible_rect().encloses(hud.pause_panel.get_global_rect()), "large LAN result with stats fits viewport")
	check(hud.stats_panel.get_child(0).get_theme_font_size("font_size") == roundi(GameBalance.get_int("stats_font_size") * GameBalance.get_number("hud_text_scale_large")), "result stats text is enlarged")


func screenshots() -> void:
	SessionState.return_to_menu()
	var match_node := arena()
	await settle()
	match_node.phase = &"RESULT"
	match_node.finished = true
	match_node.outro.running = true
	match_node.outro.time = GameBalance.get_number("result_skip_grace_s")
	scene_changed.emit()
	var service := root.get_node("Screenshots")
	var folder := "user://screenshot-test-%d" % Time.get_ticks_usec()
	service.directory = folder
	var observed := []
	service.frame_provider = func():
		check(not service.toast.visible, "toast is hidden from the captured frame")
		var frame := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		frame.fill(Color.BLUE)
		return frame
	var listener := func(path: String): observed.append(path)
	service.saved.connect(listener)
	var f12 := InputEventKey.new()
	f12.keycode = KEY_F12
	f12.pressed = true
	root.push_input(f12)
	await settle()
	check(match_node.outro.running and match_node.phase == &"RESULT", "F12 captures without skipping or changing match result")
	root.push_input(f12)
	await settle()
	check(observed.size() == 2 and observed[0] != observed[1], "F12 writes unique names for successive captures")
	var pattern := RegEx.create_from_string("^choi-trau-[0-9]{8}-[0-9]{6}(-[0-9]+)?\\.png$")
	for path: String in observed:
		check(pattern.search(path.get_file()) != null, "screenshot name has the required timestamp")
		var image := Image.load_from_file(path)
		check(image != null and image.get_size() == Vector2i(8, 8) and image.get_pixel(0, 0) == Color.BLUE, "F12 saves a readable PNG in the injected folder")
	check(service.toast.visible and service.toast.text == "Đã lưu ảnh", "successful F12 shows the save toast")
	f12.echo = true
	root.push_input(f12)
	await settle()
	check(observed.size() == 2, "held F12 repeat does not capture")
	service._process(GameBalance.get_number("screenshot_toast_s"))
	check(not service.toast.visible, "toast disappears after its data duration")
	service.saved.disconnect(listener)
	service.frame_provider = Callable()
	service.directory = "user://screenshots"
	for path: String in observed:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	match_node.free()
