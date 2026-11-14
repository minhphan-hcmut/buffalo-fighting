class_name CeremonyDiorama
extends Node3D
## Low-poly 3D tableau shown behind the Phần Lễ captions (GDD 4.5, Bảng 17).
## Built from primitive meshes only; the champion buffalo reuses the in-game model.
## Variants, in festival order: &"opening" (1/8, dâng hương, thượng cờ ở đền), &"water"
## (7/8, rước nước trên kiệu hoa), &"giap" (8/8, các giáp dắt ông trâu về đình), &"drums"
## (9/8, trống khai hội và múa cờ trên sới, rước ông trâu ra sân) and &"closing" (rước ông
## trâu vô địch về đình).

const GROUND_MATERIAL: StandardMaterial3D = preload("res://assets/environment/sparse_grass/ground.tres")
const BUFFALO_MODEL: PackedScene = preload("res://assets/characters/buffalo_hero/buffalo_hero.glb")

const LACQUER := Color("#8E2B22")
const TILE := Color("#4A3B36")
const STONE := Color("#9C8F7A")
const WOOD := Color("#6E4A33")
const GOLD := Color("#E8BC65")
const PAPER := Color("#F2E6CF")
const BRICK := Color("#A0674B")
const FLAG_BANDS: Array[Color] = [Color("#C0392B"), Color("#E8BC65"), Color("#2E6E9E"), Color("#F2E6CF"), Color("#3E8E4E")]

var variant: StringName = &"opening"
var config: Dictionary = {}
var elapsed := 0.0
var camera: Camera3D
var flag: Node3D
var champion: Node3D
var leader: Node3D
## Groups that walk from their start to their end over `procession_s`: [node, from, to].
var _movers: Array = []
## People who bob as they walk or carry (palanquin bearers, drummers on the move).
var _bobbers: Array[Node3D] = []
## Shoulder pivots of drummers' arms, swung on the beat.
var _drum_arms: Array[Node3D] = []
## Flag dancers' pivots, swung in a figure of eight.
var _dancer_flags: Array[Node3D] = []
var _camera_target := Vector3.ZERO
var _camera_offset := Vector3.ZERO
var _camera_lift := 0.0
var _procession_from := Vector3.ZERO
var _procession_to := Vector3.ZERO

# Procession walk clip speed: groups cover ~7 m in procession_s, a slow ceremonial pace.
const WALK_ANIMATION_SPEED := 0.75
const FLAG_LOW_Y := 1.6
const FLAG_HIGH_Y := 6.4


## Builds the tableau for `which` (see the variants above); `settings` is data/ceremony.json.
func setup(which: StringName, settings: Dictionary) -> void:
	variant = which
	config = settings
	if variant == &"drums":
		_build_arena_rite()
	else:
		_build_environment()
		_build_ground()
		_build_shrine()
		_build_banners()
		_build_trees()
	match variant:
		&"opening":
			_build_altar()
			_build_drums()
			_build_flagpole()
			for x in [-1.2, -0.4, 0.4, 1.2]:
				LowPoly.villager(self, Vector3(x, 0.0, 5.4), PI, Color("#5C4033"))
			_camera_target = Vector3(-1.2, 1.2, 2.5)
			_camera_offset = Vector3(0.0, 4.6, 15.5)
		&"water":
			_build_altar()
			_build_water_procession()
			_camera_target = Vector3(0.0, 1.2, 12.0)
			_camera_offset = Vector3(10.5, 4.0, 7.0)
			_camera_lift = 1.3
		&"giap":
			_build_altar()
			_build_drums()
			_build_giap_procession()
			_camera_target = Vector3(0.0, 0.9, 11.5)
			_camera_offset = Vector3(13.0, 6.0, 9.5)
			_camera_lift = 1.6
		&"drums":
			_camera_target = Vector3(-5.5, 1.3, -1.5)
			_camera_offset = Vector3(9.0, 3.4, 9.5)
			_camera_lift = 0.6
		_:
			_build_drums()
			_build_procession()
			_camera_target = Vector3(0.0, 0.6, 5.5)
			_camera_offset = Vector3(10.5, 4.4, 7.5)
	camera = Camera3D.new()
	camera.name = "CeremonyCamera"
	camera.fov = 50.0
	# Lifts the subject above the caption panel that covers the bottom third.
	camera.v_offset = -_camera_lift
	add_child(camera)
	advance(0.0)


