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
	var panel: Rect2 = (hud.settings_screen.panel if hud.showing_settings else hud.pause_panel).get_global_rect()
	check(overlay.encloses(panel), "%s panel lies fully inside the screen (panel %s, screen %s)" % [screen, panel, overlay])
	# 2026-11-22: the pause dim was a cold teal; it now matches the warm festival browns.
	var shade := hud.pause_overlay.get_node("PauseShade") as ColorRect
	check(shade.color.r > shade.color.b and shade.color.a >= 0.85, "%s pause dim is warm brown: %s" % [screen, shade.color.to_html()])
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
	check_settings(hud.settings_screen, "pause")
	hud.show_pause()
	await check_centered(hud, "pause after settings")
	hud.show_pause_wait(true)
	await check_centered(hud, "LAN wait")
	hud.show_pause_confirmation(2, true)
	await check_centered(hud, "LAN confirmation")
	# Esc on the pause settings page steps back to the pause menu; a second Esc resumes.
	arena.mode = &"SOLO"
	arena.phase = &"PLAYING"
	arena.call("_set_paused", true)
	hud.show_settings()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	arena._input(esc)
	check(arena.paused and not hud.showing_settings and hud.pause_title.text == "TẠM DỪNG", "Esc in pause settings goes back to the pause menu")
	arena._input(esc)
	check(not arena.paused, "Esc in the pause menu resumes the match")
	arena.free()
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	menu._show_settings()
	await process_frame
	check_settings(menu.menu_settings_layer, "main menu")
	menu.free()
	print("PAUSE LAYOUT TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func check_settings(screen: SettingsScreen, context: String) -> void:
	screen.select_tab(1)
	var toggles := screen.pages[1].find_children("*", "CheckButton", true, false)
	check(toggles.size() == 1 and toggles[0].name == &"Fullscreen", "%s keeps fullscreen in Điều khiển" % context)
	screen.tabs[4].pressed.emit()
	var comfort := screen.pages[4]
	var comfort_toggles := comfort.find_children("*", "CheckButton", true, false)
	check(comfort_toggles.size() == 6 and comfort_toggles.map(func(toggle: CheckButton): return toggle.name) == [&"CameraShake", &"CameraPunch", &"Hitstop", &"AutoPause", &"Rumble", &"Replay"] and comfort.find_child("CameraShakeRow", true, false).get_child(0).get_child(0).get_child(0).text == "Rung camera", "%s preserves the five Hiệu ứng toggles and adds replay" % context)
	toggles.append_array(comfort_toggles)
	for toggle: CheckButton in toggles:
		var on := toggle.get_theme_icon("checked")
		var off := toggle.get_theme_icon("unchecked")
		check(on.get_size() == Vector2(44, 24) and off.get_size() == on.get_size(), "%s toggle has clear 44x24 icons in both states" % context)
		check(on.get_image().get_pixel(22, 12).is_equal_approx(Color("#E8BC65")) and off.get_image().get_pixel(22, 12).get_luminance() < 0.2, "%s toggle uses gold ON and a dark OFF track" % context)
	screen.select_tab(0)
	var slider := screen.find_child("Master", true, false) as HSlider
	var fill := slider.get_theme_stylebox("grabber_area") as StyleBoxFlat
	var focused := slider.get_theme_stylebox("grabber_area_highlight") as StyleBoxFlat
	check(fill.bg_color == focused.bg_color and focused.bg_color.is_equal_approx(Color("#E8BC65")), "%s slider fill stays gold when focused" % context)
