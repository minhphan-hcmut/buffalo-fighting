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


func _ready() -> void:
	controller = get_parent() as MatchController
	bursts = Node3D.new()
	bursts.name = "Bursts"
	add_child(bursts)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
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
		if not controller.paused and not controller.finished and actor.state == Buffalo.State.DASH_ACTIVE and dash_times[actor.slot] <= 0.0:
			_dash_dust(actor)


## Spawns the effect for one combat event; `source` and `target` are slots 1 or 2.
func on_combat_event(event: StringName, source: int, target: int) -> void:
	if source not in [1, 2] or target not in [1, 2]:
		return
	var attacker := controller.player if source == 1 else controller.opponent
	var victim := controller.player if target == 1 else controller.opponent
	match event:
		&"HORN_HIT", &"DASH_HIT":
			_burst(&"ImpactFlash", horn_position(attacker), PAPER, "flash")
			_dust(victim, &"HitDust")
		&"GUARD_HIT":
			_burst(&"GuardSpark", horn_position(victim), PAPER, "guard")
		&"PARRY_SUCCESS":
			_burst(&"ParrySpark", horn_position(attacker), PARRY, "parry")
		&"DASH_START":
			_dash_dust(attacker)
		&"CLASH_START":
			_dust(attacker, &"ClashDust")
			_dust(victim, &"ClashDust")


## World position of the horn tips of `actor`, where hit and parry sparks appear.
func horn_position(actor: Buffalo) -> Vector3:
	return actor.visual.to_global(Vector3(0.0, GameBalance.get_number("vfx_horn_height"), -GameBalance.get_number("vfx_horn_forward")))


func _dust(actor: Buffalo, kind: StringName) -> void:
	_burst(kind, actor.global_position + Vector3.UP * GameBalance.get_number("vfx_ground_height"), EARTH, "dust")


func _dash_dust(actor: Buffalo) -> void:
	var at := actor.global_position - actor.forward() * GameBalance.get_number("vfx_dash_rear_offset")
	at.y += GameBalance.get_number("vfx_ground_height")
	_burst(&"DashDust", at, EARTH.lerp(GOLD, 0.25), "dust")
	dash_times[actor.slot] = GameBalance.get_number("vfx_dash_interval_s")


# One-shot emitter; skipped once `vfx_max_emitters` are alive so effects stay cheap.
func _burst(kind: StringName, at: Vector3, tint: Color, preset: String) -> void:
	if bursts.get_child_count() >= GameBalance.get_int("vfx_max_emitters"):
		return
	var emitter := CPUParticles3D.new()
	emitter.name = kind
	emitter.set_meta("kind", kind)
	emitter.mesh = particle_mesh
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.local_coords = false
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.amount = GameBalance.get_int("vfx_" + preset + "_count")
	emitter.lifetime = GameBalance.get_number("vfx_" + preset + "_s")
	emitter.scale_amount_min = GameBalance.get_number("vfx_" + preset + "_size") * 0.7
	emitter.scale_amount_max = GameBalance.get_number("vfx_" + preset + "_size")
	emitter.initial_velocity_min = GameBalance.get_number("vfx_" + preset + "_speed") * 0.5
	emitter.initial_velocity_max = GameBalance.get_number("vfx_" + preset + "_speed")
	emitter.direction = Vector3.UP
	emitter.spread = 75.0
	emitter.gravity = Vector3.DOWN * GameBalance.get_number("vfx_" + preset + "_gravity")
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = GameBalance.get_number("vfx_" + preset + "_radius")
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([tint, Color(tint, 0.0)])
	emitter.color_ramp = ramp
	emitter.set_meta("remaining", emitter.lifetime * 2.0)
	emitter.finished.connect(emitter.queue_free)
	bursts.add_child(emitter)
	emitter.global_position = at
	emitter.restart()
