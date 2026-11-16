extends SceneTree

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


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.theme = load("res://assets/ui/festival_theme.tres")
	SessionState.return_to_menu()
	await _check_chooser()
	var levels := DataFile.load_json("res://data/levels.json")
	check(levels.difficulty_labels == {"EASY": "Dễ", "EASY_PLUS": "Dễ+", "NORMAL": "Thường", "NORMAL_PLUS": "Thường+", "HARD": "Khó"}, "difficulty labels are data keyed by the actual AI profiles")
	for level: StringName in SessionState.SOLO_LEVELS:
		for winner in [1, 2]:
			await _check_match(level, winner, levels)
	await _check_result_navigation()
	SessionState.free_play = false
	SessionState.return_to_menu()
	print("FREE PLAY: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _menu() -> Control:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	return menu


func _escape() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	return key


func _check_page(page: Control, buttons: Array, description: String) -> void:
	var panel := page.find_children("*", "PanelContainer", true, false)[0] as Control
	check(root.get_visible_rect().encloses(panel.get_global_rect()), "%s fits 1280x720" % description)
	var focus := buttons[0] as Control
	check(focus.has_focus(), "%s starts with its first choice focused" % description)
	for button: Control in buttons:
		check(focus == button and focus.is_visible_in_tree() and focus.focus_mode == Control.FOCUS_ALL, "%s keyboard/gamepad focus reaches %s" % [description, button.name])
		focus = focus.find_next_valid_focus()
	check(focus == buttons[0], "%s focus wraps without reaching the hidden main menu" % description)


func _check_chooser() -> void:
	var menu := _menu()
	(menu.menu_layout.get_node("SoloButton") as Button).pressed.emit()
	await process_frame
	await process_frame
	check(not menu.menu_layout.visible and menu.ceremony_layer == null, "Solo opens a chooser before starting a season or a rite")
	var page: Control = menu.solo_page
	_check_page(page, [page.find_child("SeasonButton", true, false), page.find_child("FreePlayButton", true, false), page.find_child("TrainingButton", true, false), page.find_child("SoloBack", true, false)], "Solo chooser")
	menu._unhandled_input(_escape())
	check(menu.solo_page == null and menu.menu_layout.visible and menu.menu_layout.get_node("SoloButton").has_focus(), "Esc from chooser returns focus to Solo")
	menu._show_solo_chooser()
	(page_button(menu, "FreePlayButton")).pressed.emit()
	await process_frame
	await process_frame
	page = menu.solo_page
	var buttons: Array = []
	for level: StringName in SessionState.SOLO_LEVELS:
		buttons.append(page.find_child(String(level), true, false))
	buttons.append(page.find_child("SoloBack", true, false))
	_check_page(page, buttons, "Free-play list")
	menu._unhandled_input(_escape())
	check(menu.solo_page.find_child("SeasonButton", true, false) != null, "Esc from free-play list returns to the chooser")
	(page_button(menu, "SeasonButton")).pressed.emit()
	check(not SessionState.free_play and menu.ceremony_layer is CeremonyView and menu.ceremony_layer.variant == &"opening", "MÙA HỘI starts the unchanged season opening")
	(menu.ceremony_layer as CeremonyView).finish()
	await process_frame
	check(menu.ceremony_layer is CeremonyView and menu.ceremony_layer.variant == &"water", "season still follows opening with the water rite")
	(menu.ceremony_layer as CeremonyView).finish()
	await scene_changed
	check(current_scene is MatchController and current_scene.level_id == &"L01" and not SessionState.free_play, "season chooser starts the original qualifier")
	await _settle_arena(current_scene)
	current_scene.free()
	SessionState.return_to_menu()


func page_button(menu: Control, name: String) -> Button:
	return menu.solo_page.find_child(name, true, false) as Button


func _settle_arena(arena: MatchController) -> void:
	arena.set_physics_process(false)
	for frame in GameBalance.get_int("vfx_warm_up_settle_frames") + GameBalance.get_int("vfx_warm_up_frames") + 2:
		await process_frame


func _check_match(level: StringName, winner: int, levels: Dictionary) -> void:
	SessionState.free_play = false
	SessionState.return_to_menu()
	SessionState.unlocked_level = 2
	SessionState.opening_ceremony_seen = true
	SessionState.rites_seen.assign([&"water"])
	var menu := _menu()
	menu._show_free_play()
	for id: StringName in SessionState.SOLO_LEVELS:
		var button := page_button(menu, String(id))
		var data: Dictionary = levels[id]
		check(button != null and not button.disabled and button.text.contains(data.title.to_upper()) and button.text.contains(data.opponent_number + " · " + data.opponent_giap) and button.text.contains(levels.difficulty_labels[data.ai_profile]), "all rounds are available with profile-derived label and opponent: %s" % id)
	page_button(menu, String(level)).pressed.emit()
	await scene_changed
	var arena := current_scene as MatchController
	await _settle_arena(arena)
	var data: Dictionary = levels[level]
	check(SessionState.free_play and arena.mode == &"SOLO" and arena.level_id == level, "%s starts directly as free-play Solo" % level)
	check(arena.ai.profile == StringName(data.ai_profile) and arena.ai.profile_data == DataFile.load_json("res://data/ai_profiles.json")[data.ai_profile], "%s uses its actual AI profile" % level)
	check(arena.mud_zones.map(func(zone: StringName): return String(zone)) == data.mud_zones, "%s uses its mud zones" % level)
	var labels: Array = arena.hud.find_children("*", "Label", true, false).map(func(label: Label): return label.text)
	check(labels.has(data.opponent_number) and labels.has("XANH · " + data.opponent_giap), "%s uses its opponent number and giáp" % level)
	check(SessionState.take_rites_before(level).is_empty() and SessionState.rites_seen == [&"water"], "%s free play never consumes a pre-match rite" % level)
	check(root.find_children("Ceremony", "", true, false).is_empty(), "%s free play enters without Phần Lễ" % level)
	arena._finish(winner, &"FLEE")
	arena.outro.time = GameBalance.get_number("result_skip_grace_s")
	arena.outro.skip(_escape())
	var overlay := root.get_node("SoloSessionOverlay")
	overlay._process(0.0)
	check(SessionState.unlocked_level == 2 and SessionState.level_id == level and SessionState.last_match_level == level, "%s winner %d leaves all season progress untouched" % [level, winner])
	check(SessionState.last_winner == winner and SessionState.last_reason == &"FLEE", "free-play result retains its actual winner and reason")
	check(overlay.find_child("Ceremony", true, false) == null and overlay.result_panel.visible and overlay.result_title.text.begins_with("KẾT QUẢ"), "%s winner %d has no closing rite or season-ending result" % [level, winner])
	check(overlay.result_actions.get_children().map(func(button: Button): return button.text) == ["CHƠI LẠI", "ĐỔI TRẬN", "VỀ MENU"], "free-play win/loss offers exactly replay, change match and menu")
	current_scene.free()
	SessionState.return_to_menu()
	check(SessionState.unlocked_level == 2 and SessionState.opening_ceremony_seen and SessionState.rites_seen == [&"water"], "leaving free play preserves the season and its rite history")


func _finish_for_navigation(arena: MatchController) -> Control:
	arena._finish(1, &"TIME")
	arena.outro.time = GameBalance.get_number("result_skip_grace_s")
	arena.outro.skip(_escape())
	var overlay := root.get_node("SoloSessionOverlay") as Control
	overlay._process(0.0)
	return overlay


func _check_result_navigation() -> void:
	SessionState.begin_free_play(&"L04")
	var menu := _menu()
	menu._enter_arena()
	await scene_changed
	await _settle_arena(current_scene)
	var overlay := _finish_for_navigation(current_scene)
	(overlay.result_actions.get_child(0) as Button).pressed.emit()
	await scene_changed
	var arena := current_scene as MatchController
	await _settle_arena(arena)
	check(SessionState.free_play and SessionState.last_winner == 0 and arena.level_id == &"L04" and arena.phase == &"COUNTDOWN" and not arena.finished, "CHƠI LẠI restarts the selected free-play round without rites")
	overlay = _finish_for_navigation(arena)
	(overlay.result_actions.get_child(1) as Button).pressed.emit()
	await scene_changed
	menu = current_scene as Control
	await process_frame
	check(menu.solo_page != null and page_button(menu, "L05") != null and not menu.menu_layout.visible and SessionState.unlocked_level == 2, "ĐỔI TRẬN opens the five-round free-play page and preserves progress")
	page_button(menu, "L05").pressed.emit()
	await scene_changed
	await _settle_arena(current_scene)
	overlay = _finish_for_navigation(current_scene)
	(overlay.result_actions.get_child(2) as Button).pressed.emit()
	await scene_changed
	menu = current_scene as Control
	check(menu.menu_layout.visible and menu.solo_page == null and not SessionState.free_play and SessionState.unlocked_level == 2, "VỀ MENU returns to the main menu without resetting season progress")
