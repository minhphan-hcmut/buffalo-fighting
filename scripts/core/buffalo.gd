class_name Buffalo
extends CharacterBody3D

signal action_started(slot: int, action: StringName)

enum State { NORMAL, GUARD, HORN_STARTUP, HORN_ACTIVE, HORN_RECOVERY, DASH_ACTIVE,
	DASH_RECOVERY, STUNNED, CLASH, FLEE }

const STATE_NAMES := {
	State.NORMAL: &"NORMAL",
	State.GUARD: &"GUARD",
	State.HORN_STARTUP: &"HORN_STARTUP",
	State.HORN_ACTIVE: &"HORN_ACTIVE",
	State.HORN_RECOVERY: &"HORN_RECOVERY",
	State.DASH_ACTIVE: &"DASH_ACTIVE",
	State.DASH_RECOVERY: &"DASH_RECOVERY",
	State.STUNNED: &"STUNNED",
	State.CLASH: &"CLASH",
	State.FLEE: &"FLEE"
}

var slot := 1
var spirit := 100.0
var stamina := 100.0
var state := State.NORMAL
var state_time := 0.0
var state_duration := 0.0
var attack_kind: StringName = &"NONE"
var facing := Vector3.FORWARD
var camera_yaw := 0.0
var input_frame := InputFrame.new()
var hit_targets: Dictionary = {}
var hit_invulnerability := 0.0
var stamina_regen_delay := 0.0
var horn_cooldown := 0.0
var dash_cooldown := 0.0
var knockback := Vector3.ZERO
var buffered_action: StringName = &"NONE"
var input_buffer_time := 0.0
var active := true
var guarding := false
var clash_partner: Buffalo
var clash_hook_time := 0.0
var clash_hooked := false
var clash_release_pressed := false
var clash_action: StringName = &"PUSH"

@onready var visual: Node3D = $Visual


func _ready() -> void:
	reset_combat()


func reset_combat() -> void:
	spirit = GameBalance.get_number("spirit_max", 100.0)
	stamina = GameBalance.get_number("stamina_max", 100.0)
	state = State.NORMAL
	state_time = 0.0
	state_duration = 0.0
	facing = -global_basis.z
	camera_yaw = rotation.y
	hit_targets.clear()
	hit_invulnerability = 0.0
	stamina_regen_delay = 0.0
	horn_cooldown = 0.0
	dash_cooldown = 0.0
	knockback = Vector3.ZERO
	buffered_action = &"NONE"
	input_buffer_time = 0.0
	active = true
	guarding = false
	clash_partner = null
	velocity = Vector3.ZERO


func state_name() -> StringName:
	return STATE_NAMES[state]


func forward() -> Vector3:
	return facing.normalized()


func is_committed() -> bool:
	return state == State.HORN_STARTUP or state == State.HORN_ACTIVE or state == State.DASH_ACTIVE


func is_attack_active() -> bool:
	return state == State.HORN_ACTIVE or state == State.DASH_ACTIVE


func begin_input(frame: InputFrame) -> void:
	input_frame = frame
	camera_yaw = frame.camera_yaw
	if not active or state == State.STUNNED or state == State.FLEE or state == State.CLASH:
		return
	if frame.guard_held and state == State.NORMAL and stamina >= GameBalance.get_number("guard_min_stamina", 10.0):
		guarding = true
		state = State.GUARD
	elif not frame.guard_held and state == State.GUARD:
		guarding = false
		state = State.NORMAL
	if guarding:
		return
	if state == State.NORMAL and buffered_action != &"NONE" and input_buffer_time > 0.0:
		var queued := buffered_action
		buffered_action = &"NONE"
		input_buffer_time = 0.0
		if queued == &"HORN" and start_horn():
			return
		if queued == &"DASH" and start_dash():
			return
	if state != State.NORMAL:
		if frame.horn_pressed or frame.dash_pressed:
			buffered_action = &"HORN" if frame.horn_pressed else &"DASH"
			input_buffer_time = GameBalance.get_number("input_buffer_s")
		return
	if frame.horn_pressed:
		if start_horn():
			return
		buffered_action = &"HORN"
		input_buffer_time = GameBalance.get_number("input_buffer_s")
		return
	if frame.dash_pressed:
		if not start_dash():
			buffered_action = &"DASH"
			input_buffer_time = GameBalance.get_number("input_buffer_s")


func start_horn() -> bool:
	var cost := GameBalance.get_number("horn_cost")
	if horn_cooldown > 0.0 or stamina < cost:
		return false
	stamina -= cost
	stamina_regen_delay = GameBalance.get_number("stamina_regen_delay_s")
	horn_cooldown = GameBalance.get_number("horn_cooldown_s")
	state = State.HORN_STARTUP
	state_time = 0.0
	state_duration = GameBalance.get_number("horn_startup_s")
	attack_kind = &"HORN"
	hit_targets.clear()
	action_started.emit(slot, attack_kind)
	return true


func start_dash() -> bool:
	var cost := GameBalance.get_number("dash_cost")
	if dash_cooldown > 0.0 or stamina < cost:
		return false
	stamina -= cost
	stamina_regen_delay = GameBalance.get_number("stamina_regen_delay_s")
	dash_cooldown = GameBalance.get_number("dash_cooldown_s")
	state = State.DASH_ACTIVE
	state_time = 0.0
	state_duration = GameBalance.get_number("dash_active_s")
	attack_kind = &"DASH"
	hit_targets.clear()
	velocity = forward() * GameBalance.get_number("dash_speed")
	action_started.emit(slot, attack_kind)
	return true


