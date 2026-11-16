extends SceneTree

const ARENA_PATH := "res://scenes/arena.tscn"
const SETTINGS_PATH := "user://camera_options_test.cfg"
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.theme = load("res://assets/ui/festival_theme.tres")
	var original_path := SessionState.settings_path
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	SessionState.load_settings(SETTINGS_PATH)
	check(SessionState.camera_view == 1 and SessionState.camera_side == 0, "missing settings default to Vừa / Phải")
	check(GameBalance.get_number("camera_distance") == 5.2 and GameBalance.get_number("camera_pitch_deg") == 22.0 and GameBalance.get_number("camera_look_height") == 1.7, "default framing keeps all three original GDD numbers")
	for view in 3:
		for side in 2:
			SessionState.camera_view = view
			SessionState.camera_side = side
			check(SessionState.save_settings() == OK, "camera choices save to the existing ConfigFile")
			SessionState.camera_view = 1
			SessionState.camera_side = 0
			SessionState.load_settings(SETTINGS_PATH)
			check(SessionState.camera_view == view and SessionState.camera_side == side, "all six camera choices round-trip through settings")
	for invalid in [-1, 99, 1.0, true, "left", Vector2.ZERO]:
		var config := ConfigFile.new()
		config.set_value("settings", "camera_view", invalid)
		config.set_value("settings", "camera_side", invalid)
		config.save(SETTINGS_PATH)
		SessionState.load_settings(SETTINGS_PATH)
		check(SessionState.camera_view == 1 and SessionState.camera_side == 0, "invalid camera enums restore the defaults: %s" % [invalid])
	var baseline: Array = []
	for view in 3:
		for side in 2:
			await _check_camera(view, side)
			var state := await _simulate(view, side)
			if baseline.is_empty():
				baseline = state
			else:
				check(state == baseline, "scripted gameplay positions/resources are identical for camera %d/%d" % [view, side])
	await _check_live_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	SessionState.load_settings(original_path)
	print("CAMERA OPTIONS TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _arena(view: int, side: int) -> MatchController:
	SessionState.camera_view = view
	SessionState.camera_side = side
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L01"
	var arena := load(ARENA_PATH).instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	return arena


func _check_camera(view: int, side: int) -> void:
	var arena := _arena(view, side)
	var rig := arena.get_node("CameraRig")
	var suffix: String = ["_near", "", "_far"][view]
	arena.player.position = Vector3.ZERO
	rig.follow_target()
	check(is_equal_approx(rig.arm.spring_length, GameBalance.get_number("camera_distance" + suffix, GameBalance.get_number("camera_distance"))), "choice %d/%d uses the configured spring length" % [view, side])
	if view == 0:
		await physics_frame
		await physics_frame
		rig._process(0.0)
		check(_projected_height(arena.player, rig.camera) <= root.size.y * 0.62, "Gần in the open keeps the projected buffalo below 62%% of screen height (%.0f px)" % _projected_height(arena.player, rig.camera))
	var sign := 1.0 if side == 0 else -1.0
	check(is_equal_approx(rig.arm.position.x, sign * GameBalance.get_number("camera_shoulder_offset")), "choice %d/%d mirrors the shoulder correctly" % [view, side])
	for placement in [[Vector3(-10, 0, 0), -PI / 2.0], [Vector3(10, 0, 0), PI / 2.0], [Vector3(-11, 0, 0), -PI / 2.0], [Vector3(11, 0, 0), PI / 2.0], [Vector3(0, 0, 8), 0.0]]:
		arena.player.position = placement[0]
		rig.yaw = placement[1]
		for phase in [&"COUNTDOWN", &"PLAYING", &"RESULT"]:
			arena.phase = phase
			for progress in [0.0, 0.5, 1.0]:
				arena.countdown_time = GameBalance.get_number("countdown_s") * (1.0 - progress)
				arena.get_node("ReleaseHandlers")._update()
				arena.get_node("Gates").update(INF)
				rig.overview_time = progress * GameBalance.get_number("result_camera_blend_s") if phase == &"RESULT" else -1.0
				if phase == &"RESULT" and progress == 0.0:
					rig.overview_time = -1.0
					rig.show_overview()
				rig.follow_target()
				await physics_frame
				await physics_frame
				var lens: Vector3 = rig.camera.global_position
				var oval := Vector2(lens.x / GameBalance.get_number("arena_rx"), lens.z / GameBalance.get_number("arena_rz"))
				check(oval.length_squared() <= 1.001, "camera %d/%d remains inside the oval through %s and gate/release progress %.1f" % [view, side, phase, progress])
				if view == 0 and phase != &"RESULT":
					rig._process(0.0)
					# Backed against the fence the arm has to shorten, so the cap is looser than in the open.
					check(_projected_height(arena.player, rig.camera) <= root.size.y * 0.72, "Gần at the fence keeps the projected buffalo below 72%% of screen height (%.0f px)" % _projected_height(arena.player, rig.camera))
				if phase == &"COUNTDOWN":
					_check_handlers(arena, lens)
	# The winner orbit also stays inside; the side changes its orbit angle, not the result UI.
	rig.winner_time = -1.0
	rig.show_winner(arena.player)
	rig.winner_time = GameBalance.get_number("result_winner_blend_s")
	rig.follow_target()
	await physics_frame
	await physics_frame
	var lens: Vector3 = rig.camera.global_position
	check(Vector2(lens.x / GameBalance.get_number("arena_rx"), lens.z / GameBalance.get_number("arena_rz")).length_squared() <= 1.001, "winner camera stays inside the oval for %d/%d" % [view, side])
	arena.free()
	await physics_frame


func _projected_height(actor: Buffalo, camera: Camera3D) -> float:
	var body := actor.visual.find_child("HeroBody", true, false) as MeshInstance3D
	var top := INF
	var bottom := -INF
	for surface in body.mesh.get_surface_count():
		var vertices: PackedVector3Array = body.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point in vertices:
			var world := body.global_transform * point
			if not camera.is_position_behind(world):
				var y := camera.unproject_position(world).y
				top = minf(top, y)
				bottom = maxf(bottom, y)
	return bottom - top


func _check_handlers(arena: MatchController, lens: Vector3) -> void:
	var clear := true
	var sight := arena.player.global_position + Vector3.UP * GameBalance.get_number("camera_look_height")
	for handler: Node3D in arena.get_node("ReleaseHandlers").handlers:
		if not handler.visible:
			continue
		for mesh: MeshInstance3D in handler.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			clear = clear and not bounds.has_point(lens) and bounds.intersects_segment(lens, sight) == null
	check(clear, "release handlers neither contain the lens nor cross its sightline")


func _simulate(view: int, side: int) -> Array:
	var arena := _arena(view, side)
	arena.player.position = Vector3(-1.4, 0.0, 0.0)
	arena.opponent.position = Vector3(1.4, 0.0, 0.0)
	await physics_frame
	await physics_frame
	arena.start_playing()
	var result: Array = []
	for tick in 90:
		var first := InputFrame.new(1)
		first.camera_yaw = -PI / 2.0
		first.move = Vector2(0.0, -0.5)
		first.horn_pressed = tick in [0, 50]
		var second := InputFrame.new(2)
		second.camera_yaw = PI / 2.0
		second.move = Vector2(0.0, -0.5)
		arena.simulate_tick(1.0 / 60.0, first, second)
		result.append([arena.player.position, arena.opponent.position, arena.player.spirit, arena.opponent.spirit, arena.player.stamina, arena.opponent.stamina])
	check(arena.opponent.spirit < GameBalance.get_number("spirit_max"), "deterministic comparison includes an actual combat hit")
	arena.free()
	await physics_frame
	return result


func _check_live_settings() -> void:
	var arena := _arena(1, 0)
	arena.player.position = Vector3.ZERO
	var rig := arena.get_node("CameraRig")
	arena.request_pause_from_menu()
	arena.hud.show_settings()
	await process_frame
	var view := arena.hud.pause_actions.find_child("CameraView", true, false) as OptionButton
	var side := arena.hud.pause_actions.find_child("CameraSide", true, false) as OptionButton
	check(view != null and side != null, "pause settings include both camera choices")
	var old_length: float = rig.arm.spring_length
	view.select(2)
	view.item_selected.emit(2)
	side.select(1)
	side.item_selected.emit(1)
	check(arena.paused and rig.arm.spring_length == old_length, "changing camera settings during pause does not snap")
	rig._process(GameBalance.get_number("camera_settings_blend_s") * 0.5)
	rig.follow_target()
	check(rig.arm.spring_length > old_length and rig.arm.spring_length < GameBalance.get_number("camera_distance_far"), "paused camera eases toward the new distance")
	rig._process(5.0)
	rig.follow_target()
	check(is_equal_approx(rig.arm.spring_length, GameBalance.get_number("camera_distance_far")) and rig.arm.position.x < 0.0, "live pause changes settle at Xa / Trái")
	check(arena.hud.pause_panel.size.y < 660.0 and root.get_visible_rect().encloses(arena.hud.pause_panel.get_global_rect()), "pause settings stay below 660 px and inside the screen")
	await physics_frame
	await physics_frame
	arena.free()
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	menu._show_settings()
	await process_frame
	await process_frame
	var actions: Container = menu.menu_settings_actions
	var focused: Control = actions.get_child(0).get_child(1)
	var stops: Array[Control] = []
	for index in 10:
		stops.append(focused)
		focused = focused.find_next_valid_focus()
	check(stops.has(actions.find_child("CameraView", true, false)) and stops.has(actions.find_child("CameraSide", true, false)) and stops.has(actions.find_child("ComfortButton", true, false)) and stops.has(actions.find_child("GraphicsButton", true, false)) and stops.has(actions.get_child(-1)), "keyboard/gamepad focus reaches camera choices, Hiệu ứng, Đồ họa and Back")
	check(menu.menu_settings_layer.get_child(1).size.y < 660.0, "main-menu settings retain the existing 660 px cap")
	menu.free()
