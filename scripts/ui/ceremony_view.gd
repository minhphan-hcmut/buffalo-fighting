class_name CeremonyView
extends Control
## Full-screen Phần Lễ screen (GDD 4.5, Bảng 17): a 3D tableau with a date, title and
## one or two caption lines. Ends after `duration_s` (≤ 15 s) or on any key/click.

signal finished

const DATA_PATH := "res://data/ceremony.json"

var variant: StringName = &"opening"
var settings: Dictionary = {}
var diorama: CeremonyDiorama
var continue_button: Button
var caption_label: Label
var elapsed := 0.0
var done := false


## New, unparented ceremony screen for `which` (&"opening" or &"closing").
static func create(which: StringName) -> CeremonyView:
	var view := CeremonyView.new()
	view.variant = which
	return view


func _ready() -> void:
	settings = DataFile.load_json(DATA_PATH)
	name = "Ceremony"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scene: Dictionary = settings.get(String(variant), {})
	_build_viewport()
	_build_caption(scene)
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null and scene.has("sfx"):
		audio.play_sfx(String(scene["sfx"]))
	continue_button.grab_focus()


func _process(delta: float) -> void:
	advance(delta)


func _input(event: InputEvent) -> void:
	if done or elapsed < float(settings.get("min_view_s", 0.6)):
		return
	var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
	var clicked: bool = event is InputEventMouseButton and event.pressed
	if pressed_key or clicked:
		get_viewport().set_input_as_handled()
		finish()


## Advances the screen by `delta` seconds and ends it once `duration_s` has passed.
func advance(delta: float) -> void:
	if done:
		return
	elapsed += delta
	if diorama != null:
		diorama.advance(delta)
	if elapsed >= float(settings.get("duration_s", 15.0)):
		finish()


## Ends the screen once; emits `finished` the first time only.
func finish() -> void:
	if done:
		return
	done = true
	finished.emit()


func _build_viewport() -> void:
	var container := SubViewportContainer.new()
	container.name = "Tableau"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	diorama = CeremonyDiorama.new()
	diorama.name = "Diorama"
	viewport.add_child(diorama)
	diorama.setup(variant, settings)


func _build_caption(scene: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "Caption"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 48
	panel.offset_right = -48
	panel.offset_top = -232
	panel.offset_bottom = -32
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	row.add_child(text)
	text.add_child(_label(String(scene.get("date", "")), 18, Color("#E8BC65")))
	text.add_child(_label(String(scene.get("title", "")), 34, Color("#F2E6CF")))
	var lines: Array = scene.get("lines", [])
	caption_label = _label("\n".join(PackedStringArray(lines)), 20, Color("#F2E6CF"))
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(caption_label)
	text.add_child(_label(String(settings.get("skip_hint", "")), 15, Color("#C9B48A")))
	continue_button = Button.new()
	continue_button.name = "Continue"
	continue_button.text = String(scene.get("button", "TIẾP TỤC"))
	continue_button.custom_minimum_size = Vector2(240, 54)
	continue_button.size_flags_vertical = Control.SIZE_SHRINK_END
	continue_button.pressed.connect(finish)
	row.add_child(continue_button)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
