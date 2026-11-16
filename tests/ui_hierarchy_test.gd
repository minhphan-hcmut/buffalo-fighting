extends SceneTree
## Shared button tiers; screen-specific checks grow with each completed view.

var failures := 0

class AvailableLAN extends MatchNetwork:
	func can_rematch() -> bool:
		return not peer_left


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func settle() -> void:
	for frame in 4:
		await process_frame


func view_contract(view: Control, title: String) -> void:
	await settle()
	check(root.get_visible_rect().grow(1.0).encloses(view.get_global_rect()), "%s view fits %s" % [title, root.size])
	var buttons: Array[Button] = []
	var primary := 0
	for node in view.find_children("*", "Button", true, false):
		var button := node as Button
		if not button.is_visible_in_tree():
			continue
		buttons.append(button)
		if button.theme_type_variation in [&"PrimaryButton", &"MenuPrimary", &"PrimaryTab", &"PrimaryRow"]:
			primary += 1
			if button.theme_type_variation == &"PrimaryButton":
				check(button.get_theme_stylebox("normal").bg_color.is_equal_approx(ControlsDiagram.GOLD), "%s primary action has gold fill" % title)
		check(root.get_visible_rect().grow(1.0).encloses(button.get_global_rect()), "%s button fits %s: %s" % [title, root.size, button.name])
		for state in ["normal", "hover", "pressed"]:
			var style := button.get_theme_stylebox(state) as StyleBoxFlat
			check(style != null and not style.bg_color.is_equal_approx(ControlsDiagram.PAPER), "%s/%s has no cream slab" % [title, state])
		var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
		check(focus != null and (focus.border_width_left > 0 or focus.border_width_bottom > 0), "%s focus indicator exists" % title)
	check(primary == 1, "%s has exactly one visible primary (got %d)" % [title, primary])
	var enabled := buttons.filter(func(button: Button): return not button.disabled)
	if enabled.is_empty():
		return
	for reverse in [false, true]:
		enabled[0].grab_focus()
		var visited: Array[Control] = []
		for index in 64:
			var current := root.gui_get_focus_owner()
			if current != null and not visited.has(current):
				visited.append(current)
			var event := InputEventKey.new()
			event.keycode = KEY_TAB
			event.shift_pressed = reverse
			event.pressed = true
			root.push_input(event)
			event.pressed = false
			root.push_input(event)
			await process_frame
			if root.gui_get_focus_owner() == enabled[0]:
				break
		for button: Button in enabled:
			check(visited.has(button), "%s keyboard %sTab reaches %s" % [title, "Shift+" if reverse else "", button.name])


func run() -> void:
	var theme: Theme = load("res://assets/ui/festival_theme.tres")
	root.theme = theme
	for tier in [&"Button", &"PrimaryButton", &"SecondaryButton", &"QuietButton"]:
		var button := Button.new()
		button.theme_type_variation = tier if tier != &"Button" else &""
		root.add_child(button)
		for state in [&"normal", &"hover", &"pressed", &"disabled"]:
			var style := button.get_theme_stylebox(state) as StyleBoxFlat
			check(style != null, "%s/%s uses a flat style" % [tier, state])
			if style != null:
				check(not style.bg_color.is_equal_approx(ControlsDiagram.PAPER) and not style.bg_color.is_equal_approx(Color("#F9E1AE")), "%s/%s has no cream slab" % [tier, state])
		var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
		var focus_color := ControlsDiagram.INK if tier == &"PrimaryButton" else ControlsDiagram.GOLD
		check(focus != null and focus.border_color.is_equal_approx(focus_color) and focus.border_width_left > 0, "%s keyboard focus contrasts with its fill" % tier)
		if tier == &"PrimaryButton":
			check(button.get_theme_stylebox("normal").bg_color.is_equal_approx(ControlsDiagram.GOLD), "primary fill is gold")
			check(button.get_theme_color("font_color").is_equal_approx(ControlsDiagram.INK), "primary text is ink")
			check(not button.get_theme_stylebox("hover").border_color.is_equal_approx(button.get_theme_stylebox("normal").border_color), "primary hover has a contrasting frame")
		elif tier == &"QuietButton":
			check(is_zero_approx(button.get_theme_stylebox("normal").bg_color.a), "quiet normal has no fill")
			check(button.get_theme_stylebox("hover").border_width_left == 3, "quiet hover has a three-pixel gold bar")
		else:
			check(button.get_theme_color("font_color").is_equal_approx(ControlsDiagram.PAPER), "secondary text is paper")
		button.free()
	var settings := SettingsScreen.new()
	root.add_child(settings)
	check(settings.done.theme_type_variation == &"PrimaryButton", "settings keeps its one primary action")
	settings.free()
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
		root.add_child(menu)
		await view_contract(menu.menu_layout, "main menu")
		menu._show_solo_chooser()
		await view_contract(menu.solo_page, "Solo chooser")
		check(menu.solo_page.find_children("*", "PanelContainer", true, false)[0].size.x < GameBalance.get_number("ui_free_play_page_width"), "small Solo chooser shrinks to its actions")
		menu._show_free_play()
		await view_contract(menu.solo_page, "free-play chooser")
		menu._close_solo_page()
		menu.menu_layout.show()
		menu._show_training()
		await view_contract(menu.solo_page, "training chooser")
		for drill: Dictionary in DataFile.load_json("res://data/training.json").drills:
			var row: Button = menu.solo_page.find_child(drill.id, true, false)
			check(row.get_global_rect().encloses(row.get_node("Description").get_global_rect()), "training description fits its row")
			for cap: PanelContainer in row.get_node("Keys").get_children():
				check(row.get_global_rect().encloses(cap.get_global_rect()), "training keycap fits its row")
		menu._close_solo_page()
		menu.menu_layout.show()
		menu._show_settings()
		await view_contract(menu.menu_settings_layer, "Settings")
		menu.menu_settings_layer.close()
		menu._show_how_to_play()
		var howto := menu.get_node("HowToPlay") as HowToPlay
		for tab in 4:
			howto.select_tab(tab)
			await view_contract(howto.panel, "instructions tab %d" % tab)
		howto.close()
		menu.free()
		var lobby: Control = load("res://scenes/lobby.tscn").instantiate()
		root.add_child(lobby)
		await view_contract(lobby, "LAN lobby")
		lobby.free()
		await result_views()
	await settle()
	print("ui_hierarchy_test: %d failed" % failures)
	quit(1 if failures else 0)


