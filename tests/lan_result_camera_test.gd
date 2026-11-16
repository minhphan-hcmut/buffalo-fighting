extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	root.size = Vector2i(1280, 720)
	var manager := root.get_node("NetworkManager")
	SessionState.mode = &"LAN"
	SessionState.level_id = &"LAN01"
	for host_side in [true, false]:
		manager.is_host = host_side
		var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
		root.add_child(arena)
		arena.set_physics_process(false)
		arena.start_playing()
		if host_side:
			arena.opponent.spirit = 0.0
			arena._check_match_end()
		else:
			var snapshot := arena.get_snapshot()
			snapshot.phase = &"RESULT"
			snapshot.winner_slot = 2
			snapshot.end_reason = &"TIME"
			arena.lan._on_snapshot_received(snapshot)
		arena.outro.time = GameBalance.get_number("result_outro_s")
		arena._physics_process(0.0)
		arena.hud._process(0.0)
		await process_frame
		check(arena.get_node("CameraRig").winner_time >= 0.0, "host/client result activates winner camera")
		check(arena.get_node("CameraRig")._winner.slot == arena.winner_slot if arena.get_node("CameraRig")._winner != null else false, "winner camera frames the correct slot")
		check(arena.hud.pause_panel.position.x < root.size.x * 0.25, "LAN result column sits to the left of the winner")
		arena.queue_free()
		await process_frame
	manager.leave()
	for frame in 2:
		await physics_frame
	print("LAN RESULT CAMERA: ", failures, " failures")
	quit(0 if failures == 0 else 1)
