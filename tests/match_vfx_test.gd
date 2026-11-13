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
	reset_duel()
	horn_hit()
	check(count_kind(&"ImpactFlash") == 1 and count_kind(&"HitDust") == 1, "HORN creates one impact flash and victim dust")
	check((first_kind(&"HitDust").global_position - b.global_position).length() < 0.2, "hit dust originates under the victim")
	check(first_kind(&"ImpactFlash").mesh.material.albedo_texture is GradientTexture2D, "particles use generated radial texture")
	check(first_kind(&"ImpactFlash").mesh.material.billboard_keep_scale, "billboards preserve small particle sizes instead of becoming metre-wide quads")
	check(arena.hitstop_ticks == 4, "HORN keeps its existing four-tick hitstop")
	vfx._process(1.0)
	await process_frame
	check(vfx.bursts.get_child_count() == 0 and arena.hitstop_ticks == 4, "particles expire in real time while simulation is in hitstop")
	reset_duel()
	a.counter_window = 0.5
	horn_hit()
	check(count_kind(&"ImpactFlash") == 1 and count_kind(&"HitDust") == 1, "counter HORN reuses impact without duplicate burst")
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
	check(count_kind(&"DashDust") == 1, "DASH_START creates rear dust immediately")
	var rear := first_kind(&"DashDust").global_position - a.global_position
	check(rear.dot(a.forward()) < 0.0, "DASH dust originates behind the feet")
	a.position += Vector3.RIGHT
	vfx._process(GameBalance.get_number("vfx_dash_interval_s"))
	check(count_kind(&"DashDust") == 2, "active dash leaves world-space dust along its path")
	check(not first_kind(&"DashDust").local_coords, "old dust stays in world space")
	a.state = Buffalo.State.DASH_RECOVERY
	vfx._process(0.1)
	check(count_kind(&"DashDust") == 2, "dash recovery stops creating trail emitters")
	reset_duel()
	# Camera processing is frozen in this test, so end any hit punch from earlier events.
	camera.punch_time = GameBalance.get_number("camera_punch_s")
	arena.clash.enter(0.0)
	check(count_kind(&"ClashDust") == 2, "entering CLASH emits dust at both buffaloes")
	arena._process(0.0)
	camera._process(GameBalance.get_number("vfx_clash_zoom_blend_s") * 0.5)
	check(is_equal_approx(camera.camera.fov, GameBalance.get_number("camera_fov_deg") - GameBalance.get_number("vfx_clash_zoom_deg") * 0.5), "CLASH zoom interpolates in real time during heavy hitstop")
	camera._process(GameBalance.get_number("vfx_clash_zoom_blend_s") * 0.5)
	check(is_equal_approx(camera.camera.fov, GameBalance.get_number("camera_fov_deg") - GameBalance.get_number("vfx_clash_zoom_deg")), "CLASH smoothly zooms camera inward")
	arena.clash.end(0.0, &"CLASH_BREAK")
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
	for event in [&"HORN_HIT", &"DASH_HIT", &"CLASH_START", &"CLASH_BREAK"]:
		camera.trigger_shake(event)
	check(camera.shake_elapsed == 1.0, "all impact and clash shake triggers honor Settings toggle")
	SessionState.camera_shake_enabled = true
	reset_duel()
	for i in GameBalance.get_int("vfx_max_emitters") * 2:
		arena.combat_event.emit(&"HORN_HIT", 1, 2, 18.0)
	check(vfx.bursts.get_child_count() == GameBalance.get_int("vfx_max_emitters"), "concurrent emitter count is capped under event spam")
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
	vfx.dash_times.clear()
	arena.hitstop_ticks = 0
	arena.active_clash.clear()
	for actor: Buffalo in [a, b]:
		actor.reset_combat()
		actor.position = Vector3(-1.45, 0, 0) if actor == a else Vector3(1.45, 0, 0)
		actor.rotation.y = -PI / 2.0 if actor == a else PI / 2.0
		actor.facing = Vector3.RIGHT if actor == a else Vector3.LEFT


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
	check(count_kind(&"ImpactFlash") == 1 and count_kind(&"GuardSpark") == 1 and count_kind(&"ParrySpark") == 1 and count_kind(&"DashDust") == 1 and count_kind(&"ClashDust") == 2, "LAN client creates all event-driven emitters from reliable host events")
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
