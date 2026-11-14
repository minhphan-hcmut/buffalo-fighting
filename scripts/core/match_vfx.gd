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
var debris_mesh: QuadMesh
var furrows: Node3D
var skid_times: Dictionary = {}
var breath_times: Dictionary = {}
var dash_hooves: Dictionary = {}
var last_positions: Dictionary = {}
var clash_dust_time := 0.0
var clash_spark_time := 0.0
var lights: Node3D
var shock_mesh: QuadMesh
var muzzle_mesh: QuadMesh
var swing_mesh: QuadMesh
var dash_ring_mesh: QuadMesh
var impact_groups: Dictionary = {}


func _ready() -> void:
	controller = get_parent() as MatchController
	bursts = Node3D.new()
	bursts.name = "Bursts"
	add_child(bursts)
	lights = Node3D.new()
	lights.name = "ImpactLights"
	add_child(lights)
	furrows = Node3D.new()
	furrows.name = "Furrows"
	add_child(furrows)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = preload("res://assets/vfx/kenney_particle_pack/star_07.png")
	particle_mesh = QuadMesh.new()
	particle_mesh.size = Vector2.ONE
	particle_mesh.material = material
	# A softer, higher-resolution sprite and growing translucent puffs are dust-only.
	dust_mesh = particle_mesh.duplicate()
	var dust_material := material.duplicate() as StandardMaterial3D
	dust_material.albedo_texture = preload("res://assets/vfx/kenney_particle_pack/smoke_03.png")
	dust_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	dust_material.texture_repeat = false
	dust_mesh.material = dust_material
	# Contact can be inside horn meshes; a short additive star stays readable there.
	material.no_depth_test = true
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	shock_mesh = _sprite_mesh(material, preload("res://assets/vfx/kenney_particle_pack/circle_03.png"))
	swing_mesh = _sprite_mesh(material, preload("res://assets/vfx/kenney_particle_pack/slash_02.png"))
	var swing_shader := Shader.new()
	swing_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform sampler2D sprite : source_color, filter_linear, repeat_disable;
