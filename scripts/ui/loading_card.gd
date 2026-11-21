class_name LoadingCard
extends RefCounted
## Loading screen: a still of the arena with a short caption. Shown under the scene fade
## while the arena loads and under the shader warm-up cover, so both read as one screen.

const IMAGE := "res://assets/ui/loading_arena.jpg"


## A full-screen card that ignores input; the caller owns it and frees it.
static func build() -> Control:
	var card := Control.new()
	card.name = "LoadingCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color("#1E1914")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(base)
	var image := TextureRect.new()
	image.name = "Arena"
	image.texture = load(IMAGE)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(image)
	# Warm shade, darkest at the bottom-left where the caption sits.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.118, 0.098, 0.078, GameBalance.get_number("ui_loading_shade_max", 0.85)))
	gradient.set_color(1, Color(0.118, 0.098, 0.078, GameBalance.get_number("ui_loading_shade_min", 0.25)))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0.0, 1.0)
	shade_texture.fill_to = Vector2(0.6, 0.2)
	var shade := TextureRect.new()
	shade.texture = shade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(shade)
	var caption := ControlsDiagram.label("ĐANG VÀO SÂN", "heading", ControlsDiagram.GOLD)
	caption.name = "Caption"
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, int(GameBalance.get_number("ui_loading_margin", 48.0)))
	card.add_child(caption)
	return card
