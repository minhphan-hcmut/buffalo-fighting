extends SceneTree

const SETTINGS_PATH := "user://comfort_settings_test.cfg"
const DT := 1.0 / 60.0
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
	SessionState.load_settings(SETTINGS_PATH)
	var arena := _arena()
	for frame in 5:
		await process_frame
	_check_focus(arena)
	_check_punch(arena)
	_check_flash(arena)
	_check_hitstop(arena)
	await _check_page(arena)
	arena.free()
	await _check_menu_page()
	SessionState.load_settings(original_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	SessionState.return_to_menu()
	print("COMFORT SETTINGS: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _values() -> Array:
	return [SessionState.camera_shake_enabled, SessionState.camera_punch_enabled, SessionState.impact_flash, SessionState.hitstop_enabled, SessionState.auto_pause_enabled]


func _check_settings() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	SessionState.load_settings(SETTINGS_PATH)
	check(_values() == [true, true, 0, true, true], "all missing comfort settings default to on / full")
	for enabled: bool in [false, true]:
		for flash in 3:
			SessionState.camera_shake_enabled = enabled
			SessionState.camera_punch_enabled = enabled
			SessionState.impact_flash = flash
			SessionState.hitstop_enabled = enabled
			SessionState.auto_pause_enabled = enabled
			check(SessionState.save_settings() == OK, "comfort settings save using the shared ConfigFile")
			SessionState.camera_shake_enabled = not enabled
			SessionState.camera_punch_enabled = not enabled
			SessionState.impact_flash = (flash + 1) % 3
			SessionState.hitstop_enabled = not enabled
			SessionState.auto_pause_enabled = not enabled
			SessionState.load_settings(SETTINGS_PATH)
			check(_values() == [enabled, enabled, flash, enabled, enabled], "all comfort settings round-trip (%s / flash %d)" % [enabled, flash])
	for invalid in [0, 1, 1.0, -1, 3, "false", null, [], {}]:
		var config := ConfigFile.new()
		for key in ["camera_shake", "camera_punch", "hitstop", "auto_pause"]:
			config.set_value("settings", key, invalid)
		config.set_value("settings", "impact_flash", invalid)
		config.save(SETTINGS_PATH)
		SessionState.load_settings(SETTINGS_PATH)
		check(_values().slice(0, 2) == [true, true] and SessionState.hitstop_enabled and SessionState.auto_pause_enabled, "invalid boolean values fall back to on: %s" % str(invalid))
		check(SessionState.impact_flash == (invalid if invalid is int and invalid in [0, 1, 2] else 0), "flash accepts only integer choices: %s" % str(invalid))
	for invalid: bool in [false, true]:
		var config := ConfigFile.new()
		config.set_value("settings", "impact_flash", invalid)
		config.save(SETTINGS_PATH)
		SessionState.load_settings(SETTINGS_PATH)
		check(SessionState.impact_flash == 0, "boolean flash value falls back to full")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _arena() -> MatchController:
	SessionState.return_to_menu()
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.get_node("CameraRig").set_process(false)
	arena.vfx.set_process(false)
	return arena


func _escape() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	return key


func _check_focus(arena: MatchController) -> void:
	for notice in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		for phase: StringName in [&"COUNTDOWN", &"PLAYING"]:
			arena.phase = phase
			arena._notification(notice)
			check(arena.paused and arena.hud.pause_overlay.visible and arena.hud.pause_title.text == "TẠM DỪNG", "focus-out opens the normal Solo pause menu in %s (%d)" % [phase, notice])
			arena.hud.show_settings()
			arena._notification(notice)
			check(arena.paused and arena.hud.showing_settings, "duplicate focus-out does not replace settings while paused")
			arena._input(_escape())
			check(arena.paused and not arena.hud.showing_settings, "Esc from settings returns to the existing pause menu")
			arena._input(_escape())
			check(not arena.paused and not arena.hud.pause_overlay.visible, "Esc resumes an automatically paused Solo match")
		for phase: StringName in [&"READY", &"RESULT"]:
			arena.phase = phase
			arena._notification(notice)
			check(not arena.paused and not arena.hud.pause_overlay.visible, "focus-out does nothing in %s" % phase)
		arena.phase = &"PLAYING"
		arena.finished = true
		arena._notification(notice)
		check(not arena.paused, "finished match cannot auto-pause")
		arena.finished = false
		SessionState.auto_pause_enabled = false
		arena._notification(notice)
		check(not arena.paused and not arena.hud.pause_overlay.visible, "disabled setting prevents auto-pause")
		SessionState.auto_pause_enabled = true
		arena.mode = &"LAN"
		arena._notification(notice)
		check(not arena.paused and not arena.hud.pause_overlay.visible, "LAN focus-out never pauses or requests a peer pause")
		arena.mode = &"SOLO"


func _check_punch(arena: MatchController) -> void:
	var rig := arena.get_node("CameraRig")
	arena.player.position = Vector3.ZERO
	SessionState.camera_shake_enabled = false
	SessionState.camera_punch_enabled = true
	rig.trigger_shake(&"HORN_HIT")
	rig._process(0.0)
	rig.follow_target()
	var kicked_fov: float = rig.camera.fov
	check(rig.punch_weight() > 0.0 and rig.arm.spring_length < rig.distance, "punch stays independent of the shake toggle")
	SessionState.camera_punch_enabled = false
	for event: StringName in [&"HORN_HIT", &"DASH_HIT", &"COUNTER_HIT"]:
		rig.trigger_shake(event)
		rig._process(0.0)
		rig.follow_target()
		check(rig.punch_weight() == 0.0 and rig.camera.fov > kicked_fov and is_equal_approx(rig.arm.spring_length, rig.distance), "disabled punch has no FOV or push kick: %s" % event)
	SessionState.camera_shake_enabled = true
	rig.shake_elapsed = 1.0
	rig.trigger_shake(&"HORN_HIT")
	check(rig.shake_elapsed == 0.0 and rig.punch_weight() == 0.0, "shake still works while punch is off")
	SessionState.camera_punch_enabled = true


func _check_flash(arena: MatchController) -> void:
	for mode in 3:
		SessionState.impact_flash = mode
		var scale: float = [1.0, GameBalance.get_number("comfort_flash_soft_scale"), 0.0][mode]
		var flash := arena.vfx._burst(&"ComfortFlash", Vector3.ZERO, Color.WHITE, "flash")
		var light := arena.vfx._flash_light(Vector3.ZERO, Color.WHITE, 1.0)
		check(is_equal_approx(flash.color_ramp.get_color(0).a, GameBalance.get_number("vfx_flash_alpha") * scale), "flash choice %d scales sprite alpha" % mode)
		check(light != null and is_equal_approx(light.light_energy, GameBalance.get_number("vfx_light_energy") * scale) and is_equal_approx(float(light.get_meta("peak")), light.light_energy), "flash choice %d scales light energy and its fade peak" % mode)
		flash.free()
		light.free()
	SessionState.impact_flash = 0


func _damage_run(arena: MatchController, hitstop: bool) -> Array:
	SessionState.hitstop_enabled = hitstop
	arena.phase = &"PLAYING"
	arena.finished = false
	arena.remaining_time = 90.0
	arena.hitstop_ticks = 0
	var frozen := 0
	var damage: Array = []
	for hit in 6:
		for actor: Buffalo in [arena.player, arena.opponent]:
			var spirit := actor.spirit
			actor.reset_combat()
			if hit > 0:
				actor.spirit = spirit
			actor.position = Vector3.ZERO if actor == arena.player else Vector3(0.0, 0.0, -2.9)
			actor.facing = Vector3.FORWARD if actor == arena.player else Vector3.BACK
			actor.rotation.y = 0.0 if actor == arena.player else PI
		arena.player.start_horn()
		arena.player.advance_state(arena.player.state_duration)
		arena.combat.resolve_attacks()
		damage.append(arena.opponent.spirit)
		var before := arena.remaining_time
		for tick in GameBalance.get_int("hitstop_hit_ticks"):
			var first := InputFrame.new(1)
			var second := InputFrame.new(2)
			first.camera_yaw = 0.0
			second.camera_yaw = PI
			arena.simulate_tick(DT, first, second)
			if is_equal_approx(before, arena.remaining_time):
				frozen += 1
			before = arena.remaining_time
	arena._check_match_end()
	return [damage, arena.winner_slot, arena.end_reason, frozen]


func _check_hitstop(arena: MatchController) -> void:
	SessionState.begin_free_play(&"L01")
	var enabled := _damage_run(arena, true)
	var disabled := _damage_run(arena, false)
	check(enabled[0] == disabled[0] and enabled[0][0] < GameBalance.get_number("spirit_max"), "hitstop on/off produces identical damage from actual resolved horns")
	check(enabled.slice(1, 3) == disabled.slice(1, 3) and disabled[1] == 1 and disabled[2] == &"FLEE", "hitstop on/off retains the winner and FLEE result")
	check(enabled[3] > 0 and disabled[3] == 0, "Solo hitstop off removes every frozen tick")
	arena.finished = false
	arena.phase = &"PLAYING"
	arena.hitstop_ticks = 4
	var before := arena.remaining_time
	arena.simulate_tick(DT, InputFrame.new(1), InputFrame.new(2))
	check(arena.hitstop_ticks == 0 and arena.remaining_time < before, "turning hitstop off live clears a pending freeze")
	for event: StringName in [&"HORN_HIT", &"DASH_HIT", &"PARRY_SUCCESS", &"COUNTER_HIT", &"CLASH_START"]:
		arena.hitstop_ticks = 0
		arena._on_combat_event(event, 1, 2, 0.0)
		check(arena.hitstop_ticks == 0, "Solo hitstop off suppresses normal and heavy event freezes: %s" % event)
	arena.mode = &"LAN"
	for event: StringName in [&"HORN_HIT", &"DASH_HIT", &"PARRY_SUCCESS", &"COUNTER_HIT", &"CLASH_START"]:
		arena.hitstop_ticks = 0
		arena._on_combat_event(event, 1, 2, 0.0)
		check(arena.hitstop_ticks == GameBalance.get_int("hitstop_hit_ticks" if event in [&"HORN_HIT", &"DASH_HIT"] else "hitstop_heavy_ticks"), "LAN retains hitstop despite the Solo comfort preference: %s" % event)
	var lan_ticks := arena.hitstop_ticks
	before = arena.remaining_time
	arena.simulate_tick(DT, InputFrame.new(1), InputFrame.new(2))
	check(arena.hitstop_ticks == lan_ticks - 1 and arena.remaining_time == before, "LAN still simulates frozen ticks with hitstop disabled in preferences")
	arena.mode = &"SOLO"
	SessionState.hitstop_enabled = true


func _check_page(arena: MatchController) -> void:
	arena.finished = false
	arena.phase = &"PLAYING"
	arena.request_pause_from_menu()
	arena.hud.show_settings()
	var actions: VBoxContainer = arena.hud.pause_actions
	var opener := actions.find_child("ComfortButton", true, false) as Button
	check(actions.find_child("CameraShake", true, false) == null, "main settings no longer contain Rung camera")
	opener.pressed.emit()
	var page := actions.get_node("ComfortPage") as Control
	await process_frame
	await process_frame
	var panel := page.find_children("*", "PanelContainer", true, false)[0] as Control
	check(page.top_level and root.get_visible_rect().encloses(panel.get_global_rect()) and panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) < 1.0, "Hiệu ứng is a centred top-level panel fitting 1280x720")
	var controls: Array[Control] = []
	for name in ["CameraShake", "CameraPunch", "ImpactFlash", "Hitstop", "AutoPause", "Rumble", "Replay", "HudTextSize", "ComfortDone"]:
		controls.append(page.find_child(name, true, false) as Control)
	var focus: Control = controls[0]
	for index in controls.size():
		check(focus == controls[index], "Hiệu ứng keyboard/gamepad focus follows row order %d" % index)
		focus = focus.find_next_valid_focus()
	check(focus == controls[0], "Hiệu ứng traps focus inside all its controls")
	var notes := page.find_children("*", "Label", true, false).map(func(label: Label): return label.text)
	check(notes.has("Chỉ áp dụng khi đấu Solo"), "hitstop row explains its Solo-only scope")
	(controls[1] as CheckButton).button_pressed = false
	(controls[2] as OptionButton).select(1)
	(controls[2] as OptionButton).item_selected.emit(1)
	(controls[3] as CheckButton).button_pressed = false
	(controls[4] as CheckButton).button_pressed = false
	check(arena.paused and not SessionState.camera_punch_enabled and SessionState.impact_flash == 1 and not SessionState.hitstop_enabled and not SessionState.auto_pause_enabled, "pause comfort controls apply live to SessionState")
	arena._input(_escape())
	check(actions.get_node_or_null("ComfortPage") == null and opener.has_focus() and arena.hud.showing_settings and arena.paused, "Esc closes only Hiệu ứng and returns focus to its opener")
	opener.pressed.emit()
	var done := actions.find_child("ComfortDone", true, false) as Button
	done.pressed.emit()
	check(opener.has_focus() and opener.focus_mode == Control.FOCUS_ALL, "XONG restores the opener's focus and navigation")
	arena.resume_from_menu()
	SessionState.camera_punch_enabled = true
	SessionState.hitstop_enabled = true
	SessionState.auto_pause_enabled = true
	SessionState.impact_flash = 0


func _check_menu_page() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	menu._show_settings()
	var opener := menu.menu_settings_actions.find_child("ComfortButton", true, false) as Button
	opener.pressed.emit()
	menu._unhandled_input(_escape())
	check(menu.menu_settings_actions.get_node_or_null("ComfortPage") == null and menu.menu_settings_layer.visible and opener.has_focus(), "menu Esc closes Hiệu ứng while retaining Cài đặt")
	menu.free()
