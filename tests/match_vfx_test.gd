extends SceneTree

var failures := 0
var arena: MatchController
var vfx: Node3D
var a: Buffalo
var b: Buffalo


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	SessionState.mode = &"SOLO"
	arena = load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.start_playing()
	vfx = arena.vfx
	vfx.set_process(false)
	a = arena.player
	b = arena.opponent
	var camera = arena.get_node("CameraRig")
	camera.set_physics_process(false)
	camera.set_process(false)
	test_attack_launch()
	await test_impact_force(camera)
	reset_duel()
	horn_hit()
	check(count_kind(&"ImpactFlash") == 1 and count_kind(&"HitDust") == 1, "HORN creates one impact flash and victim dust")
	check(count_kind(&"ImpactRing") == 1 and count_kind(&"ImpactDebris") == 1 and vfx.bursts.get_child_count() == 7, "HORN creates swing plus star, streaks, shock, dust, ground ring and debris")
	var contact: Vector3 = vfx.horn_position(a).lerp(b.global_position + Vector3.UP * GameBalance.get_number("vfx_impact_body_height"), 0.5)
	check(first_kind(&"ImpactFlash").global_position.is_equal_approx(contact) and not contact.is_equal_approx(vfx.horn_position(a)), "impact is between attacker horns and victim body")
	var ring := first_kind(&"ImpactRing")
	check(ring.mesh is TorusMesh and is_equal_approx(ring.global_position.y, GameBalance.get_number("vfx_ground_height")) and Vector2(ring.global_position.x, ring.global_position.z).is_equal_approx(Vector2(contact.x, contact.z)), "impact ring lies on the ground below contact")
	check(ring.scale_amount_curve.sample(0.0) < ring.scale_amount_curve.sample(1.0) and ring.color_ramp.get_color(0).a <= 0.75 and ring.color_ramp.get_color(1).a == 0.0, "ground ring expands and fades with restrained alpha")
	var debris := first_kind(&"ImpactDebris")
	check(debris.mesh is QuadMesh and debris.mesh.material.albedo_texture.resource_path.ends_with("dirt_01.png") and debris.direction.dot((b.global_position - a.global_position).normalized()) > 0.5 and debris.direction.y > 0.0 and debris.gravity.y < 0.0, "earth sprites launch upward in the attacker-to-victim push direction")
	check(debris.global_position.distance_to(vfx.hoof_position(b, 0).lerp(vfx.hoof_position(b, 1), 0.5)) < 0.01, "directional hit spray originates between victim front hooves")
	check(debris.amount <= 5 and debris.scale_amount_max < GameBalance.get_number("vfx_dust_size") and debris.color_ramp.get_color(0).get_luminance() < MatchVFX.EARTH.get_luminance(), "earth clods are few, small and darker than dust")
	var landing_y := debris.global_position.y + debris.initial_velocity_max * debris.lifetime + 0.5 * debris.gravity.y * debris.lifetime * debris.lifetime
	check(debris.emission_shape == CPUParticles3D.EMISSION_SHAPE_BOX and debris.emission_box_extents.y == 0.0 and debris.global_position.y < 0.06 and landing_y <= 0.0, "clods start just above ground and even the highest arc lands within their lifetime")
	var horn_size := first_kind(&"ImpactFlash").scale_amount_max
	check((first_kind(&"HitDust").global_position - b.global_position).length() < 0.2, "hit dust originates under the victim")
	check(first_kind(&"ImpactFlash").mesh.material.albedo_texture.resource_path.ends_with("star_07.png"), "contact uses the imported CC0 star sprite")
	check(first_kind(&"HitDust").mesh.material.albedo_texture.resource_path.ends_with("smoke_03.png"), "dust uses the imported CC0 smoke sprite")
	check(first_kind(&"ImpactFlash").mesh.material.billboard_keep_scale, "billboards preserve small particle sizes instead of becoming metre-wide quads")
	var flash := first_kind(&"ImpactFlash")
	check(flash.mesh.material.no_depth_test and flash.mesh.material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and not first_kind(&"HitDust").mesh.material.no_depth_test, "additive contact star stays visible through horns while dust keeps normal depth")
	var tint := flash.color_ramp.get_color(0)
	check(tint.is_equal_approx(Color.WHITE), "impact star has a bright white core")
	check(flash.local_coords and flash.scale_amount_min == flash.scale_amount_max and flash.color_ramp.sample(0.1).a == tint.a, "contact flash keeps its placed origin, full size and peak alpha during the first frames")
	check(arena.hitstop_ticks == 4, "HORN keeps its existing four-tick hitstop")
	b.knockback_time = 0.0
	vfx._process(1.0)
	await process_frame
	check(vfx.bursts.get_child_count() == 0 and arena.hitstop_ticks == 4, "particles expire in real time while simulation is in hitstop")
	reset_duel()
	a.counter_window = 0.5
	horn_hit()
	check(count_kind(&"ImpactFlash") == 1 and count_kind(&"HitDust") == 1, "counter HORN reuses impact without duplicate burst")
	reset_duel()
	arena.combat_event.emit(&"DASH_HIT", 1, 2, 18.0)
	check(count_kind(&"ImpactFlash") == 1 and count_kind(&"ImpactRing") == 1 and count_kind(&"ImpactDebris") == 1, "DASH creates the complete impact effect")
	check(is_equal_approx(first_kind(&"ImpactFlash").scale_amount_max, horn_size * GameBalance.get_number("vfx_impact_heavy_scale")) and is_equal_approx(first_kind(&"ImpactRing").scale_amount_max, GameBalance.get_number("vfx_ring_size") * GameBalance.get_number("vfx_impact_heavy_scale")), "DASH flash and ring are one tier stronger than HORN")
	check(is_equal_approx(first_kind(&"ImpactDebris").initial_velocity_max, GameBalance.get_number("vfx_debris_speed") * GameBalance.get_number("vfx_impact_heavy_scale")), "DASH throws earth harder than HORN")
	check(first_kind(&"ImpactFlash").scale_amount_max <= 2.2 and first_kind(&"ImpactFlash").amount == 1, "even DASH uses a single brief contact star")
	reset_duel()
	var guard := InputFrame.new(2)
	guard.guard_held = true
	b.begin_input(guard)
	horn_hit()
	check(count_kind(&"GuardSpark") == 1, "valid GUARD creates a horn spark")
	check(first_kind(&"GuardSpark").global_position.is_equal_approx(vfx.horn_position(b)), "guard spark appears at defender horns")
	check(arena.hitstop_ticks == 4, "GUARD_HIT adds no hitstop")
	reset_duel()
	b.begin_input(guard)
	b.facing = Vector3.RIGHT
	b.rotation.y = -PI / 2.0
	horn_hit()
	check(count_kind(&"GuardSpark") == 0, "guard facing away produces no valid-guard spark")
	reset_duel()
	a.start_horn()
	a.advance_state(a.state_duration)
	b.start_parry()
	arena.combat.resolve_attacks()
	check(count_kind(&"ParrySpark") == 1 and count_kind(&"ImpactFlash") == 0, "successful parry creates green spark without hit flash")
	var parry := first_kind(&"ParrySpark")
	check(parry.color_ramp.get_color(0).is_equal_approx(Color("40ff50")), "parry matches existing green horn glow")
	check(parry.amount > GameBalance.get_int("vfx_guard_count") and parry.scale_amount_max > GameBalance.get_number("vfx_guard_size"), "parry is stronger than guard spark")
	reset_duel()
	b.start_parry()
	check(count_kind(&"ParrySpark") == 0, "parry without contact creates no spark")
	reset_duel()
	a.start_dash()
	check(count_kind(&"DashDust") == 1, "DASH_START creates one small hoof puff immediately")
	var hoof_dust := first_kind(&"DashDust")
	check(Vector2(hoof_dust.global_position.x, hoof_dust.global_position.z).distance_to(Vector2(vfx.hoof_position(a, 0).x, vfx.hoof_position(a, 0).z)) < 0.01 and hoof_dust.amount == GameBalance.get_int("vfx_hoof_dust_count") and is_equal_approx(hoof_dust.scale_amount_max, GameBalance.get_number("vfx_hoof_dust_size")), "DASH dust starts at a measured hoof at its own trail size")
	a.state = Buffalo.State.DASH_ACTIVE
	a.position += Vector3.RIGHT
	vfx._process(GameBalance.get_number("vfx_dash_interval_s"))
	check(count_kind(&"DashDust") == 2, "active dash leaves world-space dust along its path")
	var next_hoof := vfx.bursts.get_child(vfx.bursts.get_child_count() - 1) as CPUParticles3D
	check(Vector2(next_hoof.global_position.x, next_hoof.global_position.z).distance_to(Vector2(vfx.hoof_position(a, 1).x, vfx.hoof_position(a, 1).z)) < 0.01, "DASH puffs alternate between measured hooves")
	check(not first_kind(&"DashDust").local_coords, "old dust stays in world space")
	a.state = Buffalo.State.DASH_RECOVERY
	vfx._process(0.1)
	check(count_kind(&"DashDust") == 2, "a dash that has stopped sliding creates no more trail emitters")
	a.position += Vector3.RIGHT * 0.5
	vfx._process(GameBalance.get_number("vfx_dash_interval_s"))
	check(count_kind(&"DashDust") == 3, "the braking slide after a dash keeps kicking up dust")
	await test_skids_and_breath()
	reset_duel()
	# Camera processing is frozen in this test, so end any hit punch from earlier events.
	camera.punch_time = GameBalance.get_number("camera_punch_s")
	arena.clash.enter(0.0)
	check(count_kind(&"ClashDust") == 2, "entering CLASH emits dust at both buffaloes")
	var front_dust := first_kind(&"ClashDust")
	check(is_equal_approx((front_dust.global_position - a.global_position).dot(a.forward()), GameBalance.get_number("vfx_clash_dust_front_offset")) and front_dust.scale_amount_max > GameBalance.get_number("vfx_dust_size") and front_dust.color_initial_ramp == null, "CLASH dust is denser around front hooves instead of hidden under the belly")
	vfx._process(0.0)
	check(count_kind(&"ClashSpark") == 1 and first_kind(&"ClashSpark").global_position.is_equal_approx(vfx.horn_position(a).lerp(vfx.horn_position(b), 0.5)), "locked horns create a small spark at their midpoint")
	var lock_spark := first_kind(&"ClashSpark")
	check(lock_spark.amount <= 3 and lock_spark.lifetime <= 0.15 and lock_spark.get_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY) and lock_spark.color_ramp.get_color(0).is_equal_approx(MatchVFX.PAPER), "CLASH uses few bright short-lived sparks")
	vfx._process(GameBalance.get_number("vfx_clash_dust_interval_s"))
	check(count_kind(&"ClashDust") == 4 and count_kind(&"ClashSpark") == 1, "CLASH dust repeats at both feet before next spark")
	vfx._process(GameBalance.get_number("vfx_clash_dust_interval_s"))
	check(count_kind(&"ClashDust") == 6 and count_kind(&"ClashSpark") == 2, "CLASH maintains dust and slower sparks during hitstop")
	var count_before: int = vfx.bursts.get_child_count()
	var lifetime_before: float = first_kind(&"ClashDust").get_meta("remaining")
	arena.paused = true
	vfx._process(1.0)
	for event in [&"HORN_HIT", &"DASH_HIT", &"GUARD_HIT", &"PARRY_SUCCESS", &"DASH_START", &"CLASH_START"]:
		vfx.on_combat_event(event, 1, 2)
	check(vfx.bursts.get_child_count() == count_before and first_kind(&"ClashDust").get_meta("remaining") == lifetime_before and first_kind(&"ClashDust").speed_scale == 0.0, "pause freezes existing particles and blocks event and periodic creation")
	arena.paused = false
	vfx._process(0.0)
	check(first_kind(&"ClashDust").speed_scale == 1.0, "resume restores particle animation")
	arena.phase = &"COUNTDOWN"
	vfx._process(GameBalance.get_number("vfx_clash_dust_interval_s"))
	check(vfx.bursts.get_child_count() == count_before, "CLASH emits nothing outside PLAYING")
	arena.phase = &"PLAYING"
	arena._process(0.0)
	camera._process(GameBalance.get_number("vfx_clash_zoom_blend_s") * 0.5)
	check(is_equal_approx(camera.camera.fov, GameBalance.get_number("camera_fov_deg") - GameBalance.get_number("vfx_clash_zoom_deg") * 0.5), "CLASH zoom interpolates in real time during heavy hitstop")
	camera._process(GameBalance.get_number("vfx_clash_zoom_blend_s") * 0.5)
	check(is_equal_approx(camera.camera.fov, GameBalance.get_number("camera_fov_deg") - GameBalance.get_number("vfx_clash_zoom_deg")), "CLASH smoothly zooms camera inward")
	arena.clash.end(0.0, &"CLASH_BREAK")
	count_before = vfx.bursts.get_child_count()
	vfx._process(GameBalance.get_number("vfx_clash_dust_interval_s"))
	check(vfx.bursts.get_child_count() == count_before, "ending CLASH stops periodic dust and sparks")
	arena._process(0.0)
	camera._process(0.2)
	check(is_equal_approx(camera.camera.fov, GameBalance.get_number("camera_fov_deg")), "CLASH exit restores normal FOV")
	camera.set_clash_zoom(true)
	camera._process(0.2)
	camera.show_overview()
	camera._process(0.2)
	check(is_equal_approx(camera.camera.fov, GameBalance.get_number("camera_fov_deg")), "result overview restores normal FOV")
	camera.overview_time = -1.0
	reset_duel()
	b.position.x = 12.2
	a.position.x = 9.3
	vfx._process(0.0)
	var marker: MeshInstance3D = vfx.pinned_markers[2]
	check(marker.visible and marker.mesh is TorusMesh, "PINNED shows a 3D gold ring at the fence")
	var scale_before := marker.scale
	vfx._process(0.05)
	check(not marker.scale.is_equal_approx(scale_before), "PINNED ring pulses in real time")
	var snapshot := arena.get_snapshot()
	check(snapshot.players[1].pinned, "snapshot carries authoritative PINNED boolean")
	reset_duel()
	vfx._process(0.0)
	check(not marker.visible, "leaving the fence hides PINNED marker")
	SessionState.camera_shake_enabled = true
	camera.trigger_shake(&"HORN_HIT")
	camera.shake_elapsed = 0.03
	camera.follow_target()
	var normal_position: Vector3 = a.global_position + Vector3.UP * camera.height
	check(not camera.global_position.is_equal_approx(normal_position), "camera shake visibly displaces camera when enabled")
	SessionState.camera_shake_enabled = false
	camera.follow_target()
	check(camera.global_position.is_equal_approx(normal_position), "disabling shake removes an in-flight shake immediately")
	camera.shake_elapsed = 1.0
	for event in [&"HORN_HIT", &"DASH_HIT", &"COUNTER_HIT", &"PARRY_SUCCESS", &"CLASH_START", &"CLASH_BREAK"]:
		camera.trigger_shake(event)
	check(camera.shake_elapsed == 1.0, "all impact and clash shake triggers honor Settings toggle")
	SessionState.camera_shake_enabled = true
	reset_duel()
	for i in GameBalance.get_int("vfx_max_emitters") * 2:
		arena.combat_event.emit(&"HORN_HIT", 1, 2, 18.0)
	arena.clash.enter(0.0)
	vfx._process(GameBalance.get_number("vfx_clash_spark_interval_s"))
	check(vfx.bursts.get_child_count() == GameBalance.get_int("vfx_max_emitters"), "concurrent emitter count is capped under event spam")
	arena.active_clash.clear()
	var all_one_shot := true
	for emitter: CPUParticles3D in vfx.bursts.get_children():
		all_one_shot = all_one_shot and emitter.one_shot and emitter.finished.is_connected(emitter.queue_free)
	check(all_one_shot, "every one-shot emitter frees itself on finished")
	vfx._process(2.0)
	await process_frame
	check(vfx.bursts.get_child_count() == 0, "all capped emitters eventually free")
	await test_client(snapshot)
	arena.free()
	print("MATCH VFX TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func reset_duel() -> void:
	for emitter in vfx.bursts.get_children():
		emitter.free()
	for light in vfx.lights.get_children():
		light.free()
	vfx.impact_groups.clear()
	for mark in vfx.furrows.get_children():
		mark.free()
	vfx.dash_times.clear()
	vfx.dash_hooves.clear()
	vfx.skid_times.clear()
	vfx.breath_times.clear()
	vfx.last_positions.clear()
	vfx.clash_dust_time = 0.0
	vfx.clash_spark_time = 0.0
	arena.hitstop_ticks = 0
	arena.active_clash.clear()
	for actor: Buffalo in [a, b]:
		actor.reset_combat()
		actor.position = Vector3(-1.45, 0, 0) if actor == a else Vector3(1.45, 0, 0)
		actor.rotation.y = -PI / 2.0 if actor == a else PI / 2.0
		actor.facing = Vector3.RIGHT if actor == a else Vector3.LEFT
		actor.visual.hoof_offsets.fill(Vector3.ZERO)


func test_skids_and_breath() -> void:
	reset_duel()
	b.knockback_time = 0.3
	b.velocity = Vector3.RIGHT * (GameBalance.get_number("vfx_skid_min_speed") + 1.0)
	var before := arena.get_snapshot()
	vfx._process(0.0)
	check(vfx.furrows.get_child_count() == 2 and count_kind(&"SkidDebris") == 2, "knockback slide leaves two front-hoof furrows with small earth sprays")
	check(before == arena.get_snapshot(), "skids never mutate simulation state")
	var mark: MeshInstance3D = vfx.furrows.get_child(0)
	check(mark.mesh is QuadMesh and mark.mesh.orientation == PlaneMesh.FACE_Y and mark.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and is_equal_approx(mark.position.y, GameBalance.get_number("vfx_skid_ground_height")), "furrows are flat shadowless quads slightly above the floor")
	var alpha: float = mark.mesh.material.albedo_color.a
	arena.paused = true
	vfx._process(1.0)
	check(mark.mesh.material.albedo_color.a == alpha and vfx.furrows.get_child_count() == 2, "pause freezes furrow lifetime and emission")
	arena.paused = false
	b.knockback_time = 0.0
	vfx._process(GameBalance.get_number("vfx_skid_s") * 0.5)
	check(mark.mesh.material.albedo_color.a < alpha, "furrows fade over their configured lifetime")
	vfx._process(GameBalance.get_number("vfx_skid_s"))
	await process_frame
	check(vfx.furrows.get_child_count() == 0, "furrows automatically free after their lifetime")
	reset_duel()
	b.knockback_time = 1.0
	b.velocity = Vector3.RIGHT * GameBalance.get_number("vfx_skid_min_speed")
	vfx._process(0.0)
	check(vfx.furrows.get_child_count() == 0, "sub-threshold sliding leaves no furrows")
	reset_duel()
	arena.clash.enter(0.0)
	vfx._process(0.0)
	b.position += Vector3.RIGHT
	a.position += Vector3.RIGHT
	vfx._process(0.1)
	check(vfx.furrows.get_child_count() == 2 and b.knockback_time == 0.0, "CLASH displacement marks only the buffalo pushed backwards without relying on knockback")
	reset_duel()
	b.knockback_time = 1.0
	b.velocity = Vector3.RIGHT
	for i in GameBalance.get_int("vfx_skid_max_marks") * 2:
		vfx.skid_times.clear()
		vfx._process(0.0)
	check(vfx.furrows.get_child_count() == GameBalance.get_int("vfx_skid_max_marks") and vfx.bursts.get_child_count() <= GameBalance.get_int("vfx_max_emitters"), "furrow and emitter limits both hold during sustained sliding")
	reset_duel()
	var threshold := GameBalance.get_number("stamina_max") * GameBalance.get_number("vfx_breath_stamina_fraction")
	a.stamina = threshold
	vfx._process(0.0)
	check(count_kind(&"TiredBreath") == 0, "breath is absent at the stamina threshold")
	a.stamina = threshold - 1.0
	vfx._process(0.0)
	check(count_kind(&"TiredBreath") == 1, "tired buffalo exhales below the stamina threshold")
	var breath := first_kind(&"TiredBreath")
	check(breath.direction.is_equal_approx(a.forward()) and breath.global_position.y < vfx.horn_position(a).y and is_equal_approx(breath.color_ramp.get_color(0).a, GameBalance.get_number("vfx_breath_alpha")), "breath travels forward below horns with restrained opacity")
	vfx._process(GameBalance.get_number("vfx_breath_interval_s") * 0.5)
	check(count_kind(&"TiredBreath") == 1, "breath waits for its interval")
	vfx._process(GameBalance.get_number("vfx_breath_interval_s") * 0.5)
	check(count_kind(&"TiredBreath") == 2, "tired breath repeats at the configured interval")
	for emitter in vfx.bursts.get_children():
		emitter.free()
	a.stamina = threshold
	vfx._process(GameBalance.get_number("vfx_breath_interval_s"))
	check(count_kind(&"TiredBreath") == 0, "recovering stamina stops breath")
	a.stamina = 0.0
	arena.paused = true
	vfx._process(GameBalance.get_number("vfx_breath_interval_s"))
	check(count_kind(&"TiredBreath") == 0, "pause suppresses tired breath")
	arena.paused = false
	arena.finished = true
	vfx._process(GameBalance.get_number("vfx_breath_interval_s"))
	check(count_kind(&"TiredBreath") == 0, "match end suppresses tired breath")
	arena.finished = false


func horn_hit() -> void:
	a.start_horn()
	a.advance_state(a.state_duration)
	arena.combat.resolve_attacks()


func count_kind(kind: StringName) -> int:
	var count := 0
	for emitter in vfx.bursts.get_children():
		if emitter.get_meta("kind") == kind:
			count += 1
	return count


func first_kind(kind: StringName) -> CPUParticles3D:
	for emitter in vfx.bursts.get_children():
		if emitter.get_meta("kind") == kind:
			return emitter
	return null


func test_client(snapshot: Dictionary) -> void:
	reset_duel()
	var manager := arena.get_node("/root/NetworkManager")
	arena.lan = MatchNetwork.new(arena, manager)
	arena.lan._on_snapshot_received(snapshot)
	a.position = Vector3(-1.45, 0, 0)
	b.position = Vector3(1.45, 0, 0)
	vfx._process(0.0)
	check(vfx.pinned_markers[2].visible, "LAN client trusts host PINNED flag even at a different interpolated position")
	for event in [&"HORN_HIT", &"GUARD_HIT", &"PARRY_SUCCESS", &"DASH_START", &"CLASH_START"]:
		arena.lan._on_event_received({"type": "COMBAT", "event": event, "source": 1, "target": 2, "value": 0.0})
	check(count_kind(&"ImpactFlash") == 2 and count_kind(&"ImpactRing") == 1 and count_kind(&"ImpactDebris") == 1 and count_kind(&"GuardSpark") == 1 and count_kind(&"ParrySpark") == 1 and count_kind(&"DashDust") == 1 and count_kind(&"ClashDust") == 2, "LAN client creates all event-driven emitters from reliable host events")
	check(arena.hitstop_ticks == 0, "client presentation events do not run hitstop rules")
	var snapshot_after := arena.get_snapshot()
	vfx._process(0.05)
	check(snapshot_after == arena.get_snapshot(), "VFX updates never mutate match simulation state")
	snapshot.players[1].pinned = false
	arena.lan._on_snapshot_received(snapshot)
	b.position.x = 12.2
	vfx._process(0.0)
	check(not vfx.pinned_markers[2].visible, "client never re-evaluates PINNED from its local position")
	vfx._process(2.0)
	await process_frame
	check(vfx.bursts.get_child_count() == 0, "LAN emitters self-clean after host events")


func test_impact_force(camera: Node3D) -> void:
	for event in [&"HORN_HIT", &"DASH_HIT", &"COUNTER_HIT", &"FLANK_HIT", &"BACK_HIT"]:
		reset_duel()
		var before := arena.get_snapshot()
		vfx.on_combat_event(event, 1, 2)
		var sparks := first_kind(&"ImpactSparks")
		check(sparks != null and count_kind(&"ImpactFlash") == 1 and count_kind(&"ImpactShock") == 1 and vfx.lights.get_child_count() == 1, "FORCE hit layers " + String(event))
		if sparks != null:
			check(sparks.get_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY) and sparks.mesh.size.y > sparks.mesh.size.x and sparks.mesh.material is ShaderMaterial and sparks.mesh.material.get_shader_parameter("sprite").resource_path.ends_with("trace_06.png") and sparks.direction.dot((b.position - a.position).normalized()) > 0.5 and sparks.gravity.y < 0.0 and sparks.lifetime <= 0.35, "FORCE velocity streak " + String(event))
			check(sparks.color_ramp.get_color(0) == Color.WHITE and sparks.color_ramp.get_color(1) == MatchVFX.GOLD and sparks.color_ramp.get_color(2).g < sparks.color_ramp.get_color(1).g and sparks.color_ramp.get_color(3).a == 0.0, "FORCE hot cooling ramp " + String(event))
		check(before == arena.get_snapshot(), "FORCE simulation unchanged " + String(event))
	reset_duel()
	vfx.on_combat_event(&"HORN_HIT", 1, 2)
	var normal_count := first_kind(&"ImpactSparks").amount
	var normal_speed := first_kind(&"ImpactSparks").initial_velocity_max
	var flash := first_kind(&"ImpactFlash")
	check(flash.mesh.material.albedo_texture.resource_path.ends_with("star_07.png") and flash.mesh.material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and flash.lifetime <= 0.15 and flash.angle_min == flash.angle_max, "FORCE additive short star")
	var first_angle := flash.angle_min
	var shock := first_kind(&"ImpactShock")
	check(shock.mesh.material.albedo_texture.resource_path.ends_with("circle_03.png") and shock.mesh.material.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES and shock.scale_amount_curve.sample(1.0) > shock.scale_amount_curve.sample(0.0) and shock.lifetime <= 0.2, "FORCE expanding billboard shock")
	var light: OmniLight3D = vfx.lights.get_child(0)
	var energy := light.light_energy
	vfx._process(GameBalance.get_number("vfx_light_s") * 0.5)
	check(light.light_energy > 0.0 and light.light_energy < energy and not light.shadow_enabled, "FORCE light fades on real clock")
	arena.paused = true
	vfx._process(1.0)
	check(light.light_energy > 0.0 and first_kind(&"ImpactSparks").speed_scale == 0.0, "FORCE pause freezes light and streaks")
	arena.paused = false
	vfx._process(GameBalance.get_number("vfx_light_s"))
	await process_frame
	check(vfx.lights.get_child_count() == 0, "FORCE light self deletes")
	reset_duel()
	vfx.on_combat_event(&"HORN_HIT", 1, 2)
	check(first_kind(&"ImpactFlash").angle_min != first_angle, "FORCE random star rotation")
	for event in [&"DASH_HIT", &"COUNTER_HIT"]:
		reset_duel()
		vfx.on_combat_event(event, 1, 2)
		check(first_kind(&"ImpactSparks").amount > normal_count and first_kind(&"ImpactSparks").initial_velocity_max > normal_speed, "FORCE heavier sparks " + String(event))
	reset_duel()
	vfx.on_combat_event(&"HORN_HIT", 1, 2)
	vfx.on_combat_event(&"COUNTER_HIT", 1, 2)
	vfx.on_combat_event(&"FLANK_HIT", 1, 2)
	vfx.on_combat_event(&"BACK_HIT", 1, 2)
	check(count_kind(&"ImpactFlash") == 1 and count_kind(&"ImpactSparks") == 1 and first_kind(&"ImpactSparks").amount > normal_count and vfx.lights.get_child_count() == 1, "FORCE hit annotations upgrade without duplicate bursts")
	reset_duel()
	vfx.on_combat_event(&"GUARD_HIT", 1, 2)
	vfx.on_combat_event(&"HORN_HIT", 1, 2)
	var guard := first_kind(&"GuardSpark")
	check(guard != null and guard.get_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY) and guard.direction.dot(a.forward()) < 0.0 and guard.amount < normal_count and count_kind(&"ImpactFlash") == 0, "FORCE guard white streaks rebound without large star")
	reset_duel()
	vfx.on_combat_event(&"PARRY_SUCCESS", 2, 1)
	var parry := first_kind(&"ParrySpark")
	check(parry != null and parry.emission_shape == CPUParticles3D.EMISSION_SHAPE_RING and parry.amount > normal_count and count_kind(&"ParryFlash") == 1 and first_kind(&"ParryFlash").color_ramp.get_color(0) == MatchVFX.PARRY and first_kind(&"ParryFlash").scale_amount_max > GameBalance.get_number("vfx_flash_size") * GameBalance.get_number("vfx_impact_heavy_scale") and count_kind(&"ParryShock") == 1, "FORCE parry ring and largest green star")
	reset_duel()
	vfx.on_combat_event(&"CLASH_START", 1, 2)
	check(count_kind(&"ImpactSparks") == 1 and count_kind(&"ImpactFlash") == 1 and count_kind(&"ImpactShock") == 1 and vfx.lights.get_child_count() == 1, "FORCE clash entry impact")
	arena.clash.enter(0.0)
	vfx._process(0.0)
	var lock := first_kind(&"ClashSpark")
	check(lock != null and lock.get_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY) and lock.amount < normal_count, "FORCE periodic clash streaks")
	vfx.on_combat_event(&"CLASH_HOOK", 1, 2)
	check(count_kind(&"ClashHook") == 1 and first_kind(&"ClashHook").get_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY), "FORCE clash hook streaks")
	reset_duel()
	a.start_dash()
	var blast := first_kind(&"DashBlast")
	var muzzle := first_kind(&"DashMuzzle")
	var ring := first_kind(&"DashRing")
	var rear: Vector3 = vfx.hoof_position(a, 2).lerp(vfx.hoof_position(a, 3), 0.5)
	check(blast != null and blast.direction.dot(a.forward()) < 0.0 and blast.global_position.is_equal_approx(rear) and blast.amount > GameBalance.get_int("vfx_hoof_dust_count"), "FORCE dash rear earth explosion")
	check(muzzle != null and muzzle.mesh.orientation == PlaneMesh.FACE_Y and muzzle.mesh.material.albedo_texture.resource_path.ends_with("muzzle_01.png") and muzzle.lifetime <= 0.1 and is_equal_approx(muzzle.rotation.y, a.rotation.y + PI), "FORCE dash flat rear muzzle")
	check(ring != null and ring.mesh.orientation == PlaneMesh.FACE_Y and ring.scale_amount_curve.sample(0.0) < ring.scale_amount_curve.sample(1.0), "FORCE dash expanding dust ring")
	reset_duel()
	a.start_horn()
	var swing := first_kind(&"HornSwing")
	check(swing != null and swing.mesh.material is ShaderMaterial and swing.mesh.material.get_shader_parameter("sprite").resource_path.ends_with("slash_02.png") and swing.lifetime <= 0.18 and (swing.global_position - vfx.horn_position(a)).dot(a.forward()) > 0.0 and absf(swing.angle_min - GameBalance.get_number("vfx_swing_base_angle_deg")) == GameBalance.get_number("vfx_swing_tilt_deg"), "FORCE horn swing arc follows head side")
	reset_duel()
	a.counter_window = 0.5
	a.start_horn()
	check(count_kind(&"HornSwing") == 1, "FORCE counter start also swings horns")
	SessionState.camera_shake_enabled = true
	camera.trigger_shake(&"HORN_HIT")
	var normal_shake: float = camera.shake_strength
	var normal_duration: float = camera.shake_duration
	for event in [&"DASH_HIT", &"COUNTER_HIT", &"PARRY_SUCCESS", &"CLASH_START"]:
		camera.trigger_shake(event)
		check(camera.shake_strength > normal_shake and camera.shake_duration > normal_duration, "FORCE heavy camera shake " + String(event))
	SessionState.camera_shake_enabled = false
	camera.shake_elapsed = 1.0
	for event in [&"DASH_HIT", &"COUNTER_HIT", &"PARRY_SUCCESS", &"CLASH_START"]:
		camera.trigger_shake(event)
		check(camera.shake_elapsed == 1.0, "FORCE disabled camera shake " + String(event))
	SessionState.camera_shake_enabled = true
	reset_duel()
	for i in GameBalance.get_int("vfx_max_emitters") * 2:
		vfx.on_combat_event(&"DASH_HIT", 1, 2)
	check(vfx.bursts.get_child_count() == GameBalance.get_int("vfx_max_emitters"), "FORCE emitter cap")
	check(vfx.lights.get_child_count() == GameBalance.get_int("vfx_max_lights"), "FORCE light cap")
	vfx._process(2.0)
	await process_frame
	check(vfx.bursts.get_child_count() == 0 and vfx.lights.get_child_count() == 0, "FORCE capped effects self delete")
	reset_duel()
	var manager := arena.get_node("/root/NetworkManager")
	arena.lan = MatchNetwork.new(arena, manager)
	for event in [&"HORN_HIT", &"DASH_HIT", &"COUNTER_HIT", &"FLANK_HIT", &"BACK_HIT", &"GUARD_HIT", &"PARRY_SUCCESS", &"CLASH_START", &"CLASH_HOOK", &"DASH_START", &"HORN_START", &"COUNTER_START"]:
		reset_duel()
		arena.lan._on_event_received({"type": "COMBAT", "event": event, "source": 1, "target": 2, "value": 0.0})
		check(vfx.bursts.get_child_count() > 0 and arena.hitstop_ticks == 0, "FORCE LAN event " + String(event))
	arena.lan = null


