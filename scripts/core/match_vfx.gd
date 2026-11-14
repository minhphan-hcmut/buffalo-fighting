class_name MatchVFX
extends Node3D
## Arena-wide combat effects (GDD Bảng 19): hit flashes, guard and parry sparks, dust
## for hits, dashes and clashes, and the pulsing ring under a buffalo pinned to the
## fence. Presentation only. CPUParticles3D is used because it runs on GL Compatibility
## and keeps animating during hitstop. MatchController creates it as child "MatchVFX".
## Particle presets come from `vfx_<preset>_<field>` keys in data/presentation.json.

# Palette from GDD Bảng 18.
const EARTH := Color("8a5a3b")
const GOLD := Color("e8bc65")
const PAPER := Color("f2e6cf")
const PARRY := BuffaloFeedback.GLOW_PARRY

var controller: MatchController
var bursts: Node3D
var pinned_markers: Dictionary = {}
var dash_times: Dictionary = {}
var clock := 0.0
var particle_mesh: QuadMesh
var spark_mesh: QuadMesh
var dust_mesh: QuadMesh
var dust_growth: Curve
var dust_opacity: Gradient
var impact_ring_mesh: TorusMesh
var ring_growth: Curve
var debris_mesh: SphereMesh
var clash_dust_time := 0.0
var clash_spark_time := 0.0


func _ready() -> void:
	controller = get_parent() as MatchController
	bursts = Node3D.new()
	bursts.name = "Bursts"
	add_child(bursts)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, GameBalance.get_number("vfx_flash_core_fraction"), 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	particle_mesh = QuadMesh.new()
	particle_mesh.size = Vector2.ONE
	particle_mesh.material = material
	# A softer, higher-resolution sprite and growing translucent puffs are dust-only.
	dust_mesh = particle_mesh.duplicate()
	var dust_material := material.duplicate() as StandardMaterial3D
	var dust_texture := texture.duplicate() as GradientTexture2D
	var dust_gradient := Gradient.new()
	dust_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	dust_gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, GameBalance.get_number("vfx_dust_texture_mid_alpha")), Color(1, 1, 1, 0)])
	dust_texture.gradient = dust_gradient
	dust_texture.width = GameBalance.get_int("vfx_dust_texture_size")
	dust_texture.height = GameBalance.get_int("vfx_dust_texture_size")
	dust_material.albedo_texture = dust_texture
	dust_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	dust_material.texture_repeat = false
	dust_mesh.material = dust_material
	# Contact can be inside the horn/body meshes; brief sparks must remain visible.
	material.no_depth_test = true
	# Alpha blending preserves the warm contact tint even over bright skin.
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	spark_mesh = particle_mesh.duplicate()
	var spark_material := material.duplicate() as StandardMaterial3D
	spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mesh.material = spark_material
	dust_growth = Curve.new()
	dust_growth.max_value = GameBalance.get_number("vfx_dust_growth_end")
	dust_growth.add_point(Vector2(0.0, GameBalance.get_number("vfx_dust_growth_start")))
	dust_growth.add_point(Vector2(1.0, GameBalance.get_number("vfx_dust_growth_end")))
	dust_opacity = Gradient.new()
	dust_opacity.colors = PackedColorArray([Color(1, 1, 1, GameBalance.get_number("vfx_dust_alpha_min")), Color(1, 1, 1, GameBalance.get_number("vfx_dust_alpha_max"))])
	var solid_material := StandardMaterial3D.new()
	solid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	solid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	solid_material.vertex_color_use_as_albedo = true
	impact_ring_mesh = TorusMesh.new()
	impact_ring_mesh.inner_radius = GameBalance.get_number("vfx_ring_inner_radius")
	impact_ring_mesh.outer_radius = GameBalance.get_number("vfx_ring_outer_radius")
	impact_ring_mesh.rings = GameBalance.get_int("vfx_ring_segments")
	impact_ring_mesh.ring_segments = GameBalance.get_int("vfx_ring_tube_segments")
	impact_ring_mesh.material = solid_material
	ring_growth = Curve.new()
	ring_growth.max_value = GameBalance.get_number("vfx_ring_growth_end")
	ring_growth.add_point(Vector2(0.0, GameBalance.get_number("vfx_ring_growth_start")))
	ring_growth.add_point(Vector2(1.0, GameBalance.get_number("vfx_ring_growth_end")))
	debris_mesh = SphereMesh.new()
	debris_mesh.radius = 0.5
	debris_mesh.height = 1.0
	debris_mesh.radial_segments = GameBalance.get_int("vfx_debris_mesh_segments")
	debris_mesh.rings = GameBalance.get_int("vfx_debris_mesh_rings")
	debris_mesh.material = solid_material
	for actor: Buffalo in [controller.player, controller.opponent]:
		var marker := MeshInstance3D.new()
		marker.name = "Pinned%d" % actor.slot
		var ring := TorusMesh.new()
		ring.inner_radius = GameBalance.get_number("vfx_pinned_inner_radius")
		ring.outer_radius = GameBalance.get_number("vfx_pinned_outer_radius")
		ring.rings = 24
		ring.ring_segments = 6
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.albedo_color = GOLD
		ring.material = ring_material
		marker.mesh = ring
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.visible = false
		add_child(marker)
		pinned_markers[actor.slot] = marker