func begin_clash(partner: Buffalo) -> void:
	state = State.CLASH
	state_time = 0.0
	state_duration = GameBalance.get_number("lock_max_s")
	attack_kind = &"NONE"
	hit_targets.clear()
	guarding = false
	clash_partner = partner
	clash_hook_time = 0.0
	clash_hooked = false
	clash_release_pressed = false
	clash_action = &"PUSH"


func apply_stun(duration: float, impulse: Vector3) -> void:
	if not active:
		return
	guarding = false
	state = State.STUNNED
	state_time = 0.0
	state_duration = duration
	knockback = impulse
	velocity = impulse


func receive_spirit(amount: float, impulse: Vector3, stun: bool = true) -> void:
	if not active:
		return
	spirit = clampf(spirit - amount, 0.0, GameBalance.get_number("spirit_max", 100.0))
	if stun:
		apply_stun(GameBalance.get_number("hitstun_s"), impulse)
	else:
		velocity = impulse


func consume_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	stamina_regen_delay = GameBalance.get_number("stamina_regen_delay_s")
	if stamina <= 0.0 and guarding:
		guarding = false
		state = State.NORMAL


func update_timers(delta: float) -> void:
	horn_cooldown = maxf(0.0, horn_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	hit_invulnerability = maxf(0.0, hit_invulnerability - delta)
	stamina_regen_delay = maxf(0.0, stamina_regen_delay - delta)
	input_buffer_time = maxf(0.0, input_buffer_time - delta)
	if input_buffer_time <= 0.0:
		buffered_action = &"NONE"
	if state == State.GUARD:
		consume_stamina(GameBalance.get_number("guard_stamina_per_s") * delta)
	elif state != State.CLASH and stamina_regen_delay <= 0.0:
		stamina = minf(
			GameBalance.get_number("stamina_max"),
			stamina + GameBalance.get_number("stamina_regen_per_s") * delta
		)


func advance_state(delta: float) -> void:
	if state == State.NORMAL or state == State.GUARD or state == State.CLASH or state == State.FLEE:
		return
	state_time += delta
	if state_time < state_duration:
		return
	match state:
		State.HORN_STARTUP:
			state = State.HORN_ACTIVE
			state_time = 0.0
			state_duration = GameBalance.get_number("horn_active_s")
		State.HORN_ACTIVE:
			state = State.HORN_RECOVERY
			state_time = 0.0
			state_duration = GameBalance.get_number("horn_recovery_s")
		State.HORN_RECOVERY:
			state = State.NORMAL
			attack_kind = &"NONE"
		State.DASH_ACTIVE:
			state = State.DASH_RECOVERY
			state_time = 0.0
			state_duration = GameBalance.get_number("dash_recovery_s")
			velocity = Vector3.ZERO
		State.DASH_RECOVERY:
			state = State.NORMAL
			attack_kind = &"NONE"
		State.STUNNED:
			state = State.NORMAL
			knockback = Vector3.ZERO


func movement_world(frame: InputFrame, camera_forward: Vector3, camera_right: Vector3) -> Vector3:
	var move_dir := camera_forward * -frame.move.y + camera_right * frame.move.x
	move_dir.y = 0.0
	return move_dir.limit_length()


func simulate_movement(delta: float, move_dir: Vector3, terrain_factor: float) -> void:
	if not active or state == State.FLEE:
		return
	var desired := Vector3.ZERO
	if state == State.DASH_ACTIVE:
		desired = forward() * GameBalance.get_number("dash_speed")
	elif state == State.STUNNED:
		desired = Vector3.ZERO # knockback velocity decays at `deceleration` (GDD §3)
	elif state == State.CLASH:
		desired = Vector3.ZERO
	elif move_dir.length_squared() > 0.0001:
		var facing_dot := forward().dot(move_dir.normalized())
		var direction_factor := 1.0
		if facing_dot < -0.707:
			direction_factor = GameBalance.get_number("back_speed_multiplier")
		elif facing_dot < 0.707:
			direction_factor = GameBalance.get_number("strafe_speed_multiplier")
		var state_factor := 1.0
		if state == State.GUARD:
			state_factor = GameBalance.get_number("guard_speed_multiplier")
		elif state == State.HORN_STARTUP or state == State.HORN_ACTIVE:
			state_factor = GameBalance.get_number("horn_move_multiplier")
		elif state == State.HORN_RECOVERY:
			state_factor = GameBalance.get_number("horn_recovery_move_multiplier")
		desired = move_dir.normalized() * GameBalance.get_number("walk_speed") * direction_factor * state_factor * terrain_factor
	var rate := GameBalance.get_number("acceleration") if desired.length_squared() > 0.0 else GameBalance.get_number("deceleration")
	velocity.x = move_toward(velocity.x, desired.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired.z, rate * delta)
	velocity.y = 0.0
	move_and_slide()
	if state == State.STUNNED:
		knockback = Vector3(velocity.x, 0.0, velocity.z)


func update_facing(delta: float) -> void:
	if not active or state in [State.STUNNED, State.CLASH, State.FLEE, State.DASH_ACTIVE, State.HORN_STARTUP, State.HORN_ACTIVE]:
		return
	var target_yaw := camera_yaw
	var max_step := GameBalance.get_angle("turn_rate_deg_s") * delta
	rotation.y = wrapf(rotation.y + clampf(angle_difference(rotation.y, target_yaw), -max_step, max_step), -PI, PI)
	facing = Vector3(-sin(rotation.y), 0.0, -cos(rotation.y)).normalized()


func mark_flee() -> void:
	active = false
	guarding = false
	state = State.FLEE
	velocity = Vector3.ZERO


func freeze() -> void:
	active = false
	velocity = Vector3.ZERO
	guarding = false
