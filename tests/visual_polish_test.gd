extends SceneTree

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
	root.size = Vector2i(1280, 720)
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	var hud = arena.hud
	hud.set_process(false)
	hud._process(0.0)
	check(hud.spirit_labels[0].text == "KHÍ THẾ  100 / 100", "initial spirit label uses actor state")
	check(hud.stamina_labels[1].text == "SỨC  100 / 100", "initial opponent stamina label uses actor state")
	check(hud.player_spirit.fill_mode == ProgressBar.FILL_BEGIN_TO_END and hud.opponent_spirit.fill_mode == ProgressBar.FILL_END_TO_BEGIN, "opponent resource bars mirror player bars")
	arena.player.spirit = 77.0
	arena.player.stamina = 24.0
	arena.opponent.spirit = 56.0
	arena.opponent.stamina = 60.0
	hud._process(0.0)
	check(hud.player_spirit.value == 77.0 and hud.opponent_spirit.value == 56.0, "both spirit bars follow independent actor state")
	check(hud.player_stamina.value == 24.0 and hud.opponent_stamina.value == 60.0, "both stamina bars follow independent actor state")
	check(hud.spirit_labels[0].text == "KHÍ THẾ  77 / 100" and hud.spirit_labels[1].text == "KHÍ THẾ  56 / 100", "both spirit labels show current numbers")
	check(hud.stamina_labels[0].text == "SỨC  24 / 100 · SỨC THẤP" and hud.stamina_labels[1].text == "SỨC  60 / 100", "low stamina has a text warning without relying on color")
	check(hud.low_stamina == [true, false], "only actor below stamina threshold is warned")
	check(hud.player_stamina.get_theme_stylebox("fill").bg_color == Color("#FFAA66"), "low stamina switches fill to orange")
	check(hud.spirit_trails[0].value == 100.0, "new spirit loss keeps the old value as a bright trail")
	var duration := GameBalance.get_number("ui_spirit_trail_s")
	await create_timer(duration * 0.5).timeout
	check(hud.spirit_trails[0].value > 77.0 and hud.spirit_trails[0].value < 100.0, "trail visibly shrinks between old and new values")
	arena.player.spirit = 60.0
	hud._process(0.0)
	await create_timer(duration + 0.1).timeout
	check(is_equal_approx(hud.spirit_trails[0].value, 60.0) and is_equal_approx(hud.spirit_trails[1].value, 56.0), "successive losses settle to the latest spirit on both sides")
	arena.player.spirit = 40.0
	hud._process(0.0)
	arena.player.spirit = 90.0
	hud._process(0.0)
	await create_timer(duration + 0.1).timeout
	check(is_equal_approx(hud.spirit_trails[0].value, 90.0), "a recovered/reset spirit cancels the old drain tween")
	arena.player.stamina = GameBalance.get_number("ui_low_stamina_threshold")
	hud._process(0.0)
	check(not hud.low_stamina[0] and not hud.stamina_labels[0].text.contains("THẤP"), "stamina at threshold clears warning")
	check(hud.player_stamina.modulate.a == 1.0 and hud.player_stamina.get_theme_stylebox("fill").bg_color == Color("#E8BC65"), "recovered stamina resets pulse and fill")
	arena.opponent.stamina = 0.0
	hud._process(0.25 / GameBalance.get_number("ui_low_stamina_pulse_hz"))
	check(hud.low_stamina[1] and hud.opponent_stamina.modulate.a < 1.0, "zero stamina on opponent also pulses")
	arena.remaining_time = GameBalance.get_number("ui_timer_warning_s")
	hud._process(0.0)
	check(hud.timer_label.get_theme_color("font_color") == Color("#FF8C76"), "last ten seconds use readable red timer")
	var world: WorldEnvironment
	for child in arena.get_children():
		if child is WorldEnvironment:
			world = child
	check(world != null and world.environment.background_mode == Environment.BG_SKY and world.environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY, "arena uses sky background and sky ambient lighting")
	check(arena.get_node("Dressing/Field").mesh.size.x == GameBalance.get_number("ui_outer_ground_size"), "outer ground extends beyond fence and exit corridors")
	for actor in [arena.player, arena.opponent]:
		var feedback := actor.get_node("CombatFeedback") as BuffaloFeedback
		var has_identifier := false
		for child in actor.get_children():
			if child is Label3D and child != feedback.label:
				has_identifier = true
		check(not has_identifier, "buffalo has no floating identifier outside combat feedback")
		check(str(actor.get_meta("announcer_name", "")).contains("06" if actor == arena.player else "17"), "announcer metadata retains buffalo number")
	var panel_style: StyleBoxFlat = hud.pause_panel.get_theme_stylebox("panel")
	check(panel_style.bg_color.a == 1.0, "shared modal theme is fully opaque")
	hud.show_settings()
	await process_frame
	hud.show_pause()
	check(hud.pause_actions.get_child_count() == 4 and hud.pause_actions.get_child(0).has_focus(), "returning from settings removes old rows and focuses Resume")
	var toggle := CheckButton.new()
	hud.pause_actions.add_child(toggle)
	check(toggle.get_theme_stylebox("normal").bg_color == Color("#30281F") and toggle.get_theme_color("font_color") == Color("#F2E6CF"), "unchecked settings toggle uses contrasting wood and paper colors")
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	var backdrop := menu.find_child("MenuBackdrop", true, false) as MenuBackdrop
	check(backdrop != null and backdrop.camera.current, "main menu shows the 3D arena backdrop")
	var red := backdrop.get_node("RedBuffalo") as Node3D
	var blue := backdrop.get_node("BlueBuffalo") as Node3D
	var red_to_blue := (blue.global_position - red.global_position).normalized()
	check((-red.global_basis.z).dot(red_to_blue) > 0.99 and (-blue.global_basis.z).dot(-red_to_blue) > 0.99, "menu buffaloes face each other")
	menu._show_settings()
	await process_frame
	var settings_panel := menu.menu_settings_layer.get_child(1) as PanelContainer
	check(root.get_visible_rect().encloses(settings_panel.get_global_rect()), "menu settings are completely on screen")
	check(settings_panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) < 1.0, "menu settings stay centered")
	check(not menu.menu_layout.visible and menu.get_viewport().gui_get_focus_owner().is_visible_in_tree(), "settings hide background menu and focus a visible control")
	menu.menu_settings_actions.get_child(-1).pressed.emit()
	check(menu.menu_layout.visible and not menu.menu_settings_layer.visible, "settings back restores menu")
	menu._show_settings()
	check(not menu.menu_layout.visible, "reopening settings hides menu again")
	menu._ensure_session_overlay()
	menu.free()
	current_scene = arena
	var overlay: Control = root.get_node("SoloSessionOverlay")
	arena._finish(1, &"TIME")
	arena.outro.time = GameBalance.get_number("result_outro_s")
	arena.outro.waypoints.clear()
	arena.outro.process(0.0)
	overlay._process(0.0)
	await process_frame
	check(overlay.visible and not hud.visible, "Solo results hide the HUD so it cannot draw above the result scrim")
	check(overlay.result_actions.get_child_count() == 3 and overlay.result_actions.get_child(0).has_focus(), "Solo win keeps retry, next-round and menu actions with keyboard focus")
	var result_panel := overlay.get_child(1) as PanelContainer
	check(root.get_visible_rect().encloses(result_panel.get_global_rect()), "Solo result panel is on screen at 1280x720")
	overlay.free()
	arena.free()
	print("VISUAL POLISH FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
