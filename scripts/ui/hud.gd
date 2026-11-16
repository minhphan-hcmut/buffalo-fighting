extends CanvasLayer
## Read-only match presentation; combat state is supplied by MatchController.

var controller: MatchController
var player_spirit: ProgressBar
var player_stamina: ProgressBar
var opponent_spirit: ProgressBar
var opponent_stamina: ProgressBar
var spirit_trails: Array[ProgressBar] = []
var spirit_labels: Array[Label] = []
var stamina_labels: Array[Label] = []
var spirit_tweens: Array[Tween] = []
var low_stamina: Array[bool] = [false, false]
var warning_time := 0.0
var timer_label: Label
var center_label: Label
var previous_phase: StringName = &""
var center_punch_time := 0.0
var fight_banner_time := INF
var controls_hint_time := 0.0
var announcer_label: Label
var result_label: Label
var clash_panel: Control
var clash_title: Label
var clash_bar: ProgressBar
var clash_time_label: Label
var clash_hook_label: Label
var clash_keys_label: Label
var tutorial_label: RichTextLabel
## Player panels and timer; faded out once the result is decided so the outro shot is clean.
var top_bar: HBoxContainer
var result_fade_time := 0.0
const CONTROLS := "WASD Đi · Chuột Nhìn · Trái Húc · Space Hổ lao · Phải Ghìm · G Gạt sừng · Esc Tạm dừng"
const CLASH_KEYS := "WASD Đẩy · Trái Móc · Phải Nhả"
const TUTORIAL := {
	1: "WASD để đi, chuột để nhìn",
	2: "Chuột trái để húc khi sừng hướng về đối thủ",
	3: "Space để hổ lao",
	4: "Giữ chuột phải để ghìm đòn phía trước",
	5: "Giữ hướng để đẩy · chuột trái móc · chuột phải nhả",
	6: "Bấm G đúng lúc để gạt sừng, rồi húc ngay để phản đòn"
}
var tutorial_seen: Array[int] = []
var tutorial_queue: Array[int] = []
var tutorial_current := 0
var tutorial_time := 0.0
var tutorial_front_hit := false
var pause_overlay: Control
var pause_panel: PanelContainer
var pause_title: Label
var pause_detail: Label
var pause_actions: VBoxContainer
## True while the pause overlay shows the settings page (Esc then goes back to the pause menu).
var showing_settings := false
var lan_result_shown := false
var rematch_button: Button
var rematch_note: Label
var refresh_elapsed := 0.0
var training_panel: PanelContainer
var training_counter: Label
var training_popup: Label
var training_counts: Dictionary = {}
var training_popup_time := 0.0
var training_released := false
var stats: MatchStats
var stats_panel: GridContainer
var text_scale := -1.0
var normal_banner_position: Vector2
var normal_text_layout: Dictionary
var label_writes := 0
var range_writes := 0
var stamina_fills: Array[StyleBoxFlat] = []
var timer_second := -1
var tutorial_plain := ""
var controls_formatted := ""
var hint_visible := false
var training_counter_dirty := false
var clash_clock := -1.0
var hook_mask := -1
var hook_large := false
var countdown_number := -1
var countdown_text := ""
var lot_dot_count := -1
var lot_text := ""
const HOOK_TEXT := ["", "ĐỎ đang móc", "XANH đang móc", "ĐỎ đang móc · XANH đang móc"]
const HOOK_LARGE := ["", "ĐỎ MÓC", "XANH MÓC", "HAI BÊN MÓC"]
const LOW_COLOR := Color("#FFAA66")
const TIMER_WARNING := Color("#FF8C76")


