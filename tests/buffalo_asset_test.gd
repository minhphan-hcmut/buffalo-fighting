extends SceneTree


func _initialize() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var packed := load("res://assets/characters/buffalo/buffalo.glb") as PackedScene
	assert(packed != null, "GLB must import as a PackedScene")
	var instance := packed.instantiate()
	root.add_child(instance)
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 25, "Expected all 25 exported meshes")
	var bounds := AABB()
	var first := true
	var triangles := 0
	for node in meshes:
		assert(node.mesh != null)
		var box: AABB = node.global_transform * node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in node.mesh.get_surface_count():
			assert(node.mesh.surface_get_material(surface) != null)
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	assert(absf(bounds.position.y) < 0.002, "Feet must meet Godot Y=0")
	assert(bounds.size.y > 2.0 and bounds.size.y < 2.2)
	assert(triangles < 35000)
	var muzzle := instance.find_child("Muzzle", true, false) as MeshInstance3D
	assert(
		(muzzle.global_transform * muzzle.get_aabb().get_center()).z < -1.5,
		"Face must point Godot -Z"
	)
	var body := instance.find_child("Body", true, false) as MeshInstance3D
	assert(
		(body.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture != null,
		"Embedded skin texture must import"
	)
	print(
		"BUFFALO_ASSET_PASS meshes=%d triangles=%d bounds=%s" % [meshes.size(), triangles, bounds]
	)
	instance.queue_free()
	quit()
