class_name SettingsControls
extends RefCounted
## Builds the settings rows shared by the main menu and the in-match pause menu.


## Adds volume sliders, mouse sensitivity, fullscreen and camera-shake toggles to `container`.
## `on_sensitivity` is called with the new sensitivity after SessionState is updated.
static func populate(container: Container, on_sensitivity: Callable = Callable()) -> void:
	add_audio_slider(container, "Âm lượng tổng", "Master")
	add_audio_slider(container, "Nhạc", "Music")
	add_audio_slider(container, "Hiệu ứng", "SFX")
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.03
	sensitivity.max_value = 0.5
	sensitivity.step = 0.01
	sensitivity.value = SessionState.get_mouse_sensitivity()
	sensitivity.value_changed.connect(func(value: float):
		SessionState.mouse_sensitivity = value
		if on_sensitivity.is_valid():
			on_sensitivity.call(value)
	)
	container.add_child(labeled("Độ nhạy chuột", sensitivity))
	var fullscreen := CheckButton.new()
	fullscreen.text = "Toàn màn hình"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(set_fullscreen)
	container.add_child(fullscreen)
	var shake := CheckButton.new()
	shake.text = "Rung camera"
	shake.button_pressed = SessionState.camera_shake_enabled
	shake.toggled.connect(func(enabled: bool): SessionState.camera_shake_enabled = enabled)
	container.add_child(shake)


## Adds a 0-100 linear volume slider bound to `bus_name`, creating the bus if needed.
static func add_audio_slider(container: Container, label_text: String, bus_name: StringName) -> void:
	var bus_index := FestivalAudio.ensure_bus(bus_name)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = AudioServer.get_bus_volume_linear(bus_index) * 100.0
	slider.value_changed.connect(
		func(value: float): AudioServer.set_bus_volume_linear(bus_index, value / 100.0)
	)
	container.add_child(labeled(label_text, slider))


## A label stacked above `control`.
static func labeled(label_text: String, control: Control) -> VBoxContainer:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	row.add_child(control)
	return row


static func set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)
