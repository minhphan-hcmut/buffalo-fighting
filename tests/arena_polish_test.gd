extends SceneTree
## Arena look pass: shader mud patches, team outlines (GDD 5.1), HUD flag chips (GDD 5.2 #1) and the crowd reacting to the match.
## All presentation only.

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
	SessionState.mode = &"SOLO"
	SessionState.level_id = &"L03"
	var arena := load("res://scenes/arena.tscn").instantiate() as MatchController
	root.add_child(arena)
	arena.set_physics_process(false)
	await process_frame

	var mud_patches := arena.get_children().filter(func(n): return n is MeshInstance3D and n.material_override is ShaderMaterial and (n.material_override as ShaderMaterial).shader.resource_path.ends_with("mud_patch.gdshader"))
	check(mud_patches.size() == 2, "L03 draws both mud zones with the mud shader")
	if mud_patches.size() > 0:
		var plane := (mud_patches[0] as MeshInstance3D).mesh as PlaneMesh
		check(plane.size.x * 0.5 >= GameBalance.get_number("mud_radius"), "mud quad covers the whole gameplay radius")
		var material := mud_patches[0].material_override as ShaderMaterial
		check(float(material.get_shader_parameter("puddle_roughness")) < float(material.get_shader_parameter("wet_roughness")) and float(material.get_shader_parameter("wet_roughness")) < 0.5, "mud centre is wet and puddles have a smoother surface")
		var puddle: Color = material.get_shader_parameter("puddle_color")
		var centre: Color = material.get_shader_parameter("mud_color")
		check(puddle.r > puddle.g and puddle.g > puddle.b and puddle.get_luminance() < centre.get_luminance() and puddle.get_luminance() < 0.04, "mud water is near-black brown, darker than the wet soil")
		check(float(material.get_shader_parameter("wet_rim_darken")) > 0.0 and float(material.get_shader_parameter("sheen_sharpness")) >= 16.0, "water uses a dark wet rim and narrow reflection streaks")
		check(is_equal_approx(float(material.get_shader_parameter("edge_noise")), GameBalance.get_number("mud_edge_noise")), "broken mud rim reads its tuning from presentation data")

	for actor: Buffalo in [arena.player, arena.opponent]:
		check(actor.get_node_or_null("Banner") == null, "slot %d carries no pole or banner through its back" % actor.slot)
		var body := actor.find_child("HeroBody", true, false) as MeshInstance3D
		var outlined := 0
		for surface in body.mesh.get_surface_count():
			var material := body.get_active_material(surface)
			if material != null and material.next_pass is ShaderMaterial:
				outlined += 1
		check(outlined >= 2, "slot %d body and horns have a team outline pass" % actor.slot)
		var feedback := actor.get_node("CombatFeedback") as BuffaloFeedback
		var horn_still_live := false
		for surface in body.mesh.get_surface_count():
			if body.get_active_material(surface) == feedback.horn_material:
				horn_still_live = true
		check(feedback.horn_material == null or horn_still_live, "slot %d horn glow material stays the one BuffaloFeedback drives" % actor.slot)
	var red_outline: Color = (arena.player.find_child("HeroBody", true, false) as MeshInstance3D).get_active_material(0).next_pass.get_shader_parameter("outline_color")
	var blue_outline: Color = (arena.opponent.find_child("HeroBody", true, false) as MeshInstance3D).get_active_material(0).next_pass.get_shader_parameter("outline_color")
	check(red_outline.get_luminance() > 0.6 and blue_outline.get_luminance() < 0.2, "red side rim is bright, blue side rim is dark")

	var crowd := arena.get_node("CrowdReaction") as CrowdReaction
	check(crowd.material != null, "crowd reaction found the shared crowd material")
	arena.phase = &"PLAYING"
	crowd._process(0.0)
	crowd.excitement = 0.0
	arena.combat_event.emit(&"HORN_HIT", 1, 2, 18.0)
	var after_hit := crowd.excitement
	check(after_hit > 0.0, "a hit makes the crowd cheer")
	crowd._process(0.5)
	check(crowd.excitement < after_hit, "cheering decays")
	check(is_equal_approx(float(crowd.material.get_shader_parameter("excitement")), crowd.excitement), "excitement reaches the crowd shader")
	arena.paused = true
	var held := crowd.excitement
	crowd._process(0.5)
	check(crowd.excitement == held, "pause holds the crowd")
	arena.paused = false

	var labels: Array = arena.hud.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	check(labels.has("06") and labels.has("17"), "HUD panels show the buffalo numbers as flag chips")
	check(arena.hud.announcer_label.position.y + arena.hud.announcer_label.size.y <= arena.hud.tutorial_label.position.y, "loa ribbon sits above the controls bar")
	quit(1 if failures > 0 else 0)
