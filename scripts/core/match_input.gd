class_name MatchInput
extends RefCounted
## Samples local keyboard/mouse into an InputFrame. Buttons still held from the menu or the
## countdown are gated until released, so they cannot fire an action on the first tick.

var previous_guard := false
var horn_blocked_until_release := false
var dash_blocked_until_release := false
var parry_blocked_until_release := false
var guard_blocked_until_release := false


static func configure() -> void:
	configure_ui()
	KeyBindings.apply()


static func configure_ui() -> void:
	for entry in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var button := InputEventJoypadButton.new()
		button.device = -1
		button.button_index = entry[1]
		if not InputMap.action_has_event(entry[0], button):
			InputMap.action_add_event(entry[0], button)


## Gate menu presses, including a click released in the same frame, until fresh gameplay input.
func arm_release_gates() -> void:
	previous_guard = false
	horn_blocked_until_release = Input.is_action_pressed("horn") or Input.is_action_just_pressed("horn")
	dash_blocked_until_release = Input.is_action_pressed("dash") or Input.is_action_just_pressed("dash")
	parry_blocked_until_release = Input.is_action_pressed("parry") or Input.is_action_just_pressed("parry")
	guard_blocked_until_release = Input.is_action_pressed("guard") or Input.is_action_just_pressed("guard")


func update_release_gates() -> void:
	if not Input.is_action_pressed("horn"):
		horn_blocked_until_release = false
	if not Input.is_action_pressed("dash"):
		dash_blocked_until_release = false
	if not Input.is_action_pressed("parry"):
		parry_blocked_until_release = false
	if not Input.is_action_pressed("guard"):
		guard_blocked_until_release = false


func read(slot: int, camera_yaw: float, seq: int) -> InputFrame:
	var frame := InputFrame.new(slot)
	frame.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	frame.camera_yaw = camera_yaw
	frame.horn_pressed = not horn_blocked_until_release and Input.is_action_just_pressed("horn")
	frame.dash_pressed = not dash_blocked_until_release and Input.is_action_just_pressed("dash")
	frame.parry_pressed = not parry_blocked_until_release and Input.is_action_just_pressed("parry")
	frame.guard_held = not guard_blocked_until_release and Input.is_action_pressed("guard")
	frame.guard_pressed = frame.guard_held and not previous_guard
	update_release_gates()
	frame.seq = seq
	previous_guard = frame.guard_held
	return frame
