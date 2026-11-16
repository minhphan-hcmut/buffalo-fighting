class_name MatchRumble
extends Node
## Local presentation only. Keyboard/mouse input silences the last joypad.

var controller: MatchController
var joy_device := -1
var active_device := -1
var vibrate: Callable = Input.start_joy_vibration
var stop_vibration: Callable = Input.stop_joy_vibration


func setup(match_controller: MatchController) -> void:
	stop()
	if is_instance_valid(controller):
		controller.combat_event.disconnect(on_combat_event)
		controller.match_ended.disconnect(_on_match_ended)
	controller = match_controller
	controller.combat_event.connect(on_combat_event)
	controller.match_ended.connect(_on_match_ended)
	controller.tree_exiting.connect(_leave_match.bind(match_controller), CONNECT_ONE_SHOT)


func _on_match_ended(_winner: int, _reason: StringName) -> void:
	stop()


func _leave_match(match_controller: MatchController) -> void:
	if controller == match_controller:
		stop()
		controller = null


func _input(event: InputEvent) -> void:
	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > GameBalance.get_number("rumble_input_deadzone")):
		if joy_device != event.device:
			stop()
		joy_device = event.device
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventMouseMotion and not event.relative.is_zero_approx()):
		stop()
		joy_device = -1


func _process(_delta: float) -> void:
	if not SessionState.rumble_enabled:
		stop()


func on_combat_event(event: StringName, source: int, target: int, _value: float) -> void:
	if not is_instance_valid(controller) or joy_device < 0 or not SessionState.rumble_enabled or controller.paused or controller.finished:
		return
	if controller.local_slot not in [source, target]:
		return
	var preset := ""
	if event == &"PARRY_SUCCESS" and source == controller.local_slot:
		preset = "parry"
	elif event == &"CLASH_START":
		preset = "lock_start"
	elif event in [&"CLASH_LOSS", &"CLASH_WHIFF", &"CLASH_RELEASE", &"CLASH_BREAK", &"CLASH_TIME"]:
		preset = "lock_end"
	elif event in [&"HORN_HIT", &"DASH_HIT", &"COUNTER_HIT", &"GUARD_HIT"]:
		preset = "heavy" if event in [&"DASH_HIT", &"COUNTER_HIT"] else "hit"
	if preset.is_empty():
		return
	vibrate.call(joy_device, GameBalance.get_number("rumble_%s_weak" % preset), GameBalance.get_number("rumble_%s_strong" % preset), GameBalance.get_number("rumble_%s_s" % preset))
	active_device = joy_device


func stop() -> void:
	if active_device >= 0:
		stop_vibration.call(active_device)
		active_device = -1


func _exit_tree() -> void:
	stop()
