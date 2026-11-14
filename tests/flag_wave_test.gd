extends SceneTree
## Cloth geometry, shared wave settings, pinned UV edge and Compatibility-safe palette.

var failures := 0
const WAVE := preload("res://assets/shaders/flag_wave.gdshader")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func cloth(mesh: PlaneMesh, material: ShaderMaterial, hanging: bool) -> void:
	check(mesh != null and mesh.orientation == PlaneMesh.FACE_Z, "cloth is a vertical plane")
	if mesh == null:
		return
	check(material.shader == WAVE, "cloth uses the shared wave shader")
	check(mesh.subdivide_depth == GameBalance.get_int("flag_mesh_subdivisions") if hanging else mesh.subdivide_width == GameBalance.get_int("flag_mesh_subdivisions"), "cloth is subdivided along its free direction")
	check(bool(material.get_shader_parameter("hanging")) == hanging, "cloth pins the correct UV edge")
	for key in ["amplitude", "speed", "cycles", "phase_spread"]:
		check(is_equal_approx(float(material.get_shader_parameter(key)), GameBalance.get_number("flag_wave_" + key)), "wave reads flag_wave_" + key)
	var uv: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var pinned := 0
	var free := 0
	for point in uv:
		var distance := point.y if hanging else point.x
		if is_zero_approx(distance):
			pinned += 1
		if is_equal_approx(distance, 1.0):
			free += 1
	check(pinned >= 2 and free >= 2, "mesh includes both pinned and free edge vertices")

func run() -> void:
	check(WAVE.code.contains("* amplitude * free_edge * free_edge"), "wave displacement vanishes at the tied edge and grows toward the free edge")
	check(WAVE.code.contains("MODEL_MATRIX[3].x + MODEL_MATRIX[3].z"), "world XZ phase keeps five adjacent bands together and offsets separate flags")
	check(WAVE.code.contains("cull_disabled"), "cloth is visible from both sides")
	var scenery := Node3D.new()
	root.add_child(scenery)
	ArenaDressing._build_flags(scenery)
	await process_frame
	for name in ["PoleFlags", "Pennants"]:
		var flags := scenery.get_node(name) as MultiMeshInstance3D
		var hanging: bool = name == "Pennants"
		cloth(flags.multimesh.mesh as PlaneMesh, flags.material_override as ShaderMaterial, hanging)
		check(flags.multimesh.use_custom_data and not flags.multimesh.use_colors, "MultiMesh tint bypasses COLOR on Compatibility")
		check(bool(flags.material_override.get_shader_parameter("instance_colors")), "MultiMesh shader reads instance custom tint")
		check(bool(flags.material_override.get_shader_parameter("pennant")) == hanging, "pennants taper toward their free tip")
		# Headless keeps no MultiMesh buffers; verify their contents in the windowed run.
		if DisplayServer.get_name() != "headless":
			var palette_ok := true
			var normal_ok := true
			for index in flags.multimesh.instance_count:
				if not hanging:
					var expected := ArenaDressing.FLAG_COLORS[index % ArenaDressing.FLAG_COLORS.size()].srgb_to_linear()
					var actual := flags.multimesh.get_instance_custom_data(index)
					# Compatibility stores custom data as half floats; compare the displayed 8-bit colour.
					palette_ok = palette_ok and actual.to_rgba32() == expected.to_rgba32()
				normal_ok = normal_ok and is_equal_approx(flags.multimesh.get_instance_transform(index).basis.z.length(), 1.0)
			check(palette_ok, "pole flags retain their original palette")
			check(normal_ok, "cloth normals are unscaled so old box thickness cannot crush waves")
	var ceremony := CeremonyDiorama.new()
	root.add_child(ceremony)
	ceremony._build_banners()
	ceremony._build_flagpole()
	for band: MeshInstance3D in ceremony.flag.get_children():
		cloth(band.mesh as PlaneMesh, band.material_override as ShaderMaterial, false)
		check(band.material_override.get_shader_parameter("cloth_color").is_equal_approx(LowPoly.tone(CeremonyDiorama.FLAG_BANDS[band.get_index()])), "ceremony flag retains its material palette")
	var banners := 0
	for banner in ceremony.get_children():
		var cloth_node := banner.get_node_or_null("Cloth") as MeshInstance3D
		if cloth_node != null and cloth_node.material_override is ShaderMaterial:
			banners += 1
			cloth(cloth_node.mesh as PlaneMesh, cloth_node.material_override as ShaderMaterial, true)
	check(banners == 6, "all six ceremony banners use waving cloth")
	ceremony.advance(0.5)
	for banner in ceremony.get_children():
		var cloth_node := banner.get_node_or_null("Cloth") as MeshInstance3D
		if cloth_node != null and cloth_node.material_override is ShaderMaterial:
			check(is_zero_approx(banner.rotation.z), "banner attachment remains still while its vertices wave")
	ceremony.free()
	scenery.free()
	await process_frame
	print("FLAG WAVE FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
