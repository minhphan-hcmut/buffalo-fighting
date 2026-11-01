extends Node
## Solo FSM that emits the same InputFrame contract used by the player/network.
## The state is re-chosen every `reaction_s`; between decisions the previous move and guard are
## repeated, and edge buttons (horn/dash) are only sent on the decision tick.

enum State { APPROACH, STRAFE, ATTACK, GUARD, RECOVER, CLASH }

var actor: Buffalo
var target: Buffalo
var profile: StringName = &"EASY"
var state := State.APPROACH
var state_time := 0.0
var decision_time := 0.0
var strafe_sign := 1.0
var recovering := false
var held_move := Vector2(0.0, -1.0)
var held_guard := false
var retreat_time := 0.0
var retreat_reference := 0.0
var retreat_stalled := false
var cached_clash_action: StringName = &"PUSH"
var rng := RandomNumberGenerator.new()
var profile_data: Dictionary = {}


func _ready() -> void:
	var file := FileAccess.open("res://data/ai_profiles.json", FileAccess.READ)
	if file != null:
		var profiles: Dictionary = JSON.parse_string(file.get_as_text())
		profile_data = profiles.get(String(profile), profiles["EASY"])
	rng.seed = 31 + int(profile)


func build_input(delta: float) -> InputFrame:
	var frame := InputFrame.new(2)
	if not is_instance_valid(actor) or not is_instance_valid(target) or not actor.active:
		return frame
	state_time += delta
	decision_time -= delta
	var offset := target.global_position - actor.global_position
	offset.y = 0.0
	var distance := offset.length()
	var toward := offset.normalized() if distance > 0.001 else actor.forward()
	frame.camera_yaw = atan2(-toward.x, -toward.z)
	if actor.state == Buffalo.State.CLASH:
		if decision_time <= 0.0:
			decision_time = _param("reaction_s", 0.65)
			cached_clash_action = _clash_choice()
		frame.clash_action = cached_clash_action
		if cached_clash_action == &"PUSH":
			frame.move = Vector2(0.0, -1.0)
		return frame
	if actor.state in [Buffalo.State.STUNNED, Buffalo.State.FLEE]:
		return frame
	if decision_time <= 0.0:
		decision_time = _param("reaction_s", 0.65)
		_decide(frame, distance, toward)
	frame.move = _recover_move(delta, distance, toward) if recovering and state == State.RECOVER else held_move
	frame.guard_held = held_guard
	return frame


func _param(key: String, fallback: float) -> float:
	return float(profile_data.get(key, fallback))


func _decide(frame: InputFrame, distance: float, toward: Vector3) -> void:
	held_move = Vector2.ZERO
	held_guard = false
	var gap := ArenaBounds.head_gap(actor, target)
	if recovering and actor.stamina > _param("recover_exit", 60.0):
		recovering = false
	elif not recovering and actor.stamina < _param("recover_enter", 25.0):
		recovering = true
	if recovering:
		state = State.RECOVER
		if retreat_time <= 0.0:
			retreat_reference = distance
		held_move = Vector2(0.0, 1.0) if distance < _param("recover_distance", 5.0) else Vector2(strafe_sign, 0.0)
		return
	var in_front := actor.forward().dot(toward) >= cos(GameBalance.get_angle("horn_half_angle"))
	if bool(profile_data.get("guard", false)) and target.is_committed() \
			and distance < _param("guard_distance", 4.0) and _target_faces_actor():
		state = State.GUARD
		held_guard = true
		return
	if profile_data.has("dash_min_range") and in_front and actor.dash_cooldown <= 0.0 \
			and actor.stamina >= GameBalance.get_number("dash_cost") \
			and distance >= _param("dash_min_range", 0.0) and distance <= _param("dash_max_range", 0.0):
		state = State.ATTACK
		frame.dash_pressed = true
		return
	if gap > _param("approach_gap", 0.5):
		state = State.APPROACH
		held_move = Vector2(0.0, -1.0)
		return
	if in_front and actor.horn_cooldown <= 0.0 and actor.stamina >= GameBalance.get_number("horn_cost"):
		state = State.ATTACK
		frame.horn_pressed = true
		return
	if gap < _param("min_gap", 0.1):
		state = State.ATTACK
		held_move = Vector2(0.0, 0.5)
		return
	if bool(profile_data.get("strafe", false)):
		state = State.STRAFE
		if rng.randf() < _param("strafe_flip_chance", 0.2):
			strafe_sign *= -1.0
		# Radial term keeps the gap inside [min_gap, approach_gap] while circling.
		var middle := (_param("approach_gap", 0.5) + _param("min_gap", 0.1)) * 0.5
		held_move = Vector2(strafe_sign, -clampf((gap - middle) * _param("strafe_radial_gain", 2.0), -0.5, 0.5))
	else:
		state = State.ATTACK


## Backing off while recovering. A fence behind the AI (or a retreat that is not gaining distance)
## turns the retreat into a walk along the fence, toward the side away from the opponent.
func _recover_move(delta: float, distance: float, toward: Vector3) -> Vector2:
	if distance >= _param("recover_distance", 5.0):
		retreat_time = 0.0
		return Vector2(strafe_sign, 0.0)
	var away := -toward
	var wall_gap := ArenaBounds.fence_distance(actor.global_position, away) - _rear_extent(away)
	retreat_time += delta
	if retreat_time >= _param("wall_stuck_s", 0.3):
		retreat_stalled = distance < retreat_reference + _param("wall_stuck_gain", 0.05)
		retreat_reference = distance
		retreat_time = 0.0
	if wall_gap >= _param("wall_margin", 0.5) and not retreat_stalled:
		return Vector2(0.0, 1.0)
	# Tangent of the oval at the AI's position, pointing away from the opponent.
	var rx := GameBalance.get_number("arena_rx")
	var rz := GameBalance.get_number("arena_rz")
	var outward := Vector3(actor.position.x / (rx * rx), 0.0, actor.position.z / (rz * rz)).normalized()
	var tangent := Vector3(-outward.z, 0.0, outward.x)
	if tangent.dot(away) < 0.0 or (is_zero_approx(tangent.dot(away)) and strafe_sign < 0.0):
		tangent = -tangent
	var yaw := atan2(-toward.x, -toward.z)
	var camera_forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var camera_right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return Vector2(tangent.dot(camera_right), -tangent.dot(camera_forward))


## How far the body reaches from the actor's origin along `direction` (capsule end points + radius).
func _rear_extent(direction: Vector3) -> float:
	var origin := Vector3(actor.global_position.x, 0.0, actor.global_position.z)
	var extent := 0.0
	for shape in ArenaBounds.shapes(actor):
		for key in ["a", "b"]:
			var point: Vector3 = shape[key]
			extent = maxf(extent, (point - origin).dot(direction) + float(shape["r"]))
	return extent


func _target_faces_actor() -> bool:
	var toward_target := (actor.global_position - target.global_position)
	toward_target.y = 0.0
	return target.forward().dot(toward_target.normalized()) > 0.45


func _clash_choice() -> StringName:
	var weights: Dictionary = profile_data.get("clash_weights", {})
	var release := float(weights.get("RELEASE", 0.0))
	var hook := float(weights.get("HOOK", 0.0))
	if release <= 0.0 and hook <= 0.0:
		return &"PUSH"
	var roll := rng.randf()
	if roll < release:
		return &"RELEASE"
	if roll < release + hook:
		return &"HOOK"
	return &"PUSH"
