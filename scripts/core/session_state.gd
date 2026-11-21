class_name SessionState
extends RefCounted
## State that outlives a scene change: mode (SOLO/LAN), current level, Solo progress
## (L01 → L05), the last result and the mouse setting. Static, no node needed.

const SOLO_LEVELS: Array[StringName] = [&"L01", &"L02", &"L03", &"L04", &"L05"]

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
static var camera_punch_enabled := true
static var impact_flash := 0
static var hitstop_enabled := true
static var auto_pause_enabled := true
static var rumble_enabled := true
static var hud_text_large := false
static var replay_enabled := true
static var free_play := false
static var training := false
static var drill_id: StringName = &"dummy"
static var training_unlimited_stamina := false
static var camera_view := 1
static var camera_side := 0
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
	camera_punch_enabled = _setting_bool(config, "camera_punch", true)
	hitstop_enabled = _setting_bool(config, "hitstop", true)
	auto_pause_enabled = _setting_bool(config, "auto_pause", true)
	rumble_enabled = _setting_bool(config, "rumble", true)
	hud_text_large = _setting_bool(config, "hud_text_large", false)
	replay_enabled = _setting_bool(config, "replay", true)
	training_unlimited_stamina = _setting_bool(config, "training_unlimited_stamina", false)
	var flash: Variant = config.get_value("settings", "impact_flash", 0)
	impact_flash = flash if flash is int and flash in [0, 1, 2] else 0
	var view: Variant = config.get_value("settings", "camera_view", 1)
	camera_view = view if view is int and view in [0, 1, 2] else 1
	var side: Variant = config.get_value("settings", "camera_side", 0)
	camera_side = side if side is int and side in [0, 1] else 0
	fullscreen_enabled = _setting_bool(config, "fullscreen", false)
	var sensitivity: Variant = config.get_value("settings", "mouse_sensitivity", GameBalance.get_number("mouse_sensitivity"))
	if not (sensitivity is float or sensitivity is int) or not is_finite(float(sensitivity)) or float(sensitivity) < GameBalance.get_number("ui_settings_sensitivity_min") or float(sensitivity) > GameBalance.get_number("ui_settings_sensitivity_max"):
		sensitivity = GameBalance.get_number("mouse_sensitivity")
	mouse_sensitivity = float(sensitivity)
	KeyBindings.load_from(config)
	KeyBindings.apply()
	Language.apply(String(config.get_value("settings", "language", "vi")))
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
	config.set_value("settings", "camera_punch", camera_punch_enabled)
	config.set_value("settings", "impact_flash", impact_flash)
	config.set_value("settings", "hitstop", hitstop_enabled)
	config.set_value("settings", "auto_pause", auto_pause_enabled)
	config.set_value("settings", "rumble", rumble_enabled)
	config.set_value("settings", "hud_text_large", hud_text_large)
	config.set_value("settings", "replay", replay_enabled)
	config.set_value("settings", "training_unlimited_stamina", training_unlimited_stamina)
	config.set_value("settings", "camera_view", camera_view)
	config.set_value("settings", "camera_side", camera_side)
	config.set_value("settings", "mouse_sensitivity", get_mouse_sensitivity())
	KeyBindings.save_to(config)
	config.set_value("settings", "language", Language.code)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Không thể lưu cài đặt: %s" % error_string(error))
	return error


static func get_mouse_sensitivity() -> float:
	if mouse_sensitivity < 0.0:
		mouse_sensitivity = GameBalance.get_number("mouse_sensitivity", 0.15)
	return mouse_sensitivity


static func begin_solo() -> bool:
	training = false
	free_play = false
	mode = &"SOLO"
	level_id = SOLO_LEVELS[unlocked_level - 1]
	last_match_level = level_id
	last_winner = 0
	last_reason = &"NONE"
	var show_opening := not opening_ceremony_seen
	opening_ceremony_seen = true
	return show_opening


static func begin_free_play(level: StringName) -> void:
	if not SOLO_LEVELS.has(level):
		return
	free_play = true
	training = false
	mode = &"SOLO"
	level_id = level
	last_match_level = level
	last_winner = 0
	last_reason = &"NONE"


static func begin_training(drill: StringName) -> void:
	var drills: Array = DataFile.load_json("res://data/training.json").get("drills", [])
	if not drills.any(func(entry: Dictionary): return entry.id == String(drill)):
		return
	training = true
	free_play = false
	drill_id = drill
	mode = &"SOLO"
	level_id = &"L01"
	last_match_level = level_id
	last_winner = 0
	last_reason = &"NONE"


static func training_config() -> Dictionary:
	for drill: Dictionary in DataFile.load_json("res://data/training.json").get("drills", []):
		if drill.id == String(drill_id):
			return drill
	return {}


static func flash_scale() -> float:
	return [1.0, GameBalance.get_number("comfort_flash_soft_scale"), 0.0][impact_flash]


## The Phần Lễ to show before `level` that have not been shown yet, and marks them seen:
## rước nước before L01, các giáp đưa trâu vào hội before L03, trống khai hội before L05.
static func take_rites_before(level: StringName) -> Array[StringName]:
	var rite: StringName = {&"L01": &"water", &"L03": &"giap", &"L05": &"drums"}.get(level, &"")
	var result: Array[StringName] = []
	if mode == &"SOLO" and not free_play and not training and rite != &"" and not rites_seen.has(rite):
		rites_seen.append(rite)
		result.append(rite)
	return result


## Unlocks the next Solo round in order, retaining the finished round for retry.
static func advance_after_win() -> bool:
	last_match_level = level_id
	if free_play or training:
		return false
	var index := SOLO_LEVELS.find(level_id)
	if index < 0 or index == SOLO_LEVELS.size() - 1:
		return false
	level_id = SOLO_LEVELS[index + 1]
	unlocked_level = maxi(unlocked_level, index + 2)
	return true


static func retry() -> void:
	mode = &"SOLO"
	level_id = last_match_level
	last_winner = 0
	last_reason = &"NONE"


static func return_to_menu() -> void:
	mode = &"SOLO"
	level_id = &"L01"
	last_match_level = &"L01"
	last_winner = 0
	last_reason = &"NONE"
	if free_play or training:
		free_play = false
		training = false
		return
	unlocked_level = 1
	opening_ceremony_seen = false
	culture_cards_seen.clear()
	rites_seen.clear()
