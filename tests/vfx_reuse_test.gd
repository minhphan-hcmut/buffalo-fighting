extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	SessionState.mode = &"SOLO"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.vfx.set_process(false)
	for frame in GameBalance.get_int("vfx_warm_up_frames") + GameBalance.get_int("vfx_warm_up_settle_frames") + 2:
		await process_frame
	var first := arena.vfx._burst(&"CurveProbe", Vector3.ZERO, Color.WHITE, "dash_ring")
	var curve := first.scale_amount_curve
	var second := arena.vfx._burst(&"CurveProbe", Vector3.ZERO, Color.WHITE, "dash_ring")
	check(curve == second.scale_amount_curve, "dash rings share the immutable growth curve")
	check(is_equal_approx(curve.sample(0.0), GameBalance.get_number("vfx_dash_ring_growth_start")) and is_equal_approx(curve.sample(1.0), GameBalance.get_number("vfx_dash_ring_growth_end")), "cached curve preserves its data values")
	var audio := root.get_node("GameAudio") as FestivalAudio
	var loaded := audio.streams.size()
	for pass_index in 2:
		for event in [&"HORN_START", &"HORN_HIT", &"DASH_START", &"DASH_HIT", &"PARRY_SUCCESS", &"GUARD_HIT", &"CLASH_HOOK"]:
			arena.combat_event.emit(event, 1, 2, 0.0)
			await process_frame
	check(audio.streams.size() == loaded, "combat performs no first-use audio resource loads")
	arena.queue_free()
	await process_frame
	for player in audio.voices:
		player.stop()
		player.stream = null
	await physics_frame
	await physics_frame
	print("VFX REUSE: ", failures, " failures")
	quit(0 if failures == 0 else 1)
