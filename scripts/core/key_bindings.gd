class_name KeyBindings
extends RefCounted
## Rebindable match controls: one key or mouse button per action, saved in settings.cfg.
## A binding is a short code: "k<physical keycode>" or "m<mouse button index>".

const ACTIONS := [
	["move_forward", "Đi tới"],
	["move_back", "Đi lùi"],
	["move_left", "Sang trái"],
	["move_right", "Sang phải"],
	["horn", "Húc / móc"],
	["guard", "Ghìm / nhả"],
	["dash", "Hổ lao"],
	["parry", "Gạt sừng"],
]
const DEFAULTS := {
	"move_forward": "k%d" % KEY_W,
	"move_back": "k%d" % KEY_S,
	"move_left": "k%d" % KEY_A,
	"move_right": "k%d" % KEY_D,
	"horn": "m%d" % MOUSE_BUTTON_LEFT,
	"guard": "m%d" % MOUSE_BUTTON_RIGHT,
	"dash": "k%d" % KEY_SPACE,
	"parry": "k%d" % KEY_G,
}
## Pause and screenshot stay fixed so a player can always get back out.
const RESERVED := [KEY_ESCAPE, KEY_F12]
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Chuột trái",
	MOUSE_BUTTON_RIGHT: "Chuột phải",
	MOUSE_BUTTON_MIDDLE: "Chuột giữa",
	MOUSE_BUTTON_XBUTTON1: "Chuột 4",
	MOUSE_BUTTON_XBUTTON2: "Chuột 5",
}

const SHORT_MOUSE := {
	MOUSE_BUTTON_LEFT: "Trái",
	MOUSE_BUTTON_RIGHT: "Phải",
	MOUSE_BUTTON_MIDDLE: "Giữa",
}

static var bindings := DEFAULTS.duplicate()


## Rewrites the InputMap for every match action from the current bindings.
static func apply() -> void:
	for entry in ACTIONS:
		var action: String = entry[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event_for(bindings[action]))


static func event_for(code: String) -> InputEvent:
	var number := code.substr(1).to_int()
	if code.begins_with("m"):
		var mouse := InputEventMouseButton.new()
		mouse.button_index = number as MouseButton
		return mouse
	var key := InputEventKey.new()
	key.physical_keycode = number as Key
	return key


## The binding code for a pressed key or mouse button, or "" when it cannot be bound.
static func code_for(event: InputEvent) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		var physical: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if physical == KEY_NONE or physical in RESERVED:
			return ""
		return "k%d" % physical
	if event is InputEventMouseButton and event.pressed and MOUSE_NAMES.has(event.button_index):
		return "m%d" % event.button_index
	return ""


## Binds `code` to `action`; an action that already had it takes the old binding instead.
## Returns the action that was swapped, or "".
static func rebind(action: String, code: String) -> String:
	var old: String = bindings[action]
	var swapped := ""
	for other in bindings:
		if other != action and bindings[other] == code:
			bindings[other] = old
			swapped = other
	bindings[action] = code
	apply()
	return swapped


static func reset() -> void:
	bindings = DEFAULTS.duplicate()
	apply()


static func is_default() -> bool:
	return bindings == DEFAULTS


## Display name of the binding, e.g. "W", "Space", "Chuột trái".
static func label(action: String) -> String:
	return code_label(bindings[action])


static func code_label(code: String) -> String:
	var number := code.substr(1).to_int()
	if code.begins_with("m"):
		return Language.t(MOUSE_NAMES[number]) if MOUSE_NAMES.has(number) else Language.t("Chuột %d") % number
	# Physical keycodes are named by their US-layout position ("W", "Space").
	return OS.get_keycode_string(number as Key)


## Compact HUD form: left/right/middle mouse buttons drop "Chuột" ("Trái", "Phải", "Giữa").
static func short_label(action: String) -> String:
	var code: String = bindings[action]
	var number := code.substr(1).to_int()
	if code.begins_with("m") and SHORT_MOUSE.has(number):
		return Language.t(SHORT_MOUSE[number])
	return label(action)


## Mid-sentence form: "chuột phải" for mouse buttons, key names unchanged.
static func inline_label(action: String) -> String:
	var text := label(action)
	return text.to_lower() if bindings[action].begins_with("m") else text


## The four movement keys as one hint, "WASD" for single letters, else "↑/↓/←/→" style.
static func move_label() -> String:
	var parts := PackedStringArray()
	for action in ["move_forward", "move_left", "move_back", "move_right"]:
		parts.append(label(action))
	for part in parts:
		if part.length() != 1:
			return "/".join(parts)
	return "".join(parts)


static func display_name(action: String) -> String:
	for entry in ACTIONS:
		if entry[0] == action:
			return Language.t(entry[1])
	return action


static func load_from(config: ConfigFile) -> void:
	bindings = DEFAULTS.duplicate()
	var used := {}
	for entry in ACTIONS:
		var action: String = entry[0]
		var code: Variant = config.get_value("keys", action, DEFAULTS[action])
		if code is String and _valid(code):
			bindings[action] = code
	# A saved file with duplicates falls back to defaults rather than losing an action.
	for action in bindings:
		if used.has(bindings[action]):
			bindings = DEFAULTS.duplicate()
			break
		used[bindings[action]] = true


static func save_to(config: ConfigFile) -> void:
	for entry in ACTIONS:
		config.set_value("keys", entry[0], bindings[entry[0]])


static func _valid(code: String) -> bool:
	if code.length() < 2 or not code.substr(1).is_valid_int():
		return false
	var number := code.substr(1).to_int()
	if code.begins_with("m"):
		return MOUSE_NAMES.has(number)
	return code.begins_with("k") and number > 0 and not number in RESERVED
