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


func run() -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	var camera_rig := arena.get_node("CameraRig")
	var camera: Camera3D = camera_rig.get_node("SpringArm3D/Camera3D")
	check(is_equal_approx(camera.fov, GameBalance.get_number("camera_fov_deg")), "camera uses GDD FOV")
	check(
		is_equal_approx(camera_rig.arm.rotation.x, -GameBalance.get_angle("camera_pitch_deg")),
		"camera pitch fixed at 45 degrees"
	)
	var buffalo_model := arena.player.get_node("Visual/Model")
	check(buffalo_model != null, "latest buffalo GLB remains in gameplay scene")
	var actor := arena.player
	var input_frame := InputFrame.new(1)
	input_frame.move = Vector2(0.0, -1.0)
	var move := actor.movement_world(input_frame, Vector3.FORWARD, Vector3.RIGHT)
	check(move.is_equal_approx(Vector3.FORWARD), "forward movement follows camera yaw")
	actor.simulate_movement(1.0 / 60.0, move, 1.0)
	check(is_zero_approx(actor.velocity.y), "gameplay remains on XZ plane")
	camera_rig.yaw = 0.3
	camera_rig.follow_target()
	check(is_equal_approx(camera_rig.global_rotation.y, 0.3), "camera follows independent yaw")
	check(
		is_equal_approx(camera_rig.arm.rotation.x, -GameBalance.get_angle("camera_pitch_deg")),
		"vertical mouse does not change pitch"
	)
	SessionState.camera_shake_enabled = true
	camera_rig.trigger_shake(&"HORN_HIT")
	check(camera_rig.shake_elapsed == 0.0, "hit event starts camera feedback")
	SessionState.camera_shake_enabled = false
	camera_rig.shake_elapsed = 1.0
	camera_rig.trigger_shake(&"DASH_HIT")
	check(camera_rig.shake_elapsed == 1.0, "disabled camera shake ignores new feedback")
	var blocking: Array[String] = []
	for control in arena.hud.find_children("*", "Control", true, false):
		if control == arena.hud.pause_overlay or arena.hud.pause_overlay.is_ancestor_of(control):
			continue
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blocking.append(String(control.name))
	check(blocking.is_empty(), "in-match HUD lets clicks reach CameraRig for mouse capture %s" % [blocking])
	arena.free()
	print("TPP TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