func _process(delta: float) -> void:
	for emitter: CPUParticles3D in bursts.get_children():
		emitter.speed_scale = 0.0 if controller.paused else 1.0
	if controller.paused:
		return
	clock += delta
	# A real-time deadline also releases emitters when no renderer is running (headless tests).
	for emitter: CPUParticles3D in bursts.get_children():
		var remaining := float(emitter.get_meta("remaining")) - delta
		emitter.set_meta("remaining", remaining)
		if remaining <= 0.0:
			emitter.queue_free()
	for actor: Buffalo in [controller.player, controller.opponent]:
		var marker: MeshInstance3D = pinned_markers[actor.slot]
		marker.global_position = actor.global_position + Vector3.UP * GameBalance.get_number("vfx_ground_height")
		marker.visible = controller.phase == &"PLAYING" and not controller.finished and controller.presentation_pinned(actor)
		var pulse := 1.0 + GameBalance.get_number("vfx_pinned_pulse_scale") * sin(clock * TAU * GameBalance.get_number("vfx_pinned_pulse_hz"))
		marker.scale = Vector3(pulse, 1.0, pulse)
		var material := marker.mesh.material as StandardMaterial3D
		material.albedo_color = GOLD.lerp(PAPER, 0.5 + 0.5 * sin(clock * TAU * GameBalance.get_number("vfx_pinned_pulse_hz")))
		dash_times[actor.slot] = maxf(0.0, float(dash_times.get(actor.slot, 0.0)) - delta)
		if controller.phase == &"PLAYING" and not controller.finished and actor.state == Buffalo.State.DASH_ACTIVE and dash_times[actor.slot] <= 0.0:
			_dash_dust(actor)
	if controller.phase != &"PLAYING" or controller.finished or controller.active_clash.is_empty():
		clash_dust_time = 0.0
		clash_spark_time = 0.0
		return
	clash_dust_time -= delta
	clash_spark_time -= delta
	if clash_dust_time <= 0.0:
		for actor: Buffalo in [controller.player, controller.opponent]:
			_dust(actor, &"ClashDust", "clash_dust")
		clash_dust_time = GameBalance.get_number("vfx_clash_dust_interval_s")
	if clash_spark_time <= 0.0:
		_burst(&"ClashSpark", horn_position(controller.player).lerp(horn_position(controller.opponent), 0.5), PAPER, "clash_spark")
		clash_spark_time = GameBalance.get_number("vfx_clash_spark_interval_s")


## Spawns the effect for one combat event; `source` and `target` are slots 1 or 2.
func on_combat_event(event: StringName, source: int, target: int) -> void:
	if controller.paused or source not in [1, 2] or target not in [1, 2]:
		return
	var attacker := controller.player if source == 1 else controller.opponent
	var victim := controller.player if target == 1 else controller.opponent
	match event:
		&"HORN_HIT", &"DASH_HIT":
			var strength := GameBalance.get_number("vfx_impact_heavy_scale") if event == &"DASH_HIT" else 1.0
			var contact := horn_position(attacker).lerp(victim.global_position + Vector3.UP * GameBalance.get_number("vfx_impact_body_height"), 0.5)
			_burst(&"ImpactFlash", contact, PAPER.lerp(GOLD, GameBalance.get_number("vfx_impact_gold_mix")), "flash", strength)
			_dust(victim, &"HitDust", "dust", strength)
			var ground := Vector3(contact.x, GameBalance.get_number("vfx_ground_height"), contact.z)
			_burst(&"ImpactRing", ground, Color(GOLD, GameBalance.get_number("vfx_ring_alpha")), "ring", strength)
			_burst(&"ImpactDebris", ground, EARTH.lerp(GOLD, GameBalance.get_number("vfx_debris_gold_mix")).darkened(GameBalance.get_number("vfx_debris_darken")), "debris", strength)
		&"GUARD_HIT":
			_burst(&"GuardSpark", horn_position(victim), PAPER, "guard")
		&"PARRY_SUCCESS":
			_burst(&"ParrySpark", horn_position(attacker), PARRY, "parry")
		&"DASH_START":
			_dash_dust(attacker)
		&"CLASH_START":
			_dust(attacker, &"ClashDust", "clash_dust")
			_dust(victim, &"ClashDust", "clash_dust")
			clash_dust_time = GameBalance.get_number("vfx_clash_dust_interval_s")
			clash_spark_time = 0.0


