extends SceneTree

var failures := 0
var arena: MatchController


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	arena = load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.start_playing()
	_test_segment_distance()
	_test_static_contact()
	_test_reach()
	_test_symmetry()
	_test_velocity_after_separate()
	_test_dash_still_hits()
	_test_separate_symmetry()
	_test_guard_knockback()
	arena.free()
	print("COLLISION TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _place(actor: Buffalo, at: Vector3, yaw: float) -> void:
	actor.reset_combat()
	actor.position = at
	actor.rotation.y = yaw
	actor.facing = Vector3(-sin(yaw), 0.0, -cos(yaw))
	actor.velocity = Vector3.ZERO
	actor.active = true


# Exactly one separate() call, then the center distance.
func _settle(a: Buffalo, b: Buffalo) -> float:
	ArenaBounds.separate(a, b)
	return a.global_position.distance_to(b.global_position)


func _test_static_contact() -> void:
	var a := arena.player
	var b := arena.opponent
	# Face to face: a looks +X (yaw -PI/2), b looks -X (yaw PI/2).
	_place(a, Vector3(-1.0, 0.0, 0.0), -PI / 2.0)
	_place(b, Vector3(1.0, 0.0, 0.0), PI / 2.0)
	check(absf(_settle(a, b) - 2.90) <= 0.03, "face to face stops at center distance 2.90")
	# Side by side, both facing -Z.
	_place(a, Vector3(0.0, 0.0, -0.5), 0.0)
	_place(b, Vector3(0.0, 0.0, 0.5), 0.0)
	b.position = Vector3(0.5, 0.0, 0.0)
	a.position = Vector3(-0.5, 0.0, 0.0)
	check(absf(_settle(a, b) - 1.60) <= 0.03, "side by side stops at center distance 1.60")
	# a's head into b's flank: a faces +X toward b, b faces -Z.
	_place(a, Vector3(-1.0, 0.0, 0.0), -PI / 2.0)
	_place(b, Vector3(1.0, 0.0, 0.0), 0.0)
	check(absf(_settle(a, b) - 2.25) <= 0.05, "head into the flank stops at center distance 2.25")
	# a's head into b's rump: both face +X.
	_place(a, Vector3(-1.0, 0.0, 0.0), -PI / 2.0)
	_place(b, Vector3(1.0, 0.0, 0.0), -PI / 2.0)
	check(absf(_settle(a, b) - 3.10) <= 0.05, "head into the rump stops at center distance 3.10")


func _duel(attacker: Buffalo, defender: Buffalo, distance: float) -> void:
	_place(attacker, Vector3.ZERO, 0.0)
	_place(defender, Vector3(0.0, 0.0, -distance), PI)


func _test_reach() -> void:
	var a := arena.player
	var b := arena.opponent
	for case in [[3.35, true], [3.50, false]]:
		_duel(a, b, case[0])
		a.start_horn()
		a.advance_state(GameBalance.get_number("horn_startup_s") + 0.001)
		check(arena.combat.attack_valid(a, b) == case[1], "HORN face to face at %.2f m: %s" % [case[0], "hits" if case[1] else "misses"])
	_duel(a, b, 2.5)
	b.position = Vector3(0.0, 0.0, 2.5) # behind the attacker
	a.start_horn()
	a.advance_state(GameBalance.get_number("horn_startup_s") + 0.001)
	check(not arena.combat.attack_valid(a, b), "HORN does not hit an opponent behind")


func _test_symmetry() -> void:
	var a := arena.player
	var b := arena.opponent
	_place(a, Vector3(-3.0, 0.0, 0.5), -PI / 2.0 + 0.2)
	_place(b, Vector3(0.4, 0.0, -0.3), PI / 2.0 - 0.3)
	var forward := ArenaBounds.head_gap(a, b)
	var back := ArenaBounds.head_gap(b, a)
	var swapped_forward := ArenaBounds.head_gap(a, b)
	check(absf(swapped_forward - forward) <= 0.001, "head_gap is deterministic")
	# Swap the two roles: the same pose pair in the other slots gives the same gap.
	var pose_a := {"position": a.position, "yaw": a.rotation.y}
	var pose_b := {"position": b.position, "yaw": b.rotation.y}
	_place(a, pose_b["position"], pose_b["yaw"])
	_place(b, pose_a["position"], pose_a["yaw"])
	check(absf(ArenaBounds.head_gap(a, b) - back) <= 0.001 and absf(ArenaBounds.head_gap(b, a) - forward) <= 0.001, "swapping slot 1 and slot 2 gives the same gaps")
	_place(a, pose_a["position"], pose_a["yaw"])
	_place(b, pose_b["position"], pose_b["yaw"])
	var contact_ab := ArenaBounds.deepest_contact(a, b)
	var contact_ba := ArenaBounds.deepest_contact(b, a)
	check(absf(float(contact_ab["depth"]) - float(contact_ba["depth"])) <= 0.001, "contact depth is symmetric in A and B")


func _test_velocity_after_separate() -> void:
	var a := arena.player
	var b := arena.opponent
	_place(a, Vector3(-1.0, 0.0, 0.0), -PI / 2.0)
	_place(b, Vector3(1.0, 0.0, 0.0), PI / 2.0)
	a.velocity = Vector3(8.0, 0.0, 1.0)
	b.velocity = Vector3(-8.0, 0.0, -1.0)
	ArenaBounds.separate(a, b)
	var normal: Vector3 = (b.global_position - a.global_position).normalized()
	check(a.velocity.dot(normal) <= 0.0001 and b.velocity.dot(-normal) <= 0.0001, "after separate no velocity component points into the other body")


func _test_dash_still_hits() -> void:
	var a := arena.player
	var b := arena.opponent
	_duel(a, b, 5.0)
	check(a.start_dash(), "DASH starts")
	var hit := false
	for i in 30:
		a.begin_input(InputFrame.new(1))
		a.simulate_movement(1.0 / 60.0, Vector3.ZERO, 1.0)
		ArenaBounds.separate(a, b)
		if arena.combat.attack_valid(a, b):
			hit = true
			break
		a.advance_state(1.0 / 60.0)
	check(hit, "DASH straight at an idle opponent still reaches dash_hit_gap")


# separate(a, b) and separate(b, a) must leave both buffaloes in the same places, including when
# the two bodies coincide exactly.
func _test_separate_symmetry() -> void:
	var a := arena.player
	var b := arena.opponent
	var cases := {
		"coincident": [Vector3.ZERO, 0.0, Vector3.ZERO, 0.0],
		"coincident, facing apart": [Vector3(2.0, 0.0, 1.0), 1.0, Vector3(2.0, 0.0, 1.0), 1.0 + PI],
		"overlapping": [Vector3(-0.4, 0.0, 0.2), -PI / 2.0 + 0.1, Vector3(0.9, 0.0, -0.1), PI / 2.0 - 0.2]
	}
	for name in cases:
		var c: Array = cases[name]
		_place(a, c[0], c[1])
		_place(b, c[2], c[3])
		var normal_ab: Vector3 = ArenaBounds.deepest_contact(a, b)["normal"]
		var normal_ba: Vector3 = ArenaBounds.deepest_contact(b, a)["normal"]
		check(normal_ab.distance_to(-normal_ba) < 0.001, "%s: normals are opposite when the arguments are swapped" % name)
		ArenaBounds.separate(a, b)
		var first_a := a.global_position
		var first_b := b.global_position
		_place(a, c[0], c[1])
		_place(b, c[2], c[3])
		ArenaBounds.separate(b, a)
		check(first_a.distance_to(a.global_position) < 0.001 and first_b.distance_to(b.global_position) < 0.001, "%s: separate(a, b) and separate(b, a) end in the same positions" % name)
		check(first_a.x <= first_b.x + 0.0001, "%s: slot 1 ends on the -X side" % name)


# A guarding buffalo takes an impulse without stun; separate() must not eat that knockback.
func _test_guard_knockback() -> void:
	var a := arena.player
	var b := arena.opponent
	_place(a, Vector3(-1.45, 0.0, 0.0), -PI / 2.0)
	_place(b, Vector3(1.45, 0.0, 0.0), PI / 2.0)
	b.state = Buffalo.State.GUARD
	b.guarding = true
	a.attack_kind = &"HORN"
	arena.combat.apply_hit(a, b)
	check(b.state == Buffalo.State.GUARD and b.knockback_time > 0.0, "guarded hit sets knockback_time without stunning")
	var expected := b.velocity.x
	var decays := true
	for i in 12:
		b.simulate_movement(1.0 / 60.0, Vector3.ZERO, 1.0)
		b.update_timers(1.0 / 60.0)
		ArenaBounds.separate(a, b)
		expected = maxf(0.0, expected - GameBalance.get_number("deceleration") / 60.0)
		decays = decays and absf(b.velocity.x - expected) < 0.01
	check(decays, "guarded knockback decays at `deceleration` with separate() running every tick")
	# Knocked into the other body while overlapping: the pusher is stopped, the knocked one keeps its velocity.
	_place(a, Vector3(-0.5, 0.0, 0.0), -PI / 2.0)
	_place(b, Vector3(0.5, 0.0, 0.0), PI / 2.0)
	a.velocity = Vector3(6.0, 0.0, 0.0)
	b.receive_spirit(0.0, Vector3(-5.0, 0.0, 0.0), false)
	ArenaBounds.separate(a, b)
	check(is_equal_approx(b.velocity.x, -5.0), "knocked-back buffalo keeps its velocity through separate")
	check(a.velocity.x <= 0.0001, "the other buffalo still loses its inward velocity")


func _segment(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	return float(ArenaBounds.closest_points(p1, q1, p2, q2)["distance"])


func _test_segment_distance() -> void:
	var o := Vector3.ZERO
	check(is_equal_approx(_segment(o, Vector3(2, 0, 0), Vector3(0, 0, 1), Vector3(2, 0, 1)), 1.0), "parallel segments")
	check(is_equal_approx(_segment(o, Vector3(2, 0, 0), Vector3(3, 0, 1), Vector3(5, 0, 1)), sqrt(2.0)), "parallel and offset along the axis")
	check(is_zero_approx(_segment(Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1))), "crossing segments")
	check(is_equal_approx(_segment(o, Vector3(2, 0, 0), Vector3(1, 0, 3), Vector3(1, 0, 3)), 3.0), "a segment against a degenerate point (point above)")
	check(is_equal_approx(_segment(Vector3(1, 0, 3), Vector3(1, 0, 3), o, Vector3(2, 0, 0)), 3.0), "a degenerate point against a segment")
	check(is_equal_approx(_segment(Vector3(1, 0, 1), Vector3(1, 0, 1), Vector3(4, 0, 5), Vector3(4, 0, 5)), 5.0), "two degenerate points")
	check(is_zero_approx(_segment(o, Vector3(2, 0, 0), Vector3(2, 0, 0), Vector3(2, 0, 3))), "end points touching")
	check(is_equal_approx(_segment(o, Vector3(2, 0, 0), Vector3(3, 0, 0), Vector3(5, 0, 0)), 1.0), "collinear segments with a gap")
	var hit := ArenaBounds.closest_points(o, Vector3(2, 0, 0), Vector3(1, 0, 3), Vector3(1, 0, 3))
	check((hit["c1"] as Vector3).is_equal_approx(Vector3(1, 0, 0)) and (hit["c2"] as Vector3).is_equal_approx(Vector3(1, 0, 3)), "closest points are returned")
