extends SceneTree

const DT := 1.0 / 60.0
const SETTINGS_PATH := "user://training_test.cfg"
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
	var original_path := SessionState.settings_path
	_check_settings()
	await _check_entry()
	for drill: Dictionary in DataFile.load_json("res://data/training.json").drills:
		await _check_drill(drill)
	await _check_navigation()
	SessionState.load_settings(original_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	SessionState.return_to_menu()
	print("TRAINING: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_settings() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	SessionState.load_settings(SETTINGS_PATH)
	check(not SessionState.training_unlimited_stamina, "training infinite stamina defaults off")
	for enabled: bool in [true, false]:
		SessionState.training_unlimited_stamina = enabled
		check(SessionState.save_settings() == OK, "training stamina toggle saves")
		SessionState.training_unlimited_stamina = not enabled
		SessionState.load_settings(SETTINGS_PATH)
		check(SessionState.training_unlimited_stamina == enabled, "training stamina toggle reloads from ConfigFile")
	for invalid in [1, 0, "true", null, [], {}]:
		var config := ConfigFile.new()
		config.set_value("settings", "training_unlimited_stamina", invalid)
		config.save(SETTINGS_PATH)
		SessionState.load_settings(SETTINGS_PATH)
		check(not SessionState.training_unlimited_stamina, "invalid training stamina setting defaults off: %s" % str(invalid))


func _menu() -> Control:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	return menu


func _check_entry() -> void:
	SessionState.return_to_menu()
	var menu := _menu()
	(menu.menu_layout.get_node("SoloButton") as Button).pressed.emit()
	var opener := menu.solo_page.find_child("TrainingButton", true, false) as Button
	check(opener != null and opener.text == "SÂN TẬP", "Solo chooser includes the third training choice")
	opener.pressed.emit()
	await process_frame
	await process_frame
	var page: Control = menu.solo_page
	var panel := page.find_children("*", "PanelContainer", true, false)[0] as Control
	check(root.get_visible_rect().encloses(panel.get_global_rect()), "five-drill page fits 1280x720: %s" % panel.get_global_rect())
	var drills: Array = DataFile.load_json("res://data/training.json").drills
	var focus: Control = page.find_child(drills[0].id, true, false)
	check(focus.has_focus(), "drill page initially focuses Bao cát")
	for drill: Dictionary in drills:
		var button := page.find_child(drill.id, true, false) as Button
		check(button != null and button.text == drill.name and button.get_node("Description").text == drill.goal, "drill row shows name and goal: %s" % drill.id)
		for move: Dictionary in MoveDemo.MOVES:
			if drill.moves.has(String(move.id)):
				check(button.get_node("Keys").get_children().any(func(cap: PanelContainer): return cap.get_child(0).text == move.keys), "drill keycaps reuse MOVES text: %s/%s" % [drill.id, move.id])
		check(focus == button, "native keyboard/gamepad focus reaches %s" % drill.id)
		focus = focus.find_next_valid_focus()
	var toggle := page.find_child("UnlimitedStamina", true, false) as CheckButton
	check(focus == toggle and not toggle.button_pressed, "Sức vô hạn follows the drills and defaults off")
	toggle.button_pressed = true
	check(SessionState.training_unlimited_stamina, "drill page toggle updates the saved setting")
	focus = focus.find_next_valid_focus()
	check(focus == page.find_child("SoloBack", true, false) and focus.find_next_valid_focus() == page.find_child("dummy", true, false), "drill page focus reaches Back and wraps")
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	(page.find_child("dummy", true, false) as Button).grab_focus()
	Input.parse_input_event(down)
	await process_frame
	check(page.find_child("dash", true, false).has_focus(), "gamepad D-pad moves focus from Bao cát to Gạt Hổ lao")
	down.pressed = false
	Input.parse_input_event(down)
	(page.find_child("SoloBack", true, false) as Button).pressed.emit()
	check(menu.solo_page.find_child("TrainingButton", true, false) != null, "drill Back returns to the Solo chooser")
	menu.free()
	SessionState.training_unlimited_stamina = false


func _start(drill: String) -> MatchController:
	SessionState.training = false
	SessionState.return_to_menu()
	SessionState.unlocked_level = 3
	SessionState.opening_ceremony_seen = true
	SessionState.rites_seen.assign([&"water", &"giap"])
	SessionState.culture_cards_seen.assign([&"buffalo"])
	var menu := _menu()
	menu._show_training()
	(menu.solo_page.find_child(drill, true, false) as Button).pressed.emit()
	await scene_changed
	var arena := current_scene as MatchController
	arena.set_physics_process(false)
	arena.vfx.set_process(false)
	for frame in GameBalance.get_int("vfx_warm_up_settle_frames") + GameBalance.get_int("vfx_warm_up_frames") + 2:
		await process_frame
	arena.start_playing()
	return arena


func _player_frame(arena: MatchController, lock_drill: bool) -> InputFrame:
	var frame := InputFrame.new(1)
	var direction := (arena.opponent.position - arena.player.position).normalized()
	frame.camera_yaw = atan2(-direction.x, -direction.z)
	if lock_drill:
		if arena.clash.is_active():
			if arena.training.id == "release":
				frame.clash_action = &"RELEASE" if arena.opponent.clash_hooked else &""
			else:
				frame.clash_action = &"HOOK"
		else:
			frame.horn_pressed = arena.player.state == Buffalo.State.NORMAL and arena.player.horn_cooldown <= 0.0
	return frame


func _check_drill(drill: Dictionary) -> void:
	var arena := await _start(drill.id)
	check(SessionState.training and not SessionState.free_play and arena.mode == &"SOLO" and arena.ai.profile == StringName(drill.ai_profile), "chooser starts %s with its drill AI profile" % drill.id)
	check(arena.mud_zones.is_empty() and arena._level_config().opponent_number == "17" and arena._level_config().opponent_giap == "GIÁP TÂY", "training has no mud and uses the default opponent")
	check(not arena.announcer_active() and arena.announcer_text().is_empty(), "training has no round intro")
	check(root.find_children("Ceremony", "", true, false).is_empty() and SessionState.take_rites_before(&"L05").is_empty(), "training starts without rites")
	check(not SessionState.advance_after_win() and SessionState.unlocked_level == 3 and SessionState.level_id == &"L01", "training cannot advance season progress")
	var totals := {"horn": 0, "dash": 0, "locks": 0, "refills": 0, "illegal": 0, "hook": 0, "push": 0, "cooldown_errors": 0}
	var last_attack := {"horn": -INF, "dash": -INF}
	arena.combat_event.connect(func(event: StringName, source: int, _target: int, _value: float):
		if source == 2 and event == &"HORN_START": totals.horn += 1
		if source == 2 and event == &"DASH_START": totals.dash += 1
		if source == 2 and event in [&"HORN_START", &"DASH_START"]:
			var kind := "horn" if event == &"HORN_START" else "dash"
			var now := arena.tick * DT
			if now - float(last_attack[kind]) + DT < GameBalance.get_number(kind + "_cooldown_s"):
				totals.cooldown_errors += 1
			last_attack[kind] = now
		if event == &"CLASH_START": totals.locks += 1
		if event == &"TRAINING_REFILL": totals.refills += 1
	)
	var dummy_start := arena.opponent.position
	var lock_drill: bool = drill.id in ["release", "hook"]
	SessionState.training_unlimited_stamina = lock_drill
	await physics_frame
	for tick in (7200 if drill.id == "horn" else 2700):
		var player := _player_frame(arena, lock_drill)
		var ai: InputFrame = arena.ai.build_input(DT) if arena.hitstop_ticks == 0 else InputFrame.new(2)
		if ai.parry_pressed or ai.guard_held or ai.guard_pressed:
			totals.illegal += 1
		if arena.hitstop_ticks == 0 and ai.clash_action != &"":
			if ai.clash_action == &"HOOK": totals.hook += 1
			elif ai.clash_action == &"PUSH": totals.push += 1
			else: totals.illegal += 1
		arena.simulate_tick(DT, player, ai)
	print("DRILL ", drill.id, " ", totals, " spirit=", arena.player.spirit, " stamina=", arena.opponent.stamina)
	check(totals.illegal == 0, "%s never guards, parries or releases" % drill.id)
	check(totals.cooldown_errors == 0, "%s respects the normal horn/dash cooldowns" % drill.id)
	if drill.id == "dummy":
		check(totals.horn == 0 and totals.dash == 0 and arena.opponent.position.distance_to(dummy_start) < 0.01, "Bao cát stands still without attacks")
		arena.player.position += Vector3.FORWARD * 3.0
		for tick in 40:
			arena.simulate_tick(DT, _player_frame(arena, false))
		check(arena.opponent.forward().dot((arena.player.position - arena.opponent.position).normalized()) > 0.99 and arena.opponent.position.distance_to(dummy_start) < 0.01, "Bao cát turns to face a moving player without walking")
	elif drill.id == "dash":
		check(totals.dash >= 5 and totals.horn == 0, "Gạt Hổ lao repeats only dashes over 45 simulated seconds")
		check(totals.refills > 0, "dash drill refills spirit after real hits")
	elif drill.id == "horn":
		check(totals.horn >= 10 and totals.dash == 0, "Gạt Húc repeats only horns over 120 simulated seconds")
		check(totals.refills > 0, "horn drill refills spirit after real hits")
	else:
		check(totals.locks >= 3 and totals.horn >= 3 and totals.dash == 0, "%s forms at least three actual locks through committed horns" % drill.id)
		check(totals.hook > 0 and totals.push == 0 if drill.id == "release" else totals.push > 0 and totals.hook == 0, "%s issues only its specified clash action" % drill.id)
		check(arena.hud.training_counts.releases > 0 if drill.id == "release" else arena.hud.training_counts.wins > 0, "%s actual combat feeds its success counter" % drill.id)
		if drill.id == "release":
			_check_hook_rhythm(arena)
	check(not arena.finished and arena.phase == &"PLAYING" and arena.opponent.stamina == GameBalance.get_number("stamina_max"), "%s stays running and AI stamina never runs out" % drill.id)
	arena.player.spirit = 0.0
	arena.opponent.spirit = GameBalance.get_number("training_spirit_refill_at")
	arena.remaining_time = 0.0
	arena._check_match_end()
	arena._finish(1, &"TIME")
	check(not arena.finished and arena.phase == &"PLAYING" and arena.player.spirit == GameBalance.get_number("spirit_max") and arena.opponent.spirit == GameBalance.get_number("spirit_max"), "training refills both buffaloes and ignores FLEE/TIME/LOT result paths")
	SessionState.training_unlimited_stamina = false
	arena.player.stamina = 50.0
	arena.player.stamina_regen_delay = 1.0
	arena.simulate_tick(DT, InputFrame.new(1), InputFrame.new(2))
	check(arena.player.stamina <= 50.0, "training player stamina remains normal with the option off")
	SessionState.training_unlimited_stamina = true
	arena.opponent.stamina = 0.0
	arena.player.stamina = 0.0
	arena.simulate_tick(DT, InputFrame.new(1), InputFrame.new(2))
	check(arena.player.stamina == GameBalance.get_number("stamina_max") and arena.opponent.stamina == GameBalance.get_number("stamina_max"), "infinite stamina replenishes player and AI even during pending hitstop")
	arena.hud._process(0.0)
	check(not arena.hud.timer_label.visible and arena.hud.training_panel.visible and not arena.hud.result_label.visible, "training replaces the clock with a read-only drill panel")
	check(not arena.hud.training_counter.text.contains(".0"), "training HUD displays integer counts")
	if lock_drill:
		await process_frame
		check(arena.hud.clash_panel.position.y >= arena.hud.training_panel.get_rect().end.y, "training drill panel leaves the lock controls unobscured")
	_check_counters(arena)
	check(SessionState.unlocked_level == 3 and SessionState.rites_seen == [&"water", &"giap"] and SessionState.opening_ceremony_seen and SessionState.culture_cards_seen == [&"buffalo"], "training never changes unlocks, rites, opening or culture-card history")
	check(not root.get_node("SoloSessionOverlay").visible, "training never shows the Solo result or culture-card overlay")
	current_scene.free()
	SessionState.return_to_menu()
	check(SessionState.unlocked_level == 3 and SessionState.rites_seen == [&"water", &"giap"], "leaving training keeps season progress")
	SessionState.training_unlimited_stamina = false


func _check_hook_rhythm(arena: MatchController) -> void:
	arena.clash.active.clear()
	for actor: Buffalo in [arena.player, arena.opponent]:
		actor.reset_combat()
	arena.clash.enter(0.0)
	arena.ai.decision_time = 0.0
	arena.hitstop_ticks = 0
	var hooks: Array[int] = []
	var record := func(event: StringName, source: int, _target: int, _value: float):
		if event == &"CLASH_HOOK" and source == 2:
			hooks.append(arena.tick)
	arena.combat_event.connect(record)
	for tick in 90:
		arena.simulate_tick(DT, _player_frame(arena, false))
	check(hooks.size() >= 2, "release drill repeats hooks inside a sustained lock")
	for index in range(1, hooks.size()):
		check(absf((hooks[index] - hooks[index - 1]) * DT - float(arena.ai.profile_data.hook_interval_s)) <= DT * 2.0, "release drill hook rhythm reads its data interval")
	arena.combat_event.disconnect(record)


func _check_counters(arena: MatchController) -> void:
	var hud: CanvasLayer = arena.hud
	for key in hud.training_counts:
		hud.training_counts[key] = 0
	arena.combat_event.emit(&"HORN_START", 2, 2, 0.0)
	arena.combat_event.emit(&"DASH_START", 2, 2, 0.0)
	arena.combat_event.emit(&"HORN_HIT", 1, 2, 18.0)
	arena.combat_event.emit(&"DASH_HIT", 1, 2, 14.0)
	arena.combat_event.emit(&"FLANK_HIT", 1, 2, 23.0)
	arena.combat_event.emit(&"BACK_HIT", 1, 2, 23.0)
	arena.combat_event.emit(&"PARRY_SUCCESS", 1, 2, 0.0)
	check(hud.training_popup.text == "GẠT ĐƯỢC!", "parry signal produces a compact success popup")
	arena.combat_event.emit(&"COUNTER_HIT", 1, 2, 23.0)
	check(hud.training_popup.text == "PHẢN ĐÒN!", "counter signal produces a success popup")
	arena.combat_event.emit(&"CLASH_START", 1, 2, 0.0)
	arena.combat_event.emit(&"CLASH_HOOK", 2, 1, 0.0)
	arena.combat_event.emit(&"RELEASE_START", 1, 2, 0.0)
	arena.combat_event.emit(&"CLASH_LOSS", 1, 2, 12.0)
	arena.combat_event.emit(&"CLASH_WHIFF", 1, 2, 0.0)
	check(hud.training_popup.text == "NHẢ ĐÚNG LÚC!", "successful release sequence produces its popup")
	var expected := {"hits": 2, "flanks": 2, "attacks": 1, "parried": 1, "counters": 1, "locks": 1, "wins": 1, "hooks": 1, "releases": 1}
	for key in hud.training_counts:
		check(hud.training_counts[key] == expected[key], "%s counter follows the matching combat events: %s" % [arena.training.id, key])
	arena.combat_event.emit(&"CLASH_START", 1, 2, 0.0)
	arena.combat_event.emit(&"RELEASE_START", 1, 2, 0.0)
	arena.combat_event.emit(&"CLASH_LOSS", 2, 1, 10.0)
	arena.combat_event.emit(&"CLASH_RELEASE", 1, 2, 0.0)
	check(hud.training_counts.get("releases", 1) == 1, "failed release does not increment good releases")
	hud._process(GameBalance.get_number("training_popup_s") + DT)
	check(hud.training_popup.text.is_empty(), "success popup clears after its configured duration")
	arena.combat_event.emit(&"TRAINING_REFILL", 1, 1, 0.0)
	check(hud.training_popup.text == "Hồi khí thế", "spirit refill shows its short HUD note")


func _check_navigation() -> void:
	var arena := await _start("dash")
	arena.request_pause_from_menu()
	var actions: VBoxContainer = arena.hud.pause_actions
	check(actions.get_children().map(func(button: Button): return button.text) == ["TIẾP TỤC", "ĐỔI BÀI TẬP", "CÀI ĐẶT", "VỀ MENU"], "training pause has exactly the requested four actions")
	(actions.get_child(1) as Button).pressed.emit()
	await scene_changed
	var menu := current_scene as Control
	check(menu.solo_page != null and menu.solo_page.find_child("dummy", true, false) != null and not menu.menu_layout.visible and SessionState.unlocked_level == 3, "Đổi bài tập returns directly to the drill page with progress intact")
	(menu.solo_page.find_child("horn", true, false) as Button).pressed.emit()
	await scene_changed
	arena = current_scene as MatchController
	arena.set_physics_process(false)
	for frame in 6:
		await process_frame
	arena.request_pause_from_menu()
	(arena.hud.pause_actions.get_child(3) as Button).pressed.emit()
	await scene_changed
	menu = current_scene as Control
	check(menu.menu_layout.visible and menu.solo_page == null and not SessionState.training and SessionState.unlocked_level == 3, "training Về menu opens the main menu and preserves the season")
