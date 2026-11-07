extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_validate")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func _finish() -> void:
	print("BUFFALO ASSET TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)


func _validate() -> void:
	var packed := load("res://assets/characters/buffalo/buffalo.glb") as PackedScene
	check(packed != null, "GLB must import as a PackedScene")
	if packed == null:
		_finish()
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 25, "Expected all 25 exported meshes")
	var bounds := AABB()
	var first := true
	var triangles := 0
	var all_have_mesh := true
	var all_have_material := true
	for node in meshes:
		if node.mesh == null:
			all_have_mesh = false
			continue
		var box: AABB = node.global_transform * node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in node.mesh.get_surface_count():
			if node.mesh.surface_get_material(surface) == null:
				all_have_material = false
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	check(all_have_mesh, "Every MeshInstance3D has a mesh")
	check(all_have_material, "Every surface has a material")
	check(absf(bounds.position.y) < 0.002, "Feet must meet Godot Y=0")
	check(bounds.size.y > 2.0 and bounds.size.y < 2.2, "Height is between 2.0 and 2.2 m")
	check(triangles < 35000, "Triangle count under 35000")
	var muzzle := instance.find_child("Muzzle", true, false) as MeshInstance3D
	check(
		muzzle != null and (muzzle.global_transform * muzzle.get_aabb().get_center()).z < -1.5,
		"Face must point Godot -Z"
	)
	var body := instance.find_child("Body", true, false) as MeshInstance3D
	check(
		body != null and (body.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture != null,
		"Embedded skin texture must import"
	)
	print(
		"BUFFALO_ASSET meshes=%d triangles=%d bounds=%s" % [meshes.size(), triangles, bounds]
	)
	instance.free()
	_finish()
