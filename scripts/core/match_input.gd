class_name MatchInput
extends RefCounted
## Samples local keyboard/mouse into an InputFrame. Buttons still held from the menu or the
## countdown are gated until released, so they cannot fire an action on the first tick.

var previous_guard := false
var horn_blocked_until_release := false
var dash_blocked_until_release := false
var guard_blocked_until_release := false


static func configure() -> void:
	var keys := {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_forward": KEY_W,
		"move_back": KEY_S
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)
	_add_mouse_action("horn", MOUSE_BUTTON_LEFT)
	_add_mouse_action("guard", MOUSE_BUTTON_RIGHT)
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var dash_event := InputEventKey.new()
		dash_event.physical_keycode = KEY_SPACE
		InputMap.action_add_event("dash", dash_event)


static func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var event := InputEventMouseButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)


## Called when a countdown starts: block every button currently held down.
func arm_release_gates() -> void:
	previous_guard = false
	horn_blocked_until_release = Input.is_action_pressed("horn")
	dash_blocked_until_release = Input.is_action_pressed("dash")
	guard_blocked_until_release = Input.is_action_pressed("guard")


func update_release_gates() -> void:
	if not Input.is_action_pressed("horn"):
		horn_blocked_until_release = false
	if not Input.is_action_pressed("dash"):
		dash_blocked_until_release = false
	if not Input.is_action_pressed("guard"):
		guard_blocked_until_release = false


func read(slot: int, camera_yaw: float, seq: int) -> InputFrame:
	var frame := InputFrame.new(slot)
	frame.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	frame.camera_yaw = camera_yaw
	frame.horn_pressed = not horn_blocked_until_release and Input.is_action_just_pressed("horn")
	frame.dash_pressed = not dash_blocked_until_release and Input.is_action_just_pressed("dash")
	frame.guard_held = not guard_blocked_until_release and Input.is_action_pressed("guard")
	frame.guard_pressed = frame.guard_held and not previous_guard
	update_release_gates()
	frame.seq = seq
	previous_guard = frame.guard_held
	return frame