func result_views() -> void:
	SessionState.return_to_menu()
	SessionState.begin_solo()
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	arena.hud.set_process(false)
	await pause_views(arena)
	arena._finish(1, &"TIME")
	var overlay := Control.new()
	overlay.set_script(load("res://scripts/ui/main_menu.gd"))
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)
	overlay.set_process(false)
	overlay.show()
	for variant in ["win", "loss", "free"]:
		SessionState.free_play = variant == "free"
		SessionState.last_winner = 2 if variant == "loss" else 1
		overlay._show_result(variant)
		await view_contract(overlay.result_panel, "Solo result " + variant)
		var block: GridContainer = overlay.find_child("MatchStats", true, false)
		check(block.columns == 2 and block.get_child_count() == 14, "stats has seven label/value rows")
		for index in range(0, 14, 2):
			check(block.get_child(index).get_theme_color("font_color").is_equal_approx(SettingsControls.MUTED), "stat label is muted")
			check(block.get_child(index + 1).get_theme_color("font_color").is_equal_approx(ControlsDiagram.PAPER), "stat number is paper")
		check(overlay.result_detail.get_theme_font_size("font_size") > overlay.result_title.get_theme_font_size("font_size"), "win reason has the prominent size")
	overlay.free()
	arena.mode = &"LAN"
	arena.hud._show_lan_result()
	await view_contract(arena.hud.pause_panel, "LAN result")
	check(arena.hud.pause_title.get_theme_color("font_color").is_equal_approx(ControlsDiagram.GOLD), "LAN result title matches Solo gold")
	arena.lan = AvailableLAN.new(arena, root.get_node("NetworkManager"))
	arena.hud._show_lan_result()
	await view_contract(arena.hud.pause_panel, "LAN rematch available")
	arena.lan.remote_wants_rematch = true
	arena.hud.update_lan_rematch()
	await view_contract(arena.hud.pause_panel, "LAN rematch consent")
	check(arena.hud.rematch_button.text == "ĐỒNG Ý", "rematch consent keeps its primary action")
	arena.lan.local_wants_rematch = true
	arena.hud.update_lan_rematch()
	await view_contract(arena.hud.pause_panel, "LAN rematch waiting")
	arena.lan.peer_left = true
	arena.hud.update_lan_rematch(true)
	await view_contract(arena.hud.pause_panel, "LAN disconnected")
	arena.free()
	SessionState.return_to_menu()
	var rite := CeremonyView.create(&"opening")
	root.add_child(rite)
	await view_contract(rite, "ceremony")
	rite.free()


func pause_views(arena: MatchController) -> void:
	arena.hud.show_pause()
	await view_contract(arena.hud.pause_panel, "Solo pause")
	arena.hud.show_settings()
	await view_contract(arena.hud.settings_screen, "pause Settings")
	arena.hud.settings_screen.close()
	arena.mode = &"LAN"
	arena.hud.show_pause()
	await view_contract(arena.hud.pause_panel, "LAN pause")
	arena.hud.show_pause_wait(true)
	await view_contract(arena.hud.pause_panel, "LAN waiting")
	arena.hud.show_pause_confirmation(2, true)
	await view_contract(arena.hud.pause_panel, "LAN consent")
	arena.hud.hide_pause()
	arena.mode = &"SOLO"
