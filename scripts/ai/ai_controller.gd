extends Node
## Solo FSM that emits the same InputFrame contract used by the player/network.

enum State { APPROACH, STRAFE, ATTACK, GUARD, RECOVER, CLASH }

var actor: Buffalo
var target: Buffalo
var profile: StringName = &"EASY"
var state := State.APPROACH
var state_time := 0.0
var decision_time := 0.0
var strafe_sign := 1.0
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
	var desired_yaw := atan2(-toward.x, -toward.z)
	frame.camera_yaw = desired_yaw
	if actor.state == Buffalo.State.CLASH:
		if decision_time <= 0.0:
			decision_time = float(profile_data.get("reaction_s", 0.65))
			cached_clash_action = _clash_choice()
		frame.clash_action = cached_clash_action
		if cached_clash_action == &"PUSH":
			frame.move = Vector2(0.0, -1.0)
		return frame
	if actor.state in [Buffalo.State.STUNNED, Buffalo.State.FLEE]:
		return frame
	if decision_time > 0.0:
		frame.move = Vector2(0.0, -1.0)
		return frame
	decision_time = float(profile_data.get("reaction_s", 0.65))
	if actor.stamina <= GameBalance.get_number("guard_min_stamina") and actor.stamina < 35.0:
		state = State.RECOVER
	elif bool(profile_data.get("guard", false)) and target.is_committed() and distance < 4.0 and _target_faces_actor():
		state = State.GUARD
	elif distance <= float(profile_data.get("attack_range", 3.0)):
		state = State.ATTACK
	elif bool(profile_data.get("strafe", false)) and _target_faces_actor():
		state = State.STRAFE
	else:
		state = State.APPROACH
	match state:
		State.APPROACH:
			frame.move = Vector2(0.0, -1.0)
		State.STRAFE:
			frame.move = Vector2(strafe_sign, -0.35)
			if rng.randf() < 0.2:
				strafe_sign *= -1.0
		State.ATTACK:
			frame.move = Vector2.ZERO
			var angle := actor.forward().dot(toward)
			if absf(angle) > cos(GameBalance.get_angle("horn_half_angle")):
				if profile == &"HARD" and distance >= float(profile_data.get("dash_min_range", 2.5)) and distance <= float(profile_data.get("dash_max_range", 5.0)):
					frame.dash_pressed = true
				else:
					frame.horn_pressed = true
		State.GUARD:
			frame.guard_held = true
		State.RECOVER:
			frame.move = Vector2(0.0, 1.0)
			if actor.stamina > 70.0:
				state = State.APPROACH
	return frame


func _target_faces_actor() -> bool:
	var toward_target := (actor.global_position - target.global_position)
	toward_target.y = 0.0
	return target.forward().dot(toward_target.normalized()) > 0.45


func _clash_choice() -> StringName:
	if profile == &"EASY":
		return &"PUSH"
	if profile == &"NORMAL":
		return &"HOOK" if rng.randf() < 0.35 else &"PUSH"
	var roll := rng.randf()
	if roll < 0.25:
		return &"RELEASE"
	if roll < 0.60:
		return &"HOOK"
	return &"PUSH"