uniform float energy;
uniform float core_start;
uniform float core_end;
uniform float edge_start;
uniform float edge_end;
void vertex() {
	vec4 center = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float angle = INSTANCE_CUSTOM.x;
	mat2 turn = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	float particle_scale = length(MODEL_MATRIX[0].xyz);
	POSITION = PROJECTION_MATRIX * (center + vec4(turn * VERTEX.xy * particle_scale, 0.0, 0.0));
}
void fragment() {
	float mask = texture(sprite, UV).a;
	ALBEDO = mix(COLOR.rgb, vec3(1.0), smoothstep(core_start, core_end, mask)) * energy;
	ALPHA = smoothstep(edge_start, edge_end, mask) * COLOR.a;
}
"""
	var swing_material := ShaderMaterial.new()
	swing_material.shader = swing_shader
	swing_material.set_shader_parameter("sprite", preload("res://assets/vfx/kenney_particle_pack/slash_02.png"))
	swing_material.set_shader_parameter("energy", GameBalance.get_number("vfx_swing_energy"))
	swing_material.set_shader_parameter("core_start", GameBalance.get_number("vfx_swing_core_start"))
	swing_material.set_shader_parameter("core_end", GameBalance.get_number("vfx_swing_core_end"))
	swing_material.set_shader_parameter("edge_start", GameBalance.get_number("vfx_swing_edge_start"))
	swing_material.set_shader_parameter("edge_end", GameBalance.get_number("vfx_swing_edge_end"))
	swing_mesh.material = swing_material
	muzzle_mesh = _sprite_mesh(material, preload("res://assets/vfx/kenney_particle_pack/muzzle_01.png"), true)
	dash_ring_mesh = _sprite_mesh(dust_material, preload("res://assets/vfx/kenney_particle_pack/circle_03.png"), true)
	spark_mesh = QuadMesh.new()
	spark_mesh.size = Vector2(GameBalance.get_number("vfx_streak_width"), GameBalance.get_number("vfx_streak_length"))
	# Project the CPU velocity-aligned Y axis onto the view, keeping thin streaks face-on in GL.
	var streak_shader := Shader.new()
	streak_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D sprite : source_color, filter_linear, repeat_disable;
void vertex() {
	vec4 center = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	vec2 along = normalize(MODELVIEW_MATRIX[1].xy + vec2(0.00001));
	vec2 across = vec2(along.y, -along.x);
	float particle_scale = length(MODEL_MATRIX[1].xyz);
	POSITION = PROJECTION_MATRIX * (center + vec4((across * VERTEX.x + along * VERTEX.y) * particle_scale, 0.0, 0.0));
}
void fragment() {
	vec4 tex = texture(sprite, UV);
	ALBEDO = tex.rgb * COLOR.rgb;
	ALPHA = tex.a * COLOR.a;
}
"""
	var streak_material := ShaderMaterial.new()
	streak_material.shader = streak_shader
	streak_material.set_shader_parameter("sprite", preload("res://assets/vfx/kenney_particle_pack/trace_06.png"))
	spark_mesh.material = streak_material
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
	debris_mesh = dust_mesh.duplicate()
	var debris_material := dust_material.duplicate() as StandardMaterial3D
	debris_material.albedo_texture = preload("res://assets/vfx/kenney_particle_pack/dirt_01.png")
	debris_mesh.material = debris_material
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
	for light: OmniLight3D in lights.get_children():
		var remaining := maxf(0.0, float(light.get_meta("remaining")) - delta)
		light.set_meta("remaining", remaining)
		light.light_energy = float(light.get_meta("peak")) * remaining / GameBalance.get_number("vfx_light_s")
		if remaining <= 0.0:
			light.queue_free()
	for mark: MeshInstance3D in furrows.get_children():
		var remaining := float(mark.get_meta("remaining")) - delta
		mark.set_meta("remaining", remaining)
		mark.mesh.material.albedo_color.a = GameBalance.get_number("vfx_skid_alpha") * maxf(0.0, remaining / GameBalance.get_number("vfx_skid_s"))
		if remaining <= 0.0:
			mark.queue_free()
	# A real-time deadline also releases emitters when no renderer is running (headless tests).
	for emitter: CPUParticles3D in bursts.get_children():
		var remaining := float(emitter.get_meta("remaining")) - delta
		emitter.set_meta("remaining", remaining)
		if emitter.get_meta("kind") == &"HornSwing":
			_update_swing(emitter, emitter.get_meta("actor"))
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
		skid_times[actor.slot] = maxf(0.0, float(skid_times.get(actor.slot, 0.0)) - delta)
		breath_times[actor.slot] = maxf(0.0, float(breath_times.get(actor.slot, 0.0)) - delta)
		var travel := actor.global_position - Vector3(last_positions.get(actor.slot, actor.global_position))
		last_positions[actor.slot] = actor.global_position
		travel.y = 0.0
		if controller.phase == &"PLAYING" and not controller.finished:
			# The charge kicks up a dust trail, and the braking slide after it keeps throwing dirt.
			var dashing := actor.state == Buffalo.State.DASH_ACTIVE or (actor.state == Buffalo.State.DASH_RECOVERY and travel.length() > GameBalance.get_number("vfx_dash_dust_min_travel"))
			if dashing and dash_times[actor.slot] <= 0.0:
				_dash_dust(actor)
			var slide := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
			if not controller.active_clash.is_empty() and delta > 0.0:
				slide = travel / delta
			var sliding_back := not controller.active_clash.is_empty() and slide.dot(actor.forward()) < 0.0
			if (actor.knockback_time > 0.0 or sliding_back) and slide.length() > GameBalance.get_number("vfx_skid_min_speed") and skid_times[actor.slot] <= 0.0:
				_skid(actor, slide)
			if actor.stamina < GameBalance.get_number("stamina_max") * GameBalance.get_number("vfx_breath_stamina_fraction") and breath_times[actor.slot] <= 0.0:
				var nose := actor.visual.to_global(Vector3(0.0, GameBalance.get_number("vfx_breath_height"), -GameBalance.get_number("vfx_breath_forward")))
				_burst(&"TiredBreath", nose, Color(PAPER, GameBalance.get_number("vfx_breath_alpha")), "breath", 1.0, actor.forward())
				breath_times[actor.slot] = GameBalance.get_number("vfx_breath_interval_s")
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
	var pair := Vector2i(source, target)
	var group: Dictionary = impact_groups.get(pair, {})
	var recent := not group.is_empty() and clock - float(group.time) < GameBalance.get_number("vfx_impact_merge_s")
	match event:
		&"HORN_HIT", &"DASH_HIT", &"COUNTER_HIT", &"FLANK_HIT", &"BACK_HIT":
			if recent and group.get("guard", false):
				return
			var strength := GameBalance.get_number("vfx_impact_heavy_scale") if event in [&"DASH_HIT", &"COUNTER_HIT"] else 1.0
			# Resolver sends COUNTER/FLANK/BACK after the base hit; upgrade that burst once.
			if recent and event in [&"COUNTER_HIT", &"FLANK_HIT", &"BACK_HIT"]:
				_upgrade_impact(group, strength)
				return
			var contact := horn_position(attacker).lerp(victim.global_position + Vector3.UP * GameBalance.get_number("vfx_impact_body_height"), 0.5)
			var direction := victim.global_position - attacker.global_position
			direction.y = 0.0
			if direction.is_zero_approx():
				direction = attacker.forward()
			var first := bursts.get_child_count()
			_impact(contact, GOLD, strength, direction.normalized())
			_dust(victim, &"HitDust", "dust", strength)
			var ground := Vector3(contact.x, GameBalance.get_number("vfx_ground_height"), contact.z)
			_burst(&"ImpactRing", ground, Color(GOLD, GameBalance.get_number("vfx_ring_alpha")), "ring", strength)
			var front := hoof_position(victim, 0).lerp(hoof_position(victim, 1), 0.5)
			_burst(&"ImpactDebris", front, EARTH.lerp(GOLD, GameBalance.get_number("vfx_debris_gold_mix")).darkened(GameBalance.get_number("vfx_debris_darken")), "debris", strength, (direction.normalized() + Vector3.UP * GameBalance.get_number("vfx_debris_upward_bias")).normalized())
			impact_groups[pair] = {"time": clock, "strength": strength, "emitters": bursts.get_children().slice(first), "light": _flash_light(contact, GOLD, strength)}
		&"GUARD_HIT":
			_burst(&"GuardSpark", horn_position(victim), PAPER, "guard", 1.0, -attacker.forward())
			impact_groups[pair] = {"time": clock, "guard": true}
		&"PARRY_SUCCESS":
			var at := horn_position(attacker)
			var strength := GameBalance.get_number("vfx_parry_scale")
			_burst(&"ParrySpark", at, PARRY, "parry")
			_burst(&"ParryFlash", at, PARRY, "flash", strength)
			_burst(&"ParryShock", at, Color(PARRY, GameBalance.get_number("vfx_shock_alpha")), "shock", strength)
			_flash_light(at, PARRY, strength)
		&"DASH_START":
			var rear := hoof_position(attacker, 2).lerp(hoof_position(attacker, 3), 0.5)
			_burst(&"DashBlast", rear, EARTH, "dash_blast", 1.0, (-attacker.forward() + Vector3.UP * GameBalance.get_number("vfx_dash_launch_upward_bias")).normalized())
			_burst(&"DashClods", rear, EARTH, "dash_clods", 1.0, (-attacker.forward() + Vector3.UP * GameBalance.get_number("vfx_dash_launch_upward_bias")).normalized())
			_burst(&"DashRing", rear, Color(EARTH.lerp(GOLD, GameBalance.get_number("vfx_hoof_gold_mix")), GameBalance.get_number("vfx_dash_ring_alpha")), "dash_ring")
			var muzzle := _burst(&"DashMuzzle", rear, GOLD.lerp(Color.WHITE, GameBalance.get_number("vfx_muzzle_white_mix")), "muzzle")
			if muzzle != null:
				muzzle.rotation.y = attacker.rotation.y + PI
			_dash_dust(attacker)
		&"HORN_START", &"COUNTER_START":
			var slash := _burst(&"HornSwing", horn_position(attacker) + attacker.forward() * GameBalance.get_number("vfx_swing_forward") + Vector3.UP * GameBalance.get_number("vfx_swing_height"), Color(GOLD, GameBalance.get_number("vfx_swing_alpha")), "swing")
			if slash != null:
				slash.set_meta("actor", attacker)
				_update_swing(slash, attacker)
		&"CLASH_START":
			var at := horn_position(attacker).lerp(horn_position(victim), 0.5)
			var strength := GameBalance.get_number("vfx_impact_heavy_scale")
			_impact(at, GOLD, strength)
			_flash_light(at, GOLD, strength)
			_dust(attacker, &"ClashDust", "clash_dust")
			_dust(victim, &"ClashDust", "clash_dust")
			clash_dust_time = GameBalance.get_number("vfx_clash_dust_interval_s")
			clash_spark_time = 0.0
		&"CLASH_HOOK":
			_burst(&"ClashHook", horn_position(attacker).lerp(horn_position(victim), 0.5), GOLD, "guard", GameBalance.get_number("vfx_impact_heavy_scale"), attacker.forward())


