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
var ping_label: Label
var displayed_ping := -2
var center_label: Label
var previous_phase: StringName = &""
var center_punch_time := 0.0
var fight_banner_time := INF
const TutorialPresenter := preload("res://scripts/ui/hud_tutorial.gd")
const TrainingPresenter := preload("res://scripts/ui/hud_training.gd")
var tutorial_presenter := TutorialPresenter.new()
var training_presenter := TrainingPresenter.new()
var controls_hint_time: float:
	get: return tutorial_presenter.controls_hint_time
	set(value): tutorial_presenter.controls_hint_time = value
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
const CONTROLS := TutorialPresenter.CONTROLS
const CLASH_KEYS := "WASD Đẩy tới · Trái Móc · Phải Nhả"
const TUTORIAL := TutorialPresenter.TUTORIAL
var tutorial_seen: Array[int]:
	get: return tutorial_presenter.tutorial_seen
	set(value): tutorial_presenter.tutorial_seen = value
var tutorial_queue: Array[int]:
	get: return tutorial_presenter.tutorial_queue
	set(value): tutorial_presenter.tutorial_queue = value
var tutorial_current: int:
	get: return tutorial_presenter.tutorial_current
	set(value): tutorial_presenter.tutorial_current = value
var tutorial_time: float:
	get: return tutorial_presenter.tutorial_time
	set(value): tutorial_presenter.tutorial_time = value
var tutorial_front_hit: bool:
	get: return tutorial_presenter.tutorial_front_hit
	set(value): tutorial_presenter.tutorial_front_hit = value
const PauseView := preload("res://scripts/ui/match_pause_view.gd")
const LanResultView := preload("res://scripts/ui/lan_result_view.gd")
var pause_view := PauseView.new()
var lan_result_view := LanResultView.new()
var pause_overlay: Control:
	get: return pause_view.pause_overlay
	set(value): pause_view.pause_overlay = value
var pause_panel: PanelContainer:
	get: return pause_view.pause_panel
	set(value): pause_view.pause_panel = value
var pause_title: Label:
	get: return pause_view.pause_title
	set(value): pause_view.pause_title = value
var pause_detail: Label:
	get: return pause_view.pause_detail
	set(value): pause_view.pause_detail = value
var pause_actions: VBoxContainer:
	get: return pause_view.pause_actions
	set(value): pause_view.pause_actions = value
var showing_settings: bool:
	get: return pause_view.showing_settings
	set(value): pause_view.showing_settings = value
var settings_screen: SettingsScreen:
	get: return pause_view.settings_screen
	set(value): pause_view.settings_screen = value
var lan_result_shown: bool:
	get: return lan_result_view.lan_result_shown
	set(value): lan_result_view.lan_result_shown = value
var rematch_button: Button:
	get: return lan_result_view.rematch_button
	set(value): lan_result_view.rematch_button = value
var rematch_note: Label:
	get: return lan_result_view.rematch_note
	set(value): lan_result_view.rematch_note = value
var refresh_elapsed := 0.0
var training_panel: PanelContainer:
	get: return training_presenter.training_panel
	set(value): training_presenter.training_panel = value
var training_counter: Label:
	get: return training_presenter.training_counter
	set(value): training_presenter.training_counter = value
var training_popup: Label:
	get: return training_presenter.training_popup
	set(value): training_presenter.training_popup = value
var training_counts: Dictionary:
	get: return training_presenter.training_counts
	set(value): training_presenter.training_counts = value
var training_popup_time: float:
	get: return training_presenter.training_popup_time
	set(value): training_presenter.training_popup_time = value
var training_released: bool:
	get: return training_presenter.training_released
	set(value): training_presenter.training_released = value
var stats: MatchStats
var stats_panel: GridContainer:
	get: return pause_view.stats_panel
	set(value): pause_view.stats_panel = value
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
var training_counter_dirty: bool:
	get: return training_presenter.training_counter_dirty
	set(value): training_presenter.training_counter_dirty = value
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


func _update_ping(milliseconds: int) -> void:
	if ping_label == null or displayed_ping == milliseconds:
		return
	displayed_ping = milliseconds
	_label(ping_label, "Ping %d ms" % milliseconds if milliseconds >= 0 else "Ping —")
	_color(ping_label, TIMER_WARNING if milliseconds > GameBalance.get_int("lan_ping_warning_ms") else SettingsControls.MUTED)


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	if controller.mode == &"LAN":
		ping_label = Label.new()
		ping_label.name = "LanPing"
		root.add_child(ping_label)
		ping_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		ping_label.size = Vector2(GameBalance.get_number("hud_ping_width_px"), GameBalance.get_number("hud_ping_height_px"))
		ping_label.offset_left = -ping_label.size.x - GameBalance.get_number("hud_ping_margin_px")
		ping_label.offset_top = -ping_label.size.y - GameBalance.get_number("hud_ping_margin_px")
		ping_label.offset_right = -GameBalance.get_number("hud_ping_margin_px")
		ping_label.offset_bottom = -GameBalance.get_number("hud_ping_margin_px")
		ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ping_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ping_label.add_theme_font_size_override("font_size", GameBalance.get_int("hud_ping_font_size"))
		controller.network.ping_changed.connect(_update_ping)
		_update_ping(controller.network.ping_ms)
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
	# Add owners after root so get_child(0) and all existing UI paths stay stable.
	training_presenter.name = "TrainingPresenter"
	add_child(training_presenter)
	_build_training_panel(root)
	# The in-match HUD is display-only: let clicks through so CameraRig can capture the mouse.
	_ignore_mouse(root)
	_build_pause_overlay(root)
	tutorial_presenter.name = "TutorialPresenter"
	add_child(tutorial_presenter)
	tutorial_presenter.setup(controller, tutorial_label, _set_tutorial_text)
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
	training_presenter.setup(controller, root, _label)
	if not controller.training.is_empty():
		clash_panel.position.y = GameBalance.get_number("training_clash_top")
		center_label.position.y = GameBalance.get_number("training_clash_top")


