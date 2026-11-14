class_name ArenaBuilder
extends RefCounted
## Builds the parts of the arena that a match depends on (mud zones, the bamboo fence
## with its collision and two gates), the sun and sky, and each buffalo's identity
## (announcer name and team outline). Festival scenery (stands, crowd, flags, trees) is in ArenaDressing.

const FENCE_HEIGHT := 1.5
## Render layer for far scenery the sun must not light (see ArenaDressing hills).
const FAR_SCENERY_LAYER := 1 << 1
const BAMBOO := Color("#8F7C5A")
const BAMBOO_DARK := Color("#6E5D42")
const LASHING := Color("#5A3B27")
## Team rims (GDD 5.1): the red side gets a bright rim, the blue side a dark one.
const OUTLINE_RED := Color("#E6B490")
const OUTLINE_BLUE := Color("#0E1822")
const MUD_SHADER := preload("res://assets/shaders/mud_patch.gdshader")
const MUD_ALBEDO := preload("res://assets/textures/mud/brown_mud_03_diff_1k.jpg")
const MUD_NORMAL := preload("res://assets/textures/mud/brown_mud_03_nor_gl_1k.jpg")
const MUD_ARM := preload("res://assets/textures/mud/brown_mud_03_arm_1k.jpg")


static func build(parent: Node3D, mud_zones: Array[StringName]) -> void:
	ArenaDressing.build(parent)
	for i in mud_zones.size():
		var mud := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		# The quad overshoots the gameplay radius so the noisy rim can fade past it.
		var fraction := GameBalance.get_number("mud_visual_radius_fraction", 0.8)
		plane.size = Vector2.ONE * 2.0 * GameBalance.get_number("mud_radius") / fraction
		mud.mesh = plane
		var center := ArenaBounds.mud_center(mud_zones[i])
		mud.position = Vector3(center.x, 0.012, center.y)
		mud.rotation.y = 1.3 * i
		mud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mud.material_override = _mud_material(fraction, float(i) * 7.3, plane.size.x)
		parent.add_child(mud)
	_build_fence(parent)
	add_lighting(parent)


## The arena's sun, sky, ambient light, tonemap and haze. Shared with scenes that show the
## buffaloes outside a match (the how-to-play demo) so they look the same as in the arena.
static func add_lighting(parent: Node3D) -> void:
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
	var bright := color.r > color.b
	Buffalo.add_team_outline(actor, OUTLINE_RED if bright else OUTLINE_BLUE)


## The losing buffalo's own handler (team shirt), starting outside the gate beside the
## exit corridor (GDD 4.5 outro); MatchOutro walks them in and leads the buffalo out.
## Visual meshes only: no collision, no AI.
static func add_handler(parent: Node3D, gate: Vector3, shirt: Color) -> Node3D:
	var at := Vector3(signf(gate.x) * (GameBalance.get_number("arena_rx") + 2.0), 0.0, GameBalance.get_number("gate_width") * 0.5 + 0.35)
	var handler := LowPoly.villager(parent, at, -PI / 2.0 if gate.x > 0.0 else PI / 2.0, shirt)
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
	# Shut during play, so the gaps do not look open where the arena oval still stops a buffalo.
	parent.add_child(ArenaGates.new())


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
static func _add_bamboo_panel(body: Node3D, length: float) -> void:
	var bottom := -FENCE_HEIGHT * 0.5
	for x in [-length * 0.5, length * 0.5]:
		LowPoly.cylinder(body, "Post", 0.085, 0.1, FENCE_HEIGHT + 0.25, Vector3(x, bottom + (FENCE_HEIGHT + 0.25) * 0.5, 0.0), BAMBOO_DARK)
		LowPoly.cylinder(body, "PostCap", 0.1, 0.1, 0.06, Vector3(x, bottom + FENCE_HEIGHT + 0.25, 0.0), BAMBOO)
	for height in [0.35, 0.8, 1.25]:
		var rail := LowPoly.cylinder(body, "Rail", 0.055, 0.055, length + 0.1, Vector3(0.0, bottom + height, 0.06), BAMBOO)
		rail.rotation.z = PI * 0.5
		for x in [-length * 0.5, length * 0.5]:
			LowPoly.cylinder(body, "Lashing", 0.11, 0.11, 0.08, Vector3(x, bottom + height, 0.0), LASHING)


# Wet mud with a broken, fading rim and glossy puddles (assets/shaders/mud_patch.gdshader),
# so it reads as slower ground at a glance without looking pasted on.
static func _mud_material(radius_fraction: float, seed: float, size_m: float) -> ShaderMaterial:
	var mud := ShaderMaterial.new()
	mud.shader = MUD_SHADER
	mud.set_shader_parameter("radius_fraction", radius_fraction)
	mud.set_shader_parameter("seed", seed)
	mud.set_shader_parameter("mud_albedo", MUD_ALBEDO)
	mud.set_shader_parameter("mud_normal", MUD_NORMAL)
	mud.set_shader_parameter("mud_arm", MUD_ARM)
	mud.set_shader_parameter("tile_count", size_m / GameBalance.get_number("mud_texture_tile_m"))
	for key in ["edge_noise", "edge_soft", "puddle_amount", "wet_roughness", "wet_depth", "puddle_roughness", "wet_specular", "puddle_specular", "sheen_strength", "sheen_power", "sheen_frequency", "sheen_sharpness", "wet_rim_width", "wet_rim_darken", "texture_normal_depth", "texture_ao"]:
		mud.set_shader_parameter(key, GameBalance.get_number("mud_" + key))
	for key in ["mud_color", "rim_color", "puddle_color"]:
		mud.set_shader_parameter(key, Color(GameBalance.get_number("mud_" + key + "_r"), GameBalance.get_number("mud_" + key + "_g"), GameBalance.get_number("mud_" + key + "_b")))
	return mud
