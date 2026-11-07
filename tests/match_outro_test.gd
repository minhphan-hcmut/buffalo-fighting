extends SceneTree
## RESULT outro (GDD 2.5 SHOULD): the loser leaves through its gate, the winner stays, the camera
## rises, a LOT draw is shown before anyone moves, and the result screen waits for the outro.

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
	await _flee_outro()
	await _lot_outro()
	_detour_path()
	print("MATCH OUTRO FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _start_arena() -> MatchController:
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await physics_frame
	arena.start_playing()
	return arena


func _flee_outro() -> void:
	# Arrange: the loser (slot 2) stands right of center, so its gate is the East one (+X).
	var arena := await _start_arena()
	arena.player.global_position = Vector3(-4.0, 0.0, 3.0)
	arena.opponent.global_position = Vector3(3.0, 0.0, -2.0)
	var winner_start := arena.player.global_position
	# Act
	arena.opponent.spirit = 0.0
	await physics_frame
	await physics_frame
	# Assert
	check(arena.phase == &"RESULT" and arena.winner_slot == 1 and arena.end_reason == &"FLEE", "FLEE ends the match for slot 1")
	check(arena.opponent.state == Buffalo.State.FLEE, "loser enters FLEE")
	check(not arena.result_ready, "result screen waits while the outro plays")
	check(arena.get_node("CameraRig").overview_time >= 0.0, "camera starts the overview")
	var closest := INF
	var seconds := GameBalance.get_number("result_outro_s") + 0.5
	for frame in int(seconds * Engine.physics_ticks_per_second):
		await physics_frame
		closest = minf(closest, arena.player.global_position.distance_to(arena.opponent.global_position))
	var rx := GameBalance.get_number("arena_rx")
	var exit := arena.opponent.global_position
	check(exit.x > rx and absf(exit.z) < GameBalance.get_number("gate_width") * 0.5, "loser is out through the East gate (%.2f, %.2f)" % [exit.x, exit.z])
	check(arena.player.global_position.distance_to(winner_start) < 0.01, "winner stays in place")
	check(closest > GameBalance.get_number("body_radius") * 2.0, "loser never walks through the winner (closest %.2f m)" % closest)
	check(arena.result_ready, "result screen is ready after the outro")
	arena.free()


func _lot_outro() -> void:
	# Arrange
	var arena := await _start_arena()
	arena.player.spirit = 0.0
	arena.opponent.spirit = 0.0
	# Act
	await physics_frame
	await physics_frame
	var positions := [arena.player.global_position, arena.opponent.global_position]
	# Assert
	check(arena.end_reason == &"LOT", "both at 0 SPIRIT ends by LOT")
	check(arena.outro.is_revealing_lot(), "LOT draw is shown first")
	# process_frame fires before nodes run _process: wait two so the HUD has updated.
	await process_frame
	await process_frame
	check(arena.hud.center_label.text.begins_with("BỐC THĂM"), "HUD shows the draw (got '%s')" % arena.hud.center_label.text)
	for frame in int(GameBalance.get_number("result_lot_reveal_s") * 0.5 * Engine.physics_ticks_per_second):
		await physics_frame
	check(arena.player.global_position == positions[0] and arena.opponent.global_position == positions[1], "nobody moves during the draw")
	arena.free()


func _detour_path() -> void:
	# Arrange: the winner stands on the straight line from the loser to the West gate.
	var from := Vector3(-2.0, 0.0, 0.0)
	var obstacle := Vector3(-7.0, 0.0, 0.0)
	# Act
	var path := MatchOutro.exit_path(from, obstacle, 1)
	# Assert
	var clearance := GameBalance.get_number("body_radius") * 2.0 + 1.0
	check(path.size() == 3, "path detours around the winner")
	check(path[0].distance_to(obstacle) >= clearance - 0.01, "detour keeps %.1f m from the winner" % clearance)
	check(path[-1].x < -GameBalance.get_number("arena_rx"), "path ends outside the West gate")