func _training_count(key: String) -> void:
	training_presenter.count(key)


func _training_success(text: String) -> void:
	training_presenter.success(text)


func _training_event(event: StringName, source: int, target: int, value: float) -> void:
	training_presenter.on_combat_event(event, source, target, value)


func _build_pause_overlay(root: Control) -> void:
	pause_view.name = "PauseView"
	add_child(pause_view)
	pause_view.setup(root, {
		"resume": controller.resume_from_menu, "restart": _restart_match,
		"leave": return_to_menu, "change_training": _change_training,
		"answer": _answer_pause, "sensitivity": _set_mouse_sensitivity,
	})
	lan_result_view.name = "LanResultView"
	add_child(lan_result_view)
	lan_result_view.setup(pause_view, _request_rematch, return_to_menu)


func _place_pause_panel(panel_size: Vector2) -> void:
	pause_view.place_panel(panel_size)


func _clear_pause_actions() -> void:
	pause_view.clear_actions()


func _pause_button(text: String, callback: Callable, container: Container = null, tier: StringName = &"SecondaryButton") -> Button:
	return pause_view.button(text, callback, container, tier)


func show_pause() -> void:
	pause_view.show_pause(controller.mode, not controller.training.is_empty())


func show_pause_wait(requested_pause: bool) -> void:
	pause_view.show_wait(requested_pause)


func show_pause_confirmation(peer_id: int, requested_pause: bool) -> void:
	pause_view.show_confirmation(peer_id, requested_pause)


func _answer_pause(accepted: bool) -> void:
	controller.network.answer_pause(accepted)


func _request_rematch() -> void:
	if controller.lan != null:
		controller.lan.request_rematch()


func _rematch_status(disconnected: bool = false) -> Dictionary:
	var lan: MatchNetwork = controller.lan
	if lan == null:
		return {}
	return {
		"disconnected": disconnected or lan.peer_left,
		"can_rematch": lan.can_rematch(),
		"local_ready": lan.local_wants_rematch,
		"remote_ready": lan.remote_wants_rematch,
	}


func _show_lan_result() -> void:
	lan_result_view.show_result(result_label.text, stats, controller.lan != null, _rematch_status())


func update_lan_rematch(disconnected: bool = false) -> void:
	lan_result_view.update_rematch(_rematch_status(disconnected))


func hide_pause() -> void:
	pause_view.hide_pause()


func show_settings() -> void:
	pause_view.show_settings()


## Returns true only when this input closed the modal; pause/consent stays unchanged.
func close_settings_if_open() -> bool:
	return pause_view.close_settings_if_open()


## Applies a new sensitivity to the live camera (SessionState is updated by SettingsControls).
func _set_mouse_sensitivity(value: float) -> void:
	controller.get_node("CameraRig").mouse_sensitivity = value


func _restart_match() -> void:
	if controller.mode == &"LAN":
		controller.network.leave()
	get_tree().reload_current_scene()


## Compatibility alias for existing callers; controller uses the public intent.
func _return_to_menu() -> void:
	return_to_menu()


func return_to_menu() -> void:
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
	stamina.custom_minimum_size = Vector2(GameBalance.get_number("ui_stamina_bar_width"), GameBalance.get_number("ui_stamina_bar_height"))
	stamina.fill_mode = trail.fill_mode
	stamina.show_percentage = false
	stamina.add_theme_stylebox_override("fill", _bar_style(Color("#E8BC65")))
	stamina.add_theme_stylebox_override("background", _bar_style(Color("#1E1914B0")))
	stamina_fills.append(stamina.get_theme_stylebox("fill") as StyleBoxFlat)
	content.add_child(stamina)
	# Only shown when stamina is low, so the warning never relies on colour alone.
	var stamina_text := Label.new()
	stamina_text.add_theme_font_size_override("font_size", GameBalance.get_int("ui_stamina_warning_size"))
	stamina_text.add_theme_color_override("font_outline_color", Color("#1E1914"))
	stamina_text.add_theme_constant_override("outline_size", GameBalance.get_int("ui_stamina_warning_outline"))
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
	training_presenter.update(delta)
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
	return tutorial_presenter.enabled()


func _queue_tutorial(id: int) -> void:
	tutorial_presenter.queue_hint(id)


func _tutorial_event(event: StringName, source: int, target: int, value: float) -> void:
	tutorial_presenter.on_combat_event(event, source, target, value)


func _update_tutorial(delta: float) -> void:
	hint_visible = tutorial_presenter.update(delta)


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
