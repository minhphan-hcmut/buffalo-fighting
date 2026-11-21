extends SceneTree
## Shared modal contract: inventory, geometry, input, persistence, scoped reset and exit.

const SETTINGS := "user://settings_screen_test.cfg"
const GRAPHICS := "user://settings_screen_graphics_test.cfg"
const KEYS := [
	["Master", "Music", "SFX"],
	["Language", "Sensitivity", "Fullscreen", "Key_move_forward", "Key_move_back", "Key_move_left", "Key_move_right", "Key_horn", "Key_guard", "Key_dash", "Key_parry"],
	["CameraView", "CameraSide"],
	["Preset", "crowd", "shadows", "scenery", "models", "render_scale", "FpsLimit", "ShowFps"],
	["CameraShake", "CameraPunch", "ImpactFlash", "Hitstop", "AutoPause", "Rumble", "Replay", "HudTextSize"],
]
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func settle() -> void:
	for frame in 4:
		await process_frame


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)


func joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
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


func snapshot() -> Array:
	return [
		[AudioServer.get_bus_volume_linear(FestivalAudio.ensure_bus("Master")), AudioServer.get_bus_volume_linear(FestivalAudio.ensure_bus("Music")), AudioServer.get_bus_volume_linear(FestivalAudio.ensure_bus("SFX"))],
		[SessionState.get_mouse_sensitivity(), SessionState.fullscreen_enabled],
		[SessionState.camera_view, SessionState.camera_side],
		[GraphicsQuality.DETAILS.map(func(entry: Array): return GraphicsQuality.detail(entry[0])), GraphicsQuality.fps_limit(), GraphicsQuality.show_fps()],
		SettingsControls.effect_values(),
	]


