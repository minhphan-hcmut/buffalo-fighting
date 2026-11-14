class_name BuffaloFeedback
extends Node3D
## Per-buffalo combat readability (GDD Bảng 19): a floating word over the buffalo and a
## horn glow whose colour says what the buffalo is doing. Presentation only; it reads
## `combat_event` from MatchController, which the host also forwards to LAN clients.
## MatchController adds one as the child "CombatFeedback" of each Buffalo.

const HORN_SHADER := preload("res://assets/shaders/horn_glow.gdshader")

## Floating words, only for moments worth calling out: a successful parry, a counter, a
## flank/back hit and a whiff (the punish window). Ordinary starts (húc, hổ lao, móc, nhả)
## already read from the pose, horn glow and sound, so they get no word: fewer, rarer
## words keep the screen clean and make the important ones land.
const WORDS := {
	&"PARRY_SUCCESS": "GẠT SỪNG!", &"COUNTER_HIT": "PHẢN ĐÒN!",
	&"FLANK_HIT": "ĐÁNH SƯỜN!", &"BACK_HIT": "ĐÁNH LƯNG!", &"WHIFF_START": "HỤT"
}

## Horn glow colours (GDD Bảng 19): green parry, red dash, yellow horn/hook/counter, white guard.
const GLOW_PARRY := Color("40ff50")
const GLOW_DASH := Color("ff3030")
const GLOW_HORN := Color("ffd12a")
const GLOW_GUARD := Color("dbe7ea")

var actor: Buffalo
var controller: MatchController
var label: Label3D
var label_time := 0.0
var flash_time := 0.0
var clock := 0.0
static var label_sequence := 0
var label_order := 0
var label_importance := 1.0
## Null when the buffalo model has no keratin surface (e.g. the fallback model).
var horn_material: ShaderMaterial


func _ready() -> void:
	actor = get_parent() as Buffalo
	controller = actor.get_parent() as MatchController
	label = Label3D.new()
	label.position = Vector3.UP * GameBalance.get_number("combat_label_height")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = GameBalance.get_int("combat_label_font_size")
	label.outline_size = GameBalance.get_int("combat_label_outline_size")
	label.pixel_size = GameBalance.get_number("combat_label_pixel_size")
	label.no_depth_test = true
	label.visible = false
	add_child(label)
	_build_horn_material()
	controller.combat_event.connect(_on_event)


## Colour the horns should glow right now; black means no glow.
func glow_color() -> Color:
	if actor.state == Buffalo.State.PARRY_ACTIVE or flash_time > 0.0:
		return GLOW_PARRY
	if actor.state == Buffalo.State.DASH_ACTIVE:
		return GLOW_DASH
	if actor.state in [Buffalo.State.HORN_STARTUP, Buffalo.State.HORN_ACTIVE] or actor.clash_hooked:
		return GLOW_HORN
	if actor.guarding:
		return GLOW_GUARD
	if actor.counter_window > 0.0:
		return GLOW_HORN
	return Color.BLACK


func _process(delta: float) -> void:
	if controller.paused:
		return
	clock += delta
	label_time = maxf(0.0, label_time - delta)
	label.visible = label_time > 0.0
	if label.visible:
		_update_label()
	if horn_material != null:
		var energy := GameBalance.get_number("guard_glow_energy" if actor.guarding else "horn_glow_energy")
		if actor.counter_window > 0.0 and actor.state == Buffalo.State.NORMAL and flash_time <= 0.0:
			energy *= 0.5 + 0.5 * sin(clock * TAU * GameBalance.get_number("counter_glow_hz"))
		horn_material.set_shader_parameter("glow_color", glow_color())
		horn_material.set_shader_parameter("glow_energy", energy)
	flash_time = maxf(0.0, flash_time - delta)


func _on_event(event: StringName, source: int, _target: int, _value: float) -> void:
	if source != actor.slot:
		return
	if WORDS.has(event):
		label.text = WORDS[event]
		label_time = GameBalance.get_number("combat_label_s")
		label_sequence += 1
		label_order = label_sequence
		label_importance = GameBalance.get_number("combat_label_important_scale") if label.text.ends_with("!") else 1.0
		label.modulate = Color.WHITE
		match event:
			&"PARRY_START", &"PARRY_SUCCESS":
				label.modulate = GLOW_PARRY
			&"DASH_START":
				label.modulate = GLOW_DASH
			&"HORN_START", &"COUNTER_START", &"COUNTER_HIT", &"CLASH_HOOK":
				label.modulate = GLOW_HORN
		label.visible = true
		_update_label()
	if event == &"PARRY_SUCCESS":
		flash_time = GameBalance.get_number("parry_flash_s")


