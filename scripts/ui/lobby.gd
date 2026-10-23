extends Control

var status_label: Label
var address_edit: LineEdit
var port_input: SpinBox
var host_button: Button
var join_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#263B42")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)

	var title := Label.new()
	title.text = "SỚI GIAO HỮU · LAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)

	var intro := Label.new()
	intro.text = "Host tạo phòng hoặc Join bằng địa chỉ IPv4 trong cùng mạng."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)

	host_button = Button.new()
	host_button.text = "TẠO PHÒNG"
	host_button.custom_minimum_size.y = 48
	host_button.pressed.connect(_host)
	content.add_child(host_button)

	var address_row := HBoxContainer.new()
	address_row.add_theme_constant_override("separation", 8)
	content.add_child(address_row)

	address_edit = LineEdit.new()
	address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_edit.placeholder_text = "IPv4 máy host"
	address_edit.text = "127.0.0.1"
	address_edit.custom_minimum_size.y = 42
	address_edit.text_submitted.connect(func(_text: String): _join())
	address_row.add_child(address_edit)

	port_input = SpinBox.new()
	port_input.min_value = 1
	port_input.max_value = 65535
	port_input.step = 1
	port_input.value = GameBalance.get_int("lan_port", 7777)
	port_input.prefix = "Port "
	port_input.custom_minimum_size = Vector2(130, 42)
	address_row.add_child(port_input)

	join_button = Button.new()
	join_button.text = "JOIN PHÒNG"
	join_button.custom_minimum_size.y = 48
	join_button.pressed.connect(_join)
	content.add_child(join_button)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 44
	content.add_child(status_label)

	var back := Button.new()
	back.text = "QUAY LẠI"
	back.pressed.connect(_back)
	content.add_child(back)

	if not NetworkManager.status_changed.is_connected(_on_status_changed):
		NetworkManager.status_changed.connect(_on_status_changed)
	if not NetworkManager.lobby_ready.is_connected(_on_lobby_ready):
		NetworkManager.lobby_ready.connect(_on_lobby_ready)
	if not NetworkManager.connection_lost.is_connected(_on_connection_lost):
		NetworkManager.connection_lost.connect(_on_connection_lost)
	_set_status("Host mở phòng hoặc nhập IPv4 máy host để Join.")


func _exit_tree() -> void:
	if NetworkManager.status_changed.is_connected(_on_status_changed):
		NetworkManager.status_changed.disconnect(_on_status_changed)
	if NetworkManager.lobby_ready.is_connected(_on_lobby_ready):
		NetworkManager.lobby_ready.disconnect(_on_lobby_ready)
	if NetworkManager.connection_lost.is_connected(_on_connection_lost):
		NetworkManager.connection_lost.disconnect(_on_connection_lost)


func _host() -> void:
	var error: Error = NetworkManager.host(_selected_port())
	if error == OK:
		_set_controls_enabled(false)


func _join() -> void:
	var error: Error = NetworkManager.join(address_edit.text, _selected_port())
	if error == OK:
		_set_controls_enabled(false)


func _selected_port() -> int:
	return int(port_input.value)


func _back() -> void:
	NetworkManager.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _set_controls_enabled(enabled: bool) -> void:
	host_button.disabled = not enabled
	join_button.disabled = not enabled
	address_edit.editable = enabled
	port_input.editable = enabled


func _set_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message


func _on_status_changed(message: String) -> void:
	_set_status(message)
	if message.begins_with("Kết nối thất bại") or message.begins_with("Hết thời gian") or message.begins_with("Không thể"):
		_set_controls_enabled(true)


func _on_connection_lost() -> void:
	_set_controls_enabled(true)


func _on_lobby_ready() -> void:
	SessionState.mode = &"LAN"
	SessionState.level_id = &"LAN01"
	get_tree().change_scene_to_file("res://scenes/arena.tscn")
