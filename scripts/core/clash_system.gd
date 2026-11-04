class_name ClashSystem
extends RefCounted
## Horn-lock tug-of-war (CLASH): PUSH moves the shared balance, HOOK adds a burst after a
## startup, RELEASE punishes a hooker in startup or costs the releaser. Slot A is the player.

var controller: MatchController
## Empty when no CLASH is running; otherwise {"a", "b", "time", "lock_balance", ...blend data}.
var active: Dictionary = {}
var cooldown := 0.0


func _init(owner: MatchController) -> void:
	controller = owner


func is_active() -> bool:
	return not active.is_empty()


func tick_cooldown(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)


func enter(bias: float) -> void:
	if not active.is_empty():
		return
	var player := controller.player
	var opponent := controller.opponent
	player.begin_clash(opponent)
	opponent.begin_clash(player)
	var direction := (opponent.global_position - player.global_position)
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.RIGHT
	direction = direction.normalized()
	var midpoint := (player.global_position + opponent.global_position) * 0.5
	var half := GameBalance.get_number("clash_distance") * 0.5
	# The lock pose is reached over clash_enter_blend_s instead of teleporting.
	active = {
		"a": player,
		"b": opponent,
		"time": 0.0,
		"lock_balance": bias,
		"blend": 0.0,
		"slide_speed": 0.0,
		"from_a": player.global_position,
		"from_b": opponent.global_position,
		"to_a": midpoint - direction * half,
		"to_b": midpoint + direction * half,
		"yaw_from_a": player.rotation.y,
		"yaw_from_b": opponent.rotation.y,
		"yaw_to_a": atan2(-direction.x, -direction.z),
		"yaw_to_b": atan2(direction.x, direction.z)
	}
	controller.combat_event.emit(&"CLASH_START", player.slot, opponent.slot, bias)


## Moves both buffaloes toward the lock pose; true while the blend is still running.
func _blend(a: Buffalo, b: Buffalo, delta: float) -> bool:
	var duration := GameBalance.get_number("clash_enter_blend_s", 0.1)
	var elapsed := float(active.get("blend", duration))
	if elapsed >= duration:
		return false
	elapsed = minf(duration, elapsed + delta)
	active["blend"] = elapsed
	var weight := 1.0 if duration <= 0.0 else smoothstep(0.0, 1.0, elapsed / duration)
	a.global_position = Vector3(active["from_a"]).lerp(active["to_a"], weight)
	b.global_position = Vector3(active["from_b"]).lerp(active["to_b"], weight)
	a.rotation.y = lerp_angle(float(active["yaw_from_a"]), float(active["yaw_to_a"]), weight)
	b.rotation.y = lerp_angle(float(active["yaw_from_b"]), float(active["yaw_to_b"]), weight)
	a.facing = Vector3(-sin(a.rotation.y), 0.0, -cos(a.rotation.y))
	b.facing = Vector3(-sin(b.rotation.y), 0.0, -cos(b.rotation.y))
	_fit_pair(a, b)
	return true


func process(delta: float, a_frame: InputFrame, b_frame: InputFrame) -> void:
	var a: Buffalo = active["a"]
	var b: Buffalo = active["b"]
	active["time"] += delta
	var blending := _blend(a, b, delta)
	var a_choice := choice_for(a_frame)
	var b_choice := choice_for(b_frame)
	if a_choice == &"RELEASE" or b_choice == &"RELEASE":
		if a_choice == &"RELEASE" and b_choice == &"RELEASE":
			end(0.0, &"CLASH_RELEASE")
		elif a_choice == &"RELEASE":
			if is_hooking(b, b_choice):
				_apply_whiff(b)
			else:
				_apply_release(a)
		elif is_hooking(a, a_choice):
			_apply_whiff(a)
		else:
			_apply_release(b)
		return
	start_hook(a, b, a_choice)
	start_hook(b, a, b_choice)
	advance_hooks(a, b, delta)
	var push_a := push_strength(a, a_choice)
	var push_b := push_strength(b, b_choice)
	a.consume_stamina(GameBalance.get_number("lock_stamina_per_s") * delta if push_a > 0.0 else 0.0)
	b.consume_stamina(GameBalance.get_number("lock_stamina_per_s") * delta if push_b > 0.0 else 0.0)
	active["lock_balance"] = clampf(
		float(active["lock_balance"]) + (push_a - push_b) * GameBalance.get_number("lock_rate") * delta,
		-GameBalance.get_number("lock_balance_max", 100.0),
		GameBalance.get_number("lock_balance_max", 100.0)
	)
	if not blending:
		_slide(a, b, push_a - push_b, delta)
	if absf(float(active["lock_balance"])) >= GameBalance.get_number("lock_balance_max", 100.0):
		var loser := b if float(active["lock_balance"]) > 0.0 else a
		apply_loss(loser, GameBalance.get_number("lock_loss_spirit"), GameBalance.get_number("lock_loss_stun_s"), GameBalance.get_number("lock_loss_knockback_multiplier"))
		end(float(active["lock_balance"]), &"CLASH_BREAK")
	elif active["time"] >= GameBalance.get_number("lock_max_s"):
		var balance := float(active["lock_balance"])
		var loss := GameBalance.get_number("lock_split_min_spirit") if is_zero_approx(balance) else _split_loss(balance)
		if balance > 0.0:
			apply_loss(b, loss)
		elif balance < 0.0:
			apply_loss(a, loss)
		end(balance, &"CLASH_TIME")


