extends SceneTree
## Bamboo gates in the fence gaps: shut while the match is played (the arena oval stops a
## buffalo there, so the gap must not look open), open while people walk through. Presentation only.

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func free_ends(gates: ArenaGates) -> Array[Vector3]:
	var ends: Array[Vector3] = []
	for leaf in gates.leaves:
		ends.append((leaf.pivot as Node3D).global_transform * Vector3(float(leaf.length), 0.0, 0.0))
	return ends


func run() -> void:
	var rx := GameBalance.get_number("arena_rx")
	var rz := GameBalance.get_number("arena_rz")
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L01"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	await process_frame
	var gates := arena.get_node_or_null("Gates") as ArenaGates
	check(gates != null and gates.leaves.size() == 4, "arena hangs two leaves in each of its two gates")
	if gates == null:
		quit(1)
		return
	check(gates.find_children("*", "CollisionShape3D", true, false).is_empty(), "gates have no collision: the arena oval stays the only gameplay edge")
	check(gates.target_open() == 1.0, "gates stand open before the countdown, while the handlers are still in")
	gates.update(INF)
	var open_ok := true
	for end in free_ends(gates):
		open_ok = open_ok and absf(end.x) > rx and absf(end.z) > GameBalance.get_number("gate_width") * 0.5
	check(open_ok, "open leaves swing outward, clear of the gate opening")

	# Act: countdown starts, then the handlers have left.
	arena.phase = &"COUNTDOWN"
	arena.countdown_time = GameBalance.get_number("countdown_s", 3.0)
	check(gates.target_open() == 1.0, "gates stay open while the release handlers walk out")
	arena.countdown_time = 0.0
	check(gates.target_open() == 0.0, "gates shut once the release handlers are through")
	arena.phase = &"PLAYING"
	gates.update(GameBalance.get_number("gate_swing_s") * 0.5)
	check(gates.open_amount > 0.0 and gates.open_amount < 1.0, "gates swing over time instead of snapping shut")
	gates.update(INF)
	var shut_ok := true
	for end in free_ends(gates):
		shut_ok = shut_ok and end.distance_to(Vector3(signf(end.x) * rx, 0.0, 0.0)) < 0.05
	check(shut_ok, "shut leaves meet on the arena oval, closing the gap during play")
	var edge := ArenaGates.gap_edge_angle()
	var hinge_ok := true
	for leaf in gates.leaves:
		var hinge := (leaf.pivot as Node3D).global_position
		hinge_ok = hinge_ok and absf(pow(hinge.x / rx, 2.0) + pow(hinge.z / rz, 2.0) - 1.0) < 0.001 and absf(absf(hinge.z) - rz * sin(edge)) < 0.001
	check(hinge_ok and edge * rz * 2.0 >= GameBalance.get_number("gate_width"), "leaves hang on the last fence posts, covering the whole gap")

	arena.phase = &"RESULT"
	check(gates.target_open() == 1.0, "gates open for the result outro")

	var backdrop := Node3D.new()
	root.add_child(backdrop)
	var loose := ArenaGates.new()
	backdrop.add_child(loose)
	check(loose.target_open() == 1.0 and loose.open_amount == 1.0, "without a match (menu, ceremony) the gates stand open")
	quit(1 if failures > 0 else 0)