func _label(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
		label_writes += 1


func _range(bar: Range, value: float) -> void:
	var target := snappedf(value, bar.step) if bar.step > 0.0 else value
	target = clampf(target, bar.min_value, bar.max_value)
	if bar.value != target:
		bar.value = target
		range_writes += 1


func _alpha(control: CanvasItem, value: float) -> void:
	if control.modulate.a != value:
		control.modulate.a = value


func _visible(control: CanvasItem, value: bool) -> void:
	if control.visible != value:
		control.visible = value


func _color(label: Label, value: Color) -> void:
	if label.get_theme_color("font_color") != value:
		label.add_theme_color_override("font_color", value)


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var top := HBoxContainer.new()
	top.position = Vector2(24, 20)
	top.size = Vector2(1232, 140)
	top.add_theme_constant_override("separation", 26)
	root.add_child(top)
	top_bar = top
	var left := _make_player_panel("ĐỎ · 06 · GIÁP ĐÔNG", Color("#B6453B"))
	top.add_child(left)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var level := controller._level_config()
	var right := _make_player_panel("XANH · %s · %s" % [level["opponent_number"], level["opponent_giap"]], Color("#477B9C"), true)
	top.add_child(right)
	timer_label = Label.new()
	timer_label.position = Vector2(585, 22)
	timer_label.size = Vector2(110, 46)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_stylebox_override("normal", _soft_style())
	root.add_child(timer_label)
	center_label = Label.new()
	center_label.size = Vector2(GameBalance.get_number("ui_countdown_label_width"), GameBalance.get_number("ui_countdown_label_height"))
	center_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center_label.position = Vector2(-center_label.size.x * 0.5, GameBalance.get_number("hud_banner_top"))
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 42)
	center_label.add_theme_color_override("font_color", Color("#F2E6CF"))
	center_label.add_theme_color_override("font_outline_color", Color("#1E1914"))
	center_label.add_theme_constant_override("outline_size", GameBalance.get_int("ui_banner_outline_size"))
	center_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, GameBalance.get_number("ui_banner_shadow_alpha")))
	center_label.add_theme_constant_override("shadow_offset_x", 0)
	center_label.add_theme_constant_override("shadow_offset_y", GameBalance.get_int("ui_banner_shadow_offset_y"))
	root.add_child(center_label)
	announcer_label = Label.new()
	# A slim loa ribbon above the controls bar, clear of both buffaloes' heads.
	announcer_label.position = Vector2(150, 594)
	announcer_label.size = Vector2(980, 54)
	announcer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	announcer_label.add_theme_font_size_override("font_size", 20)
	announcer_label.add_theme_color_override("font_color", Color("#F2E6CF"))
	var ribbon := _panel_style()
	ribbon.bg_color = Color("#30281FE6")
	ribbon.border_color = Color("#E8BC65")
	ribbon.set_border_width_all(0)
	ribbon.border_width_top = 2
	ribbon.border_width_bottom = 2
	ribbon.content_margin_top = 6
	ribbon.content_margin_bottom = 6
	announcer_label.add_theme_stylebox_override("normal", ribbon)
	announcer_label.text = controller.announcer_text()
	announcer_label.visible = controller.announcer_active()
	root.add_child(announcer_label)
	# Tug-of-war panel tucked under the timer, clear of the player's buffalo; it carries its own
	# key reminder so the bottom bar can stay out of the way during the lock.
	clash_panel = Panel.new()
	clash_panel.position = Vector2(440, 82)
	clash_panel.size = Vector2(400, 96)
	clash_panel.visible = false
	root.add_child(clash_panel)
	clash_title = Label.new()
	clash_title.text = "KHÓA SỪNG"
	clash_title.position = Vector2(16, 4)
	clash_title.size = Vector2(368, 24)
	clash_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clash_title.add_theme_font_size_override("font_size", 20)
	clash_title.add_theme_color_override("font_color", Color("#E8BC65"))
	clash_panel.add_child(clash_title)
	clash_bar = ProgressBar.new()
	clash_bar.min_value = -GameBalance.get_number("lock_balance_max", 100.0)
	clash_bar.max_value = GameBalance.get_number("lock_balance_max", 100.0)
	clash_bar.show_percentage = false
	clash_bar.position = Vector2(16, 32)
	clash_bar.size = Vector2(368, 16)
	clash_bar.add_theme_stylebox_override("fill", _bar_style(Color("#E8BC65")))
	clash_panel.add_child(clash_bar)
	clash_time_label = Label.new()
	clash_time_label.position = Vector2(16, 51)
	clash_time_label.size = Vector2(368, 20)
	clash_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clash_time_label.add_theme_font_size_override("font_size", 15)
	clash_panel.add_child(clash_time_label)
	clash_keys_label = Label.new()
	clash_keys_label.text = CLASH_KEYS
	clash_keys_label.position = Vector2(16, 72)
	clash_keys_label.size = Vector2(368, 18)
	clash_keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clash_keys_label.add_theme_font_size_override("font_size", 13)
	clash_keys_label.add_theme_color_override("font_color", Color("#D9C9A8"))
	clash_panel.add_child(clash_keys_label)
	# Who is hooking is folded into the title; this label keeps the raw text for LAN probes.
	clash_hook_label = Label.new()
	clash_hook_label.visible = false
	clash_panel.add_child(clash_hook_label)
	tutorial_label = RichTextLabel.new()
	tutorial_label.bbcode_enabled = true
	tutorial_label.scroll_active = false
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tutorial_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_label.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_label.position = Vector2(230, 664)
	tutorial_label.size = Vector2(820, 36)
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HudText.set_size(tutorial_label, "normal_font_size", GameBalance.get_int("ui_controls_font_size"))
	tutorial_label.add_theme_color_override("default_color", Color("#F2E6CF"))
	tutorial_label.add_theme_stylebox_override("normal", _soft_style())
	_set_tutorial_text(CONTROLS)
	root.add_child(tutorial_label)
	result_label = Label.new()
	result_label.visible = false
	result_label.position = Vector2(280, 320)
	result_label.size = Vector2(720, 160)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 30)
	result_label.add_theme_color_override("font_color", Color("#F2E6CF"))
	result_label.add_theme_stylebox_override("normal", _panel_style())
	root.add_child(result_label)
	if not controller.training.is_empty():
		_build_training_panel(root)
	# The in-match HUD is display-only: let clicks through so CameraRig can capture the mouse.
	_ignore_mouse(root)
	_build_pause_overlay(root)
	controller.combat_event.connect(_tutorial_event)
	if controller.training.is_empty():
		stats = MatchStats.new(controller.local_slot)
		controller.combat_event.connect(stats.on_combat_event)
	normal_banner_position = center_label.position
	normal_text_layout = {
		"hint_left": tutorial_label.position.x, "hint_width": tutorial_label.size.x,
		"clash_height": clash_panel.size.y, "clash_bar_top": clash_bar.position.y,
		"clash_time_top": clash_time_label.position.y, "clash_keys_top": clash_keys_label.position.y
	}
	_apply_text_scale()


