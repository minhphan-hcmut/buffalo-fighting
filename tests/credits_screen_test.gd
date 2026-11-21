extends SceneTree
## Credits page and version label on the main menu (2026-11-22).

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


func run() -> void:
	root.theme = load("res://assets/ui/festival_theme.tres")
	SessionState.return_to_menu()
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var version := menu.find_child("VersionLabel", true, false) as Label
	check(version != null and version.text == "Phiên bản " + String(ProjectSettings.get_setting("application/config/version")), "menu corner shows the version")
	check(version != null and version.size.y < version.size.x, "version label stays on one line: %s" % (version.size if version else Vector2.ZERO))
	var button := menu.find_child("CreditsButton", true, false) as Button
	check(button != null and button.text == "THỰC HIỆN", "menu has a credits button")
	button.pressed.emit()
	await process_frame
	var credits := menu.get_node_or_null("Credits") as CreditsScreen
	check(credits != null and not menu.menu_layout.visible, "credits open over the menu")
	var words := PackedStringArray()
	for label: Label in credits.find_children("*", "Label", true, false):
		words.append(label.text)
	var all := "\n".join(words)
	for name in ["Nhóm thực hiện", "Kenney", "Quaternius", "Poly Haven", "Godot"]:
		check(all.contains(name), "credits mention " + name)
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	root.push_input(event)
	await process_frame
	await process_frame
	check(menu.get_node_or_null("Credits") == null and menu.menu_layout.visible and button.has_focus(), "Esc closes credits and focus returns to the button")
	menu.free()
	await process_frame
	print("Credits: %d failures" % failures)
	quit(0 if failures == 0 else 1)
