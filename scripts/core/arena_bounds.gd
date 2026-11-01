class_name ArenaBounds
extends RefCounted
## Oval arena geometry shared by movement, combat and CLASH: body/head capsules, fence limit,
## PINNED, mud zones. Each buffalo is two 2D capsules on XZ (segment along its facing + radius).


## Body and head capsules in world space: [{"a", "b", "r"}, ...], body first. Points keep y = 0.
static func shapes(actor: Buffalo) -> Array[Dictionary]:
	var origin := Vector3(actor.global_position.x, 0.0, actor.global_position.z)
	var forward := actor.forward()
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	# Local -Z is the front, so a segment z of -0.3 sits 0.3 m ahead of the origin.
	var result: Array[Dictionary] = []
	result.append({
		"a": origin - forward * GameBalance.get_number("body_seg_front"),
		"b": origin - forward * GameBalance.get_number("body_seg_back"),
		"r": GameBalance.get_number("body_radius")
	})
	result.append({
		"a": origin - forward * GameBalance.get_number("head_seg_front"),
		"b": origin - forward * GameBalance.get_number("head_seg_back"),
		"r": GameBalance.get_number("head_radius")
	})
	return result


## Closest points between segments p1-q1 and p2-q2 on XZ: {"distance", "c1", "c2"}.
static func closest_points(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Dictionary:
	var a1 := Vector2(p1.x, p1.z)
	var b1 := Vector2(q1.x, q1.z)
	var a2 := Vector2(p2.x, p2.z)
	var b2 := Vector2(q2.x, q2.z)
	var d1 := b1 - a1
	var d2 := b2 - a2
	var r := a1 - a2
	var len1 := d1.dot(d1)
	var len2 := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if len1 <= 0.000001 and len2 <= 0.000001:
		pass
	elif len1 <= 0.000001:
		t = clampf(f / len2, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if len2 <= 0.000001:
			s = clampf(-c / len1, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var denom := len1 * len2 - b * b
			if denom > 0.000001:
				s = clampf((b * f - c * len2) / denom, 0.0, 1.0)
			t = (b * s + f) / len2
			if t < 0.0:
				t = 0.0
				s = clampf(-c / len1, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / len1, 0.0, 1.0)
	var c1 := a1 + d1 * s
	var c2 := a2 + d2 * t
	return {
		"distance": c1.distance_to(c2),
		"c1": Vector3(c1.x, 0.0, c1.y),
		"c2": Vector3(c2.x, 0.0, c2.y)
	}


## Deepest overlap among the 4 body/head pairs: {"depth", "normal"} with the normal from a to b.
static func deepest_contact(a: Buffalo, b: Buffalo) -> Dictionary:
	var best_depth := -INF
	var best_normal := Vector3.RIGHT
	for shape_a in shapes(a):
		for shape_b in shapes(b):
			var hit := closest_points(shape_a["a"], shape_a["b"], shape_b["a"], shape_b["b"])
			var depth: float = float(shape_a["r"]) + float(shape_b["r"]) - float(hit["distance"])
			if depth <= best_depth:
				continue
			best_depth = depth
			var normal: Vector3 = hit["c2"] - hit["c1"]
			if normal.length() < 0.001:
				normal = b.global_position - a.global_position
				normal.y = 0.0
			best_normal = normal.normalized() if normal.length() >= 0.001 else Vector3.RIGHT
	return {"depth": best_depth, "normal": best_normal}


## Open space from the attacker's head capsule to the nearest target capsule (head or body).
static func head_gap(attacker: Buffalo, target: Buffalo) -> float:
	var head: Dictionary = shapes(attacker)[1]
	var best := INF
	for shape in shapes(target):
		var hit := closest_points(head["a"], head["b"], shape["a"], shape["b"])
		best = minf(best, float(hit["distance"]) - float(head["r"]) - float(shape["r"]))
	return best


## Keeps every capsule end point inside the arena oval shrunk per axis by that capsule's radius.
static func constrain(actor: Buffalo) -> void:
	var rx := GameBalance.get_number("arena_rx")
	var rz := GameBalance.get_number("arena_rz")
	for pass_index in 2:
		for shape_index in 2:
			for key in ["a", "b"]:
				var shape: Dictionary = shapes(actor)[shape_index]
				var half := Vector2(rx - float(shape["r"]), rz - float(shape["r"]))
				var point: Vector3 = shape[key]
				var scaled := Vector2(point.x / half.x, point.z / half.y)
				if scaled.length() <= 1.0:
					continue
				scaled = scaled.normalized()
				actor.global_position.x += scaled.x * half.x - point.x
				actor.global_position.z += scaled.y * half.y - point.z


## Pushes two overlapping bodies apart symmetrically (up to 3 passes with the fence clamp), then
## drops the velocity component that still points into the other body.
static func separate(a: Buffalo, b: Buffalo) -> void:
	var normal := Vector3.ZERO
	for pass_index in 3:
		var contact := deepest_contact(a, b)
		if float(contact["depth"]) <= 0.0:
			break
		normal = contact["normal"]
		var correction := float(contact["depth"]) * 0.5
		a.global_position -= normal * correction
		b.global_position += normal * correction
		constrain(a)
		constrain(b)
	if normal == Vector3.ZERO:
		return
	if a.state != Buffalo.State.STUNNED:
		a.velocity -= normal * maxf(0.0, a.velocity.dot(normal))
	if b.state != Buffalo.State.STUNNED:
		b.velocity += normal * maxf(0.0, -b.velocity.dot(normal))


## PINNED: the body capsule is within `pinned_distance` of the fence and `away` points at it.
static func is_pinned(target: Buffalo, away: Vector3) -> bool:
	var rx := GameBalance.get_number("arena_rx")
	var rz := GameBalance.get_number("arena_rz")
	if Vector2(target.position.x, target.position.z).length() < 0.001:
		return false
	var body: Dictionary = shapes(target)[0]
	var fence_gap := INF
	for key in ["a", "b"]:
		var point: Vector3 = body[key]
		var normalized := Vector2(point.x / rx, point.z / rz)
		if normalized.length() < 0.001:
			continue
		# Gap along the center ray from the body surface to the fence.
		var flat := Vector2(point.x, point.z)
		fence_gap = minf(fence_gap, flat.length() * (1.0 / normalized.length() - 1.0) - float(body["r"]))
	var outward := Vector3(target.position.x / (rx * rx), 0.0, target.position.z / (rz * rz)).normalized()
	return fence_gap <= GameBalance.get_number("pinned_distance") and outward.dot(away) > 0.25


static func in_mud(position: Vector3, mud_zones: Array[StringName]) -> bool:
	var radius := GameBalance.get_number("mud_radius")
	var flat := Vector2(position.x, position.z)
	for zone in mud_zones:
		if (zone == &"A" or zone == &"B") and flat.distance_to(mud_center(zone)) <= radius:
			return true
	return false


static func mud_center(zone: StringName) -> Vector2:
	if zone == &"A":
		return Vector2(GameBalance.get_number("mud_a_x"), GameBalance.get_number("mud_a_z"))
	return Vector2(GameBalance.get_number("mud_b_x"), GameBalance.get_number("mud_b_z"))
