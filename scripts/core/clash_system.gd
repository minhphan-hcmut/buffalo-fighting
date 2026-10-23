class_name ClashSystem
extends RefCounted
## Horn-lock tug-of-war (CLASH): PUSH moves the shared balance, HOOK adds a burst after a
## startup, RELEASE punishes a hooker in startup or costs the releaser. Slot A is the player.

var controller: MatchController
## Empty when no CLASH is running; otherwise {"a", "b", "time", "balance"}.
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
	active = {"a": player, "b": opponent, "time": 0.0, "balance": bias}
	var direction := (opponent.global_position - player.global_position)
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.RIGHT
	direction = direction.normalized()
	var midpoint := (player.global_position + opponent.global_position) * 0.5
	var separation := GameBalance.get_number("buffalo_radius") * 2.0
	player.global_position = midpoint - direction * separation * 0.5
	opponent.global_position = midpoint + direction * separation * 0.5
	player.rotation.y = atan2(-direction.x, -direction.z)
	opponent.rotation.y = atan2(direction.x, direction.z)
	player.facing = direction
	opponent.facing = -direction
	controller.combat_event.emit(&"CLASH_START", player.slot, opponent.slot, bias)


func process(delta: float, a_frame: InputFrame, b_frame: InputFrame) -> void:
	var a: Buffalo = active["a"]
	var b: Buffalo = active["b"]
	active["time"] += delta
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
	active["balance"] = clampf(
		float(active["balance"]) + (push_a - push_b) * GameBalance.get_number("lock_rate") * delta,
		-100.0,
		100.0
	)
	_slide(a, b, push_a - push_b, delta)
	if absf(float(active["balance"])) >= 100.0:
		var loser := b if float(active["balance"]) > 0.0 else a
		apply_loss(loser, GameBalance.get_number("lock_loss_spirit"), GameBalance.get_number("lock_loss_stun_s"), GameBalance.get_number("lock_loss_knockback_multiplier"))
		end(float(active["balance"]), &"CLASH_BREAK")
	elif active["time"] >= GameBalance.get_number("lock_max_s"):
		var balance := float(active["balance"])
		var loss := 3.0 if is_zero_approx(balance) else _split_loss(balance)
		if balance > 0.0:
			apply_loss(b, loss)
		elif balance < 0.0:
			apply_loss(a, loss)
		end(balance, &"CLASH_TIME")


## The match timer ran out mid-CLASH: the side behind on balance takes the split loss.
func resolve_timeout() -> void:
	if active.is_empty():
		return
	var balance := float(active["balance"])
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
	return 0.5 + 0.5 * actor.stamina / GameBalance.get_number("stamina_max")


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
		active["balance"] = float(active["balance"]) + GameBalance.get_number("lock_hook_power")
	elif b_complete:
		b.clash_hooked = false
		active["balance"] = float(active["balance"]) - GameBalance.get_number("lock_hook_power")


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
	a.clash_partner = null
	b.clash_partner = null
	a.clash_hooked = false
	b.clash_hooked = false
	active.clear()
	cooldown = GameBalance.get_number("clash_cooldown_s")
	controller.combat_event.emit(event_name, a.slot, b.slot, 0.0)


func _split_loss(balance: float) -> float:
	return maxf(3.0, roundf(absf(balance) * GameBalance.get_number("lock_split_spirit_per_point")))


func _apply_whiff(hooker: Buffalo) -> void:
	apply_loss(hooker, GameBalance.get_number("lock_whiff_spirit"), GameBalance.get_number("lock_whiff_stun_s"))
	end(0.0, &"CLASH_WHIFF")


func _apply_release(releaser: Buffalo) -> void:
	var balance := float(active["balance"])
	var releaser_sign := 1.0 if releaser == active["a"] else -1.0
	var advantage := maxf(0.0, -balance * releaser_sign)
	var loss := GameBalance.get_number("lock_release_spirit_base") + advantage * GameBalance.get_number("lock_release_spirit_per_point")
	apply_loss(releaser, loss, GameBalance.get_number("lock_release_stun_s"))
	end(float(active["balance"]), &"CLASH_RELEASE")


func _slide(a: Buffalo, b: Buffalo, difference: float, delta: float) -> void:
	if is_zero_approx(difference):
		return
	var direction := (b.global_position - a.global_position).normalized()
	var midpoint := (a.global_position + b.global_position) * 0.5
	midpoint += direction * signf(difference) * GameBalance.get_number("lock_slide_speed") * absf(difference) * delta
	var separation := GameBalance.get_number("buffalo_radius") * 2.0
	a.global_position = midpoint - direction * separation * 0.5
	b.global_position = midpoint + direction * separation * 0.5
	ArenaBounds.constrain(a)
	ArenaBounds.constrain(b)
