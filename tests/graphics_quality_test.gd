extends SceneTree
## Graphics settings (GraphicsQuality + the Đồ họa page): presets set the five detail options,
## a changed detail reads as Tùy chỉnh, choices are saved, and each option really draws less.

const TEST_PATH := "user://graphics_quality_test.cfg"
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func crowd_count(preset: int) -> int:
	GraphicsQuality.set_preset(preset)
	var parent := Node3D.new()
	root.add_child(parent)
	ArenaDressing.build(parent)
	var count := 0
	for node in parent.find_children("Crowd*", "MultiMeshInstance3D", true, false):
		count += (node as MultiMeshInstance3D).multimesh.instance_count
	parent.free()
	return count


func grove_trees(preset: int) -> int:
	GraphicsQuality.set_preset(preset)
	var parent := Node3D.new()
	root.add_child(parent)
	ArenaDressing.build(parent)
	var trunks := parent.find_child("TreeTrunks", true, false) as MultiMeshInstance3D
	var count := trunks.multimesh.instance_count if trunks != null else -1
	parent.free()
	return count


func fence_geometry(preset: int) -> Dictionary:
	GraphicsQuality.set_preset(preset)
	var parent := Node3D.new()
	root.add_child(parent)
	ArenaBuilder._build_fence(parent)
	var bodies: Array = []
	var colors := {}
	var bounds := AABB()
	var first := true
	var meshes := parent.find_children("*", "MeshInstance3D", true, false)
	for child in parent.get_children():
		if child is StaticBody3D:
			var shape := child.get_child(0) as CollisionShape3D
			bodies.append([child.transform, shape.transform, (shape.shape as BoxShape3D).size])
	for mesh: MeshInstance3D in meshes:
		var material := mesh.get_active_material(0) as BaseMaterial3D
		var faces := mesh.mesh.get_faces()
		colors[material.albedo_color] = int(colors.get(material.albedo_color, 0)) + faces.size() / 3
		for vertex in faces:
			var point := mesh.global_transform * vertex
			bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
			first = false
	var result := {"bodies": bodies, "colors": colors, "bounds": bounds, "meshes": meshes.size(),
		"batches": parent.find_children("FenceBatch*", "MeshInstance3D", true, false).size()}
	parent.free()
	return result


func check_low_hud() -> void:
	GraphicsQuality.set_preset(GraphicsQuality.LOW)
	var interval := 1.0 / GameBalance.get_number("graphics_hud_refresh_hz_low")
	check(is_equal_approx(GraphicsQuality.hud_refresh_interval(), interval), "Thấp reads the HUD refresh interval from data")
	SessionState.mode = &"SOLO"
	SessionState.training = false
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.hud.set_process(false)
	arena.start_playing()
	arena.hud._process(0.0)
	var previous: String = arena.hud.timer_label.text
	arena.remaining_time = 32.0
	var snapshot := arena.get_snapshot()
	var clock: float = arena.hud.warning_time
	arena.hud._process(interval * 0.4)
	check(arena.hud.timer_label.text == previous, "Thấp defers redundant HUD redraws until the next refresh")
	arena.hud._process(interval * 0.7)
	check(arena.hud.timer_label.text == "00:32" and is_equal_approx(arena.hud.warning_time - clock, interval * 1.1), "HUD refresh uses accumulated elapsed time, without slowing its timers")
	check(arena.get_snapshot() == snapshot, "HUD refresh never changes gameplay state")
	arena.paused = true
	arena.remaining_time = 31.0
	arena.hud._process(interval * 0.1)
	check(arena.hud.timer_label.text == "00:31", "pause/settings updates bypass HUD throttling")
	arena.paused = false
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	arena.remaining_time = 30.0
	arena.hud._process(interval * 0.1)
	check(GraphicsQuality.hud_refresh_interval() == 0.0 and arena.hud.timer_label.text == "00:30", "Cao still updates the HUD each frame")
	for frame in GameBalance.get_int("vfx_warm_up_settle_frames") + GameBalance.get_int("vfx_warm_up_frames") + 2:
		await process_frame
	arena.free()
	await process_frame