func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)


func _build_training_panel(root: Control) -> void:
	for key: String in controller.training.counters:
		training_counts[key] = 0
	training_panel = PanelContainer.new()
	training_panel.name = "TrainingPanel"
	var width := GameBalance.get_number("training_panel_width")
	training_panel.position = Vector2((get_viewport().get_visible_rect().size.x - width) * 0.5, GameBalance.get_number("training_panel_top"))
	training_panel.custom_minimum_size.x = width
	root.add_child(training_panel)
	var rows := VBoxContainer.new()
	training_panel.add_child(rows)
	var title := Label.new()
	title.text = controller.training.name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameBalance.get_int("training_title_font_size"))
	title.add_theme_color_override("font_color", Color("#E8BC65"))
	rows.add_child(title)
	training_counter = Label.new()
	training_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	training_counter.add_theme_font_size_override("font_size", GameBalance.get_int("training_counter_font_size"))
	rows.add_child(training_counter)
	training_popup = Label.new()
	training_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	training_popup.add_theme_font_size_override("font_size", GameBalance.get_int("training_popup_font_size"))
	training_popup.add_theme_color_override("font_color", Color("#E8BC65"))
	training_popup.visible = false
	rows.add_child(training_popup)
	training_counter.text = String(controller.training.counter_text).format(training_counts)
	clash_panel.position.y = GameBalance.get_number("training_clash_top")
	center_label.position.y = GameBalance.get_number("training_clash_top")
	controller.combat_event.connect(_training_event)


func _training_count(key: String) -> void:
	if training_counts.has(key):
		training_counts[key] += 1
		training_counter_dirty = true


func _training_success(text: String) -> void:
	_label(training_popup, text)
	training_popup_time = GameBalance.get_number("training_popup_s")


func _training_event(event: StringName, source: int, target: int, _value: float) -> void:
	if source == 2 and String(event) == controller.training.get("attack_event", ""):
		_training_count("attacks")
	if source == 1:
		if event in [&"HORN_HIT", &"DASH_HIT"]:
			_training_count("hits")
		elif event in [&"FLANK_HIT", &"BACK_HIT"]:
			_training_count("flanks")
		elif event == &"PARRY_SUCCESS":
			_training_count("parried")
			_training_success("GẠT ĐƯỢC!")
		elif event == &"COUNTER_HIT":
			_training_count("counters")
			_training_success("PHẢN ĐÒN!")
		elif event == &"RELEASE_START":
			training_released = true
	if event == &"CLASH_START":
		_training_count("locks")
		training_released = false
	elif event == &"CLASH_HOOK" and source == 2:
		_training_count("hooks")
	elif event == &"CLASH_LOSS" and target == 2:
		_training_count("wins")
		if training_released:
			_training_count("releases")
			_training_success("NHẢ ĐÚNG LÚC!")
	elif event in [&"CLASH_WHIFF", &"CLASH_RELEASE", &"CLASH_BREAK", &"CLASH_TIME"]:
		training_released = false
	elif event == &"TRAINING_REFILL" and training_popup_time <= 0.0:
		_training_success("Hồi khí thế")
	if training_counter_dirty:
		_label(training_counter, String(controller.training.counter_text).format(training_counts))
		training_counter_dirty = false


func _build_pause_overlay(root: Control) -> void:
	pause_overlay = Control.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	root.add_child(pause_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#17262EE8")
	pause_overlay.add_child(shade)
	pause_panel = PanelContainer.new()
	pause_overlay.add_child(pause_panel)
	_place_pause_panel(Vector2(520, 0))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	pause_panel.add_child(content)
	pause_title = Label.new()
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 30)
	content.add_child(pause_title)
	pause_detail = Label.new()
	pause_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(pause_detail)
	pause_actions = VBoxContainer.new()
	pause_actions.add_theme_constant_override("separation", 10)
	content.add_child(pause_actions)


## Centres the pause panel at `panel_size`. Uses anchor offsets, not `position`: once the panel is
## in the tree, `position` is relative to the overlay's top-left corner, not to the centre anchor.
## A height of 0 lets the panel shrink to its content; growing both ways keeps it centred.
func _place_pause_panel(panel_size: Vector2) -> void:
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_panel.offset_left = -panel_size.x * 0.5
	pause_panel.offset_top = -panel_size.y * 0.5
	pause_panel.offset_right = panel_size.x * 0.5
	pause_panel.offset_bottom = panel_size.y * 0.5


func _clear_pause_actions() -> void:
	rematch_button = null
	rematch_note = null
	if is_instance_valid(stats_panel):
		stats_panel.get_parent().remove_child(stats_panel)
		stats_panel.queue_free()
	for child in pause_actions.get_children():
		pause_actions.remove_child(child)
		child.queue_free()


