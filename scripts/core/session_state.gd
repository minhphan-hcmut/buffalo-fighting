class_name SessionState
extends RefCounted
## State that outlives a scene change: mode (SOLO/LAN), current level, Solo progress
## (L01 → L02 → L03), the last result and the mouse setting. Static, no node needed.

static var mode: StringName = &"SOLO"
static var level_id: StringName = &"L01"
static var unlocked_level := 1
static var last_winner := 0
static var last_reason: StringName = &"NONE"
static var last_match_level: StringName = &"L01"
static var opening_ceremony_seen := false
static var culture_cards_seen: Array[StringName] = []
## Phần Lễ shown before a round (GDD Bảng 17, SHOULD); each plays once per festival run.
static var rites_seen: Array[StringName] = []
static var camera_shake_enabled := true
static var mouse_sensitivity := -1.0
static var fullscreen_enabled := false
static var settings_path := "user://settings.cfg"


## The path is injectable so tests never write the player's settings.
static func load_settings(path: String = "user://settings.cfg") -> void:
	settings_path = path
	var config := ConfigFile.new()
	if config.load(path) != OK:
		config = ConfigFile.new()
	for bus in [&"Master", &"Music", &"SFX"]:
		var volume: Variant = config.get_value("audio", bus, 1.0)
		if not (volume is float or volume is int) or not is_finite(float(volume)) or float(volume) < 0.0 or float(volume) > 1.0:
			volume = 1.0
		AudioServer.set_bus_volume_linear(FestivalAudio.ensure_bus(bus), float(volume))
	camera_shake_enabled = _setting_bool(config, "camera_shake", true)
	fullscreen_enabled = _setting_bool(config, "fullscreen", false)
	var sensitivity: Variant = config.get_value("settings", "mouse_sensitivity", GameBalance.get_number("mouse_sensitivity"))
	if not (sensitivity is float or sensitivity is int) or not is_finite(float(sensitivity)) or float(sensitivity) < GameBalance.get_number("ui_settings_sensitivity_min") or float(sensitivity) > GameBalance.get_number("ui_settings_sensitivity_max"):
		sensitivity = GameBalance.get_number("mouse_sensitivity")
	mouse_sensitivity = float(sensitivity)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED)


static func _setting_bool(config: ConfigFile, key: String, fallback: bool) -> bool:
	var value: Variant = config.get_value("settings", key, fallback)
	return value if value is bool else fallback


static func save_settings() -> Error:
	var config := ConfigFile.new()
	for bus in [&"Master", &"Music", &"SFX"]:
		config.set_value("audio", bus, AudioServer.get_bus_volume_linear(FestivalAudio.ensure_bus(bus)))
	config.set_value("settings", "fullscreen", fullscreen_enabled)
	config.set_value("settings", "camera_shake", camera_shake_enabled)
	config.set_value("settings", "mouse_sensitivity", get_mouse_sensitivity())
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Không thể lưu cài đặt: %s" % error_string(error))
	return error


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


## The Phần Lễ to show before `level` that have not been shown yet, and marks them seen:
## rước nước before L01, các giáp đưa trâu vào hội before L02, trống khai hội before L03.
static func take_rites_before(level: StringName) -> Array[StringName]:
	var rite: StringName = {&"L01": &"water", &"L02": &"giap", &"L03": &"drums"}.get(level, &"")
	var result: Array[StringName] = []
	if mode == &"SOLO" and rite != &"" and not rites_seen.has(rite):
		rites_seen.append(rite)
		result.append(rite)
	return result


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
	culture_cards_seen.clear()
	rites_seen.clear()
