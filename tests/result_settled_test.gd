extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	SessionState.begin_free_play(&"L01")
	SessionState.replay_enabled = false
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.start_playing()
	arena.hitstop_ticks = GameBalance.get_int("hitstop_hit_ticks")
	arena._finish(1, &"FLEE")
	arena._physics_process(1.0 / Engine.physics_ticks_per_second)
	check(arena.hitstop_ticks == 0, "final hitstop cannot freeze the outro animator")
	for actor in [arena.player, arena.opponent]:
		actor.visual.speed = GameBalance.get_number("walk_speed")
		actor.visual.local_velocity = Vector3.RIGHT * GameBalance.get_number("walk_speed")
	arena.outro.time = GameBalance.get_number("result_outro_max_s")
	arena.outro.process(0.0)
	check(arena.result_ready and not arena.opponent.visible, "bounded outro settles before exposing the result")
	for actor in [arena.player, arena.opponent]:
		check(is_zero_approx(actor.visual.speed) and actor.visual.local_velocity == Vector3.ZERO, "both actors lose residual walking motion")
	var time := arena.outro.time
	arena.outro.process(0.0)
	check(arena.outro.time == time and arena.winner_slot == 1 and arena.end_reason == &"FLEE", "settling adds no outro time and preserves the result")
	# A fresh skip must flush the same presentation cache, without waiting another frame.
	arena.outro.running = false
	arena.opponent.show()
	arena.outro.start()
	arena.player.visual.speed = GameBalance.get_number("walk_speed")
	arena.outro.time = GameBalance.get_number("result_skip_grace_s")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	check(arena.outro.skip(key) and is_zero_approx(arena.player.visual.speed), "skip also settles before revealing its result")
	arena.queue_free()
	await process_frame
	await physics_frame
	await physics_frame
	print("RESULT SETTLED: ", failures, " failures")
	quit(0 if failures == 0 else 1)
