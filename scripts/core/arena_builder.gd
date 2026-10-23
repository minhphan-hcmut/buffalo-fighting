class_name ArenaBuilder
extends RefCounted
## Builds the placeholder oval arena (ground, mud, fence with two gates, light) and the
## flag + number identifiers carried by each buffalo.


static func build(parent: Node3D, mud_zones: Array[StringName]) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GameBalance.get_number("arena_rx") * 2.0 + 4.0, GameBalance.get_number("arena_rz") * 2.0 + 4.0)
	ground.mesh = plane
	ground.material_override = material(Color("#8A5A3B"))
	parent.add_child(ground)
	for zone in mud_zones:
		var mud := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = GameBalance.get_number("mud_radius")
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = 0.025
		mud.mesh = cylinder
		var center := ArenaBounds.mud_center(zone)
		mud.position = Vector3(center.x, 0.015, center.y)
		mud.material_override = material(Color("#5D4638"))
		parent.add_child(mud)
	_build_fence(parent)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	parent.add_child(light)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#33546D")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#F2E6CF")
	environment.ambient_light_energy = 0.7
	world.environment = environment
	parent.add_child(world)


static func add_identifier(actor: Buffalo, color: Color, number: String, faction: String) -> void:
	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.05, 0.55, 0.38)
	flag.mesh = flag_mesh
	flag.position = Vector3(0.0, 1.75, 0.0)
	flag.material_override = material(color)
	actor.add_child(flag)
	var label := Label3D.new()
	label.text = "%s · %s\n%s" % [faction, number, "ĐỎ" if color.r > color.b else "XANH"]
	label.position = Vector3(0.0, 2.25, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.modulate = color
	actor.add_child(label)


static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	return result


static func _build_fence(parent: Node3D) -> void:
	var rx := GameBalance.get_number("arena_rx")
	var rz := GameBalance.get_number("arena_rz")
	var count := 32
	for index in range(count):
		var a0 := TAU * float(index) / count
		var a1 := TAU * float(index + 1) / count
		var midpoint_angle := (a0 + a1) * 0.5
		var gate_half_angle := GameBalance.get_number("gate_width") / (2.0 * rz)
		if absf(wrapf(midpoint_angle, -PI, PI)) < gate_half_angle or absf(absf(wrapf(midpoint_angle, -PI, PI)) - PI) < gate_half_angle:
			continue
		var p0 := Vector3(rx * cos(a0), 0.0, rz * sin(a0))
		var p1 := Vector3(rx * cos(a1), 0.0, rz * sin(a1))
		var midpoint := (p0 + p1) * 0.5
		var tangent := p1 - p0
		var segment := _fence_segment(midpoint, tangent.length())
		segment.rotation.y = atan2(-tangent.z, tangent.x)
		parent.add_child(segment)
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.11
		post_mesh.bottom_radius = 0.11
		post_mesh.height = 1.4
		post.mesh = post_mesh
		post.position = p0 + Vector3.UP * 0.7
		post.material_override = material(Color("#5B3826"))
		parent.add_child(post)


static func _fence_segment(position: Vector3, length: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position + Vector3.UP * 0.75
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 1.5, 0.28)
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	mesh.material_override = material(Color("#5B3826"))
	body.add_child(mesh)
	return body