## Steps the tableau's animation by `delta` seconds (flag rise, procession, camera drift, banners).
func advance(delta: float) -> void:
	elapsed += delta
	var duration := float(config.get("duration_s", 15.0))
	var drift := deg_to_rad(float(config.get("camera_drift_deg", 8.0)))
	var phase := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var yaw := lerpf(-drift, drift, phase)
	if camera != null:
		camera.position = _camera_target + _camera_offset.rotated(Vector3.UP, yaw)
		camera.look_at(_camera_target, Vector3.UP)
	if flag != null:
		var rise := smoothstep(0.0, 1.0, clampf(elapsed / float(config.get("flag_rise_s", 5.0)), 0.0, 1.0))
		flag.position.y = lerpf(FLAG_LOW_Y, FLAG_HIGH_Y, rise)
	if champion != null and variant == &"closing":
		var walk := clampf(elapsed / float(config.get("procession_s", 12.0)), 0.0, 1.0)
		champion.position = _procession_from.lerp(_procession_to, walk)
		champion.position.y = 0.04 * absf(sin(elapsed * 5.0)) * (1.0 - walk)
		leader.position = champion.position + Vector3(0.9, 0.0, -2.3)
		LowPoly.set_villager_animation(leader, &"Walk" if walk < 1.0 else &"Stand", WALK_ANIMATION_SPEED)
	var walk_phase := clampf(elapsed / float(config.get("procession_s", 12.0)), 0.0, 1.0)
	for mover in _movers:
		(mover[0] as Node3D).position = (mover[1] as Vector3).lerp(mover[2], walk_phase)
	var walking := 1.0 if walk_phase < 1.0 else 0.0
	for walker in _bobbers:
		LowPoly.set_villager_animation(walker.get_child(0), &"Walk" if walking > 0.0 else &"Stand", WALK_ANIMATION_SPEED)
	for index in _drum_arms.size():
		var beat := elapsed * 5.5 + index * 0.6
		LowPoly.drum_swing(_drum_arms[index], absf(sin(beat)), absf(sin(beat + PI * 0.5)))
	for index in _dancer_flags.size():
		var t := elapsed * 1.6 + index * 0.8
		_dancer_flags[index].rotation.z = 0.85 * sin(t)
		_dancer_flags[index].rotation.x = 0.35 * sin(t * 2.0)


## True once the flag has reached the top of the pole (opening variant only).
func flag_raised() -> bool:
	return flag != null and is_equal_approx(flag.position.y, FLAG_HIGH_Y)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -35.0 if variant == &"opening" else 30.0, 0.0)
	sun.light_color = Color("#FFE0B0")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	# Softer shadows: at full opacity the flag cast a black slab across the tiled roof.
	sun.shadow_opacity = GameBalance.get_number("ceremony_shadow_opacity")
	add_child(sun)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#6F8FA3") if variant == &"opening" else Color("#7C7A93")
	sky_material.sky_horizon_color = Color("#F0C995") if variant == &"opening" else Color("#F2A96B")
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.ground_bottom_color = Color("#7A7550")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Light haze, as in the arena: it fades the ground into the horizon instead of a hard dark
	# band where the plane meets the sky. No filmic tonemap here: it washed this brighter,
	# unshadowed courtyard out to pastels.
	environment.fog_enabled = true
	environment.fog_light_color = sky_material.sky_horizon_color.lerp(Color("#CBD3D2"), 0.5)
	environment.fog_density = GameBalance.get_number("ceremony_fog_density")
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(240.0, 240.0)
	ground.mesh = plane
	# World-triplanar material: keep its own tile size (a large uv scale blurs it to flat olive).
	ground.material_override = GROUND_MATERIAL
	add_child(ground)
	LowPoly.box(self, "Forecourt", Vector3(3.4, 0.03, 14.0), Vector3(0.0, 0.015, 9.5), BRICK)


