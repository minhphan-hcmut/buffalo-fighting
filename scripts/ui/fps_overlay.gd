class_name FpsOverlay
extends CanvasLayer
## Small FPS readout in the bottom-right corner, shown when the player turns it on in
## Cài đặt (GraphicsQuality.show_fps). Lives under the root so it survives scene changes.

var label: Label


func _ready() -> void:
	layer = GameBalance.get_int("graphics_fps_layer", 110)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_right = -12.0
	label.offset_bottom = -8.0
	label.add_theme_font_size_override("font_size", GameBalance.get_int("graphics_fps_font_size", 14))
	label.add_theme_color_override("font_color", Color("#F2E6CF"))
	label.add_theme_color_override("font_outline_color", Color("#1E1914"))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	visible = GraphicsQuality.show_fps()


func _process(_delta: float) -> void:
	if visible:
		label.text = "%d FPS · %s" % [Engine.get_frames_per_second(), GraphicsQuality.PRESET_NAMES[GraphicsQuality.preset()]]