func _update_swing(emitter: CPUParticles3D, actor: Buffalo) -> void:
	var side := float(actor.visual.get("_hook_side"))
	emitter.global_position = horn_position(actor) + actor.forward() * GameBalance.get_number("vfx_swing_forward") + Vector3.UP * GameBalance.get_number("vfx_swing_height")
	emitter.angle_min = GameBalance.get_number("vfx_swing_base_angle_deg") + side * GameBalance.get_number("vfx_swing_tilt_deg")
	emitter.angle_max = emitter.angle_min
	emitter.angular_velocity_min = -side * GameBalance.get_number("vfx_swing_sweep_deg") / emitter.lifetime
	emitter.angular_velocity_max = emitter.angular_velocity_min


func _sprite_mesh(source: StandardMaterial3D, texture: Texture2D, flat: bool = false) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var material := source.duplicate() as StandardMaterial3D
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if flat:
		mesh.orientation = PlaneMesh.FACE_Y
		material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mesh.material = material
	return mesh


func _impact(at: Vector3, tint: Color, strength: float, direction: Vector3 = Vector3.UP) -> void:
	_burst(&"ImpactFlash", at, Color.WHITE, "flash", strength)
	_burst(&"ImpactSparks", at, Color.WHITE, "spark", strength, (direction + Vector3.UP * GameBalance.get_number("vfx_debris_upward_bias")).normalized())
	_burst(&"ImpactShock", at, Color(tint, GameBalance.get_number("vfx_shock_alpha")), "shock", strength)


