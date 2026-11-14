extends SceneTree
## Stands crowd: the baked Quaternius villager drawn as MultiMeshes (ArenaDressing, LowPoly).

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
	for variant in 2:
		var mesh := LowPoly.crowd_villager_mesh(variant)
		var box := mesh.get_aabb()
		check(box.position.y > -0.05 and box.end.y > 1.6 and box.end.y < 2.0, "pose %d stands on the origin, ~1.7 m tall with hat: %s" % [variant, box])
		var parts: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var tags := {}
		for uv in parts:
			tags[snappedf(uv.x, 0.1)] = true
		check(tags.size() == 5, "pose %d tags skin, hair, shirt, trousers and hat (found %s)" % [variant, tags.keys()])
	check(LowPoly.crowd_villager_mesh(0) == LowPoly.crowd_villager_mesh(0), "baked crowd mesh is cached")
	check(not LowPoly.crowd_villager_mesh(1).get_aabb().is_equal_approx(LowPoly.crowd_villager_mesh(0).get_aabb()), "cheering pose differs from the calm pose")

	var holder := Node3D.new()
	root.add_child(holder)
	ArenaDressing.build(holder)
	var dressing := holder.get_node("Dressing")
	var calm := dressing.get_node_or_null("Crowd") as MultiMeshInstance3D
	var cheering := dressing.get_node_or_null("CrowdCheering") as MultiMeshInstance3D
	check(calm != null and cheering != null, "stands hold a calm and a cheering crowd")
	if calm != null and cheering != null:
		var total := calm.multimesh.instance_count + cheering.multimesh.instance_count
		check(total > 200, "stands are full (%d villagers)" % total)
		check(cheering.multimesh.instance_count < calm.multimesh.instance_count, "most of the crowd stands calm")
		check(calm.multimesh.use_custom_data and calm.material_override == cheering.material_override, "shared crowd material with per-villager custom data")
		check(calm.material_override == dressing.get_meta("crowd_material"), "CrowdReaction drives the same material")
		check(calm.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "crowd casts no shadows")
		# Per-villager shirt and hat data is not readable here: the headless renderer keeps no MultiMesh buffers.
	var straw := LowPoly.STRAW_HAT
	check(LowPoly.material(straw).albedo_color == LowPoly.tone(straw), "plain materials show palette colours through LowPoly.tone()")
	check(GameBalance.get_number("ui_palette_depth") <= 0.0 or LowPoly.tone(straw).get_luminance() < straw.get_luminance(), "palette depth deepens pale plain colours")
	var palm_count := 0
	for kind in ArenaDressing.PALM_MODELS.size():
		var palms := dressing.get_node_or_null("Palms%d" % kind) as MultiMeshInstance3D
		check(palms != null, "palm row %d exists" % kind)
		if palms == null:
			continue
		palm_count += palms.multimesh.instance_count
		var leaf_tone := LowPoly.tone(ArenaDressing.PALM_LEAF)
		var colours: Array[Color] = []
		for surface in palms.multimesh.mesh.get_surface_count():
			colours.append((palms.multimesh.mesh.surface_get_material(surface) as StandardMaterial3D).albedo_color)
		check(colours.has(leaf_tone), "palm %d leaves use the arena palette, not Kenney's teal" % kind)
	var round_trees := (dressing.get_node("TreeTrunks") as MultiMeshInstance3D).multimesh.instance_count
	check(palm_count > 0 and round_trees > palm_count, "palms mix into the tree ring without replacing it (%d palms, %d round trees)" % [palm_count, round_trees])
	holder.free()
	await process_frame
	print("CROWD TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
