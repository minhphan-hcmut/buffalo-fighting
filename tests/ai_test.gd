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
	var controller: Node = arena.ai
	check(controller != null, "solo match creates AI controller")
	check(controller.profile == &"EASY", "L01 selects EASY profile")
	var frame: InputFrame = controller.build_input(0.7)
	check(frame.player_slot == 2, "AI emits slot 2 InputFrame")
	check(frame.camera_yaw is float, "AI supplies facing intent through camera yaw")
	check(controller.state >= 0 and controller.state <= 5, "AI uses declared FSM state")
	controller.profile = &"HARD"
	var next_frame: InputFrame = controller.build_input(0.3)
	check(next_frame is InputFrame, "HARD profile still produces standard InputFrame")
	arena.free()
	print("AI TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