## The match timer ran out mid-CLASH: the side behind on balance takes the split loss.
func resolve_timeout() -> void:
	if active.is_empty():
		return
	var balance := float(active["lock_balance"])
	if not is_zero_approx(balance):
		apply_loss(active["b"] if balance > 0.0 else active["a"], _split_loss(balance))
	end(balance, &"CLASH_TIME")


## Hook already in startup, or pressed this tick with enough stamina to start.
func is_hooking(actor: Buffalo, choice: StringName) -> bool:
	return actor.clash_hooked or (choice == &"HOOK" and actor.stamina >= GameBalance.get_number("horn_cost"))


func choice_for(frame: InputFrame) -> StringName:
	if frame.guard_pressed:
		return &"RELEASE"
	if frame.horn_pressed:
		return &"HOOK"
	if frame.clash_action == &"HOOK" or frame.clash_action == &"RELEASE":
		return frame.clash_action
	return &"PUSH"


func push_strength(actor: Buffalo, choice: StringName) -> float:
	if choice != &"PUSH" or actor.stamina <= 0.0:
		return 0.0
	var partner := actor.clash_partner
	if not is_instance_valid(partner):
		return 0.0
	var toward := (partner.global_position - actor.global_position).normalized()
	var camera_forward := Vector3(-sin(actor.input_frame.camera_yaw), 0.0, -cos(actor.input_frame.camera_yaw))
	var camera_right := Vector3(cos(actor.input_frame.camera_yaw), 0.0, -sin(actor.input_frame.camera_yaw))
	var move_dir := actor.movement_world(actor.input_frame, camera_forward, camera_right)
	if move_dir.length_squared() <= 0.001 or move_dir.normalized().dot(toward) < 0.5:
		return 0.0
	return GameBalance.get_number("lock_push_base") + GameBalance.get_number("lock_push_stamina_scale") * actor.stamina / GameBalance.get_number("stamina_max")


func start_hook(actor: Buffalo, other: Buffalo, choice: StringName) -> void:
	if choice == &"HOOK" and not actor.clash_hooked and actor.stamina >= GameBalance.get_number("horn_cost"):
		actor.consume_stamina(GameBalance.get_number("horn_cost"))
		actor.clash_hooked = true
		actor.clash_hook_time = GameBalance.get_number("lock_hook_startup_s")
		controller.combat_event.emit(&"CLASH_HOOK", actor.slot, other.slot, 0.0)


func advance_hooks(a: Buffalo, b: Buffalo, delta: float) -> void:
	if a.clash_hooked:
		a.clash_hook_time -= delta
	if b.clash_hooked:
		b.clash_hook_time -= delta
	var a_complete := a.clash_hooked and a.clash_hook_time <= 0.0
	var b_complete := b.clash_hooked and b.clash_hook_time <= 0.0
	if (a_complete and b.clash_hooked) or (b_complete and a.clash_hooked):
		a.clash_hooked = false
		b.clash_hooked = false
		return
	if a_complete:
		a.clash_hooked = false
		active["lock_balance"] = float(active["lock_balance"]) + GameBalance.get_number("lock_hook_power")
	elif b_complete:
		b.clash_hooked = false
		active["lock_balance"] = float(active["lock_balance"]) - GameBalance.get_number("lock_hook_power")


