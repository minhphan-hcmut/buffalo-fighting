extends SceneTree

class AudioSpy extends FestivalAudio:
	var cues: Array[String] = []

	func play_sfx(cue: String) -> AudioStreamPlayer:
		cues.append(cue)
		return super.play_sfx(cue)

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
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L02"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	var audio: Node
	for child in arena.get_children():
		if child.get_script() == load("res://scripts/core/match_audio.gd"):
			audio = child
	audio.set_process(false)
	var spy := AudioSpy.new()
	root.add_child(spy)
	audio.GameAudio = spy
	var hud = arena.hud
	hud.set_process(false)
	hud._process(0.0)
	check(hud.announcer_label.visible, "subtitle is visible during Solo countdown")
	check(hud.announcer_label.text.begins_with("Bán kết — sân lầy"), "round title comes from the current level")
	check(hud.announcer_label.text.contains("06 cờ đỏ Giáp Đông") and hud.announcer_label.text.contains("17 cờ xanh Giáp Tây"), "subtitle uses the buffalo identifiers")
	ArenaBuilder.add_identifier(arena.player, Color.BLUE, "23", "GIÁP NAM")
	check(arena.announcer_text().contains("23 cờ xanh Giáp Nam"), "announcement follows changed identity without duplicate constants")
	audio._process(0.0)
	check(spy.cues.count("announcer_intro_vi") == 1, "announcer cue plays once at its configured time")
	check(audio.intro_voice != null and audio.intro_voice.bus == &"SFX", "announcer uses the existing SFX bus")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	arena._input(escape)
	var before := arena.countdown_time
	arena._physics_process(0.5)
	audio._process(0.5)
	check(arena.paused and hud.pause_overlay.visible and arena.countdown_time == before, "Esc pauses countdown and opens the existing pause panel")
	check(audio.intro_voice.stream_paused, "announcer pauses with the countdown")
	check(spy.play_sfx("ui_confirm") != audio.intro_voice, "pause menu sounds do not reuse the paused announcer voice")
	arena._input(escape)
	audio._process(0.0)
	check(not arena.paused and not audio.intro_voice.stream_paused, "Esc resumes countdown and announcer")
	for i in 4:
		audio._process(0.1)
	check(spy.cues.count("announcer_intro_vi") == 1, "pause and repeated frames do not repeat the announcer")
	var duration: float = GameBalance.values["announcer_intro_duration_s"]
	GameBalance.values["announcer_intro_delay_s"] = 0.5
	GameBalance.values["announcer_intro_duration_s"] = 1.0
	arena.countdown_time = 3.0
	hud._process(0.0)
	check(not hud.announcer_label.visible, "subtitle respects configured delay")
	arena.countdown_time = 2.0
	hud._process(0.0)
	check(hud.announcer_label.visible, "subtitle appears inside configured window")
	arena.countdown_time = 1.0
	hud._process(0.0)
	check(not hud.announcer_label.visible, "subtitle respects configured duration")
	GameBalance.values["announcer_intro_delay_s"] = 0.0
	GameBalance.values["announcer_intro_duration_s"] = duration
	arena.start_playing()
	hud._process(0.0)
	audio._process(0.0)
	check(not hud.announcer_label.visible and audio.intro_voice == null, "PLAYING hides subtitle and releases announcer voice")
	check(spy.cues.count("match_start_drums") == 1, "start drums still play once")
	# Start far from the gate, facing away: the old four-second delay is too short.
	arena.player.position = Vector3(0.0, 0.0, -7.0)
	arena.opponent.position = Vector3(0.0, 0.0, 9.0)
	arena.opponent.rotation.y = 0.0
	arena._finish(1, &"FLEE")
	audio._process(0.0)
	var handler := arena.outro.handler
	check(handler != null and handler.visible and handler.find_child("Hat", true, false) != null, "outro spawns a low-poly handler with a conical hat")
	check(absf(handler.position.x) > GameBalance.get_number("arena_rx") and absf(handler.position.z) > GameBalance.get_number("gate_width") * 0.5, "handler waits outside the arena and beside the exit path")
	check(handler.find_children("*", "CollisionObject3D").is_empty() and handler.find_children("*", "CollisionShape3D").is_empty(), "handler has no collision or AI")
	check(arena.outro.lead == MatchOutro.Lead.APPROACH and (handler.find_child("Human_Mesh", true, false) as MeshInstance3D).material_override == LowPoly._villager_material(ReleaseHandlers.SHIRTS[arena.opponent.slot - 1]), "the loser's own handler comes to fetch it")
	var waiting_at := arena.opponent.global_position
	var handler_start := handler.global_position
	var approach_frames := 0
	while arena.outro.lead == MatchOutro.Lead.APPROACH and approach_frames < 900:
		arena.outro.process(1.0 / 60.0)
		approach_frames += 1
	check(arena.outro.lead == MatchOutro.Lead.LEAD, "handler reaches the loser (%.1f s)" % (approach_frames / 60.0))
	check(arena.opponent.global_position.is_equal_approx(waiting_at), "loser waits in place until its handler arrives")
	check(handler.global_position.distance_to(handler_start) > 5.0 and handler.global_position.distance_to(arena.outro.lead_spot()) < 0.3, "handler walked in to the loser's head")
	check(arena.outro.rope != null and arena.outro.rope.visible, "the rope appears once the handler holds the loser")
	for frame in 60:
		arena.outro.process(1.0 / 60.0)
	var nose := arena.opponent.visual.global_transform * Vector3(0.0, GameBalance.get_number("result_rope_nose_y"), -GameBalance.get_number("result_rope_nose_ahead"))
	var rope_end := arena.outro.rope.get_child(arena.outro.rope.get_child_count() - 1) as Node3D
	check(rope_end.global_position.distance_to(nose) < 0.5, "rope runs to the loser's nose")
	check(arena.opponent.global_position.distance_to(waiting_at) > 1.0 and handler.global_position.distance_to(arena.outro.lead_spot()) < 1.0, "handler leads the walking loser and stays at its head")
	check(not arena.outro.waypoints.is_empty() and not arena.result_ready, "Solo result waits while the loser is led out")
	for frame in 1200:
		arena.outro.process(1.0 / 60.0)
		if arena.result_ready:
			break
	check(arena.result_ready and arena.outro.waypoints.is_empty() and not arena.opponent.visible, "Solo result becomes ready after the loser reaches the gate and disappears")
	check(arena.outro.time < GameBalance.get_number("result_outro_max_s"), "normal exit completes before the timeout")
	for i in 4:
		audio._process(0.1)
	check(spy.cues.count("festival_gong") == 1 and spy.cues.count("crowd_cheer") == 1, "result gong and cheer play once when the result is determined")
	# A stalled path still has a bounded end, including the LOT reveal time.
	arena.outro.running = false
	arena.end_reason = &"LOT"
	arena.opponent.show()
	arena.outro.handler.free()
	arena.outro.start()
	var maximum := GameBalance.get_number("result_outro_max_s")
	arena.outro.time = arena.outro.reveal_duration() + maximum - 0.01
	check(not arena.result_ready, "stalled LOT outro waits until its configured maximum after the draw")
	arena.outro.process(0.02)
	check(arena.result_ready and not arena.opponent.visible, "timeout releases the result and hides the stalled loser")
	arena.mode = &"LAN"
	arena.outro.time = arena.outro.reveal_duration() + GameBalance.get_number("result_outro_s")
	check(arena.result_ready and not arena.announcer_active(), "LAN retains its previous result timing without the Solo subtitle")
	arena.free()
	spy.free()
	print("SOLO ANNOUNCER OUTRO: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
