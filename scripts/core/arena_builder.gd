class_name ArenaBuilder
extends RefCounted
## Builds the parts of the arena that a match depends on (mud zones, the bamboo fence
## with its collision and two gates), the sun and sky, and the flag + number carried by
## each buffalo. Festival scenery (stands, crowd, flags, trees) is in ArenaDressing.

const FENCE_HEIGHT := 1.5
## Render layer for far scenery the sun must not light (see ArenaDressing hills).
const FAR_SCENERY_LAYER := 1 << 1
const BAMBOO := Color("#B9A060")
const BAMBOO_DARK := Color("#8E7740")
const LASHING := Color("#5A3B27")


static func build(parent: Node3D, mud_zones: Array[StringName]) -> void:
	ArenaDressing.build(parent)
	for zone in mud_zones:
		var mud := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = GameBalance.get_number("mud_radius")
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = 0.025
		mud.mesh = cylinder
		var center := ArenaBounds.mud_center(zone)
		mud.position = Vector3(center.x, 0.015, center.y)
		mud.material_override = _mud_material()
		parent.add_child(mud)
	_build_fence(parent)
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	light.light_color = Color("#FFF1DC")
	light.light_energy = GameBalance.get_number("ui_sun_energy")
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 60.0
	# On the Compatibility renderer, objects wholly beyond the shadow distance are
	# over-lit by the sun; far scenery sits on its own layer and gets sky light only.
	light.light_cull_mask = ~FAR_SCENERY_LAYER & 0xFFFFF
	parent.add_child(light)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#5F86A6")
	sky_material.sky_horizon_color = Color("#EBC8A0")
	sky_material.ground_horizon_color = Color("#C9B48A")
	sky_material.ground_bottom_color = Color("#59523B")
	sky_material.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.ambient_light_energy = GameBalance.get_number("ui_ambient_energy")
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = GameBalance.get_number("ui_exposure", 1.0)
	# Haze softens the hills and trees so the arena reads first.
	environment.fog_enabled = true
	environment.fog_light_color = Color("#CBD3D2")
	environment.fog_density = GameBalance.get_number("ui_fog_density", 0.006)
	environment.fog_sky_affect = 0.0
	world.environment = environment
	parent.add_child(world)


static func add_identifier(actor: Buffalo, color: Color, number: String, faction: String) -> void:
	actor.set_meta("announcer_name", "Ông trâu số %s cờ %s %s" % [number, "đỏ" if color.r > color.b else "xanh", faction.capitalize()])
	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.05, 0.55, 0.38)
	flag.mesh = flag_mesh
	flag.position = Vector3(0.0, 1.75, 0.0)
	flag.material_override = LowPoly.material(color)
	actor.add_child(flag)


## A handler waiting beside the exit corridor for the losing buffalo, outside its
## path (GDD 4.5 outro). Visual meshes only: no collision, no AI.
static func add_handler(parent: Node3D, gate: Vector3) -> Node3D:
	var at := Vector3(signf(gate.x) * (GameBalance.get_number("arena_rx") + 2.0), 0.0, GameBalance.get_number("gate_width") * 0.5 + 0.35)
	var handler := LowPoly.villager(parent, at, -PI / 2.0 if gate.x > 0.0 else PI / 2.0, Color("#33546D"))
	handler.name = "GateHandler"
	return handler


static func _build_fence(parent: Node3D) -> void:
	var rx := GameBalance.get_number("arena_rx")
	var rz := GameBalance.get_number("arena_rz")
	var count := GameBalance.get_int("arena_fence_segments", 32)
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


static func _fence_segment(position: Vector3, length: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position + Vector3.UP * 0.75
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, FENCE_HEIGHT, 0.28)
	collision.shape = shape
	body.add_child(collision)
	_add_bamboo_panel(body, length)
	return body


# Visual bamboo for one fence segment centred on `body`: a post at each end and three
# rails, with dark lashing where they meet. Thick enough to stay solid from the
# gameplay camera (thin slats flicker at that distance).
static func _add_bamboo_panel(body: StaticBody3D, length: float) -> void:
	var bottom := -FENCE_HEIGHT * 0.5
	for x in [-length * 0.5, length * 0.5]:
		LowPoly.cylinder(body, "Post", 0.085, 0.1, FENCE_HEIGHT + 0.25, Vector3(x, bottom + (FENCE_HEIGHT + 0.25) * 0.5, 0.0), BAMBOO_DARK)
		LowPoly.cylinder(body, "PostCap", 0.1, 0.1, 0.06, Vector3(x, bottom + FENCE_HEIGHT + 0.25, 0.0), BAMBOO)
	for height in [0.35, 0.8, 1.25]:
		var rail := LowPoly.cylinder(body, "Rail", 0.055, 0.055, length + 0.1, Vector3(0.0, bottom + height, 0.06), BAMBOO)
		rail.rotation.z = PI * 0.5
		for x in [-length * 0.5, length * 0.5]:
			LowPoly.cylinder(body, "Lashing", 0.11, 0.11, 0.08, Vector3(x, bottom + height, 0.0), LASHING)


# Dark wet earth with a slight sheen, so mud reads as slower ground at a glance.
static func _mud_material() -> StandardMaterial3D:
	var mud := LowPoly.material(Color("#4A3426")).duplicate() as StandardMaterial3D
	mud.roughness = 0.35
	return mud
