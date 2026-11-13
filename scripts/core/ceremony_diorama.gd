class_name CeremonyDiorama
extends Node3D
## Low-poly 3D tableau shown behind the Phần Lễ captions (GDD 4.5, Bảng 17).
## Built from primitive meshes only; the champion buffalo reuses the in-game model.
## Variants: &"opening" (dâng hương, thượng cờ ở đền) and &"closing" (rước ông trâu về đình).

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
var _banners: Array[Node3D] = []
var _camera_target := Vector3.ZERO
var _camera_offset := Vector3.ZERO
var _procession_from := Vector3.ZERO
var _procession_to := Vector3.ZERO

const FLAG_LOW_Y := 1.6
const FLAG_HIGH_Y := 6.4


## Builds the tableau for `which` (&"opening" or &"closing"); `settings` is data/ceremony.json.
func setup(which: StringName, settings: Dictionary) -> void:
	variant = which
	config = settings
	_build_environment()
	_build_ground()
	_build_shrine()
	_build_banners()
	_build_trees()
	if variant == &"opening":
		_build_altar()
		_build_drums()
		_build_flagpole()
		for x in [-1.2, -0.4, 0.4, 1.2]:
			LowPoly.villager(self, Vector3(x, 0.0, 5.4), PI, Color("#5C4033"))
		_camera_target = Vector3(-1.2, 1.2, 2.5)
		_camera_offset = Vector3(0.0, 4.6, 15.5)
	else:
		_build_drums()
		_build_procession()
		_camera_target = Vector3(0.0, 0.6, 5.5)
		_camera_offset = Vector3(10.5, 4.4, 7.5)
	camera = Camera3D.new()
	camera.name = "CeremonyCamera"
	camera.fov = 50.0
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
		flag.rotation.y = 0.18 * sin(elapsed * 2.4)
	if champion != null:
		var walk := clampf(elapsed / float(config.get("procession_s", 12.0)), 0.0, 1.0)
		champion.position = _procession_from.lerp(_procession_to, walk)
		champion.position.y = 0.04 * absf(sin(elapsed * 5.0)) * (1.0 - walk)
		leader.position = champion.position + Vector3(0.9, 0.0, -2.3)
	for index in _banners.size():
		_banners[index].rotation.z = 0.06 * sin(elapsed * 1.7 + index)


## True once the flag has reached the top of the pole (opening variant only).
func flag_raised() -> bool:
	return flag != null and is_equal_approx(flag.position.y, FLAG_HIGH_Y)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -35.0 if variant == &"opening" else 30.0, 0.0)
	sun.light_color = Color("#FFE0B0")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#6F8FA3") if variant == &"opening" else Color("#7C7A93")
	sky_material.sky_horizon_color = Color("#F0C995") if variant == &"opening" else Color("#F2A96B")
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.ground_bottom_color = Color("#59523B")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground.mesh = plane
	var ground_material := GROUND_MATERIAL.duplicate() as StandardMaterial3D
	ground_material.uv1_scale = Vector3(8.0, 8.0, 8.0)
	ground.material_override = ground_material
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
		LowPoly.box(flag, "FlagBand", Vector3(2.4, band_height, 0.03), Vector3(1.25, y, 0.0), FLAG_BANDS[index])


func _build_banners() -> void:
	var colors: Array[Color] = [Color("#C0392B"), GOLD, Color("#2E6E9E"), Color("#3E8E4E")]
	var index := 0
	for z in [5.5, 8.0, 10.5]:
		# The closing camera sits on +X: keep that side clear so the procession reads.
		for side in ([-1.0] if variant == &"closing" else [-1.0, 1.0]):
			var post := Vector3(side * 3.6, 0.0, z)
			LowPoly.cylinder(self, "BannerPole", 0.04, 0.05, 4.2, post + Vector3(0.0, 2.1, 0.0), Color("#D8C38A"))
			var banner := Node3D.new()
			banner.name = "Banner"
			banner.position = post + Vector3(side * -0.3, 4.0, 0.0)
			add_child(banner)
			LowPoly.box(banner, "Cloth", Vector3(0.5, 2.2, 0.03), Vector3(0.0, -1.1, 0.0), colors[index % colors.size()])
			_banners.append(banner)
			index += 1


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
	BuffaloAnimator.make_matte(model)
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
