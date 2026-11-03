extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var model := load("res://assets/characters/buffalo_hero/buffalo_hero.glb") as PackedScene
	assert(model != null)
	var instance := model.instantiate()
	root.add_child(instance)
	var bounds := AABB()
	var first := true
	var triangles := 0
	for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			assert(material != null and material.albedo_texture != null)
			var arrays := mesh.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	assert(triangles < 35000)
	assert(absf(bounds.position.y) < 0.01)
	assert(bounds.size.y > 2.0 and bounds.size.y < 2.2)
	var audio := root.get_node("GameAudio")
	for file in DirAccess.get_files_at("res://assets/audio"):
		if file.ends_with(".wav") or file.ends_with(".ogg"):
			var stream: AudioStream = audio.stream_for(file.get_basename())
			assert(stream != null and stream.get_length() > 0.0)
	assert(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0)
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	await process_frame
	arena.start_playing()
	await process_frame
	arena._set_paused(true)
	await process_frame
	arena._set_paused(false)
	arena._finish(1, &"TIME")
	await process_frame
	assert(audio.music.stream != null)
	print("HERO_AUDIO_PASS triangles=%d bounds=%s" % [triangles, bounds])
	arena.free()
	instance.free()
	quit()
