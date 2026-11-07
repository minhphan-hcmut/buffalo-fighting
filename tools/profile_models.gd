extends SceneTree
# Read-only runtime experiment: never saves resources or project settings.
var arena: Node3D
var models: Array[Node3D] = []
var lights: Array[DirectionalLight3D] = []


func _initialize() -> void:
	call_deferred("run")


func sample(label: String, shadows: bool, visible_models: bool) -> void:
	for light in lights:
		light.shadow_enabled = shadows
	for model in models:
		model.visible = visible_models
	for i in range(60):
		await process_frame
	var times: Array[float] = []
	var calls := 0.0
	var primitives := 0.0
	var objects := 0.0
	var last := Time.get_ticks_usec()
	for i in range(240):
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	times.sort()
	var mean := 0.0
	for value in times:
		mean += value / times.size()
	print(
		JSON.stringify(
			{
				"case": label,
				"mean_frame_ms": mean,
				"median_frame_ms": times[120],
				"p95_frame_ms": times[228],
				"draw_calls": calls / 240,
				"render_primitives": primitives / 240,
				"render_objects": objects / 240,
				"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
				"texture_memory_bytes":
				Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
				"buffer_memory_bytes": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
			}
		)
	)


func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	for child in arena.get_children():
		child.set_physics_process(false)
		if child is DirectionalLight3D:
			lights.append(child)
	models.append(arena.player.get_node("Visual/Model"))
	models.append(arena.opponent.get_node("Visual/Model"))
	var meshes := {}
	var materials := {}
	var surfaces := 0
	var triangles := 0
	var instances := 0
	var shadow_instances := 0
	for model in models:
		for node in model.find_children("*", "MeshInstance3D", true, false):
			instances += 1
			var mesh: Mesh = node.mesh
			meshes[mesh.get_instance_id()] = true
			if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadow_instances += 1
			for s in mesh.get_surface_count():
				surfaces += 1
				var arrays := mesh.surface_get_arrays(s)
				var indices = arrays[Mesh.ARRAY_INDEX]
				triangles += (
					indices.size() / 3
					if indices != null and indices.size() > 0
					else arrays[Mesh.ARRAY_VERTEX].size() / 3
				)
				var mat: Material = node.get_active_material(s)
				if mat:
					materials[mat.get_instance_id()] = true
	print(
		JSON.stringify(
			{
				"instances": instances,
				"unique_mesh_resources": meshes.size(),
				"surfaces": surfaces,
				"base_triangles_two_models": triangles,
				"unique_materials": materials.size(),
				"shadow_caster_instances": shadow_instances,
				"viewport": str(root.get_visible_rect().size),
				"adapter": RenderingServer.get_video_adapter_name(),
				"render_method": RenderingServer.get_current_rendering_method()
			}
		)
	)
	for light in lights:
		print(
			"LIGHT shadow_mode=", light.directional_shadow_mode, " enabled=", light.shadow_enabled
		)
	await sample("models_on_shadows_on_A", true, true)
	await sample("models_on_shadows_off_A", false, true)
	await sample("models_hidden_shadows_on", true, false)
	await sample("models_on_shadows_off_B", false, true)
	await sample("models_on_shadows_on_B", true, true)
	for model in models:
		for node in model.find_children("*", "MeshInstance3D", true, false):
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await sample("models_visible_only_model_casting_off", true, true)
	arena.free()
	quit()
