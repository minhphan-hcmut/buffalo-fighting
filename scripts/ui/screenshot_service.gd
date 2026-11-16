extends CanvasLayer
## Global F12 capture; the toast appears only after the frame is written.

signal saved(path: String)

var directory := "user://screenshots"
var frame_provider: Callable
var toast: Label
var toast_time := 0.0
var capturing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	# Input propagates in reverse tree order; F12 must precede scene skip handlers.
	get_tree().scene_changed.connect(func(): get_tree().root.move_child(self, -1))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	toast = Label.new()
	toast.text = "Đã lưu ảnh"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toast.offset_left = -GameBalance.get_number("screenshot_toast_width")
	toast.offset_right = -GameBalance.get_number("screenshot_toast_margin")
	toast.offset_top = GameBalance.get_number("screenshot_toast_margin")
	toast.add_theme_font_size_override("font_size", GameBalance.get_int("screenshot_toast_font_size"))
	toast.add_theme_color_override("font_color", Color("#F2E6CF"))
	toast.add_theme_color_override("font_outline_color", Color("#1E1914"))
	toast.add_theme_constant_override("outline_size", GameBalance.get_int("screenshot_toast_outline"))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.hide()
	root.add_child(toast)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		get_viewport().set_input_as_handled()
		capture()


func capture() -> void:
	if capturing:
		return
	capturing = true
	toast.hide()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var frame: Image = frame_provider.call() if frame_provider.is_valid() else get_viewport().get_texture().get_image()
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK or frame == null or frame.is_empty():
		push_warning("Không thể chụp ảnh màn hình.")
		capturing = false
		return
	var stamp := Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "-")
	var base := directory.path_join("choi-trau-" + stamp)
	var path := base + ".png"
	var suffix := 2
	while FileAccess.file_exists(path):
		path = "%s-%d.png" % [base, suffix]
		suffix += 1
	error = frame.save_png(path)
	capturing = false
	if error != OK:
		push_warning("Không thể lưu ảnh: %s" % error_string(error))
		return
	toast_time = GameBalance.get_number("screenshot_toast_s")
	toast.show()
	saved.emit(path)


func _process(delta: float) -> void:
	toast_time = maxf(0.0, toast_time - delta)
	if toast_time <= 0.0:
		toast.hide()
