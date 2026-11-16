extends SceneTree

const DT := 1.0 / 60.0
const SETTINGS := "user://replay_test.cfg"
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func fixture() -> MatchController:
	SessionState.return_to_menu()
	SessionState.begin_solo()
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.replay.set_physics_process(false)
	arena.replay.set_process(false)
	arena.hud.set_process(false)
	arena.start_playing()
	for actor: Buffalo in [arena.player, arena.opponent]:
		actor.visual.set_process(false)
		actor.visual.set_physics_process(false)
	return arena


func record(arena: MatchController, seconds: float) -> void:
	for index in roundi(seconds / DT):
		arena.player.position = Vector3(-3.0 + index * DT, 0.0, 0.0)
		arena.opponent.position = Vector3(3.0 - index * DT, 0.0, 0.0)
		for actor: Buffalo in [arena.player, arena.opponent]:
			actor.state = Buffalo.State.HORN_ACTIVE if index % 30 < 10 else Buffalo.State.NORMAL
			actor.state_time = DT * (index % 10)
			actor.state_duration = 0.2
			(actor.visual as BuffaloAnimator).sample_motion(DT)
			(actor.visual as BuffaloAnimator).update_pose(DT)
		arena.replay._physics_process(DT)


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.theme = load("res://assets/ui/festival_theme.tres")
	var saved_path := SessionState.settings_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	SessionState.load_settings(SETTINGS)
	check(SessionState.replay_enabled, "replay defaults to on")
	SessionState.replay_enabled = false
	SessionState.save_settings()
	SessionState.replay_enabled = true
	SessionState.load_settings(SETTINGS)
	check(not SessionState.replay_enabled, "replay setting persists")
	var invalid := ConfigFile.new()
	invalid.set_value("settings", "replay", "false")
	invalid.save(SETTINGS)
	SessionState.load_settings(SETTINGS)
	check(SessionState.replay_enabled, "wrong setting type falls back to on")
	SessionState.auto_pause_enabled = false

	var arena := fixture()
	record(arena, 6.0)
	var history := arena.replay.history()
	check(history.size() <= ceili(GameBalance.get_number("replay_seconds") / DT) + 1, "ring capacity is bounded by the clip length")
	check(history[0].time >= 6.0 - GameBalance.get_number("replay_seconds") - DT and history[-1].time - history[0].time <= GameBalance.get_number("replay_seconds") + DT, "ring retains only the last N seconds")
	check(history[-1].actors[0].transform == arena.player.global_transform, "recording includes both actual transforms")
	check(history[-1].actors[1].state == arena.opponent.state and history[-1].actors[1].state_time == arena.opponent.state_time, "recording includes animator action inputs")
	arena.combat_event.emit(&"HORN_HIT", 1, 2, 1.0)
	var counts: Dictionary = arena.hud.stats.counts.duplicate()
	arena._finish(1, &"FLEE")
	var frozen := arena.get_snapshot()
	check(arena.replay.active and not arena.outro.running and not arena.result_ready, "Solo FLEE plays replay before the outro and result")
	check(arena.replay.camera.current and arena.replay.tag.get_child(0).text == "XEM LẠI", "replay uses a side camera and a small label")
	check(arena.replay.actors[0] != arena.player and arena.replay.actors[0].collision_layer == 0, "playback uses separate non-colliding actors")
	arena.replay._process(0.5)
	check(is_equal_approx(arena.replay.cursor - arena.replay.clip[0].time, 0.5 * GameBalance.get_number("replay_speed")), "playback clock runs at configured slow speed without global time scale")
	check(arena.get_snapshot() == frozen and arena.hud.stats.counts == counts and Engine.time_scale == 1.0, "playback cannot change simulation, stats or global time scale")
	var clone := arena.replay.actors[0]
	check(clone.state in [Buffalo.State.NORMAL, Buffalo.State.HORN_ACTIVE] and clone.visual.controller != arena, "animator receives recorded state through a separate animation context")
	var release := InputEventKey.new()
	release.keycode = KEY_A
	check(not arena.replay.skip(release), "release does not skip")
	release.pressed = true
	release.echo = true
	check(not arena.replay.skip(release), "held key echo does not skip")
	var motion := InputEventJoypadMotion.new()
	motion.axis_value = 1.0
	check(not arena.replay.skip(motion), "stick movement does not skip")
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	arena.replay.elapsed = GameBalance.get_number("result_skip_grace_s")
	arena._input(key)
	check(not arena.replay.active and arena.outro.running and arena.player.visible and arena.opponent.visible, "fresh key skips replay, restores live presentation and starts the existing outro")
	check(arena.replay.actors.is_empty() and arena.replay.context == null, "skipping releases replay actors and context")
	check(arena.hud.stats.counts == counts, "skipping replay leaves all stat counts intact")
	arena.free()

	var outcomes: Array[Dictionary] = []
	for enabled: bool in [false, true]:
		SessionState.replay_enabled = enabled
		arena = fixture()
		record(arena, 3.0)
		arena.combat_event.emit(&"DASH_HIT", 1, 2, 1.0)
		arena._finish(1, &"FLEE")
		check(arena.replay.active == enabled, "off produces no replay; on plays FLEE")
		if enabled:
			arena.replay._process(GameBalance.get_number("replay_seconds") / GameBalance.get_number("replay_speed") + 1.0)
			check(not arena.replay.active and arena.outro.running, "completed replay automatically hands over to outro")
		outcomes.append({"snapshot": arena.get_snapshot(), "stats": arena.hud.stats.counts.duplicate(),
			"level": SessionState.level_id, "unlocked": SessionState.unlocked_level,
			"winner": SessionState.last_winner, "reason": SessionState.last_reason})
		arena.free()
	check(outcomes[0] == outcomes[1], "result, snapshot, stats and season progress are identical with replay on and off")

	for reason: StringName in [&"TIME", &"LOT"]:
		arena = fixture()
		record(arena, 3.0)
		arena._finish(1, reason)
		check(not arena.replay.active and arena.outro.running, "%s goes straight to outro" % reason)
		arena.free()
	for excluded: String in ["LAN", "training"]:
		arena = fixture()
		if excluded == "LAN":
			arena.mode = &"LAN"
		else:
			arena.training = {"id": "dummy"}
		record(arena, 3.0)
		check(arena.replay.history().is_empty(), excluded + " does not record")
		arena.finished = true
		arena.end_reason = &"FLEE"
		check(not arena.replay.start(), excluded + " cannot start playback")
		arena.free()

	for input: InputEvent in [InputEventMouseButton.new(), InputEventJoypadButton.new()]:
		arena = fixture()
		SessionState.begin_free_play(&"L03")
		record(arena, 3.0)
		arena._finish(2, &"FLEE")
		check(arena.replay.active, "free play FLEE supports replay for either winner")
		input.pressed = true
		arena.replay.elapsed = GameBalance.get_number("result_skip_grace_s")
		check(arena.replay.skip(input), "mouse and gamepad button can skip")
		arena.free()

	arena = fixture()
	var opener := Button.new()
	arena.hud.pause_actions.add_child(opener)
	var comfort := SettingsControls.open_comfort(arena.hud.pause_actions, opener)
	var toggle := comfort.find_child("Replay", true, false) as CheckButton
	check(toggle != null and toggle.button_pressed, "Hiệu ứng exposes the default-on replay setting")
	toggle.button_pressed = false
	check(not SessionState.replay_enabled, "Hiệu ứng toggles replay immediately")
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses((comfort.find_children("*", "PanelContainer", true, false)[0] as Control).get_global_rect()), "expanded Hiệu ứng page fits 1280x720")
	for frame in GameBalance.get_int("vfx_warm_up_settle_frames") + GameBalance.get_int("vfx_warm_up_frames") + 2:
		await process_frame
	arena.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	SessionState.load_settings(saved_path)
	SessionState.return_to_menu()
	await process_frame
	print("REPLAY TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