func _flash_light(at: Vector3, tint: Color, strength: float) -> OmniLight3D:
	if lights.get_child_count() >= GameBalance.get_int("vfx_max_lights"):
		return null
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = GameBalance.get_number("vfx_light_energy") * strength
	light.omni_range = GameBalance.get_number("vfx_light_range")
	light.shadow_enabled = false
	light.set_meta("remaining", GameBalance.get_number("vfx_light_s"))
	light.set_meta("peak", light.light_energy)
	lights.add_child(light)
	light.global_position = at + Vector3.UP * GameBalance.get_number("vfx_light_height")
	return light


func _upgrade_impact(group: Dictionary, strength: float) -> void:
	if strength <= float(group.strength):
		return
	var ratio := strength / float(group.strength)
	for emitter in group.emitters:
		if not is_instance_valid(emitter) or emitter.is_queued_for_deletion():
			continue
		emitter.scale_amount_min *= ratio
		emitter.scale_amount_max *= ratio
		emitter.initial_velocity_min *= ratio
		emitter.initial_velocity_max *= ratio
		if emitter.get_meta("kind") == &"ImpactSparks":
			emitter.amount = roundi(emitter.amount * ratio)
		emitter.restart()
	if is_instance_valid(group.light):
		group.light.light_energy *= ratio
		group.light.set_meta("peak", group.light.light_energy)
	group.strength = strength


## World position of the horn tips of `actor`, where hit and parry sparks appear.
func horn_position(actor: Buffalo) -> Vector3:
	return actor.to_global(actor.visual.head_point(Vector3(0.0, GameBalance.get_number("vfx_horn_height"), -GameBalance.get_number("vfx_horn_forward"))))


