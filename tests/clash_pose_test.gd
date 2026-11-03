extends SceneTree
## Locked muzzles must slide past each other instead of sinking into the opponent's body.

const TICK := 1.0 / 60.0
const MUZZLE := Vector3(0.0, 1.0, -2.027)
const BODY_HALF_WIDTH := 0.78
const BODY_Z := Vector2(-1.918, 1.644)

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
	arena.start_playing()
	var a := arena.player
	var b := arena.opponent
	a.position = Vector3(-1.0, 0.0, 0.0)
	b.position = Vector3(1.0, 0.0, 0.0)
	a.rotation.y = -PI / 2.0
	b.rotation.y = PI / 2.0
	a.facing = Vector3.RIGHT
	b.facing = Vector3.LEFT
	arena.clash.enter(0.0)
	var visual_a: Node3D = a.get_node("Visual")
	var visual_b: Node3D = b.get_node("Visual")
	for i in 90:
		arena.clash.process(TICK, InputFrame.new(1), InputFrame.new(2))
		visual_a.sample_motion(TICK)
		visual_b.sample_motion(TICK)
		visual_a.update_pose(TICK)
		visual_b.update_pose(TICK)
	check(is_equal_approx(a.global_position.distance_to(b.global_position), GameBalance.get_number("clash_distance")), "locked pair sits at clash_distance")
	for pair in [[visual_a, visual_b, "A into B"], [visual_b, visual_a, "B into A"]]:
		var muzzle: Vector3 = pair[0].global_transform * MUZZLE
		var local: Vector3 = pair[1].global_transform.affine_inverse() * muzzle
		var inside := absf(local.x) <= BODY_HALF_WIDTH and local.z >= BODY_Z.x and local.z <= BODY_Z.y
		check(not inside, "%s: muzzle stays outside the opponent body (x=%.2f z=%.2f)" % [pair[2], local.x, local.z])
	arena.free()
	print("CLASH POSE TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