func _label_position() -> Vector3:
	var progress := 1.0 - label_time / GameBalance.get_number("combat_label_s")
	return actor.global_position + Vector3.UP * (GameBalance.get_number("combat_label_height") + progress * GameBalance.get_number("combat_label_rise_m"))


func _label_scale() -> float:
	var elapsed := GameBalance.get_number("combat_label_s") - label_time
	var progress := clampf(elapsed / GameBalance.get_number("combat_label_pop_s"), 0.0, 1.0)
	var peak_at := GameBalance.get_number("combat_label_peak_at")
	var size := lerpf(GameBalance.get_number("combat_label_start_scale"), GameBalance.get_number("combat_label_peak_scale"), minf(progress / peak_at, 1.0))
	if progress > peak_at:
		size = lerpf(GameBalance.get_number("combat_label_peak_scale"), 1.0, (progress - peak_at) / (1.0 - peak_at))
	return size * label_importance


## Use the active camera's pixels, including font/outline size and pop scale, for separation.
func _label_rect(camera: Camera3D, at: Vector3) -> Rect2:
	var font := label.font if label.font != null else ThemeDB.fallback_font
	var size := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
	size += Vector2.ONE * label.outline_size * 2.0
	var half_size := size * label.pixel_size * _label_scale() * 0.5
	var center := camera.unproject_position(at)
	var right := camera.unproject_position(at + camera.global_basis.x * half_size.x)
	var top := camera.unproject_position(at + camera.global_basis.y * half_size.y)
	var extent := Vector2(absf(right.x - center.x), absf(top.y - center.y))
	return Rect2(center - extent, extent * 2.0)


func _update_label() -> void:
	label.global_position = _label_position()
	label.scale = Vector3.ONE * _label_scale()
	var alpha := minf(1.0, label_time / (GameBalance.get_number("combat_label_s") * GameBalance.get_number("combat_label_fade_fraction")))
	var camera := get_viewport().get_camera_3d()
	var other_actor := controller.opponent if actor == controller.player else controller.player
	var other := other_actor.get_node_or_null("CombatFeedback") as BuffaloFeedback
	if camera != null and other != null and other.label_time > 0.0 and label_order < other.label_order:
		var at := _label_position()
		var other_at := other._label_position()
		if not camera.is_position_behind(at) and not camera.is_position_behind(other_at):
			var rect := _label_rect(camera, at)
			var other_rect := other._label_rect(camera, other_at)
			var gap := GameBalance.get_number("combat_label_gap_px")
			if rect.grow(gap).intersects(other_rect):
				var screen := camera.unproject_position(at)
				screen.y -= rect.end.y - other_rect.position.y + gap
				label.global_position = camera.project_position(screen, -camera.to_local(at).z)
				alpha *= GameBalance.get_number("combat_label_older_alpha")
	label.modulate.a = alpha
	label.outline_modulate.a = alpha


# Swaps the model's keratin surface for horn_glow.gdshader, copying its textures.
func _build_horn_material() -> void:
	var mesh := actor.find_child("HeroBody", true, false) as MeshInstance3D
	if mesh == null:
		return
	for surface in mesh.mesh.get_surface_count():
		var source := mesh.get_active_material(surface) as BaseMaterial3D
		if source == null or not source.resource_name.contains("keratin"):
			continue
		horn_material = ShaderMaterial.new()
		horn_material.shader = HORN_SHADER
		horn_material.set_shader_parameter("base_color", source.albedo_color)
		horn_material.set_shader_parameter("base_texture", source.albedo_texture)
		horn_material.set_shader_parameter("orm_texture", source.roughness_texture)
		horn_material.set_shader_parameter("normal_texture", source.normal_texture)
		horn_material.set_shader_parameter("base_roughness", source.roughness)
		horn_material.set_shader_parameter("base_metallic", source.metallic)
		horn_material.set_shader_parameter("base_specular", source.metallic_specular)
		horn_material.set_shader_parameter("normal_scale", source.normal_scale)
		horn_material.set_shader_parameter("horn_base_height", GameBalance.get_number("horn_glow_base_height"))
		horn_material.set_shader_parameter("horn_full_height", GameBalance.get_number("horn_glow_full_height"))
		mesh.set_surface_override_material(surface, horn_material)
		break