## World position of the horn tips of `actor`, where hit and parry sparks appear.
func horn_position(actor: Buffalo) -> Vector3:
	return actor.visual.to_global(Vector3(0.0, GameBalance.get_number("vfx_horn_height"), -GameBalance.get_number("vfx_horn_forward")))


func _dust(actor: Buffalo, kind: StringName, preset: String = "dust", strength: float = 1.0) -> void:
	var at := actor.global_position + Vector3.UP * GameBalance.get_number("vfx_ground_height")
	var tint := EARTH
	if preset == "clash_dust":
		at += actor.forward() * GameBalance.get_number("vfx_clash_dust_front_offset")
		tint = EARTH.lerp(GOLD, GameBalance.get_number("vfx_clash_dust_gold_mix"))
	_burst(kind, at, tint, preset, strength)


func _dash_dust(actor: Buffalo) -> void:
	var at := actor.global_position - actor.forward() * GameBalance.get_number("vfx_dash_rear_offset")
	at.y += GameBalance.get_number("vfx_ground_height")
	_burst(&"DashDust", at, EARTH.lerp(GOLD, 0.25), "dust")
	dash_times[actor.slot] = GameBalance.get_number("vfx_dash_interval_s")


# One-shot emitter; skipped once `vfx_max_emitters` are alive so effects stay cheap.
func _burst(kind: StringName, at: Vector3, tint: Color, preset: String, strength: float = 1.0) -> void:
	if bursts.get_child_count() >= GameBalance.get_int("vfx_max_emitters"):
		return
	var emitter := CPUParticles3D.new()
	emitter.name = kind
	emitter.set_meta("kind", kind)
	emitter.mesh = spark_mesh
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.local_coords = false
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.amount = GameBalance.get_int("vfx_" + preset + "_count")
	emitter.lifetime = GameBalance.get_number("vfx_" + preset + "_s")
	emitter.scale_amount_min = GameBalance.get_number("vfx_" + preset + "_size") * 0.7 * strength
	emitter.scale_amount_max = GameBalance.get_number("vfx_" + preset + "_size") * strength
	emitter.initial_velocity_min = GameBalance.get_number("vfx_" + preset + "_speed") * 0.5
	emitter.initial_velocity_max = GameBalance.get_number("vfx_" + preset + "_speed")
	emitter.direction = Vector3.UP
	emitter.spread = 75.0
	emitter.gravity = Vector3.DOWN * GameBalance.get_number("vfx_" + preset + "_gravity")
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = GameBalance.get_number("vfx_" + preset + "_radius")
	if preset == "flash":
		emitter.mesh = particle_mesh
		# A stationary contact flash must use its placed transform on the first frame.
		emitter.local_coords = true
		emitter.scale_amount_min = emitter.scale_amount_max
		tint.a = GameBalance.get_number("vfx_flash_alpha")
	elif preset in ["dust", "clash_dust"]:
		emitter.mesh = dust_mesh
		emitter.scale_amount_curve = dust_growth
		emitter.color_initial_ramp = dust_opacity
		# Keep spawn points above the floor instead of clipping half a spherical burst.
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		emitter.emission_box_extents = Vector3(emitter.emission_sphere_radius, GameBalance.get_number("vfx_dust_emission_height"), emitter.emission_sphere_radius)
		at.y += GameBalance.get_number("vfx_dust_lift_m")
		if preset == "clash_dust":
			emitter.color_initial_ramp = null
	elif preset == "ring":
		emitter.mesh = impact_ring_mesh
		emitter.scale_amount_min = emitter.scale_amount_max
		emitter.scale_amount_curve = ring_growth
	elif preset == "debris":
		emitter.mesh = debris_mesh
		emitter.spread = GameBalance.get_number("vfx_debris_spread_deg")
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		emitter.emission_box_extents = Vector3(emitter.emission_sphere_radius, 0.0, emitter.emission_sphere_radius)
		at.y = GameBalance.get_number("vfx_debris_launch_height")
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([tint, Color(tint, 0.0)])
	if preset == "flash":
		ramp.offsets = PackedFloat32Array([0.0, GameBalance.get_number("vfx_flash_hold_fraction"), 1.0])
		ramp.colors = PackedColorArray([tint, tint, Color(tint, 0.0)])
	emitter.color_ramp = ramp
	emitter.set_meta("remaining", emitter.lifetime * 2.0)
	emitter.finished.connect(emitter.queue_free)
	bursts.add_child(emitter)
	emitter.global_position = at
	emitter.restart()
