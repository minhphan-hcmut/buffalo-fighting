class_name BuffaloFeedback
extends Node3D
## Per-buffalo combat readability (GDD Bảng 19): a floating word over the buffalo and a
## horn glow whose colour says what the buffalo is doing. Presentation only; it reads
## `combat_event` from MatchController, which the host also forwards to LAN clients.
## MatchController adds one as the child "CombatFeedback" of each Buffalo.

const HORN_SHADER := preload("res://assets/shaders/horn_glow.gdshader")

## Floating word shown for each combat event of this buffalo.
const WORDS := {
	&"HORN_START": "HÚC", &"DASH_START": "HỔ LAO", &"PARRY_START": "GẠT SỪNG!",
	&"PARRY_SUCCESS": "GẠT SỪNG!", &"COUNTER_START": "PHẢN ĐÒN!", &"COUNTER_HIT": "PHẢN ĐÒN!",
	&"FLANK_HIT": "ĐÁNH SƯỜN!", &"BACK_HIT": "ĐÁNH LƯNG!", &"WHIFF_START": "HỤT",
	&"CLASH_HOOK": "MÓC", &"RELEASE_START": "NHẢ"
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
		label.visible = true
	if event == &"PARRY_SUCCESS":
		flash_time = GameBalance.get_number("parry_flash_s")


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
