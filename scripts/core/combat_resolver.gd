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
	var offset := target.global_position - attacker.global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= 0.001:
		return false
	var direction := offset.normalized()
	var facing_dot := attacker.forward().dot(direction)
	if attacker.state == Buffalo.State.HORN_ACTIVE:
		return distance <= GameBalance.get_number("horn_range") and facing_dot >= cos(GameBalance.get_angle("horn_half_angle"))
	if attacker.state == Buffalo.State.DASH_ACTIVE:
		return distance <= GameBalance.get_number("buffalo_radius") * 2.0 + 0.1 and facing_dot >= cos(GameBalance.get_angle("dash_half_angle"))
	return false


## True while a committed attack (startup or active) points at the target within range.
func aims_at(attacker: Buffalo, target: Buffalo) -> bool:
	if not attacker.is_committed():
		return false
	var offset := target.global_position - attacker.global_position
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		return false
	var dot := attacker.forward().dot(offset.normalized())
	if attacker.attack_kind == &"HORN":
		return offset.length() <= GameBalance.get_number("horn_range") and dot >= cos(GameBalance.get_angle("horn_half_angle"))
	if attacker.attack_kind == &"DASH":
		return offset.length() <= GameBalance.get_number("buffalo_radius") * 2.0 + 0.1 and dot >= cos(GameBalance.get_angle("dash_half_angle"))
	return false


func apply_hit(attacker: Buffalo, target: Buffalo) -> void:
	if attacker.hit_targets.has(target.slot):
		return
	attacker.hit_targets[target.slot] = true
	var offset := target.global_position - attacker.global_position
	offset.y = 0.0
	var away := offset.normalized()
	var guard_valid := target.guarding and target.forward().dot(-away) >= cos(GameBalance.get_angle("guard_half_angle"))
	var damage := GameBalance.get_number("horn_damage") if attacker.attack_kind == &"HORN" else GameBalance.get_number("dash_damage")
	var knockback := GameBalance.get_number("knockback_speed")
	if guard_valid:
		damage *= GameBalance.get_number("guard_damage_multiplier")
		knockback *= GameBalance.get_number("guard_knockback_multiplier")
	if ArenaBounds.is_pinned(target, away):
		damage *= GameBalance.get_number("pinned_spirit_multiplier")
	damage = roundi(damage)
	if target.hit_invulnerability <= 0.0:
		target.receive_spirit(damage, away * knockback, not guard_valid)
		target.hit_invulnerability = GameBalance.get_number("hit_invulnerability_s")
		controller.combat_event.emit(&"HORN_HIT" if attacker.attack_kind == &"HORN" else &"DASH_HIT", attacker.slot, target.slot, damage)
		controller.resource_changed.emit(target.slot, target.spirit, target.stamina)
	if target.state == Buffalo.State.HORN_STARTUP:
		target.state = Buffalo.State.NORMAL
		target.attack_kind = &"NONE"
