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


func key(pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_A
	event.pressed = pressed
	event.echo = echo
	return event


func click(pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


func fixture(winner: int, reason: StringName, mode: StringName = &"SOLO", level: StringName = &"L01") -> Dictionary:
	SessionState.return_to_menu()
	SessionState.begin_solo()
	SessionState.level_id = level
	SessionState.last_match_level = level
	var arena: MatchController = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	arena.hud.set_process(false)
	arena.mode = mode
	arena.start_playing()
	arena._finish(winner, reason)
	var overlay := Control.new()
	overlay.name = "SoloSessionOverlay"
	overlay.set_script(load("res://scripts/ui/main_menu.gd"))
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)
	overlay.set_process(false)
	return {"arena": arena, "overlay": overlay}


func cleanup(test: Dictionary) -> void:
	test.overlay.free()
	test.arena.free()


func run() -> void:
	root.size = Vector2i(1280, 720)
	var data := DataFile.load_json("res://data/presentation.json")
	for setting in ["result_skip_grace_s", "result_skip_hint_font_size", "result_skip_hint_fade_s"]:
		check(data.has(setting) and GameBalance.get_number(setting) > 0.0, "positive presentation tuning: " + setting)
	var grace := GameBalance.get_number("result_skip_grace_s")
	var fade := GameBalance.get_number("result_skip_hint_fade_s")
	var test := fixture(1, &"FLEE")
	var arena: MatchController = test.arena
	check(not arena.result_ready, "result initially waits for the outro")
	arena.outro.time = grace * 0.5
	arena._input(key())
	arena._input(click())
	arena.hud._process(0.0)
	check(not arena.result_ready and not arena.outro.can_skip(), "key and click inside grace do not skip")
	check(not arena.hud.tutorial_label.visible, "skip hint stays hidden inside grace")
	arena.outro.time = grace + fade * 0.5
	arena.hud._process(0.0)
	check(arena.hud.tutorial_label.visible and arena.hud.tutorial_label.get_parsed_text() == "Bấm phím bất kỳ để bỏ qua", "quiet bottom hint appears after grace")
	check(arena.hud.tutorial_label.modulate.a > 0.0 and arena.hud.tutorial_label.modulate.a < 1.0, "skip hint fades in")
	check(arena.hud.tutorial_label.get_theme_font_size("normal_font_size") == GameBalance.get_int("result_skip_hint_font_size"), "skip hint uses its configured small font")
	for event in [key(true, true), key(false), click(false), InputEventMouseMotion.new(), InputEventJoypadMotion.new(), InputEventJoypadButton.new()]:
		arena._input(event)
		check(not arena.result_ready, "echo, release or motion cannot skip: " + event.get_class())
	var winner := arena.winner_slot
	var reason := arena.end_reason
	var remaining := arena.remaining_time
	root.push_input(key())
	check(arena.result_ready and arena.outro.time < GameBalance.get_number("result_outro_s"), "new key reaches result well before the normal outro duration")
	check(arena.winner_slot == winner and arena.end_reason == reason and arena.remaining_time == remaining and arena.phase == &"RESULT", "skip leaves winner, reason, timer and match phase unchanged")
	check(SessionState.last_winner == winner and SessionState.last_reason == reason, "skip preserves the saved result")
	check(not arena.outro.loser.visible and not arena.outro.handler.visible and not arena.outro.rope.visible, "skip hides loser, handler and rope")
	arena.hud._process(0.0)
	check(not arena.hud.tutorial_label.visible, "skip hint hides once result is ready")
	test.overlay._process(0.0)
	check(test.overlay.visible and not arena.hud.visible and test.overlay.result_actions.get_child_count() == 3, "same result panel and next/retry/menu actions appear")
	check(test.overlay.find_child("CultureCard", true, false) != null and SessionState.culture_cards_seen.size() == 1, "skipped win retains the culture card")
	cleanup(test)

	test = fixture(2, &"TIME")
	arena = test.arena
	arena.outro.time = grace + fade
	root.push_input(click())
	check(arena.result_ready and arena.winner_slot == 2 and arena.end_reason == &"TIME", "mouse click also skips a loss without changing its result")
	test.overlay._process(0.0)
	check(test.overlay.visible and test.overlay.result_actions.get_child_count() == 2 and test.overlay.find_child("CultureCard", true, false) != null, "skipped loss retains retry/menu and culture card")
	cleanup(test)

	test = fixture(1, &"LOT")
	arena = test.arena
	arena.outro.time = grace
	check(arena.outro.is_revealing_lot(), "LOT reveal is still running at the grace boundary")
	var gamepad := InputEventJoypadButton.new()
	gamepad.button_index = JOY_BUTTON_A
	gamepad.pressed = true
	root.push_input(gamepad)
	check(arena.result_ready and not arena.outro.is_revealing_lot() and arena.end_reason == &"LOT", "gamepad button skips LOT reveal after grace without changing the draw")
	cleanup(test)

	test = fixture(1, &"FLEE", &"SOLO", &"L05")
	arena = test.arena
	arena.outro.time = grace
	root.push_input(click())
	test.overlay._process(0.0)
	var closing := test.overlay.find_child("Ceremony", true, false) as CeremonyView
	check(arena.result_ready and closing != null and closing.variant == &"closing" and not test.overlay.result_panel.visible, "skipping the final still opens the closing rite before its result")
	if closing != null:
		check(not closing.done, "the skip click does not also dismiss the closing rite")
		closing.elapsed = float(closing.settings.min_view_s)
		root.push_input(key())
		check(closing.done and test.overlay.result_panel.visible and SessionState.culture_cards_seen.size() == 1, "closing rite returns to the same final result and culture card")
	cleanup(test)

	test = fixture(1, &"FLEE", &"LAN")
	arena = test.arena
	arena.outro.time = grace + fade
	for event in [key(), click(), gamepad]:
		arena._input(event)
	check(not arena.result_ready and arena.outro.running and not arena.outro.can_skip(), "LAN result delivery and outro remain unchanged")
	cleanup(test)
	await _check_ceremonies()
	SessionState.return_to_menu()
	print("OUTRO SKIP TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _check_ceremonies() -> void:
	var data := DataFile.load_json(CeremonyView.DATA_PATH)
	check(String(data.skip_hint).begins_with("Bấm phím bất kỳ"), "ceremony hint already describes any-key input")
	for which in [&"opening", &"water", &"giap", &"drums", &"closing"]:
		for event in [key(), click()]:
			var view := CeremonyView.create(which)
			root.add_child(view)
			view.set_process(false)
			var count := [0]
			view.finished.connect(func(): count[0] += 1)
			view.elapsed = 0.0
			view._input(event)
			check(not view.done, "%s keeps its minimum view time for %s" % [which, event.get_class()])
			view.elapsed = float(data.min_view_s)
			for ignored in [key(true, true), key(false), click(false), InputEventMouseMotion.new()]:
				view._input(ignored)
			check(not view.done, "%s ignores echo, releases and motion" % which)
			view._input(event)
			view._input(event)
			check(view.done and count[0] == 1, "%s advances once on non-Space key/click: %s" % [which, event.get_class()])
			view.free()
			await process_frame