func test_attack_launch() -> void:
	reset_duel()
	a.start_horn()
	var arc := first_kind(&"HornSwing")
	var material := arc.mesh.material as ShaderMaterial
	check(is_equal_approx(arc.lifetime, 0.18) and arc.color_ramp.get_color(0).a >= 0.95 and arc.color_ramp.sample(0.4).a >= 0.95 and material.get_shader_parameter("energy") > 1.0 and material.get_shader_parameter("core_end") > material.get_shader_parameter("core_start"), "LAUNCH hot white-core arc holds near full opacity")
	check(material.shader.code.contains("blend_add") and not material.shader.code.contains("depth_test_disabled"), "LAUNCH arc adds light while respecting victim depth")
	var old_side: float = a.visual.get("_hook_side")
	a.visual.set("_hook_side", -old_side)
	vfx._process(0.0)
	check(arc.angular_velocity_min * float(a.visual.get("_hook_side")) < 0.0 and absf(arc.angular_velocity_min) * arc.lifetime >= 45.0 and arc.angle_min == GameBalance.get_number("vfx_swing_base_angle_deg") - old_side * GameBalance.get_number("vfx_swing_tilt_deg"), "LAUNCH arc sweeps with the current head side")
	var previous := arc.global_position
	a.position += Vector3.RIGHT
	vfx._process(0.0)
	check(arc.global_position.is_equal_approx(previous + Vector3.RIGHT), "LAUNCH arc follows moving horns")
	arena.paused = true
	previous = arc.global_position
	a.position += Vector3.RIGHT
	vfx._process(0.1)
	check(arc.global_position == previous and arc.speed_scale == 0.0, "LAUNCH pause freezes arc sweep and tracking")
	arena.paused = false
	a.visual.set("_hook_side", old_side)
	reset_duel()
	a.start_dash()
	var clods := first_kind(&"DashClods")
	check(clods != null and clods.mesh == vfx.debris_mesh and clods.amount >= 12 and clods.initial_velocity_max * clods.lifetime >= 1.5 and clods.direction.dot(-a.forward()) > 0.8 and clods.gravity.y < 0.0, "LAUNCH rear clods are plentiful and travel farther")
	var plume := first_kind(&"DashBlast")
	check(plume.amount >= 16 and plume.initial_velocity_max >= 5.0 and plume.mesh == vfx.dust_mesh and plume.spread <= 35.0, "LAUNCH rear dust has a strong directed burst")
	var ring := first_kind(&"DashRing")
	var diameter := ring.scale_amount_curve.sample(1.0) * ring.scale_amount_max
	check(diameter >= 1.5 and diameter <= 2.5 and ring.scale_amount_curve.sample(0.3) >= ring.scale_amount_curve.sample(1.0) and ring.color_ramp.get_color(0).a >= 0.9, "LAUNCH dust ring reaches full broad diameter quickly")
	var muzzle := first_kind(&"DashMuzzle")
	check(muzzle.scale_amount_max >= 2.5 and muzzle.color_ramp.sample(0.4).a >= 0.95 and muzzle.color_ramp.get_color(0).get_luminance() > MatchVFX.GOLD.get_luminance(), "LAUNCH muzzle is larger brighter and holds its flash")
	reset_duel()
