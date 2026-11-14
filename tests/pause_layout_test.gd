extends SceneTree
## Every in-match pause panel (pause, settings, LAN wait, LAN confirmation) must sit centred
## inside the overlay, fully on screen.

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func check_centered(hud: CanvasLayer, screen: String) -> void:
	await process_frame
	var overlay: Rect2 = hud.pause_overlay.get_global_rect()
	var panel: Rect2 = hud.pause_panel.get_global_rect()
	check(overlay.encloses(panel), "%s panel lies fully inside the screen (panel %s, screen %s)" % [screen, panel, overlay])
	check(panel.get_center().distance_to(overlay.get_center()) < 1.0, "%s panel is centred (panel centre %s, screen centre %s)" % [screen, panel.get_center(), overlay.get_center()])


func run() -> void:
	root.theme = load("res://assets/ui/festival_theme.tres")
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	var hud: CanvasLayer = arena.hud
	hud.show_pause()
	await check_centered(hud, "pause")
	var last_button: Control = hud.pause_actions.get_child(hud.pause_actions.get_child_count() - 1)
	check(hud.pause_panel.get_global_rect().end.y - last_button.get_global_rect().end.y < 40.0, "pause panel hugs its buttons (no empty band under VỀ MENU)")
	hud.show_settings()
	await check_centered(hud, "settings")
	check_settings(hud.pause_actions, "pause")
	hud.show_pause()
	await check_centered(hud, "pause after settings")
	hud.show_pause_wait(true)
	await check_centered(hud, "LAN wait")
	hud.show_pause_confirmation(2, true)
	await check_centered(hud, "LAN confirmation")
	arena.free()
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	menu._show_settings()
	await process_frame
	check_settings(menu.menu_settings_actions, "main menu")
	menu.free()
	print("PAUSE LAYOUT TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func check_settings(container: Container, screen: String) -> void:
	var toggles := container.find_children("*", "CheckButton", true, false)
	check(toggles.size() == 2, "%s shares both settings toggles" % screen)
	for toggle: CheckButton in toggles:
		var on := toggle.get_theme_icon("checked")
		var off := toggle.get_theme_icon("unchecked")
		check(on.get_size() == Vector2(44, 24) and off.get_size() == on.get_size(), "%s toggle has clear 44x24 icons in both states" % screen)
		check(on.get_image().get_pixel(22, 12).is_equal_approx(Color("#E8BC65")) and off.get_image().get_pixel(22, 12).get_luminance() < 0.2, "%s toggle uses gold ON and a dark OFF track" % screen)
	var slider := container.get_child(0).get_child(1) as HSlider
	var fill := slider.get_theme_stylebox("grabber_area") as StyleBoxFlat
	var focused := slider.get_theme_stylebox("grabber_area_highlight") as StyleBoxFlat
	check(fill.bg_color == focused.bg_color and focused.bg_color.is_equal_approx(Color("#E8BC65")), "%s slider fill stays gold when focused" % screen)