func _build_shrine() -> void:
	var shrine := Node3D.new()
	shrine.name = "Shrine"
	add_child(shrine)
	LowPoly.box(shrine, "Platform", Vector3(8.2, 0.5, 5.2), Vector3(0.0, 0.25, 0.0), STONE)
	LowPoly.box(shrine, "Step", Vector3(3.0, 0.25, 0.8), Vector3(0.0, 0.125, 3.0), STONE.darkened(0.1))
	LowPoly.box(shrine, "BackWall", Vector3(7.4, 2.6, 0.2), Vector3(0.0, 1.8, -2.0), WOOD)
	for x in [-3.3, -1.1, 1.1, 3.3]:
		for z in [1.9, -1.7]:
			LowPoly.cylinder(shrine, "Column", 0.16, 0.16, 2.6, Vector3(x, 1.8, z), LACQUER)
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var prism := PrismMesh.new()
	prism.size = Vector3(6.4, 1.8, 9.6)
	roof.mesh = prism
	roof.position = Vector3(0.0, 4.0, 0.0)
	roof.rotation.y = PI * 0.5
	roof.material_override = LowPoly.material(TILE)
	shrine.add_child(roof)
	LowPoly.box(shrine, "Ridge", Vector3(9.8, 0.16, 0.28), Vector3(0.0, 4.95, 0.0), GOLD.darkened(0.2))
	LowPoly.sphere(shrine, "Moon", 0.28, Vector3(0.0, 5.3, 0.0), GOLD)
	for side in [-1.0, 1.0]:
		var dragon := LowPoly.box(shrine, "RidgeDragon", Vector3(0.9, 0.16, 0.16), Vector3(side * 0.75, 5.12, 0.0), GOLD.darkened(0.2))
		dragon.rotation.z = side * 0.35
		for z in [-3.15, 3.15]:
			var eave := LowPoly.box(shrine, "EaveTip", Vector3(0.9, 0.14, 0.22), Vector3(side * 4.95, 3.25, z), TILE.lightened(0.1))
			eave.rotation.z = side * 0.45
	LowPoly.box(shrine, "PlaqueBorder", Vector3(2.4, 0.62, 0.06), Vector3(0.0, 2.75, 2.02), GOLD)
	LowPoly.box(shrine, "Plaque", Vector3(2.2, 0.5, 0.08), Vector3(0.0, 2.75, 2.04), LACQUER)


