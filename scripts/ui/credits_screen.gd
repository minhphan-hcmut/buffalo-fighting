class_name CreditsScreen
extends Control
## Credits page over the menu: team, free CC0 assets and tools, read from data/credits.json.

signal closed

const CREDITS_PATH := "res://data/credits.json"

var back: Button


func _ready() -> void:
	name = "Credits"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#17120EF0")
	add_child(shade)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	add_child(panel)
	var width := GameBalance.get_number("ui_credits_panel_width")
	var height := GameBalance.get_number("ui_credits_panel_height")
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_gap"))
	panel.add_child(content)
	content.add_child(ControlsDiagram.label("THỰC HIỆN", "title", ControlsDiagram.GOLD))
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "Sections"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", GameBalance.get_int("ui_credits_section_gap"))
	scroll.add_child(list)
	for section: Dictionary in DataFile.load_json(CREDITS_PATH).get("sections", []):
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", GameBalance.get_int("ui_credits_line_gap"))
		block.add_child(ControlsDiagram.label(String(section.get("title", "")), "heading", ControlsDiagram.GOLD))
		for line in section.get("lines", []):
			var text := ControlsDiagram.label(String(line))
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			block.add_child(text)
		list.add_child(block)
	var footer := HBoxContainer.new()
	content.add_child(footer)
	back = Button.new()
	back.name = "Back"
	back.theme_type_variation = &"QuietButton"
	back.text = "QUAY LẠI"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.custom_minimum_size = Vector2(GameBalance.get_number("ui_howto_back_width"), GameBalance.get_number("ui_howto_back_height"))
	UiMotion.attach(back)
	back.pressed.connect(close)
	footer.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var version := ControlsDiagram.label(version_text(), "body", SettingsControls.MUTED)
	version.name = "Version"
	version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(version)
	back.grab_focus()


## "Phiên bản 1.0.0" from the project's application/config/version.
static func version_text() -> String:
	return Language.t("Phiên bản %s") % String(ProjectSettings.get_setting("application/config/version", "1.0.0"))


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	hide()
	closed.emit()
	queue_free()