func _dust(actor: Buffalo, kind: StringName, preset: String = "dust", strength: float = 1.0) -> void:
	var at := actor.global_position + Vector3.UP * GameBalance.get_number("vfx_ground_height")
	var tint := EARTH
	if preset == "clash_dust":
		at += actor.forward() * GameBalance.get_number("vfx_clash_dust_front_offset")
		tint = EARTH.lerp(GOLD, GameBalance.get_number("vfx_clash_dust_gold_mix"))
	_burst(kind, at, tint, preset, strength)


func _dash_dust(actor: Buffalo) -> void:
	var leg := int(dash_hooves.get(actor.slot, 0))
	# Dry, pale dust: earth-coloured puffs vanish against the dirt floor.
	_burst(&"DashDust", hoof_position(actor, leg), EARTH.lerp(PAPER, GameBalance.get_number("vfx_dash_dust_pale_mix")), "hoof_dust")
	dash_hooves[actor.slot] = (leg + 1) % BuffaloAnimator.LEG_JOINTS.size()
	dash_times[actor.slot] = GameBalance.get_number("vfx_dash_interval_s")


func hoof_position(actor: Buffalo, leg: int) -> Vector3:
	var at := actor.to_global(actor.visual.hoof_position(leg))
	at.y = GameBalance.get_number("vfx_debris_launch_height")
	return at


func _skid(actor: Buffalo, slide: Vector3) -> void:
	for leg in 2:
		if furrows.get_child_count() >= GameBalance.get_int("vfx_skid_max_marks"):
			break
		var at := hoof_position(actor, leg)
		var mark := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.orientation = PlaneMesh.FACE_Y
		quad.size = Vector2(GameBalance.get_number("vfx_skid_width"), GameBalance.get_number("vfx_skid_length"))
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(EARTH.darkened(GameBalance.get_number("vfx_skid_darken")), GameBalance.get_number("vfx_skid_alpha"))
		quad.material = material
		mark.mesh = quad
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.set_meta("remaining", GameBalance.get_number("vfx_skid_s"))
		furrows.add_child(mark)
		mark.global_position = at - slide.normalized() * quad.size.y * 0.5
		mark.global_position.y = GameBalance.get_number("vfx_skid_ground_height")
		mark.rotation.y = atan2(slide.x, slide.z)
		_burst(&"SkidDebris", at, EARTH, "skid_debris", 1.0, (slide.normalized() + Vector3.UP * GameBalance.get_number("vfx_debris_upward_bias")).normalized())
	skid_times[actor.slot] = GameBalance.get_number("vfx_skid_interval_s")


