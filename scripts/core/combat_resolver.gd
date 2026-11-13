class_name CombatResolver
extends RefCounted
## HORN/DASH hit detection and SPIRIT/knockback resolution. Hits are evaluated A→B and B→A from
## the same snapshot; two committed attacks aimed at each other start a CLASH instead.

var controller: MatchController


func _init(owner: MatchController) -> void:
	controller = owner


func resolve_attacks() -> void:
	var player := controller.player
	var opponent := controller.opponent
	var a_hits_b := attack_valid(player, opponent)
	var b_hits_a := attack_valid(opponent, player)
	var a_committed := aims_at(player, opponent)
	var b_committed := aims_at(opponent, player)
	if controller.clash.cooldown <= 0.0 and ((a_hits_b and b_committed) or (b_hits_a and a_committed)):
		var bias := 0.0
		if player.attack_kind == &"DASH" and opponent.attack_kind == &"HORN":
			bias = GameBalance.get_number("dash_clash_bias")
		elif opponent.attack_kind == &"DASH" and player.attack_kind == &"HORN":
			bias = -GameBalance.get_number("dash_clash_bias")
		controller.clash.enter(bias)
		return
	if a_hits_b:
		apply_hit(player, opponent)
	if b_hits_a:
		apply_hit(opponent, player)


func attack_valid(attacker: Buffalo, target: Buffalo) -> bool:
	if not attacker.is_attack_active() or attacker.hit_targets.has(target.slot):
		return false
	if attacker.state == Buffalo.State.HORN_ACTIVE:
		return in_reach(attacker, target, &"HORN")
	if attacker.state == Buffalo.State.DASH_ACTIVE:
		return in_reach(attacker, target, &"DASH")
	return false


## True while a committed attack (startup or active) points at the target within reach.
func aims_at(attacker: Buffalo, target: Buffalo) -> bool:
	if not attacker.is_committed():
		return false
	return in_reach(attacker, target, attacker.attack_kind)


## Gap from the attacker's head capsule to the target's nearest capsule, plus the cone check.
func in_reach(attacker: Buffalo, target: Buffalo, kind: StringName) -> bool:
	var offset := target.global_position - attacker.global_position
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		return false
	var dot := attacker.forward().dot(offset.normalized())
	var gap := ArenaBounds.head_gap(attacker, target)
	if kind == &"HORN":
		return gap <= GameBalance.get_number("horn_reach") and dot >= cos(GameBalance.get_angle("horn_half_angle"))
	if kind == &"DASH":
		return gap <= GameBalance.get_number("dash_hit_gap") and dot >= cos(GameBalance.get_angle("dash_half_angle"))
	return false


func apply_hit(attacker: Buffalo, target: Buffalo) -> void:
	if attacker.hit_targets.has(target.slot):
		return
	attacker.hit_targets[target.slot] = true
	if target.hit_invulnerability > 0.0:
		return
	var offset := target.global_position - attacker.global_position
	offset.y = 0.0
	var away := offset.normalized()
	var facing_dot := target.forward().dot(-away)
	if target.state == Buffalo.State.PARRY_ACTIVE and facing_dot + 0.000001 >= cos(GameBalance.get_angle("parry_half_angle")):
		var duration_key := "parry_stun_horn_s" if attacker.attack_kind == &"HORN" else "parry_stun_dash_s"
		attacker.apply_stun(GameBalance.get_number(duration_key), -away * GameBalance.get_number("parry_recoil_speed"))
		attacker.parry_recoil = true
		target.parry_success()
		controller.combat_event.emit(&"PARRY_SUCCESS", target.slot, attacker.slot, 0.0)
		return
	attacker.attack_connected = true
	var guard_valid := target.guarding and facing_dot + 0.000001 >= cos(GameBalance.get_angle("guard_half_angle"))
	var damage := GameBalance.get_number("horn_damage") if attacker.attack_kind == &"HORN" else GameBalance.get_number("dash_damage")
	var knockback := GameBalance.get_number("knockback_speed")
	var bonus := GameBalance.get_number("counter_damage_multiplier") if attacker.counter_attack else 1.0
	var angle := acos(clampf(facing_dot, -1.0, 1.0))
	var side: StringName = &"NONE"
	if angle > GameBalance.get_angle("back_min_deg") + 0.000001:
		bonus = maxf(bonus, GameBalance.get_number("back_damage_multiplier"))
		side = &"BACK_HIT"
	elif angle > GameBalance.get_angle("flank_min_deg") + 0.000001:
		bonus = maxf(bonus, GameBalance.get_number("flank_damage_multiplier"))
		side = &"FLANK_HIT"
	if guard_valid:
		damage *= GameBalance.get_number("guard_damage_multiplier")
		knockback *= GameBalance.get_number("guard_knockback_multiplier")
		controller.combat_event.emit(&"GUARD_HIT", attacker.slot, target.slot, 0.0)
	if ArenaBounds.is_pinned(target, away):
		bonus = maxf(bonus, GameBalance.get_number("pinned_spirit_multiplier"))
	damage = roundi(damage * bonus)
	target.receive_spirit(damage, away * knockback, not guard_valid)
	target.hit_invulnerability = GameBalance.get_number("hit_invulnerability_s")
	controller.combat_event.emit(&"HORN_HIT" if attacker.attack_kind == &"HORN" else &"DASH_HIT", attacker.slot, target.slot, damage)
	if attacker.counter_attack:
		controller.combat_event.emit(&"COUNTER_HIT", attacker.slot, target.slot, damage)
	if side != &"NONE":
		controller.combat_event.emit(side, attacker.slot, target.slot, damage)
	controller.resource_changed.emit(target.slot, target.spirit, target.stamina)
