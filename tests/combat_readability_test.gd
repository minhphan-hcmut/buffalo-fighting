extends SceneTree

const DT := 1.0 / 60.0
var failures := 0
var checks := 0
var arena: MatchController
var a: Buffalo
var b: Buffalo


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	arena = load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	arena.start_playing()
	a = arena.player
	b = arena.opponent
	_config()
	_horn_timing()
	await _parry()
	_counter_and_angles()
	_hitstop()
	_presentation_and_input()
	arena.free()
	print("READABILITY: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)


func duel() -> void:
	arena.active_clash.clear()
	arena.clash.cooldown = 0.0
	arena.hitstop_ticks = 0
	arena.remaining_time = 90.0
	for actor: Buffalo in [a, b]:
		actor.reset_combat()
		actor.position = Vector3.ZERO if actor == a else Vector3(0.0, 0.0, -2.9)
		actor.rotation.y = 0.0 if actor == a else PI
		actor.camera_yaw = actor.rotation.y
		actor.facing = Vector3.FORWARD if actor == a else Vector3.BACK


func active_horn() -> void:
	a.start_horn()
	a.advance_state(a.state_duration)


func frame(actor: Buffalo, action: String = "") -> InputFrame:
	var result := InputFrame.new(actor.slot)
	result.camera_yaw = actor.rotation.y
	result.horn_pressed = action == "horn"
	result.parry_pressed = action == "parry"
	return result


func _config() -> void:
	var expected := {
		"horn_startup_s": 0.25, "horn_whiff_recovery_s": 0.4, "parry_active_s": 0.15,
		"parry_whiff_recovery_s": 0.45, "parry_stamina_cost": 10.0, "parry_cooldown_s": 0.8,
		"parry_half_angle": 60.0, "parry_stun_horn_s": 0.5, "parry_stun_dash_s": 0.7,
		"parry_recoil_speed": 2.0, "parry_move_multiplier": 0.3, "parry_whiff_move_multiplier": 0.5,
		"counter_window_s": 0.5, "counter_horn_startup_s": 0.08, "counter_damage_multiplier": 1.3,
		"flank_min_deg": 60.0, "back_min_deg": 120.0, "flank_damage_multiplier": 1.25,
		"back_damage_multiplier": 1.25, "hitstop_hit_ticks": 4, "hitstop_heavy_ticks": 6,
		"horn_startup_head_pitch_deg": 18.0
	}
	for key: String in expected:
		check(GameBalance.values.has(key) and is_equal_approx(GameBalance.get_number(key), float(expected[key])), "balance data: " + key)
	check(is_equal_approx(GameBalance.get_number("parry_half_angle"), GameBalance.get_number("guard_half_angle")), "parry and guard share front cone")
	duel()
	var old := GameBalance.get_number("parry_active_s")
	GameBalance.values["parry_active_s"] = 0.19
	b.start_parry()
	check(is_equal_approx(b.state_duration, 0.19), "parry duration is read from data at action start")
	GameBalance.values["parry_active_s"] = old


func _horn_timing() -> void:
	duel()
	a.start_horn()
	for i in 14:
		a.advance_state(DT)
		arena.combat.resolve_attacks()
	check(b.spirit == 100.0 and a.state == Buffalo.State.HORN_STARTUP, "no HORN hit before 0.25 s")
	a.advance_state(DT)
	arena.combat.resolve_attacks()
	check(b.spirit == 82.0 and a.state == Buffalo.State.HORN_ACTIVE, "first HORN hit at 0.25 s / tick 15")
	a.advance_state(a.state_duration)
	check(is_equal_approx(a.state_duration, 0.2), "connected HORN recovers for 0.20 s")
	duel()
	active_horn()
	a.advance_state(a.state_duration)
	check(a.state == Buffalo.State.HORN_RECOVERY and is_equal_approx(a.state_duration, 0.4), "whiff HORN recovers for 0.40 s")
	duel()
	b.begin_input(_guard(b))
	active_horn()
	arena.combat.resolve_attacks()
	check(b.spirit == 92.0 and b.state == Buffalo.State.GUARD, "GUARD remains x0.45 with no stun")
	check(is_equal_approx(b.velocity.length(), GameBalance.get_number("knockback_speed") * 0.6), "GUARD knockback remains x0.60")
	a.advance_state(a.state_duration)
	check(is_equal_approx(a.state_duration, 0.2), "guarded HORN recovers for 0.20 s")


func _guard(actor: Buffalo) -> InputFrame:
	var result := frame(actor)
	result.guard_held = true
	return result


func _parry() -> void:
	for kind in ["horn", "dash"]:
		duel()
		if kind == "horn":
			active_horn()
		else:
			a.start_dash()
		b.begin_input(frame(b, "parry"))
		check(b.stamina == 90.0 and is_equal_approx(b.parry_cooldown, 0.8), "PARRY costs 10 and starts 0.8 cooldown")
		arena.combat.resolve_attacks()
		check(b.spirit == 100.0 and b.velocity == Vector3.ZERO and b.state == Buffalo.State.NORMAL, "same-tick G parries " + kind)
		check(a.state == Buffalo.State.STUNNED and is_equal_approx(a.state_duration, 0.5 if kind == "horn" else 0.7), "parry stun for " + kind)
		check(is_equal_approx(a.velocity.length(), 2.0) and a.hit_invulnerability == 0.0, "parried attacker recoils at 2 m/s without immunity")
		check(arena.active_clash.is_empty() and is_equal_approx(b.counter_window, 0.5), "PARRY opens counter and never clashes")
		var origin := a.position
		for i in 18:
			await physics_frame
			a.simulate_movement(DT, Vector3.ZERO, 1.0)
			a.update_timers(DT)
		check(absf(a.position.distance_to(origin) - 0.6) < 0.04, "parry recoil travels about 0.6 m")
	duel()
	active_horn()
	b.start_parry()
	b.hit_invulnerability = 0.45
	arena.combat.resolve_attacks()
	check(b.state == Buffalo.State.PARRY_ACTIVE and b.spirit == 100.0 and a.state == Buffalo.State.HORN_ACTIVE and b.counter_window == 0.0, "immunity is checked before PARRY")
	duel()
	b.start_parry()
	b.advance_state(0.15)
	check(b.state == Buffalo.State.PARRY_RECOVERY and is_equal_approx(b.state_duration, 0.45), "missed PARRY has 0.45 recovery")
	active_horn()
	arena.combat.resolve_attacks()
	check(b.spirit == 82.0, "PARRY recovery takes full front damage")
	duel()
	b.start_parry()
	b.advance_state(0.15)
	b.update_timers(0.15)
	b.advance_state(0.45)
	b.update_timers(0.45)
	check(not b.start_parry(), "G blocked after recovery until cooldown expires")
	b.update_timers(0.2)
	check(b.start_parry(), "G usable again at 0.8 seconds")
	duel()
	b.begin_input(_guard(b))
	var g := _guard(b)
	g.parry_pressed = true
	b.begin_input(g)
	check(b.state == Buffalo.State.PARRY_ACTIVE and not b.guarding, "G interrupts held GUARD")
	b.advance_state(0.15)
	b.advance_state(0.45)
	b.begin_input(_guard(b))
	check(b.guarding and b.state == Buffalo.State.GUARD, "held GUARD resumes after PARRY recovery")
	duel()
	a.start_horn()
	a.begin_input(frame(a, "parry"))
	check(a.state == Buffalo.State.HORN_STARTUP and a.buffered_action == &"PARRY", "G buffers while committed")
	duel()
	a.start_horn()
	b.start_dash()
	b.hit_invulnerability = 0.45
	arena.combat.resolve_attacks()
	check(arena.clash.is_active(), "CLASH still precedes immunity")
	check(not b.start_parry(), "G cannot start during CLASH")
	duel()
	b.stamina = 9.0
	check(not b.start_parry(), "G validates stamina")
	b.stamina = 100.0
	b.apply_stun(0.5, Vector3.ZERO)
	check(not b.start_parry(), "G cannot start while stunned")
	b.mark_flee()
	check(not b.start_parry(), "G cannot start while fleeing")
	duel()
	b.start_parry()
	b.camera_yaw = 0.0
	b.update_facing(1.0)
	check(is_equal_approx(b.rotation.y, PI), "PARRY active locks body turning")
	await physics_frame
	b.simulate_movement(1.0, b.forward(), 1.0)
	check(is_equal_approx(b.velocity.length(), GameBalance.get_number("walk_speed") * 0.3), "PARRY active movement x0.30")
	b.advance_state(0.15)
	b.simulate_movement(1.0, b.forward(), 1.0)
	check(is_equal_approx(b.velocity.length(), GameBalance.get_number("walk_speed") * 0.5), "PARRY whiff movement x0.50")
	duel()
	b.state = Buffalo.State.HORN_RECOVERY
	b.state_duration = 0.2
	b.state_time = 0.15
	b.begin_input(frame(b, "parry"))
	b.advance_state(0.05)
	b.update_timers(0.05)
	b.begin_input(_guard(b))
	check(b.state == Buffalo.State.PARRY_ACTIVE, "buffered G starts when recovery ends, including held GUARD")
	duel()
	b.parry_cooldown = 0.05
	b.begin_input(frame(b, "parry"))
	b.begin_input(frame(b))
	b.update_timers(0.05)
	b.begin_input(frame(b))
	check(b.state == Buffalo.State.PARRY_ACTIVE, "buffered G survives unsuccessful attempts until its cooldown ends")


func _counter_and_angles() -> void:
	duel()
	active_horn()
	b.start_parry()
	arena.combat.resolve_attacks()
	b.start_horn()
	check(b.counter_attack and is_equal_approx(b.state_duration, 0.08) and b.counter_window == 0.0, "counter starts in window with 0.08 startup and consumes window")
	b.advance_state(0.08)
	arena.combat.resolve_attacks()
	check(a.spirit == 77.0 and arena.hitstop_ticks == 6, "front counter deals 23 with heavy hitstop")
	for angle in [60.0, 90.0, 120.0, 180.0]:
		duel()
		b.position.z = -2.4
		b.rotation.y = PI + deg_to_rad(angle)
		b.facing = YawBasis.forward(b.rotation.y)
		b.start_parry()
		active_horn()
		arena.combat.resolve_attacks()
		check(b.spirit == (100.0 if angle == 60.0 else 77.0), "PARRY front/flank/back boundary %.0f degrees" % angle)
	for counter in [false, true]:
		duel()
		b.position = Vector3(0, 0, -10.0)
		a.position = b.position + Vector3(0, 0, 2.9)
		b.facing = Vector3.FORWARD
		active_horn()
		a.counter_attack = counter
		check(ArenaBounds.is_pinned(b, Vector3.FORWARD), "pinned fixture touches fence")
		arena.combat.resolve_attacks()
		check(b.spirit == 73.0, "pinned/back/counter bonuses take max, damage 27")
	for cancel in ["dash", "parry", "hit", "clash", "expiry"]:
		duel()
		b.parry_success()
		match cancel:
			"dash": b.start_dash()
			"parry": b.start_parry()
			"hit": b.receive_spirit(1.0, Vector3.ZERO, false)
			"clash": b.begin_clash(a)
			"expiry": b.update_timers(0.5)
		check(b.counter_window == 0.0, "counter window closes on " + cancel)
	duel()
	a.counter_window = 0.5
	active_horn()
	b.begin_input(_guard(b))
	arena.combat.resolve_attacks()
	check(b.spirit == 89.0, "counter obeys GUARD: round(18 x .45 x 1.3) = 11")


func _hitstop() -> void:
	for event in [&"HORN_HIT", &"DASH_HIT", &"PARRY_SUCCESS", &"COUNTER_HIT", &"CLASH_START"]:
		duel()
		a.start_horn()
		b.stamina = 50.0
		arena.combat_event.emit(event, 1, 2, 0.0)
		var count := 4 if event in [&"HORN_HIT", &"DASH_HIT"] else 6
		check(arena.hitstop_ticks == count, "hitstop length for " + String(event))
		var before := [a.position, a.stamina, a.state_time, a.horn_cooldown, arena.remaining_time]
		for i in count:
			arena.simulate_tick(DT, frame(a, "parry") if i == 0 else frame(a), frame(b))
		check(before == [a.position, a.stamina, a.state_time, a.horn_cooldown, arena.remaining_time] and arena.hitstop_ticks == 0, "positions, stamina, action, cooldown and clock freeze exactly H ticks")
		check(b.stamina == 50.0, "STAMINA regeneration also freezes during hitstop")
		check(a.buffered_action == &"PARRY" and is_equal_approx(a.input_buffer_time, 0.1), "hitstop captures input and freezes its buffer")
		arena.simulate_tick(DT, frame(a), frame(b))
		check(a.state_time > 0.0 and arena.remaining_time < float(before[4]), "simulation resumes after H frozen ticks")
	duel()
	arena.combat_event.emit(&"PARRY_SUCCESS", 1, 2, 0)
	arena.combat_event.emit(&"HORN_HIT", 1, 2, 0)
	arena.combat_event.emit(&"CLASH_START", 1, 2, 0)
	check(arena.hitstop_ticks == 6, "same-tick hitstop takes max, never sum")
	check(arena.get_snapshot()["hitstop_ticks"] == 6, "snapshot carries host hitstop")
	duel()
	b.parry_success()
	arena.hitstop_ticks = 6
	for i in 6:
		arena.simulate_tick(DT, frame(a), frame(b, "horn") if i == 0 else frame(b))
	check(b.state == Buffalo.State.NORMAL and is_equal_approx(b.counter_window, 0.5), "counter window stays open through hitstop")
	arena.simulate_tick(DT, frame(a), frame(b))
	check(b.state == Buffalo.State.HORN_STARTUP and b.counter_attack and is_equal_approx(b.state_duration, 0.08), "HORN buffered during hitstop starts as counter on resume")


func _presentation_and_input() -> void:
	check(InputMap.action_get_events("parry")[0].physical_keycode == KEY_G, "G input action is configured")
	var input := frame(a, "parry")
	input.seq = 123
	var decoded := MatchNetwork.payload_to_frame(MatchNetwork.frame_to_payload(input))
	check(decoded.parry_pressed and decoded.seq == 123, "PARRY payload roundtrip preserves reliable action and seq")
	duel()
	var feedback = a.get_node("CombatFeedback")
	var other = b.get_node("CombatFeedback")
	check(feedback.horn_material != null and other.horn_material != null and feedback.horn_material != other.horn_material, "both HERO buffaloes have independent horn emission materials")
	for action in [&"HORN", &"DASH", &"PARRY", &"COUNTER", &"WHIFF"]:
		a.action_started.emit(a.slot, action)
		b.action_started.emit(b.slot, action)
		check(feedback.label.visible and other.label.visible and feedback.label.outline_size > 0 and is_equal_approx(feedback.label_time, 0.6), "outlined 0.6s Label3D for both buffaloes: " + String(action))
	feedback._process(0.61)
	check(not feedback.label.visible, "floating label expires after 0.6s")
	for sample in [[Buffalo.State.HORN_STARTUP, Color("ffd12a")], [Buffalo.State.DASH_ACTIVE, Color("ff3030")], [Buffalo.State.PARRY_ACTIVE, Color("40ff50")]]:
		a.state = sample[0]
		check(feedback.glow_color().is_equal_approx(sample[1]), "horn glow color for " + String(a.state_name()))
	a.state = Buffalo.State.GUARD
	a.guarding = true
	check(feedback.glow_color().is_equal_approx(Color("dbe7ea")), "GUARD horns glow pale white")
	a.guarding = false
	a.state = Buffalo.State.NORMAL
	a.counter_window = 0.5
	feedback._process(0.01)
	var energy: float = feedback.horn_material.get_shader_parameter("glow_energy")
	feedback._process(0.05)
	check(not is_equal_approx(energy, float(feedback.horn_material.get_shader_parameter("glow_energy"))), "counter window pulses yellow horn emission")
	arena.combat_event.emit(&"PARRY_SUCCESS", 1, 2, 0)
	feedback._process(0.2)
	check(feedback.horn_material.get_shader_parameter("glow_color").is_equal_approx(Color("40ff50")), "parry-success flash remains visible on its first render even with a long frame")
	duel()
	arena.clash.enter(0.0)
	arena.clash.start_hook(b, a, &"HOOK")
	check(other.label.text == "MÓC", "MÓC appears on the hooking buffalo")
	var release := frame(b)
	release.guard_pressed = true
	arena.clash.process(DT, frame(a), release)
	check(other.label.text == "NHẢ", "NHẢ appears on the releasing buffalo, including slot 2")
	duel()
	a.state = Buffalo.State.HORN_STARTUP
	a.state_duration = 0.25
	a.state_time = 0.25
	var animator := a.visual as BuffaloAnimator
	animator._compute_targets()
	check(is_equal_approx(animator._target_pitch, deg_to_rad(-18.0)) and animator._target_offset.z > 0.0, "HORN startup targets 18 degree dip and backward windup")