# One-shot emitter; skipped once `vfx_max_emitters` are alive so effects stay cheap.
func _burst(kind: StringName, at: Vector3, tint: Color, preset: String, strength: float = 1.0, direction: Vector3 = Vector3.UP) -> CPUParticles3D:
	if bursts.get_child_count() >= GameBalance.get_int("vfx_max_emitters"):
		return null
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
	emitter.initial_velocity_min = GameBalance.get_number("vfx_" + preset + "_speed") * 0.5 * strength
	emitter.initial_velocity_max = GameBalance.get_number("vfx_" + preset + "_speed") * strength
	emitter.direction = direction
	emitter.spread = 75.0
	emitter.gravity = Vector3.DOWN * GameBalance.get_number("vfx_" + preset + "_gravity")
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = GameBalance.get_number("vfx_" + preset + "_radius")
	if preset in ["spark", "guard", "parry", "clash_spark"]:
		emitter.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
		emitter.spread = GameBalance.get_number("vfx_streak_spread_deg")
		if preset == "spark":
			emitter.amount = roundi(emitter.amount * strength)
		if preset == "parry":
			emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			emitter.emission_ring_axis = Vector3.UP
			emitter.emission_ring_radius = emitter.emission_sphere_radius
			emitter.emission_ring_inner_radius = emitter.emission_sphere_radius
			emitter.emission_ring_height = 0.0
			emitter.direction = Vector3.FORWARD
			emitter.spread = 180.0
	elif preset in ["flash", "shock", "swing", "muzzle", "dash_ring"]:
		emitter.mesh = particle_mesh
		if preset == "shock":
			emitter.mesh = shock_mesh
			emitter.scale_amount_curve = ring_growth
		elif preset == "swing":
			emitter.mesh = swing_mesh
		elif preset == "muzzle":
			emitter.mesh = muzzle_mesh
			at.y = GameBalance.get_number("vfx_muzzle_ground_height")
		elif preset == "dash_ring":
			emitter.mesh = dash_ring_mesh
			var growth := Curve.new()
			growth.max_value = GameBalance.get_number("vfx_dash_ring_growth_end")
			growth.add_point(Vector2(0.0, GameBalance.get_number("vfx_dash_ring_growth_start")))
			growth.add_point(Vector2(GameBalance.get_number("vfx_dash_ring_peak_at"), GameBalance.get_number("vfx_dash_ring_growth_end")))
			growth.add_point(Vector2(1.0, GameBalance.get_number("vfx_dash_ring_growth_end")))
			emitter.scale_amount_curve = growth
			at.y = GameBalance.get_number("vfx_muzzle_ground_height")
		# A stationary contact flash must use its placed transform on the first frame.
		emitter.local_coords = true
		emitter.scale_amount_min = emitter.scale_amount_max
		if preset == "flash":
			tint.a = GameBalance.get_number("vfx_flash_alpha")
			emitter.angle_min = randf_range(-180.0, 180.0)
			emitter.angle_max = emitter.angle_min
	elif preset in ["dust", "clash_dust", "hoof_dust", "breath"]:
		emitter.mesh = dust_mesh
		emitter.scale_amount_curve = dust_growth
		emitter.color_initial_ramp = dust_opacity
		# Keep spawn points above the floor instead of clipping half a spherical burst.
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		emitter.emission_box_extents = Vector3(emitter.emission_sphere_radius, GameBalance.get_number("vfx_dust_emission_height"), emitter.emission_sphere_radius)
		at.y += GameBalance.get_number("vfx_dust_lift_m")
		if preset in ["clash_dust", "breath"]:
			emitter.color_initial_ramp = null
		if preset == "breath":
			emitter.spread = GameBalance.get_number("vfx_breath_spread_deg")
	elif preset == "ring":
		emitter.mesh = impact_ring_mesh
		emitter.scale_amount_min = emitter.scale_amount_max
		emitter.scale_amount_curve = ring_growth
	elif preset in ["debris", "skid_debris", "dash_blast", "dash_clods"]:
		emitter.mesh = debris_mesh
		if preset == "dash_blast":
			emitter.mesh = dust_mesh
			emitter.scale_amount_curve = dust_growth
		emitter.spread = GameBalance.get_number("vfx_dash_launch_spread_deg" if preset in ["dash_blast", "dash_clods"] else "vfx_debris_spread_deg")
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		emitter.emission_box_extents = Vector3(emitter.emission_sphere_radius, 0.0, emitter.emission_sphere_radius)
		at.y = GameBalance.get_number("vfx_debris_launch_height")
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([tint, Color(tint, 0.0)])
	if preset in ["flash", "swing", "muzzle"]:
		ramp.offsets = PackedFloat32Array([0.0, GameBalance.get_number("vfx_" + preset + "_hold_fraction"), 1.0])
		ramp.colors = PackedColorArray([tint, tint, Color(tint, 0.0)])
	if preset == "spark":
		var orange := Color(GameBalance.get_number("vfx_streak_orange_r"), GameBalance.get_number("vfx_streak_orange_g"), GameBalance.get_number("vfx_streak_orange_b"))
		ramp.offsets = PackedFloat32Array([0.0, GameBalance.get_number("vfx_streak_gold_at"), GameBalance.get_number("vfx_streak_orange_at"), 1.0])
		ramp.colors = PackedColorArray([Color.WHITE, GOLD, orange, Color(orange, 0.0)])
	emitter.color_ramp = ramp
	emitter.set_meta("remaining", emitter.lifetime * 2.0)
	emitter.finished.connect(emitter.queue_free)
	bursts.add_child(emitter)
	emitter.global_position = at
	emitter.restart()
	return emitter
