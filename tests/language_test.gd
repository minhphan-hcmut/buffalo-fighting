extends SceneTree
## English option (2026-11-22): Vietnamese stays the default, English translates every screen,
## composed sentences translate part by part, and every Vietnamese string has an entry.

const SETTINGS := "user://language_test.cfg"
## Proper names and the bilingual setting title stay as they are in English.
const KEEP := ["GIÁP ĐÔNG", "GIÁP BẮC", "GIÁP NAM", "GIÁP TRUNG", "GIÁP THƯỢNG", "GIÁP TÂY", "ĐỎ · 06 · GIÁP ĐÔNG", "Tiếng Việt", "Ngôn ngữ / Language", "CHỌI TRÂU"]
const VIETNAMESE := "[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ]"

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


func run() -> void:
	SessionState.settings_path = SETTINGS
	root.theme = load("res://assets/ui/festival_theme.tres")
	check(Language.code == "vi" and Language.t("TIẾP TỤC") == "TIẾP TỤC", "Vietnamese is the default")
	var english := load(Language.ENGLISH) as Translation
	check(english != null, "English table loads")
	if english == null:
		quit(1)
		return
	coverage(english)

	Language.apply("en")
	check(Language.t("TIẾP TỤC") == "CONTINUE" and TranslationServer.get_locale().begins_with("en"), "English switches the locale")
	check(CreditsScreen.version_text() == "Version 1.0.0", "composed version line is English: " + CreditsScreen.version_text())
	var tutorial: GDScript = load("res://scripts/ui/hud_tutorial.gd")
	var controls: String = tutorial.controls_text()
	check(controls == "WASD Move · Mouse Look · Left Horn · Space Tiger Charge · Right Guard · G Parry · Esc Pause", "HUD controls are English: " + controls)
	check(MoveDemo.keys_for(&"clash") == "WASD Push · Left Hook · Right Release", "move card keys are English: " + MoveDemo.keys_for(&"clash"))
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var settings_button := menu.find_child("SettingsButton", true, false) as Button
	check(settings_button != null and settings_button.atr(settings_button.text) == "SETTINGS", "menu buttons show English")
	var version := menu.find_child("VersionLabel", true, false) as Label
	check(version != null and version.text == "Version 1.0.0", "menu version follows the language")
	menu.free()

	await settings_row()
	Language.apply("vi")
	check(Language.t("TIẾP TỤC") == "TIẾP TỤC" and CreditsScreen.version_text() == "Phiên bản 1.0.0", "switching back restores Vietnamese")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	print("Language: %d failures" % failures)
	quit(0 if failures == 0 else 1)


func settings_row() -> void:
	Language.apply("vi")
	var opener := Button.new()
	root.add_child(opener)
	var screen := SettingsScreen.new()
	root.add_child(screen)
	screen.open(opener)
	await process_frame
	var selector := screen.pages[1].find_child("Language", true, false) as SettingsSelector
	check(selector != null and selector.selected == 0, "Controls tab offers the language, Vietnamese selected")
	if selector == null:
		return
	selector.select(1)
	selector.item_selected.emit(1)
	var saved := ConfigFile.new()
	check(Language.code == "en" and saved.load(SETTINGS) == OK and saved.get_value("settings", "language", "") == "en", "choosing English applies and saves it")
	SettingsControls.reset_tab(screen.pages[1], 1)
	check(Language.code == "en" and selector.selected == 1, "restoring control defaults keeps the language")
	SessionState.load_settings(SETTINGS)
	check(Language.code == "en", "the saved language returns on the next start")
	screen.free()
	opener.free()
	await process_frame


## Every Vietnamese string in code and data has an English entry with the same placeholders.
func coverage(english: Translation) -> void:
	var vietnamese := RegEx.create_from_string(VIETNAMESE)
	var literal := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	var sources: Array[String] = []
	for path in files("res://scripts", ".gd"):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for found in literal.search_all(line):
				sources.append(found.get_string(1).replace("\\n", "\n").replace("\\\"", "\""))
	for path in files("res://data", ".json"):
		collect(JSON.parse_string(FileAccess.get_file_as_string(path)), sources)
	var missing: Array[String] = []
	for text in sources:
		if vietnamese.search(text) != null and not text in KEEP and english.get_message(text) == StringName():
			missing.append(text)
	check(missing.is_empty(), "every Vietnamese string has English (%d checked), missing: %s" % [sources.size(), missing])
	var mismatched: Array[String] = []
	for key in english.get_message_list():
		var value := String(english.get_message(key))
		if value.is_empty() or key.count("%") != value.count("%") or key.count("{") != value.count("{"):
			mismatched.append(key)
	check(mismatched.is_empty(), "English entries are filled and keep placeholders: %s" % [mismatched])


func collect(value: Variant, into: Array[String]) -> void:
	if value is String:
		into.append(value)
	elif value is Dictionary:
		for item in value.values():
			collect(item, into)
	elif value is Array:
		for item in value:
			collect(item, into)


func files(folder: String, extension: String) -> Array[String]:
	var result: Array[String] = []
	for name in DirAccess.get_files_at(folder):
		if name.ends_with(extension):
			result.append(folder.path_join(name))
	for sub in DirAccess.get_directories_at(folder):
		result.append_array(files(folder.path_join(sub), extension))
	return result