func _pause_button(text: String, callback: Callable, container: Container = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.focus_mode = Control.FOCUS_ALL
	UiMotion.attach(button)
	button.pressed.connect(callback)
	(container if container != null else pause_actions).add_child(button)
	HudText.apply(button)
	return button


func show_pause() -> void:
	showing_settings = false
	pause_overlay.visible = true
	_place_pause_panel(Vector2(520, 0))
	pause_title.text = "TẠM DỪNG" if controller.mode == &"SOLO" else "TRẬN LAN ĐANG TẠM DỪNG"
	pause_detail.text = "Trận solo đã dừng." if controller.mode == &"SOLO" else "Hai người chơi đã đồng ý tạm dừng."
	_clear_pause_actions()
	if controller.mode == &"LAN":
		_pause_button("GỬI YÊU CẦU TIẾP TỤC", controller.resume_from_menu)
	else:
		_pause_button("TIẾP TỤC", controller.resume_from_menu)
	if not controller.training.is_empty():
		_pause_button("ĐỔI BÀI TẬP", _change_training)
	_pause_button("CÀI ĐẶT", show_settings)
	if controller.mode == &"SOLO" and controller.training.is_empty():
		_pause_button("CHƠI LẠI", _restart_match)
	_pause_button("VỀ MENU", _return_to_menu)
	HudText.apply(pause_title)
	HudText.apply(pause_detail)
	pause_actions.get_child(0).grab_focus()


func show_pause_wait(requested_pause: bool) -> void:
	pause_overlay.visible = true
	_place_pause_panel(Vector2(520, 0))
	pause_title.text = "ĐANG CHỜ XÁC NHẬN"
	pause_detail.text = (
		"Yêu cầu tạm dừng đã gửi tới đối phương."
		if requested_pause
		else "Yêu cầu tiếp tục trận đã gửi tới đối phương."
	)
	_clear_pause_actions()
	_pause_button("CÀI ĐẶT", show_settings)
	_pause_button("RỜI TRẬN", _return_to_menu)
	HudText.apply(pause_title)
	HudText.apply(pause_detail)
	pause_actions.get_child(0).grab_focus()


func show_pause_confirmation(peer_id: int, requested_pause: bool) -> void:
	pause_overlay.visible = true
	_place_pause_panel(Vector2(520, 0))
	pause_title.text = "YÊU CẦU TỪ NGƯỜI CHƠI %d" % peer_id
	pause_detail.text = (
		"Đối phương muốn tạm dừng trận."
		if requested_pause
		else "Đối phương muốn tiếp tục trận."
	)
	_clear_pause_actions()
	_pause_button("CHẤP NHẬN", func(): controller.network.answer_pause(true))
	_pause_button("TỪ CHỐI", func(): controller.network.answer_pause(false))
	HudText.apply(pause_title)
	HudText.apply(pause_detail)
	pause_actions.get_child(0).grab_focus()


func _show_lan_result() -> void:
	lan_result_shown = true
	showing_settings = false
	pause_overlay.show()
	_place_pause_panel(Vector2(520, 0))
	pause_title.text = "KẾT QUẢ TRẬN LAN"
	pause_detail.text = result_label.text
	_clear_pause_actions()
	if stats != null:
		stats_panel = stats.create_block()
		var content := pause_actions.get_parent()
		content.add_child(stats_panel)
		content.move_child(stats_panel, pause_actions.get_index())
		HudText.apply(stats_panel)
	if controller.lan != null:
		rematch_note = Label.new()
		rematch_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rematch_note.add_theme_font_size_override("font_size", GameBalance.get_int("stats_font_size"))
		pause_actions.add_child(rematch_note)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", GameBalance.get_int("stats_column_gap"))
		pause_actions.add_child(row)
		rematch_button = _pause_button("ĐẤU LẠI", controller.lan.request_rematch, row)
		rematch_button.name = "RematchButton"
		rematch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var menu := _pause_button("VỀ MENU", _return_to_menu, row)
		menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		update_lan_rematch()
		(rematch_button if not rematch_button.disabled else menu).grab_focus()
	else:
		_pause_button("VỀ MENU", _return_to_menu).grab_focus()
	HudText.apply(pause_title)
	HudText.apply(pause_detail)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func update_lan_rematch(disconnected: bool = false) -> void:
	if not is_instance_valid(rematch_button) or controller.lan == null:
		return
	var lan: MatchNetwork = controller.lan
	disconnected = disconnected or lan.peer_left
	rematch_button.disabled = disconnected or not lan.can_rematch() or lan.local_wants_rematch
	if disconnected:
		rematch_note.text = "Đối phương đã rời trận."
	elif lan.local_wants_rematch:
		rematch_note.text = "Đã gửi yêu cầu. Đang chờ đối phương…"
	elif lan.remote_wants_rematch:
		rematch_note.text = "Đối phương muốn đấu lại"
	else:
		rematch_note.text = ""
	rematch_button.text = "ĐẤU LẠI" if disconnected else ("ĐANG CHỜ" if lan.local_wants_rematch else ("ĐỒNG Ý" if lan.remote_wants_rematch else "ĐẤU LẠI"))
	rematch_note.visible = not rematch_note.text.is_empty()
	HudText.apply(rematch_note)
	if rematch_button.disabled and rematch_button.has_focus():
		(rematch_button.get_parent().get_child(-1) as Button).grab_focus()


func hide_pause() -> void:
	showing_settings = false
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = false


func show_settings() -> void:
	showing_settings = true
	pause_overlay.visible = true
	_place_pause_panel(Vector2(520, 620))
	pause_title.text = "CÀI ĐẶT"
	pause_detail.text = "Âm lượng áp dụng cho các bus audio của project."
	_clear_pause_actions()
	SettingsControls.populate(pause_actions, _set_mouse_sensitivity)
	_pause_button("QUAY LẠI", show_pause)
	pause_actions.get_child(0).get_child(1).grab_focus()


## Applies a new sensitivity to the live camera (SessionState is updated by SettingsControls).
func _set_mouse_sensitivity(value: float) -> void:
	controller.get_node("CameraRig").mouse_sensitivity = value


func _restart_match() -> void:
	if controller.mode == &"LAN":
		controller.network.leave()
	get_tree().reload_current_scene()


func _return_to_menu() -> void:
	if controller.mode == &"LAN":
		controller.network.leave()
	SessionState.return_to_menu()
	if controller.mode == &"LAN":
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		UiMotion.change_scene(get_tree(), load("res://scenes/main_menu.tscn"))


func _change_training() -> void:
	load("res://scripts/ui/main_menu.gd").return_to_training = true
	_return_to_menu()


func _make_player_panel(title: String, color: Color, mirror: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	# Frameless: the bars float over the scene so the arena, not HUD boxes, fills the top
	# of the screen. Text carries a dark outline to stay readable over sky and crowd.
	panel.custom_minimum_size = Vector2(380, 0)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	# Title row (GDD 5.2 #1): a small giáp flag with the buffalo number, then side + giáp.
	var parts := title.split(" · ")
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_row.alignment = BoxContainer.ALIGNMENT_END if mirror else BoxContainer.ALIGNMENT_BEGIN
	content.add_child(title_row)
	var chip := PanelContainer.new()
	var chip_style := _bar_style(color)
	chip_style.border_color = Color("#E8BC65")
	chip_style.set_border_width_all(2)
	chip_style.content_margin_left = 8
	chip_style.content_margin_right = 8
	chip.add_theme_stylebox_override("panel", chip_style)
	var number_label := Label.new()
	number_label.text = parts[1] if parts.size() > 1 else ""
	number_label.add_theme_font_size_override("font_size", 20)
	number_label.add_theme_color_override("font_color", Color("#F2E6CF"))
	number_label.add_theme_color_override("font_outline_color", Color("#241D18"))
	number_label.add_theme_constant_override("outline_size", 4)
	chip.add_child(number_label)
	var title_label := Label.new()
	title_label.text = "%s · %s" % [parts[0], parts[2]] if parts.size() > 2 else title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_outline_color", Color("#1E1914"))
	title_label.add_theme_constant_override("outline_size", 6)
	if mirror:
		title_row.add_child(title_label)
		title_row.add_child(chip)
	else:
		title_row.add_child(chip)
		title_row.add_child(title_label)
	var spirit_row := Control.new()
	spirit_row.custom_minimum_size = Vector2(380, 22)
	content.add_child(spirit_row)
	var trail := ProgressBar.new()
	trail.max_value = GameBalance.get_number("spirit_max")
	trail.value = trail.max_value
	trail.show_percentage = false
	trail.fill_mode = ProgressBar.FILL_END_TO_BEGIN if mirror else ProgressBar.FILL_BEGIN_TO_END
	trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trail.add_theme_stylebox_override("fill", _bar_style(Color("#F7DDA4")))
	trail.add_theme_stylebox_override("background", _bar_style(Color("#1E1914B0")))
	spirit_row.add_child(trail)
	var spirit := ProgressBar.new()
	spirit.max_value = trail.max_value
	spirit.value = spirit.max_value
	spirit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spirit.fill_mode = trail.fill_mode
	spirit.show_percentage = false
	spirit.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var spirit_fill := _bar_style(color)
	spirit.add_theme_stylebox_override("fill", spirit_fill)
	spirit_row.add_child(spirit)
	var spirit_text := Label.new()
	spirit_text.text = "KHÍ THẾ"
	spirit_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spirit_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spirit_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spirit_text.add_theme_font_size_override("font_size", 14)
	spirit_text.add_theme_color_override("font_color", Color("#F2E6CF"))
	spirit_text.add_theme_color_override("font_outline_color", Color("#1E1914"))
	spirit_text.add_theme_constant_override("outline_size", 4)
	spirit_row.add_child(spirit_text)
	var stamina := ProgressBar.new()
	stamina.max_value = GameBalance.get_number("stamina_max")
	stamina.custom_minimum_size = Vector2(380, 6)
	stamina.fill_mode = trail.fill_mode
	stamina.show_percentage = false
	stamina.add_theme_stylebox_override("fill", _bar_style(Color("#E8BC65")))
	stamina.add_theme_stylebox_override("background", _bar_style(Color("#1E1914B0")))
	stamina_fills.append(stamina.get_theme_stylebox("fill") as StyleBoxFlat)
	content.add_child(stamina)
	# Only shown when stamina is low, so the warning never relies on colour alone.
	var stamina_text := Label.new()
	stamina_text.add_theme_font_size_override("font_size", 14)
	stamina_text.add_theme_color_override("font_outline_color", Color("#1E1914"))
	stamina_text.add_theme_constant_override("outline_size", 4)
	stamina_text.horizontal_alignment = title_label.horizontal_alignment
	content.add_child(stamina_text)
	spirit_trails.append(trail)
	spirit_labels.append(spirit_text)
	stamina_labels.append(stamina_text)
	spirit_tweens.append(null)
	if player_spirit == null:
		player_spirit = spirit
		player_stamina = stamina
	else:
		opponent_spirit = spirit
		opponent_stamina = stamina
	return panel


func _panel_style() -> StyleBoxFlat:
	var style := _bar_style(Color("#30281F"))
	style.border_color = Color("#8A5A3B")
	style.set_border_width_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


## Light, borderless chrome for always-on HUD text (timer, controls): it reads over
## the scene without boxing it in.
func _soft_style() -> StyleBoxFlat:
	var style := _bar_style(Color("#1E1914A0"))
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _process(delta: float) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(controller.player):
		return
	var interval := GraphicsQuality.hud_refresh_interval()
	# Thấp throttles only the live fight; countdown, results and paused settings stay immediate.
	if interval > 0.0 and delta > 0.0 and controller.phase == &"PLAYING" and not controller.paused:
		refresh_elapsed += delta
		if refresh_elapsed < interval:
			return
		delta = refresh_elapsed
	refresh_elapsed = 0.0
	if not is_equal_approx(text_scale, HudText.scale_factor()):
		_apply_text_scale()
	warning_time += delta
	_update_resources(0, controller.player, player_spirit, player_stamina)
	_update_resources(1, controller.opponent, opponent_spirit, opponent_stamina)
	var second := int(controller.remaining_time)
	if second != timer_second:
		timer_second = second
		_label(timer_label, "%02d:%02d" % [second / 60, second % 60])
	_color(timer_label, TIMER_WARNING if controller.remaining_time <= GameBalance.get_number("ui_timer_warning_s") else ControlsDiagram.PAPER)
	_visible(announcer_label, controller.announcer_active())
	_update_center(delta)
	if controller.phase == &"COUNTDOWN":
		# Only the loa ribbon talks during the countdown; controls appear with VÀO TRẬN!.
		controls_hint_time = 0.0
		hint_visible = false
	if controller.mode == &"LAN" and controller.result_ready and not lan_result_shown:
		_show_lan_result()
	if controller.phase == &"PLAYING":
		_update_tutorial(delta)
	elif controller.phase == &"RESULT":
		# Solo hands over to the outro camera and the result panel; LAN keeps a short hint
		# next to its result label because the next step waits on the other player.
		hint_visible = (controller.mode == &"LAN" and not controller.result_ready) or controller.outro.can_skip()
		if controller.mode == &"SOLO":
			HudText.set_size(tutorial_label, "normal_font_size", GameBalance.get_int("result_skip_hint_font_size"))
			_alpha(tutorial_label, clampf((controller.outro.time - GameBalance.get_number("result_skip_grace_s")) / GameBalance.get_number("result_skip_hint_fade_s"), 0.0, 1.0))
			_set_tutorial_text("Bấm phím bất kỳ để bỏ qua")
		else:
			_alpha(tutorial_label, 1.0)
			_set_tutorial_text("Kết quả đã khóa · bấm Esc để thả chuột")
	_update_result_fade(delta)
	_update_clash()
	_visible(center_label, not clash_panel.visible)
	if not controller.training.is_empty():
		training_popup_time = maxf(0.0, training_popup_time - (0.0 if controller.paused else delta))
		if training_popup_time <= 0.0:
			_label(training_popup, "")
		# The popup line takes space only while it shows, so the panel stays two lines tall.
		if training_popup.visible != (training_popup.text != ""):
			training_popup.visible = training_popup.text != ""
			training_panel.reset_size()
	_visible(tutorial_label, hint_visible and not clash_panel.visible)


func _update_result_fade(delta: float) -> void:
	if controller.phase == &"RESULT":
		result_fade_time += delta
	else:
		result_fade_time = 0.0
	var fade := GameBalance.get_number("ui_result_hud_fade_s", 0.6)
	var alpha := 1.0 - clampf(result_fade_time / maxf(fade, 0.001), 0.0, 1.0)
	_alpha(top_bar, alpha)
	_alpha(timer_label, alpha)
	_visible(top_bar, alpha > 0.0)
	_visible(timer_label, alpha > 0.0 and controller.training.is_empty())


func _update_center(delta: float) -> void:
	var elapsed := 0.0 if controller.paused else delta
	if previous_phase == &"COUNTDOWN" and controller.phase == &"PLAYING":
		fight_banner_time = 0.0
	elif controller.phase == &"PLAYING":
		fight_banner_time += elapsed
	previous_phase = controller.phase
	var text := ""
	var color := ControlsDiagram.PAPER
	var font_size := 42
	var banner_hold := GameBalance.get_number("ui_fight_banner_s")
	var banner_fade := GameBalance.get_number("ui_fight_banner_fade_s")
	if controller.phase == &"COUNTDOWN":
		var number := ceili(controller.countdown_time)
		if number != countdown_number:
			countdown_number = number
			countdown_text = str(number)
		text = countdown_text
	elif controller.outro.is_revealing_lot():
		var dots := 1 + int(controller.outro.time * 4.0) % 3
		if dots != lot_dot_count:
			lot_dot_count = dots
			lot_text = "BỐC THĂM" + ".".repeat(dots)
		text = lot_text
	elif controller.phase == &"PLAYING" and fight_banner_time < banner_hold + banner_fade:
		text = "VÀO TRẬN!"
		color = ControlsDiagram.GOLD
	if text != center_label.text:
		center_punch_time = 0.0
	else:
		center_punch_time += elapsed
	_label(center_label, text)
	var scale := Vector2.ONE
	var alpha := 1.0
	if controller.phase == &"COUNTDOWN" or text == "VÀO TRẬN!":
		font_size = GameBalance.get_int("ui_countdown_font_size")
		scale = UiMotion.banner_scale(center_punch_time)
		if text == "VÀO TRẬN!" and fight_banner_time > banner_hold:
			alpha = 1.0 - (fight_banner_time - banner_hold) / banner_fade
	if center_label.scale != scale:
		center_label.scale = scale
	_alpha(center_label, alpha)
	HudText.set_size(center_label, "font_size", font_size)
	_color(center_label, color)
	var pivot := center_label.size * 0.5
	if center_label.pivot_offset != pivot:
		center_label.pivot_offset = pivot


func _update_resources(index: int, actor: Buffalo, spirit: ProgressBar, stamina: ProgressBar) -> void:
	var previous := spirit.value
	_range(spirit, actor.spirit)
	_range(stamina, actor.stamina)
	if spirit.value != previous:
		if spirit_tweens[index] != null:
			spirit_tweens[index].kill()
		if spirit.value < previous:
			spirit_tweens[index] = create_tween()
			spirit_tweens[index].tween_property(spirit_trails[index], "value", spirit.value, GameBalance.get_number("ui_spirit_trail_s"))
		else:
			_range(spirit_trails[index], spirit.value)
	low_stamina[index] = stamina.value < GameBalance.get_number("ui_low_stamina_threshold")
	var color := LOW_COLOR if low_stamina[index] else ControlsDiagram.GOLD
	if stamina_fills[index].bg_color != color:
		stamina_fills[index].bg_color = color
	_label(stamina_labels[index], "SỨC THẤP" if low_stamina[index] else "")
	_color(stamina_labels[index], color)
	var alpha := 1.0
	if low_stamina[index]:
		var pulse := 0.5 + 0.5 * cos(warning_time * TAU * GameBalance.get_number("ui_low_stamina_pulse_hz"))
		alpha = lerpf(GameBalance.get_number("ui_low_stamina_pulse_min_alpha"), 1.0, pulse)
	_alpha(stamina, alpha)


func _set_tutorial_text(plain: String) -> void:
	if tutorial_plain == plain:
		return
	tutorial_plain = plain
	HudText.set_size(tutorial_label, "bold_font_size", tutorial_label.get_meta("hud_base_normal_font_size", tutorial_label.get_theme_font_size("normal_font_size")))
	var formatted := plain
	if plain == CONTROLS and controls_formatted.is_empty():
		var items := PackedStringArray()
		for item in plain.split(" · "):
			var pair := item.split(" ", true, 1)
			items.append("[b][color=#E8BC65]%s[/color][/b] %s" % [pair[0], pair[1]])
		var separator := " [color=%s]·[/color] " % Color(1.0, 1.0, 1.0, GameBalance.get_number("ui_controls_separator_alpha")).to_html()
		controls_formatted = separator.join(items)
	if plain == CONTROLS:
		formatted = controls_formatted
	if tutorial_label.text != formatted:
		tutorial_label.text = formatted
		label_writes += 1


func _tutorial_enabled() -> bool:
	return controller.training.is_empty() and controller.mode == &"SOLO" and controller.level_id == &"L01"


func _queue_tutorial(id: int) -> void:
	if not tutorial_seen.has(id) and not tutorial_queue.has(id):
		tutorial_queue.append(id)
		tutorial_queue.sort()


func _tutorial_event(event: StringName, source: int, target: int, _value: float) -> void:
	if not _tutorial_enabled():
		return
	if event == &"CLASH_START":
		_queue_tutorial(5)
	if target != controller.local_slot or event not in [&"HORN_HIT", &"DASH_HIT", &"CLASH_LOSS"]:
		return
	_queue_tutorial(4)
	if event == &"HORN_HIT":
		var attacker := controller.player if source == 1 else controller.opponent
		var victim := controller.player if target == 1 else controller.opponent
		var toward := (attacker.global_position - victim.global_position).normalized()
		if victim.forward().dot(toward) >= cos(GameBalance.get_angle("flank_min_deg")):
			tutorial_front_hit = true


func _update_tutorial(delta: float) -> void:
	hint_visible = true
	var alpha := 1.0
	HudText.set_size(tutorial_label, "normal_font_size", GameBalance.get_int("ui_controls_font_size"))
	if not _tutorial_enabled():
		_set_tutorial_text(CONTROLS)
		if not controller.paused:
			controls_hint_time += delta
		var duration := GameBalance.get_number("ui_controls_hint_s")
		var fade := GameBalance.get_number("ui_controls_hint_fade_s")
		hint_visible = controls_hint_time < duration
		if hint_visible and controls_hint_time > duration - fade:
			alpha = (duration - controls_hint_time) / fade
		_alpha(tutorial_label, alpha)
		return
	_alpha(tutorial_label, alpha)
	_queue_tutorial(1)
	var distance := controller.player.global_position.distance_to(controller.opponent.global_position)
	if distance <= GameBalance.get_number("tutorial_horn_range"):
		_queue_tutorial(2)
	elif distance <= GameBalance.get_number("tutorial_dash_range"):
		_queue_tutorial(3)
	if tutorial_front_hit and tutorial_seen.has(4):
		_queue_tutorial(6)
	if not controller.paused:
		tutorial_time = maxf(0.0, tutorial_time - delta)
	if tutorial_time <= 0.0:
		tutorial_current = 0
		if not tutorial_queue.is_empty():
			tutorial_current = tutorial_queue.pop_front()
			tutorial_seen.append(tutorial_current)
			tutorial_time = GameBalance.get_number("tutorial_hint_s")
	_set_tutorial_text(TUTORIAL[tutorial_current] if tutorial_current > 0 else CONTROLS)


## Tug-of-war bar: the right half is always the local player's side.
func _update_clash() -> void:
	var clash: Dictionary = controller.active_clash
	_visible(clash_panel, not clash.is_empty())
	if clash.is_empty():
		return
	var mirror := 1.0 if controller.local_slot == 1 else -1.0
	_range(clash_bar, float(clash.get("lock_balance", 0.0)) * mirror)
	var time_left := maxf(0.0, GameBalance.get_number("lock_max_s") - float(clash.get("time", 0.0)))
	if time_left != clash_clock:
		clash_clock = time_left
		_label(clash_time_label, "ĐỐI PHƯƠNG  ←  %.1f s  →  BẠN" % time_left)
	var mask := int(controller.player.clash_hooked) + int(controller.opponent.clash_hooked) * 2
	if mask != hook_mask or hook_large != SessionState.hud_text_large:
		hook_mask = mask
		hook_large = SessionState.hud_text_large
		_label(clash_hook_label, HOOK_TEXT[mask])
		_label(clash_title, "KHÓA SỪNG" if mask == 0 else "KHÓA SỪNG · " + (HOOK_LARGE[mask] if hook_large else HOOK_TEXT[mask]))


func show_result(winner_slot: int, reason: StringName) -> void:
	lan_result_shown = false
	if reason == &"CONNECTION_LOST":
		result_label.text = "MẤT KẾT NỐI\nĐối phương đã rời trận."
		return
	var winner := "ÔNG TRÂU ĐỎ" if winner_slot == 1 else "ÔNG TRÂU XANH"
	var reason_text: String = {
		&"FLEE": "THẮNG THẾ · ĐỐI PHƯƠNG LUI SỚI",
		&"TIME": "THẮNG THỜI GIAN · KHÍ THẾ CAO HƠN",
		&"LOT": "BỐC THĂM · LOT"
	}.get(reason, "TRẬN KẾT THÚC")
	# Shown by _process once the outro has played.
	result_label.text = "%s\n%s" % [winner, reason_text]


func _apply_text_scale() -> void:
	text_scale = HudText.scale_factor()
	for child in get_child(0).get_children():
		if child != pause_overlay:
			HudText.apply(child)
	HudText.apply(pause_title)
	HudText.apply(pause_detail)
	if not showing_settings:
		HudText.apply(pause_actions)
	# Fixed HUD strips need room for the larger glyphs, not a scaled screen.
	tutorial_label.position.x = GameBalance.get_number("hud_large_hint_left") if SessionState.hud_text_large else normal_text_layout.hint_left
	tutorial_label.size.x = GameBalance.get_number("hud_large_hint_width") if SessionState.hud_text_large else normal_text_layout.hint_width
	clash_panel.size.y = GameBalance.get_number("hud_large_clash_height") if SessionState.hud_text_large else normal_text_layout.clash_height
	clash_bar.position.y = GameBalance.get_number("hud_large_clash_bar_top") if SessionState.hud_text_large else normal_text_layout.clash_bar_top
	clash_time_label.position.y = GameBalance.get_number("hud_large_clash_time_top") if SessionState.hud_text_large else normal_text_layout.clash_time_top
	clash_keys_label.position.y = GameBalance.get_number("hud_large_clash_keys_top") if SessionState.hud_text_large else normal_text_layout.clash_keys_top
	center_label.position = normal_banner_position
	if not controller.training.is_empty():
		var top := GameBalance.get_number("hud_large_training_clash_top") if SessionState.hud_text_large else GameBalance.get_number("training_clash_top")
		clash_panel.position.y = top
		center_label.position.y = top
