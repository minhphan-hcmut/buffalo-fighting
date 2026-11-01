class_name ArenaBounds
extends RefCounted
## Oval arena geometry shared by movement, combat and CLASH: fence limit, PINNED, mud zones.


static func constrain(actor: Buffalo) -> void:
	var radius := GameBalance.get_number("buffalo_radius")
	var half := Vector2(GameBalance.get_number("arena_rx") - radius, GameBalance.get_number("arena_rz") - radius)
	var point := Vector2(actor.position.x / half.x, actor.position.z / half.y)
	if point.length() > 1.0:
		point = point.normalized()
		actor.position.x = point.x * half.x
		actor.position.z = point.y * half.y


## Pushes two overlapping bodies apart symmetrically (up to 3 passes with the fence clamp), then
## drops the velocity component that still points into the other body.
static func separate(a: Buffalo, b: Buffalo) -> void:
	var required := GameBalance.get_number("buffalo_radius") * 2.0
	var normal := Vector3.ZERO
	for pass_index in 3:
		var offset := b.global_position - a.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance >= required:
			break
		normal = Vector3.RIGHT if distance < 0.001 else offset / distance
		var correction := (required - distance) * 0.5
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


static func is_pinned(target: Buffalo, away: Vector3) -> bool:
	var rx := GameBalance.get_number("arena_rx")
	var rz := GameBalance.get_number("arena_rz")
	var position := Vector2(target.position.x, target.position.z)
	var normalized := Vector2(position.x / rx, position.y / rz)
	if normalized.length() < 0.001:
		return false
	# Gap along the center ray from the body surface to the fence.
	var fence_gap := position.length() * (1.0 / normalized.length() - 1.0) - GameBalance.get_number("buffalo_radius")
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