func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	GraphicsQuality.reset(TEST_PATH)
	check(GraphicsQuality.preset() == GraphicsQuality.auto_preset(), "with nothing saved the preset follows the GPU type")
	for preset in [GraphicsQuality.LOW, GraphicsQuality.MEDIUM, GraphicsQuality.HIGH]:
		GraphicsQuality.set_preset(preset)
		check(GraphicsQuality.preset() == preset, "preset %s reads back as itself" % GraphicsQuality.PRESET_NAMES[preset])
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	GraphicsQuality.set_detail("shadows", 1)
	check(GraphicsQuality.preset() == GraphicsQuality.CUSTOM, "changing one detail away from a preset reads as Tùy chỉnh")
	GraphicsQuality.set_show_fps(true)
	GraphicsQuality.reset(TEST_PATH)
	check(GraphicsQuality.detail("shadows") == 1 and GraphicsQuality.detail("crowd") == 2 and GraphicsQuality.show_fps(), "details and the FPS toggle are saved and loaded back")
	GraphicsQuality.set_show_fps(false)

	# Each option draws less on its lower choices.
	var full := LowPoly.crowd_villager_mesh(0)
	GraphicsQuality.set_preset(GraphicsQuality.LOW)
	var simple := GraphicsQuality.crowd_mesh(full)
	var full_indices := (full.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	var simple_indices := (simple.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	check(simple_indices < full_indices * 0.8, "Thưa/Vừa crowd uses a simplified villager mesh (%d vs %d indices)" % [simple_indices, full_indices])
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	check(GraphicsQuality.crowd_mesh(full) == full, "Đầy đủ crowd keeps the full villager mesh")
	var high_crowd := crowd_count(GraphicsQuality.HIGH)
	var low_crowd := crowd_count(GraphicsQuality.LOW)
	check(low_crowd > 0 and low_crowd < high_crowd * 0.7, "Thấp thins the crowd (%d vs %d villagers)" % [low_crowd, high_crowd])
	check(crowd_count(GraphicsQuality.HIGH) == high_crowd, "Cao keeps the same crowd every build")
	check(grove_trees(GraphicsQuality.LOW) < grove_trees(GraphicsQuality.HIGH), "Gọn scenery drops the outer grove")
	var sun := DirectionalLight3D.new()
	GraphicsQuality.set_detail("shadows", 0)
	GraphicsQuality.apply_sun(sun)
	check(not sun.shadow_enabled, "Bóng đổ Tắt turns the sun's shadows off")
	GraphicsQuality.set_detail("shadows", 1)
	GraphicsQuality.apply_sun(sun)
	check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Bóng đổ Thấp uses two shadow splits")
	GraphicsQuality.set_detail("shadows", 2)
	GraphicsQuality.apply_sun(sun)
	check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "Bóng đổ Cao keeps four splits")
	sun.free()
	GraphicsQuality.set_detail("render_scale", 0)
	check(is_equal_approx(root.scaling_3d_scale, 0.7), "Độ phân giải 3D 70% scales the 3D render")
	GraphicsQuality.set_detail("models", 0)
	check(root.mesh_lod_threshold > 1.0, "Chi tiết model Thấp raises the mesh LOD threshold")
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	check(is_equal_approx(root.scaling_3d_scale, 1.0) and is_equal_approx(root.mesh_lod_threshold, 1.0), "Cao restores full resolution and model detail")
	var high_fence := fence_geometry(GraphicsQuality.HIGH)
	var low_fence := fence_geometry(GraphicsQuality.LOW)
	check(low_fence.meshes < high_fence.meshes * 0.5 and low_fence.batches > 0, "Thấp batches the static fence into fewer draw submissions (%d vs %d meshes)" % [low_fence.meshes, high_fence.meshes])
	check(low_fence.bodies == high_fence.bodies and not low_fence.bodies.is_empty(), "fence batching preserves every collision body, transform and shape")
	check(low_fence.colors == high_fence.colors, "batching preserves all triangles and material colors")
	check(low_fence.bounds.position.distance_to(high_fence.bounds.position) < 0.001 and low_fence.bounds.end.distance_to(high_fence.bounds.end) < 0.001, "batched fence remains in the same world bounds")
	check(high_fence.batches == 0 and fence_geometry(GraphicsQuality.HIGH).meshes == high_fence.meshes, "Cao keeps the original unbatched fence")
	GraphicsQuality.set_preset(GraphicsQuality.MEDIUM)
	check(GraphicsQuality.fence_batch_size() == 1 and GraphicsQuality.hud_refresh_interval() == 0.0, "Vừa retains its previous fence and HUD behavior")
	for quality in [GraphicsQuality.HIGH, GraphicsQuality.MEDIUM, GraphicsQuality.LOW]:
		GraphicsQuality.set_preset(quality)
		if quality == GraphicsQuality.LOW:
			check(GraphicsQuality.vfx_particle_scale() > 0.0 and GraphicsQuality.vfx_particle_scale() < 1.0 and is_equal_approx(GraphicsQuality.vfx_particle_scale(), GameBalance.get_number("graphics_vfx_particle_scale_low")), "Thấp reads its reduced particle count from data")
			check(GraphicsQuality.vfx_dust_lifetime_scale() > 0.0 and GraphicsQuality.vfx_dust_lifetime_scale() < 1.0 and is_equal_approx(GraphicsQuality.vfx_dust_lifetime_scale(), GameBalance.get_number("graphics_vfx_dust_lifetime_scale_low")), "Thấp reads its shorter dust lifetime from data")
			check(not GraphicsQuality.vfx_secondary_enabled() and GameBalance.get_int("graphics_vfx_secondary_enabled_low") == 0, "Thấp omits decorative secondary effects according to data")
		else:
			check(GraphicsQuality.vfx_particle_scale() == 1.0 and GraphicsQuality.vfx_dust_lifetime_scale() == 1.0 and GraphicsQuality.vfx_secondary_enabled(), "Cao/Vừa preserve the original VFX tuning")
	await check_low_hud()

	# FPS limit: VSync by default, any cap or unlimited, saved, independent of the preset.
	# Headless has no window to report VSync, so it is checked only with a real display.
	var windowed := DisplayServer.get_name() != "headless"
	check(GraphicsQuality.fps_limit() == 0 and (not windowed or DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED) and Engine.max_fps == 0, "by default the frame rate follows the screen with VSync")
	var sixty := GraphicsQuality.FPS_LIMITS.find(60)
	GraphicsQuality.set_fps_limit(sixty)
	check(Engine.max_fps == 60 and (not windowed or DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED), "a 60 FPS limit caps the frame rate with VSync off")
	GraphicsQuality.set_fps_limit(GraphicsQuality.FPS_LIMITS.find(-1))
	check(Engine.max_fps == 0 and (not windowed or DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED), "Không giới hạn removes the limit")
	GraphicsQuality.set_fps_limit(sixty)
	GraphicsQuality.set_preset(GraphicsQuality.LOW)
	GraphicsQuality.reset(TEST_PATH)
	check(GraphicsQuality.fps_limit() == sixty and GraphicsQuality.preset() == GraphicsQuality.LOW, "the FPS limit is saved and a preset does not change it")
	GraphicsQuality.set_fps_limit(0)
	GraphicsQuality.set_preset(GraphicsQuality.HIGH)

	# The Đồ họa page in the settings.
	var holder := VBoxContainer.new()
	root.add_child(holder)
	SettingsControls.populate(holder)
	var opener := holder.find_child("GraphicsButton", true, false) as Button
	check(opener != null and opener.text.contains("Cao"), "settings show an Đồ họa button with the current preset")
	opener.pressed.emit()
	var page := holder.find_child("GraphicsPage", true, false) as Control
	var options := page.find_children("*", "OptionButton", true, false) if page != null else []
	check(options.size() == 2 + GraphicsQuality.DETAILS.size(), "the Đồ họa page has a preset row, one row per detail and an FPS limit row")
	await process_frame
	var panel := page.find_children("*", "PanelContainer", true, false)[0] as Control if page != null else null
	check(panel != null and root.get_visible_rect().encloses(panel.get_global_rect()), "the Đồ họa page fits the window (%s)" % (panel.get_global_rect() if panel != null else "none"))
	if options.size() == 7:
		(options[6] as OptionButton).select(GraphicsQuality.FPS_LIMITS.find(30))
		(options[6] as OptionButton).item_selected.emit(GraphicsQuality.FPS_LIMITS.find(30))
		check(Engine.max_fps == 30, "picking 30 on the page limits the frame rate at once")
		(options[6] as OptionButton).item_selected.emit(0)
		(options[0] as OptionButton).select(GraphicsQuality.LOW)
		(options[0] as OptionButton).item_selected.emit(GraphicsQuality.LOW)
		check(GraphicsQuality.preset() == GraphicsQuality.LOW and (options[1] as OptionButton).selected == 0, "picking Thấp on the page sets the details and shows them")
		(options[2] as OptionButton).select(2)
		(options[2] as OptionButton).item_selected.emit(2)
		check((options[0] as OptionButton).selected == GraphicsQuality.CUSTOM and opener.text.contains("Tùy chỉnh"), "changing a detail on the page shows Tùy chỉnh")
	holder.free()

	GraphicsQuality.set_preset(GraphicsQuality.HIGH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	GraphicsQuality.reset()
	print("GRAPHICS QUALITY TEST FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