func _build_altar() -> void:
	var altar := Node3D.new()
	altar.name = "Altar"
	altar.position = Vector3(0.0, 0.0, 4.3)
	add_child(altar)
	LowPoly.box(altar, "Table", Vector3(1.4, 0.8, 0.7), Vector3(0.0, 0.4, 0.0), LACQUER)
	LowPoly.box(altar, "Cloth", Vector3(1.5, 0.05, 0.8), Vector3(0.0, 0.82, 0.0), GOLD)
	LowPoly.cylinder(altar, "Censer", 0.2, 0.16, 0.22, Vector3(0.0, 0.96, 0.0), Color("#7D6A4A"))
	for x in [-0.07, 0.0, 0.07]:
		LowPoly.cylinder(altar, "Incense", 0.012, 0.012, 0.45, Vector3(x, 1.25, 0.0), Color("#B6453B"))
		var tip := LowPoly.sphere(altar, "Ember", 0.022, Vector3(x, 1.48, 0.0), Color("#FF8A3D"))
		var glow := (tip.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		tip.material_override = glow
		glow.emission_enabled = true
		glow.emission = Color("#FF8A3D")
		glow.emission_energy_multiplier = 2.0
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.position = Vector3(0.0, 1.5, 0.0)
	smoke.amount = 24
	smoke.lifetime = 3.0
	smoke.direction = Vector3.UP
	smoke.spread = 8.0
	smoke.gravity = Vector3(0.05, 0.25, 0.0)
	smoke.initial_velocity_min = 0.2
	smoke.initial_velocity_max = 0.35
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.4
	var puff := SphereMesh.new()
	puff.radius = 0.05
	puff.height = 0.1
	var puff_material := StandardMaterial3D.new()
	puff_material.albedo_color = Color(0.92, 0.9, 0.86, 0.35)
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = puff_material
	smoke.mesh = puff
	altar.add_child(smoke)


func _build_drums() -> void:
	for side in [-1.0, 1.0]:
		var drum := Node3D.new()
		drum.name = "Drum"
		drum.position = Vector3(side * 2.7, 0.0, 4.2)
		add_child(drum)
		for leg_z in [-0.35, 0.35]:
			LowPoly.box(drum, "Stand", Vector3(0.1, 0.8, 0.1), Vector3(0.0, 0.4, leg_z), WOOD)
		var body := LowPoly.cylinder(drum, "Body", 0.55, 0.55, 0.8, Vector3(0.0, 1.25, 0.0), LACQUER)
		body.rotation.z = PI * 0.5
		for face_x in [-0.41, 0.41]:
			var face := LowPoly.cylinder(drum, "Face", 0.5, 0.5, 0.02, Vector3(face_x, 1.25, 0.0), Color("#E6D3A8"))
			face.rotation.z = PI * 0.5


func _build_flagpole() -> void:
	var pole_base := Vector3(-5.6, 0.0, 3.0)
	LowPoly.cylinder(self, "FlagPole", 0.08, 0.1, 7.6, pole_base + Vector3(0.0, 3.8, 0.0), Color("#D8C38A"))
	LowPoly.sphere(self, "PoleTop", 0.14, pole_base + Vector3(0.0, 7.65, 0.0), GOLD)
	flag = Node3D.new()
	flag.name = "Flag"
	flag.position = Vector3(pole_base.x, FLAG_LOW_Y, pole_base.z)
	add_child(flag)
	var band_height := 0.32
	for index in FLAG_BANDS.size():
		var y := (FLAG_BANDS.size() * 0.5 - index - 0.5) * band_height
		_flag_cloth(flag, "FlagBand", Vector2(2.4, band_height), Vector3(1.25, y, 0.0), FLAG_BANDS[index])


func _build_banners() -> void:
	var colors: Array[Color] = [Color("#C0392B"), GOLD, Color("#2E6E9E"), Color("#3E8E4E")]
	var index := 0
	for z in [5.5, 8.0, 10.5]:
		# Procession cameras sit on +X: keep that side clear so the procession reads.
		for side in ([-1.0, 1.0] if variant == &"opening" else [-1.0]):
			var post := Vector3(side * 3.6, 0.0, z)
			LowPoly.cylinder(self, "BannerPole", 0.04, 0.05, 4.2, post + Vector3(0.0, 2.1, 0.0), Color("#D8C38A"))
			var banner := Node3D.new()
			banner.name = "Banner"
			banner.position = post + Vector3(side * -0.3, 4.0, 0.0)
			add_child(banner)
			_flag_cloth(banner, "Cloth", Vector2(0.5, 2.2), Vector3(0.0, -1.1, 0.0), colors[index % colors.size()], true)
			index += 1


func _flag_cloth(parent: Node3D, node_name: String, size: Vector2, at: Vector3, color: Color, hanging := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = LowPoly.flag_cloth(size, hanging)
	instance.position = at
	instance.material_override = LowPoly.flag_material(hanging, color)
	instance.extra_cull_margin = GameBalance.get_number("flag_wave_amplitude")
	parent.add_child(instance)
	return instance


func _build_trees() -> void:
	for spot in [Vector3(-8.0, 0.0, -4.0), Vector3(-6.0, 0.0, -6.5), Vector3(7.5, 0.0, -4.5), Vector3(9.0, 0.0, -1.0), Vector3(-10.0, 0.0, 1.5), Vector3(3.0, 0.0, -7.5)]:
		LowPoly.cylinder(self, "Trunk", 0.18, 0.25, 2.0, spot + Vector3(0.0, 1.0, 0.0), WOOD)
		LowPoly.sphere(self, "Canopy", 1.5, spot + Vector3(0.0, 3.0, 0.0), Color("#4E6B3A"))
		LowPoly.sphere(self, "Canopy", 1.1, spot + Vector3(0.6, 3.9, 0.3), Color("#5C7A44"))


func _build_procession() -> void:
	champion = Node3D.new()
	champion.name = "Champion"
	add_child(champion)
	var model := BUFFALO_MODEL.instantiate()
	champion.add_child(model)
	Buffalo.use_natural_skin(model)
	for index in 7:
		var bead := LowPoly.sphere(champion, "Garland", 0.09, Vector3(-0.42 + index * 0.14, 1.42 - 0.12 * sin(index / 6.0 * PI), -1.25), FLAG_BANDS[index % FLAG_BANDS.size()])
		bead.name = "Garland%d" % index
	_procession_from = Vector3(0.0, 0.0, 12.5)
	_procession_to = Vector3(0.0, 0.0, 6.4)
	leader = LowPoly.villager(self, Vector3.ZERO, 0.0, Color("#33546D"))
	leader.name = "Leader"
	for z in [7.0, 9.5, 12.0]:
		LowPoly.villager(self, Vector3(-1.6, 0.0, z), PI * 0.5, Color("#5C4033"))
		LowPoly.villager(self, Vector3(-2.6, 0.0, z + 1.0), PI * 0.5, Color("#6B4B2B"))


## Rước nước (7/8): flag bearers lead a flower palanquin carrying the water jar toward the
## shrine, with drummers and villagers behind.
func _build_water_procession() -> void:
	var group := _walking_group("WaterProcession", Vector3(0.0, 0.0, 17.0), Vector3(0.0, 0.0, 9.5))
	for side in [-1.0, 1.0]:
		var bearer := _bobbing_villager(group, Vector3(side * 0.9, 0.0, -3.2), Color("#B8432F"))
		_five_colour_flag(bearer, Vector3(side * 0.28, 0.0, 0.0), 3.6, Vector2(0.55, 1.4))
	var palanquin := Node3D.new()
	palanquin.name = "Palanquin"
	group.add_child(palanquin)
	for x in [-0.55, 0.55]:
		for z in [-1.05, 1.05]:
			_bobbing_villager(group, Vector3(x, 0.0, z), Color("#C9A24A"))
		LowPoly.box(palanquin, "CarryPole", Vector3(0.08, 0.08, 3.2), Vector3(x, 1.42, 0.0), WOOD)
	LowPoly.box(palanquin, "Bed", Vector3(0.9, 0.14, 1.1), Vector3(0.0, 1.55, 0.0), LACQUER)
	LowPoly.box(palanquin, "Skirt", Vector3(0.94, 0.05, 1.14), Vector3(0.0, 1.47, 0.0), GOLD)
	for x in [-0.38, 0.38]:
		for z in [-0.46, 0.46]:
			LowPoly.cylinder(palanquin, "Post", 0.025, 0.025, 0.8, Vector3(x, 2.02, z), LACQUER)
	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	var prism := PrismMesh.new()
	prism.size = Vector3(1.15, 0.38, 1.35)
	canopy.mesh = prism
	canopy.position = Vector3(0.0, 2.6, 0.0)
	canopy.material_override = LowPoly.material(GOLD.darkened(0.15))
	palanquin.add_child(canopy)
	var glaze := LowPoly.material(Color("#4F7A80")).duplicate() as StandardMaterial3D
	glaze.roughness = 0.35
	var jar := LowPoly.sphere(palanquin, "WaterJar", 0.27, Vector3(0.0, 1.88, 0.0), Color("#4F7A80"))
	jar.material_override = glaze
	var neck := LowPoly.cylinder(palanquin, "JarNeck", 0.12, 0.15, 0.14, Vector3(0.0, 2.17, 0.0), Color("#4F7A80"))
	neck.material_override = glaze
	LowPoly.box(palanquin, "JarCloth", Vector3(0.3, 0.05, 0.3), Vector3(0.0, 2.25, 0.0), Color("#C0392B"))
	var petals: Array[Color] = [Color("#E35D6A"), Color("#F2C14E"), Color("#F2E6CF"), Color("#D9486B")]
	for index in 12:
		var angle := TAU * index / 12.0
		LowPoly.sphere(palanquin, "Flower", 0.075, Vector3(cos(angle) * 0.42, 1.66, sin(angle) * 0.5), petals[index % petals.size()])
	for side in [-1.0, 1.0]:
		var drummer := _bobbing_villager(group, Vector3(side * 0.75, 0.0, 2.7), Color("#8E2B22"))
		var drum := LowPoly.cylinder(drummer, "HandDrum", 0.24, 0.24, 0.3, Vector3(0.0, 1.05, -0.32), LACQUER)
		drum.rotation.x = PI * 0.5
		_make_drummer(drummer)
	for x in [-0.8, 0.0, 0.8]:
		_bobbing_villager(group, Vector3(x, 0.0, 4.2), Color("#5C4033"))


## Các giáp đưa trâu vào hội (8/8): each giáp leads its buffalo in single file to the shrine.
func _build_giap_procession() -> void:
	var group := _walking_group("GiapProcession", Vector3(0.0, 0.0, 19.0), Vector3(0.0, 0.0, 11.5))
	var shirts: Array[Color] = [Color("#8E2B22"), Color("#2E5E80"), Color("#7A6A2E")]
	for index in 3:
		var at := Vector3(0.0, 0.0, -4.6 + index * 4.6)
		var buffalo := BUFFALO_MODEL.instantiate() as Node3D
		buffalo.name = "GiapBuffalo%d" % index
		buffalo.position = at
		group.add_child(buffalo)
		Buffalo.use_natural_skin(buffalo)
		if index == 1:
			Buffalo.dress_west(buffalo)
		elif index == 2:
			_tint_cloth(buffalo, Color("#F0C46A"))
		_garland(buffalo)
		_bobbing_villager(group, at + Vector3(0.9, 0.0, -2.2), shirts[index])
		var flag_bearer := _bobbing_villager(group, at + Vector3(-0.95, 0.0, -1.2), shirts[index])
		_five_colour_flag(flag_bearer, Vector3(-0.28, 0.0, 0.0), 3.0, Vector2(0.45, 1.0))
		if index == 0:
			champion = buffalo


## Trống khai hội, múa cờ (9/8), on the arena itself: a drum line by the pavilion, flag
## dancers mid-arena and a buffalo led in through the west gate.
func _build_arena_rite() -> void:
	var no_mud: Array[StringName] = []
	ArenaBuilder.build(self, no_mud)
	for index in 4:
		var drum := Node3D.new()
		drum.name = "Drum"
		drum.position = Vector3(-7.5 + index * 2.2, 0.0, -6.6)
		add_child(drum)
		for leg_x in [-0.35, 0.35]:
			LowPoly.box(drum, "Stand", Vector3(0.1, 0.7, 0.1), Vector3(leg_x, 0.35, 0.0), WOOD)
		var body := LowPoly.cylinder(drum, "Body", 0.5, 0.5, 0.75, Vector3(0.0, 1.05, 0.0), LACQUER)
		body.rotation.x = PI * 0.5
		var face := LowPoly.cylinder(drum, "Face", 0.46, 0.46, 0.02, Vector3(0.0, 1.05, 0.39), Color("#E6D3A8"))
		face.rotation.x = PI * 0.5
		var drummer := LowPoly.villager(drum, Vector3(0.0, 0.0, 1.05), 0.0, Color("#8E2B22"))
		_make_drummer(drummer)
	for index in 5:
		var at := Vector3(-8.4 + index * 2.0, 0.0, -1.6 + (index % 2) * 1.6)
		var dancer := LowPoly.villager(self, at, PI * 0.15, FLAG_BANDS[index % FLAG_BANDS.size()].darkened(0.25))
		var pivot := Node3D.new()
		pivot.name = "FlagSwing"
		pivot.position = LowPoly.DRUM_GRIP
		dancer.add_child(pivot)
		LowPoly.make_drummer(dancer, false)
		_five_colour_flag(pivot, Vector3.ZERO, 3.6, Vector2(1.4, 1.7), -1.0)
		_dancer_flags.append(pivot)
	var group := _walking_group("GateEntry", Vector3(-19.0, 0.0, 0.6), Vector3(-11.0, 0.0, 0.6))
	var buffalo := BUFFALO_MODEL.instantiate() as Node3D
	buffalo.name = "ArenaBuffalo"
	buffalo.rotation.y = -PI * 0.5
	group.add_child(buffalo)
	Buffalo.use_natural_skin(buffalo)
	_garland(buffalo)
	champion = buffalo
	leader = _bobbing_villager(group, Vector3(2.3, 0.0, -0.9), Color("#8E2B22"))
	leader.rotation.y = -PI * 0.5


func _walking_group(group_name: String, from: Vector3, to: Vector3) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	group.position = from
	add_child(group)
	_movers.append([group, from, to])
	return group


func _bobbing_villager(parent: Node3D, at: Vector3, shirt: Color) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Walker"
	holder.position = at
	parent.add_child(holder)
	LowPoly.villager(holder, Vector3.ZERO, 0.0, shirt, &"Walk")
	_bobbers.append(holder)
	return holder


## A pole with a five-band flag, held at `at` inside `parent`; `size` is the cloth (width,
## height). `base_y` drops the pole's foot below the holder (for a flag swung from the hands).
func _five_colour_flag(parent: Node3D, at: Vector3, height: float, size: Vector2, base_y := 0.0) -> void:
	LowPoly.cylinder(parent, "FlagPole", 0.025, 0.03, height, at + Vector3(0.0, base_y + height * 0.5, 0.0), Color("#D8C38A"))
	var band := size.y / FLAG_BANDS.size()
	for index in FLAG_BANDS.size():
		var y := base_y + height - 0.1 - band * (index + 0.5)
		var cloth := _flag_cloth(parent, "FlagBand", Vector2(size.x, band), at + Vector3(0.0, y, size.x * 0.5 + 0.03), FLAG_BANDS[index])
		cloth.rotation.y = -PI * 0.5


# Real arms and mallets from the villager rig; `advance()` swings them on the beat.
func _make_drummer(person: Node3D) -> void:
	LowPoly.make_drummer(person)
	_drum_arms.append(person)


func _garland(buffalo: Node3D) -> void:
	for index in 7:
		LowPoly.sphere(buffalo, "Garland%d" % index, 0.09, Vector3(-0.42 + index * 0.14, 1.42 - 0.12 * sin(index / 6.0 * PI), -1.25), FLAG_BANDS[index % FLAG_BANDS.size()])


func _tint_cloth(buffalo: Node3D, tint: Color) -> void:
	var cloth := buffalo.find_child("FACTION_Cloth_and_Belt", true, false) as MeshInstance3D
	if cloth != null:
		var material := cloth.get_active_material(0).duplicate() as BaseMaterial3D
		material.albedo_color = tint
		cloth.set_surface_override_material(0, material)
