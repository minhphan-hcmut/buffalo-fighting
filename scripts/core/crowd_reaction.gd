class_name CrowdReaction
extends Node
## Makes the stands react to the match (GDD Bảng 19: khán giả). Presentation only: it reads
## MatchController signals and phase and drives the crowd shader's `excitement`; it never
## changes gameplay state. Strengths and decay are `crowd_*` keys in data/presentation.json.

const EVENT_STRENGTH := {
	&"HORN_HIT": "crowd_hit_excitement",
	&"DASH_HIT": "crowd_hit_excitement",
	&"FLANK_HIT": "crowd_big_excitement",
	&"BACK_HIT": "crowd_big_excitement",
	&"COUNTER_HIT": "crowd_big_excitement",
	&"PARRY_SUCCESS": "crowd_big_excitement",
	&"CLASH_START": "crowd_clash_excitement",
	&"CLASH_LOSS": "crowd_big_excitement",
}

var controller: MatchController
var material: ShaderMaterial
var excitement := 0.0
var previous_phase: StringName = &""


## `crowd_material` is the shared crowd material from ArenaDressing (null = no stands).
func setup(match_controller: MatchController, crowd_material: ShaderMaterial) -> void:
	controller = match_controller
	material = crowd_material
	controller.combat_event.connect(_on_combat_event)


func _process(delta: float) -> void:
	if material == null or controller == null:
		return
	if controller.phase != previous_phase:
		if controller.phase == &"PLAYING":
			cheer(GameBalance.get_number("crowd_start_excitement", 0.7))
		previous_phase = controller.phase
	# The crowd keeps cheering through the whole result.
	if controller.finished:
		excitement = maxf(excitement, GameBalance.get_number("crowd_result_excitement", 0.9))
	elif not controller.paused:
		excitement = maxf(0.0, excitement - delta * GameBalance.get_number("crowd_decay_per_s", 0.6))
	material.set_shader_parameter("excitement", excitement)


## Raises excitement to at least `amount` (0..1).
func cheer(amount: float) -> void:
	excitement = clampf(maxf(excitement, amount), 0.0, 1.0)


func _on_combat_event(event_name: StringName, _source: int, _target: int, _value: float) -> void:
	if EVENT_STRENGTH.has(event_name):
		cheer(GameBalance.get_number(EVENT_STRENGTH[event_name], 0.5))