func run() -> void:
	root.theme = load("res://assets/ui/festival_theme.tres")
	root.size = Vector2i(1280, 720)
	MatchInput.configure_ui()
	var original := SessionState.settings_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GRAPHICS))
	SessionState.load_settings(SETTINGS)
	GraphicsQuality.reset(GRAPHICS)
	var opener := Button.new()
	root.add_child(opener)
	var screen := SettingsScreen.new()
	root.add_child(screen)
	screen.open(opener)
	await settle()
	var all_keys: Array[String] = []
	for tab in KEYS.size():
		var keys: Array[String] = []
		for row: SettingsRow in screen.pages[tab].get_children():
			keys.append(str(row.control.name))
			all_keys.append(str(row.control.name))
		check(keys == KEYS[tab], "tab %d contains each expected setting in order" % tab)
	for group in KEYS:
		for setting: String in group:
			check(all_keys.count(setting) == 1, "%s appears exactly once" % setting)
	check(screen.find_child("training_unlimited_stamina", true, false) == null and screen.find_children("*", "OptionButton", true, false).is_empty(), "training stays separate and no dropdown UI remains")
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		for tab in KEYS.size():
			screen.select_tab(tab)
			await settle()
			check(root.get_visible_rect().encloses(screen.panel.get_global_rect()), "panel fits %s tab %d" % [resolution, tab])
			check(screen.panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) < 1.0, "panel centred at %s tab %d" % [resolution, tab])
			var rows := screen.pages[tab].get_children()
			var first: SettingsRow = rows[0]
			check(first.has_focus(), "tab %d opens on its first row" % tab)
			for row: SettingsRow in rows:
				check(is_equal_approx(row.size.y, GameBalance.get_number("settings_row_height")) and is_equal_approx(row.size.y, first.size.y), "uniform row height %s" % row.name)
				check(is_equal_approx(row.column.global_position.x, first.column.global_position.x) and is_equal_approx(row.column.size.x, GameBalance.get_number("settings_control_width")), "aligned fixed control column %s" % row.name)
				var label: Label = row.get_child(0).get_child(0).get_child(0)
				check(label.get_minimum_size().x <= label.size.x and row.get_global_rect().encloses(row.column.get_global_rect()), "label and control fit %s" % row.name)
			var focus: Control = first
			for step in rows.size() + 7:
				check(screen.is_ancestor_of(focus) and focus.is_visible_in_tree(), "focus stays in current modal tab %d step %d" % [tab, step])
				focus.grab_focus()
				await process_frame
				focus = focus.find_next_valid_focus()
			check(focus == first, "tab %d focus cycle returns to first row" % tab)
			(rows[-1] as Control).grab_focus()
			await settle()
			check(screen.scrolls[tab].get_global_rect().encloses((rows[-1] as Control).get_global_rect()), "last row scrolls fully into view tab %d" % tab)
	root.size = Vector2i(1280, 720)
	screen.select_tab(2)
	await settle()
	key(KEY_RIGHT)
	check(SessionState.camera_view == 2, "selector Right changes the focused row")
	var config := ConfigFile.new()
	check(config.load(SETTINGS) == OK and config.get_value("settings", "camera_view") == 2, "selector change saves immediately")
	key(KEY_RIGHT)
	check(SessionState.camera_view == 0, "selector Right wraps at the end")
	key(KEY_LEFT)
	check(SessionState.camera_view == 2, "selector Left wraps at the start")
	joy(JOY_BUTTON_DPAD_LEFT)
	check(SessionState.camera_view == 1, "D-pad Left changes the focused selector")
	joy(JOY_BUTTON_DPAD_RIGHT)
	check(SessionState.camera_view == 2, "D-pad Right changes the focused selector")
	var selector := screen.find_child("CameraView", true, false) as SettingsSelector
	await settle()
	click(selector.get_child(0))
	check(SessionState.camera_view == 1, "clicking selector arrow updates and saves")
	key(KEY_Q)
	check(screen.selected_tab == 1, "Q switches to previous tab")
	key(KEY_E)
	check(screen.selected_tab == 2, "E switches to next tab")
	joy(JOY_BUTTON_LEFT_SHOULDER)
	check(screen.selected_tab == 1, "LB switches to previous tab")
	joy(JOY_BUTTON_RIGHT_SHOULDER)
	check(screen.selected_tab == 2, "RB switches to next tab")
	screen.select_tab(0)
	key(KEY_Q)
	check(screen.selected_tab == 4, "tab navigation wraps")
	await settle()
	click(screen.tabs[0])
	check(screen.selected_tab == 0, "mouse selects a tab")
	screen.select_tab(4)
	key(KEY_LEFT)
	check(not SessionState.camera_shake_enabled, "Left toggles a focused switch")
	key(KEY_ENTER)
	check(SessionState.camera_shake_enabled, "Enter toggles a focused switch")
	for tab in KEYS.size():
		# Other tabs must also differ from defaults, or an accidental reset-all would pass.
		for page in screen.pages:
			for row: SettingsRow in page.get_children():
				if row.control is HSlider:
					row.control.value = 0.2 if row.control.name == &"Sensitivity" else 20
				elif row.control is CheckButton:
					row.control.button_pressed = row.control.name in [&"Fullscreen", &"ShowFps"]
				elif row.control is SettingsSelector:
					row.control.select(0 if row.control.name == &"CameraView" else 1)
					row.control.item_selected.emit(row.control.selected)
		screen.select_tab(tab)
		var before := snapshot()
		var training_before := SessionState.training_unlimited_stamina
		screen.reset_button.pressed.emit()
		var after := snapshot()
		for other in KEYS.size():
			if other != tab:
				check(after[other] == before[other], "reset tab %d preserves tab %d" % [tab, other])
		check(SessionState.training_unlimited_stamina == training_before, "reset preserves training preference")
		match tab:
			0: check(after[0] == [1.0, 1.0, 1.0], "audio reset restores all buses to 100%")
			1: check(after[1] == [GameBalance.get_number("mouse_sensitivity"), false], "controls reset restores sensitivity and windowed mode")
			2: check(after[2] == [1, 0], "camera reset restores Vừa / Phải")
			3: check(GraphicsQuality.preset() == GraphicsQuality.auto_preset() and GraphicsQuality.fps_limit() == 0 and not GraphicsQuality.show_fps(), "graphics reset restores auto preset and FPS defaults")
			4: check(after[4].values() == [true, true, 0, true, true, true, true, false], "effects reset restores every comfort default")
		SessionState.load_settings(SETTINGS)
		GraphicsQuality.reset(GRAPHICS)
		var reloaded := snapshot()
		var same_audio := true
		# AudioServer converts linear volume through dB, with normal float round-off.
		for bus in 3:
			same_audio = same_audio and is_equal_approx(reloaded[0][bus], after[0][bus])
		check(same_audio and is_equal_approx(reloaded[1][0], after[1][0]) and reloaded[1][1] == after[1][1] and reloaded.slice(2) == after.slice(2), "reset tab %d persists without modifying other tabs" % tab)
	SettingsControls.set_fullscreen(false)
	GraphicsQuality.set_fps_limit(0)
	screen.close()
	screen.free()
	opener.free()
	await check_exit_paths()
	SessionState.load_settings(original)
	GraphicsQuality.reset()
	for path in [SETTINGS, GRAPHICS]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("SETTINGS SCREEN: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check_exit_paths() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	for joypad in [false, true]:
		menu._show_settings()
		await settle()
		check(menu.menu_settings_layer.pages[0].get_child(0).has_focus(), "menu settings focus first audio row")
		if joypad:
			joy(JOY_BUTTON_B)
		else:
			key(KEY_ESCAPE)
		check(not menu.menu_settings_layer.visible and menu.menu_layout.get_node("SettingsButton").has_focus(), "menu Esc/B closes and restores settings opener")
	menu.free()
	SessionState.begin_free_play(&"L01")
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.start_playing()
	arena.request_pause_from_menu()
	for joypad in [false, true]:
		arena.hud.show_settings()
		await settle()
		var pause_opener: Control = arena.hud.settings_screen.opener
		check(arena.paused and not arena.get_node("CameraRig").gameplay_enabled and arena.hud.settings_screen.pages[0].get_child(0).has_focus(), "pause settings keeps match paused and focuses first row")
		check(not arena.hud.pause_overlay.get_child(0).visible, "settings supplies one backdrop without double-dimming pause")
		if joypad:
			joy(JOY_BUTTON_B)
		else:
			key(KEY_ESCAPE)
		check(arena.paused and not arena.hud.showing_settings and pause_opener.has_focus(), "pause Esc/B closes settings and restores opener without resuming")
		check(arena.hud.pause_overlay.get_child(0).visible, "closing settings restores the normal pause backdrop")
	arena.resume_from_menu()
	arena.free()
	SessionState.return_to_menu()
