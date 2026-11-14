extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func _finish() -> void:
	print("HERO AUDIO TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func run() -> void:
	var model := load("res://assets/characters/buffalo_hero/buffalo_hero.glb") as PackedScene
	check(model != null, "HERO GLB imports as a PackedScene")
	if model == null:
		_finish()
		return
	var instance := model.instantiate()
	root.add_child(instance)
	var bounds := AABB()
	var first := true
	var triangles := 0
	var all_textured := true
	for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if material == null or material.albedo_texture == null:
				all_textured = false
			var arrays := mesh.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	check(all_textured, "Every HERO surface has a textured material")
	check(triangles < 35000, "HERO triangle count under 35000")
	check(absf(bounds.position.y) < 0.01, "HERO feet meet Godot Y=0")
	check(bounds.size.y > 2.0 and bounds.size.y < 2.2, "HERO height is between 2.0 and 2.2 m")
	var audio := root.get_node("GameAudio")
	for file in DirAccess.get_files_at("res://assets/audio"):
		if file.ends_with(".wav") or file.ends_with(".ogg"):
			var stream: AudioStream = audio.stream_for(file.get_basename())
			check(stream != null and stream.get_length() > 0.0, "Audio stream loads: " + file)
	check(
		AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0,
		"Music and SFX buses exist"
	)
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
	check(audio.music.stream != null, "Music plays after the match ends")
	print("HERO_AUDIO triangles=%d bounds=%s" % [triangles, bounds])
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	arena.free()
	instance.free()
	await physics_frame
	await physics_frame
	_finish()
