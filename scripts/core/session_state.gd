class_name SessionState
extends RefCounted

static var mode: StringName = &"SOLO"
static var level_id: StringName = &"L01"
static var unlocked_level := 1
static var last_winner := 0
static var last_reason: StringName = &"NONE"
static var last_match_level: StringName = &"L01"
static var opening_ceremony_seen := false
static var camera_shake_enabled := true
static var mouse_sensitivity := -1.0


static func get_mouse_sensitivity() -> float:
	if mouse_sensitivity < 0.0:
		mouse_sensitivity = GameBalance.get_number("mouse_sensitivity", 0.15)
	return mouse_sensitivity


static func begin_solo() -> bool:
	mode = &"SOLO"
	level_id = StringName("L%02d" % unlocked_level)
	last_match_level = level_id
	last_winner = 0
	last_reason = &"NONE"
	var show_opening := not opening_ceremony_seen
	opening_ceremony_seen = true
	return show_opening


static func advance_after_win() -> bool:
	last_match_level = level_id
	if level_id == &"L01":
		unlocked_level = maxi(unlocked_level, 2)
		level_id = &"L02"
		return true
	if level_id == &"L02":
		unlocked_level = maxi(unlocked_level, 3)
		level_id = &"L03"
		return true
	return false


static func retry() -> void:
	mode = &"SOLO"
	level_id = last_match_level
	last_winner = 0
	last_reason = &"NONE"


static func return_to_menu() -> void:
	mode = &"SOLO"
	level_id = &"L01"
	last_match_level = &"L01"
	unlocked_level = 1
	last_winner = 0
	last_reason = &"NONE"
	opening_ceremony_seen = false
