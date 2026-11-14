extends SceneTree
## Release handlers (GDD 2.6, 4.6): beside the buffaloes when the countdown starts, out through
## their gates before the signal, never in the arena during PLAYING. Presentation only.

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
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	await process_frame
	var crew := arena.get_node("ReleaseHandlers") as ReleaseHandlers
	var total := GameBalance.get_number("countdown_s", 3.0)
	arena.countdown_time = total
	crew._update()
	check(crew.handlers.size() == 2, "one handler per buffalo")
	var red := crew.handlers[0]
	check(red.visible and red.position.distance_to(arena.player.global_position) < 2.5, "red handler starts beside the red buffalo")
	arena.countdown_time = total * 0.5
	crew._update()
	check(absf(red.position.x) > absf(arena.player.global_position.x), "red handler walks out toward its own gate")
	arena.countdown_time = GameBalance.get_number("release_handler_wait_s", 0.4) * 0.5
	crew._update()
	check(not red.visible and not crew.handlers[1].visible, "both handlers have left before the signal")
	check(absf(red.position.x) > GameBalance.get_number("arena_rx"), "handler leaves outside the fence")
	arena.start_playing()
	crew._update()
	check(not red.visible, "no handler in the arena while PLAYING")
	check(is_equal_approx(arena.player.spirit, GameBalance.get_number("spirit_max", 100.0)), "handlers do not touch match state")
	print("RELEASE HANDLERS TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
