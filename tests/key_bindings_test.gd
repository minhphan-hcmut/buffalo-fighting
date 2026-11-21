extends SceneTree
## Rebindable controls (2026-11-22): InputMap, swaps, reserved keys, save/load, hints and
## the Cài đặt → Điều khiển rows.

const SETTINGS := "user://key_bindings_test.cfg"
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


func key(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event


func bound_key(action: String) -> Key:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.physical_keycode
	return KEY_NONE


func run() -> void:
	SessionState.settings_path = SETTINGS
	root.theme = load("res://assets/ui/festival_theme.tres")
	KeyBindings.reset()
	check(bound_key("dash") == KEY_SPACE and bound_key("parry") == KEY_G and bound_key("move_forward") == KEY_W, "defaults reach the InputMap")
	check(TutorialPresenter().controls_text() == "WASD Đi · Chuột Nhìn · Trái Húc · Space Hổ lao · Phải Ghìm · G Gạt sừng · Esc Tạm dừng", "default HUD controls text is unchanged")

	KeyBindings.rebind("dash", KeyBindings.code_for(key(KEY_F)))
	check(bound_key("dash") == KEY_F, "dash rebinds to F")
	var swapped := KeyBindings.rebind("dash", KeyBindings.code_for(key(KEY_G)))
	check(swapped == "parry" and bound_key("dash") == KEY_G and bound_key("parry") == KEY_F, "taking G from parry gives parry the old key")
	check(KeyBindings.code_for(key(KEY_ESCAPE)).is_empty() and KeyBindings.code_for(key(KEY_F12)).is_empty() and KeyBindings.code_for(key(KEY_H, false)).is_empty(), "Esc, F12 and key releases cannot be bound")
	check(TutorialPresenter().controls_text().contains("G Hổ lao") and TutorialPresenter().controls_text().contains("F Gạt sừng"), "HUD hint shows the new keys")
	check(MoveDemo.keys_for(&"parry") == "F → Chuột trái" and MoveDemo.keys_for(&"dash") == "G", "move cards show the new keys")

	var config := ConfigFile.new()
	KeyBindings.save_to(config)
	KeyBindings.reset()
	KeyBindings.load_from(config)
	check(KeyBindings.bindings["dash"] == "k%d" % KEY_G and KeyBindings.bindings["parry"] == "k%d" % KEY_F, "bindings survive save and load")
	config.set_value("keys", "horn", "k%d" % KEY_G)
	KeyBindings.load_from(config)
	check(KeyBindings.is_default(), "a saved file with a duplicate key falls back to defaults")
	config.set_value("keys", "horn", "k%d" % KEY_ESCAPE)
	KeyBindings.load_from(config)
	check(KeyBindings.bindings["horn"] == KeyBindings.DEFAULTS["horn"], "a saved reserved key is ignored")
	KeyBindings.reset()

	await settings_rows()
	KeyBindings.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	print("Key bindings: %d failures" % failures)
	quit(0 if failures == 0 else 1)


func TutorialPresenter() -> GDScript:
	return load("res://scripts/ui/hud_tutorial.gd")


func settings_rows() -> void:
	var opener := Button.new()
	root.add_child(opener)
	var screen := SettingsScreen.new()
	root.add_child(screen)
	screen.open(opener)
	screen.select_tab(1)
	await process_frame
	var button := screen.pages[1].find_child("Key_dash", true, false) as KeyBindButton
	check(button != null and button.text == "Space", "Controls tab lists the dash key")
	var row := button.get_parent().get_parent().get_parent() as SettingsRow
	row.grab_focus()
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	root.push_input(accept)
	await process_frame
	check(button.capturing and button.text == "Nhấn phím…", "Enter on the row waits for a key")
	root.push_input(key(KEY_ESCAPE))
	await process_frame
	check(not button.capturing and button.text == "Space" and screen.visible, "Esc cancels the capture without closing settings")
	button.pressed.emit()
	root.push_input(key(KEY_G))
	await process_frame
	var parry := screen.pages[1].find_child("Key_parry", true, false) as KeyBindButton
	check(button.text == "G" and parry.text == "Space" and bound_key("dash") == KEY_G, "pressing G binds dash and the swapped parry row updates")
	var saved := ConfigFile.new()
	check(saved.load(SETTINGS) == OK and saved.get_value("keys", "dash", "") == "k%d" % KEY_G, "a rebind is saved to settings")
	button.pressed.emit()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_MIDDLE
	click.pressed = true
	root.push_input(click)
	await process_frame
	check(button.text == "Chuột giữa" and KeyBindings.bindings["dash"] == "m%d" % MOUSE_BUTTON_MIDDLE, "a mouse button can be bound")
	SettingsControls.reset_tab(screen.pages[1], 1)
	check(KeyBindings.is_default() and button.text == "Space" and parry.text == "G", "reset restores default keys")
	screen.free()
	opener.free()
	await process_frame