func apply_loss(actor: Buffalo, amount: float, stun_s: float = -1.0, knockback_multiplier: float = 1.0) -> void:
	var direction := (actor.global_position - actor.clash_partner.global_position).normalized()
	if ArenaBounds.is_pinned(actor, direction):
		amount *= GameBalance.get_number("pinned_spirit_multiplier")
	var impulse := direction * GameBalance.get_number("knockback_speed") * knockback_multiplier
	actor.receive_spirit(amount, impulse, false)
	actor.apply_stun(stun_s if stun_s >= 0.0 else GameBalance.get_number("hitstun_s"), impulse)
	controller.combat_event.emit(&"CLASH_LOSS", actor.clash_partner.slot, actor.slot, amount)


func end(_balance: float, event_name: StringName) -> void:
	if active.is_empty():
		return
	var a: Buffalo = active["a"]
	var b: Buffalo = active["b"]
	if a.state == Buffalo.State.CLASH:
		a.state = Buffalo.State.NORMAL
	if b.state == Buffalo.State.CLASH:
		b.state = Buffalo.State.NORMAL
	# A loser keeps the knockback applied by apply_loss(); everyone else stops dead.
	if a.knockback_time <= 0.0:
		a.velocity = Vector3.ZERO
	if b.knockback_time <= 0.0:
		b.velocity = Vector3.ZERO
	a.clash_partner = null
	b.clash_partner = null
	a.clash_hooked = false
	b.clash_hooked = false
	active.clear()
	cooldown = GameBalance.get_number("clash_cooldown_s")
	controller.combat_event.emit(event_name, a.slot, b.slot, 0.0)


func _split_loss(balance: float) -> float:
	return maxf(GameBalance.get_number("lock_split_min_spirit"), roundf(absf(balance) * GameBalance.get_number("lock_split_spirit_per_point")))


func _apply_whiff(hooker: Buffalo) -> void:
	apply_loss(hooker, GameBalance.get_number("lock_whiff_spirit"), GameBalance.get_number("lock_whiff_stun_s"))
	end(0.0, &"CLASH_WHIFF")


func _apply_release(releaser: Buffalo) -> void:
	var balance := float(active["lock_balance"])
	var releaser_sign := 1.0 if releaser == active["a"] else -1.0
	var advantage := maxf(0.0, -balance * releaser_sign)
	var loss := GameBalance.get_number("lock_release_spirit_base") + advantage * GameBalance.get_number("lock_release_spirit_per_point")
	apply_loss(releaser, loss, GameBalance.get_number("lock_release_stun_s"))
	end(float(active["lock_balance"]), &"CLASH_RELEASE")


func _slide(a: Buffalo, b: Buffalo, difference: float, delta: float) -> void:
	var target := difference * GameBalance.get_number("lock_slide_speed")
	var speed := float(active.get("slide_speed", 0.0))
	var braking := is_zero_approx(target) or speed * target < 0.0 or absf(target) < absf(speed)
	var rate := GameBalance.get_number("clash_slide_deceleration", 12.0) if braking else GameBalance.get_number("clash_slide_acceleration", 6.0)
	# A reversal brakes to rest first; it never instantly flips the pair's momentum.
	var next := move_toward(speed, 0.0 if speed * target < 0.0 else target, rate * delta)
	var direction := (b.global_position - a.global_position).normalized()
	var before := (a.global_position + b.global_position) * 0.5
	var travel := (speed + next) * 0.5 * delta
	var midpoint := before + direction * travel
	var separation := GameBalance.get_number("clash_distance")
	a.global_position = midpoint - direction * separation * 0.5
	b.global_position = midpoint + direction * separation * 0.5
	_fit_pair(a, b)
	# Discard blocked momentum instead of banking it against the fence.
	var actual := ((a.global_position + b.global_position) * 0.5 - before).dot(direction)
	if absf(actual) + 0.00001 < absf(travel):
		next = 0.0
	active["slide_speed"] = next


## Keeps the pair inside the arena by moving both together, so a locked pair never gets squeezed
## below clash_distance when one buffalo is against the fence.
func _fit_pair(a: Buffalo, b: Buffalo) -> void:
	for pass_index in 3:
		var before_a := a.global_position
		var before_b := b.global_position
		ArenaBounds.constrain(a)
		ArenaBounds.constrain(b)
		var shift_a := a.global_position - before_a
		var shift_b := b.global_position - before_b
		if shift_a.length_squared() < 0.000001 and shift_b.length_squared() < 0.000001:
			return
		var shift := shift_a if shift_a.length_squared() > shift_b.length_squared() else shift_b
		a.global_position = before_a + shift
		b.global_position = before_b + shift
