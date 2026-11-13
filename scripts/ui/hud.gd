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
var tutorial_label: Label
const CONTROLS := "WASD Đi · Chuột Nhìn · Trái Húc · Space Hổ lao · Phải Ghìm · G Gạt sừng · Esc Tạm dừng"
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
	var left := _make_player_panel("ĐỎ · 06 · GIÁP ĐÔNG", Color("#B6453B"))
	top.add_child(left)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var right := _make_player_panel("XANH · 17 · GIÁP TÂY", Color("#477B9C"), true)
	top.add_child(right)
	timer_label = Label.new()
	timer_label.position = Vector2(574, 26)
	timer_label.size = Vector2(132, 58)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 30)
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_stylebox_override("normal", _panel_style())
	root.add_child(timer_label)
	center_label = Label.new()
	center_label.size = Vector2(GameBalance.get_number("ui_countdown_label_width"), GameBalance.get_number("ui_countdown_label_height"))
	center_label.set_anchors_preset(Control.PRESET_CENTER)
	center_label.position = -center_label.size * 0.5
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 42)
	center_label.add_theme_color_override("font_color", Color("#F2E6CF"))
	center_label.add_theme_color_override("font_outline_color", Color("#241D18"))
	center_label.add_theme_constant_override("outline_size", 8)
	root.add_child(center_label)
	announcer_label = Label.new()
	announcer_label.position = Vector2(180, 548)
	announcer_label.size = Vector2(920, 88)
	announcer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	announcer_label.add_theme_font_size_override("font_size", 23)
	announcer_label.add_theme_color_override("font_color", Color("#F2E6CF"))
	announcer_label.add_theme_stylebox_override("normal", _panel_style())
	announcer_label.text = controller.announcer_text()
	announcer_label.visible = controller.announcer_active()
	root.add_child(announcer_label)
	clash_panel = Panel.new()
	clash_panel.position = Vector2(420, 530)
	clash_panel.size = Vector2(440, 116)
	clash_panel.visible = false
	root.add_child(clash_panel)
	clash_title = Label.new()
	clash_title.text = "KHÓA SỪNG"
	clash_title.position = Vector2(20, 6)
	clash_title.size = Vector2(400, 26)
	clash_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clash_title.add_theme_font_size_override("font_size", 22)
	clash_title.add_theme_color_override("font_color", Color("#E8BC65"))
	clash_panel.add_child(clash_title)
	clash_bar = ProgressBar.new()
	clash_bar.min_value = -GameBalance.get_number("lock_balance_max", 100.0)
	clash_bar.max_value = GameBalance.get_number("lock_balance_max", 100.0)
	clash_bar.show_percentage = false
	clash_bar.position = Vector2(20, 40)
	clash_bar.size = Vector2(400, 20)
	clash_bar.add_theme_stylebox_override("fill", _bar_style(Color("#E8BC65")))
	clash_panel.add_child(clash_bar)
	clash_time_label = Label.new()
	clash_time_label.position = Vector2(20, 64)
	clash_time_label.size = Vector2(400, 20)
	clash_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clash_time_label.add_theme_font_size_override("font_size", 16)
	clash_panel.add_child(clash_time_label)
	clash_hook_label = Label.new()
	clash_hook_label.position = Vector2(20, 88)
	clash_hook_label.size = Vector2(400, 18)
	clash_hook_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clash_hook_label.add_theme_font_size_override("font_size", 14)
	clash_panel.add_child(clash_hook_label)
	tutorial_label = Label.new()
	tutorial_label.position = Vector2(24, 658)
	tutorial_label.size = Vector2(1232, 42)
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_label.add_theme_font_size_override("font_size", 18)
	tutorial_label.add_theme_stylebox_override("normal", _panel_style())
	tutorial_label.text = CONTROLS
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
	# The in-match HUD is display-only: let clicks through so CameraRig can capture the mouse.
	_ignore_mouse(root)
	_build_pause_overlay(root)
	controller.combat_event.connect(_tutorial_event)


func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)


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
	_place_pause_panel(Vector2(520, 440))
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
func _place_pause_panel(panel_size: Vector2) -> void:
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -panel_size.x * 0.5
	pause_panel.offset_top = -panel_size.y * 0.5
	pause_panel.offset_right = panel_size.x * 0.5
	pause_panel.offset_bottom = panel_size.y * 0.5


func _clear_pause_actions() -> void:
	for child in pause_actions.get_children():
		pause_actions.remove_child(child)
		child.queue_free()


func _pause_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	pause_actions.add_child(button)


func show_pause() -> void:
	pause_overlay.visible = true
	_place_pause_panel(Vector2(520, 440))
	pause_title.text = "TẠM DỪNG" if controller.mode == &"SOLO" else "TRẬN LAN ĐANG TẠM DỪNG"
	pause_detail.text = "Trận solo đã dừng." if controller.mode == &"SOLO" else "Hai người chơi đã đồng ý tạm dừng."
	_clear_pause_actions()
	if controller.mode == &"LAN":
		_pause_button("GỬI YÊU CẦU TIẾP TỤC", controller.resume_from_menu)
	else:
		_pause_button("TIẾP TỤC", controller.resume_from_menu)
	_pause_button("CÀI ĐẶT", show_settings)
	_pause_button("CHƠI LẠI", _restart_match)
	_pause_button("VỀ MENU", _return_to_menu)
	pause_actions.get_child(0).grab_focus()


func show_pause_wait(requested_pause: bool) -> void:
	pause_overlay.visible = true
	_place_pause_panel(Vector2(520, 440))
	pause_title.text = "ĐANG CHỜ XÁC NHẬN"
	pause_detail.text = (
		"Yêu cầu tạm dừng đã gửi tới đối phương."
		if requested_pause
		else "Yêu cầu tiếp tục trận đã gửi tới đối phương."
	)
	_clear_pause_actions()
	_pause_button("CÀI ĐẶT", show_settings)
	_pause_button("RỜI TRẬN", _return_to_menu)


func show_pause_confirmation(peer_id: int, requested_pause: bool) -> void:
	pause_overlay.visible = true
	_place_pause_panel(Vector2(520, 380))
	pause_title.text = "YÊU CẦU TỪ NGƯỜI CHƠI %d" % peer_id
	pause_detail.text = (
		"Đối phương muốn tạm dừng trận."
		if requested_pause
		else "Đối phương muốn tiếp tục trận."
	)
	_clear_pause_actions()
	_pause_button("CHẤP NHẬN", func(): controller.network.answer_pause(true))
	_pause_button("TỪ CHỐI", func(): controller.network.answer_pause(false))


func hide_pause() -> void:
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = false


func show_settings() -> void:
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
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _make_player_panel(title: String, color: Color, mirror: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(424, 140)
	panel.add_theme_stylebox_override("panel", _panel_style())
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_size_override("font_size", 22)
	content.add_child(title_label)
	var spirit_row := Control.new()
	spirit_row.custom_minimum_size = Vector2(400, 32)
	content.add_child(spirit_row)
	var trail := ProgressBar.new()
	trail.max_value = GameBalance.get_number("spirit_max")
	trail.value = trail.max_value
	trail.show_percentage = false
	trail.fill_mode = ProgressBar.FILL_END_TO_BEGIN if mirror else ProgressBar.FILL_BEGIN_TO_END
	trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trail.add_theme_stylebox_override("fill", _bar_style(Color("#F7DDA4")))
	spirit_row.add_child(trail)
	var spirit := ProgressBar.new()
	spirit.max_value = trail.max_value
	spirit.value = spirit.max_value
	spirit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spirit.fill_mode = trail.fill_mode
	spirit.show_percentage = false
	spirit.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var spirit_fill := _bar_style(color)
	spirit_fill.border_color = Color("#F2E6CF")
	spirit_fill.set_border_width_all(1)
	spirit.add_theme_stylebox_override("fill", spirit_fill)
	spirit_row.add_child(spirit)
	var spirit_text := Label.new()
	spirit_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spirit_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spirit_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spirit_text.add_theme_font_size_override("font_size", 18)
	spirit_text.add_theme_color_override("font_outline_color", Color("#241D18"))
	spirit_text.add_theme_constant_override("outline_size", 6)
	spirit_row.add_child(spirit_text)
	var stamina_text := Label.new()
	stamina_text.add_theme_font_size_override("font_size", 16)
	stamina_text.horizontal_alignment = title_label.horizontal_alignment
	content.add_child(stamina_text)
	var stamina := ProgressBar.new()
	stamina.max_value = GameBalance.get_number("stamina_max")
	stamina.custom_minimum_size = Vector2(400, 10)
	stamina.fill_mode = trail.fill_mode
	stamina.show_percentage = false
	stamina.add_theme_stylebox_override("fill", _bar_style(Color("#E8BC65")))
	content.add_child(stamina)
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
	warning_time += delta
	_update_resources(0, controller.player, player_spirit, player_stamina)
	_update_resources(1, controller.opponent, opponent_spirit, opponent_stamina)
	timer_label.text = "%02d:%02d" % [int(controller.remaining_time) / 60, int(controller.remaining_time) % 60]
	timer_label.add_theme_color_override("font_color", Color("#FF8C76") if controller.remaining_time <= GameBalance.get_number("ui_timer_warning_s") else Color("#F2E6CF"))
	announcer_label.visible = controller.announcer_active()
	_update_center(delta)
	if controller.phase == &"COUNTDOWN":
		controls_hint_time = 0.0
	result_label.visible = controller.mode == &"LAN" and controller.result_ready
	if controller.phase == &"PLAYING":
		_update_tutorial(delta)
	elif controller.phase == &"RESULT":
		tutorial_label.visible = true
		tutorial_label.modulate.a = 1.0
		tutorial_label.text = "Kết quả đã khóa · bấm Esc để thả chuột"
	_update_clash()


func _update_center(delta: float) -> void:
	var elapsed := 0.0 if controller.paused else delta
	if previous_phase == &"COUNTDOWN" and controller.phase == &"PLAYING":
		fight_banner_time = 0.0
	elif controller.phase == &"PLAYING":
		fight_banner_time += elapsed
	previous_phase = controller.phase
	var text := ""
	var color := Color("#F2E6CF")
	var font_size := 42
	var banner_hold := GameBalance.get_number("ui_fight_banner_s")
	var banner_fade := GameBalance.get_number("ui_fight_banner_fade_s")
	if controller.phase == &"COUNTDOWN":
		text = str(ceili(controller.countdown_time))
	elif controller.outro.is_revealing_lot():
		text = "BỐC THĂM" + ".".repeat(1 + int(controller.outro.time * 4.0) % 3)
	elif controller.phase == &"PLAYING" and fight_banner_time < banner_hold + banner_fade:
		text = "VÀO TRẬN!"
		color = Color("#E8BC65")
	if text != center_label.text:
		center_punch_time = 0.0
	else:
		center_punch_time += elapsed
	center_label.text = text
	center_label.scale = Vector2.ONE
	center_label.modulate.a = 1.0
	if controller.phase == &"COUNTDOWN" or text == "VÀO TRẬN!":
		font_size = GameBalance.get_int("ui_countdown_font_size")
		var duration := GameBalance.get_number("ui_countdown_punch_s")
		var punch_scale := GameBalance.get_number("ui_countdown_punch_scale")
		center_label.scale = Vector2.ONE * Tween.interpolate_value(punch_scale, 1.0 - punch_scale, minf(center_punch_time, duration), duration, Tween.TRANS_QUAD, Tween.EASE_OUT)
		if text == "VÀO TRẬN!" and fight_banner_time > banner_hold:
			center_label.modulate.a = 1.0 - (fight_banner_time - banner_hold) / banner_fade
	center_label.add_theme_font_size_override("font_size", font_size)
	center_label.add_theme_color_override("font_color", color)
	center_label.pivot_offset = center_label.size * 0.5


func _update_resources(index: int, actor: Buffalo, spirit: ProgressBar, stamina: ProgressBar) -> void:
	var previous := spirit.value
	spirit.value = actor.spirit
	stamina.value = actor.stamina
	spirit_labels[index].text = "KHÍ THẾ  %d / %d" % [roundi(spirit.value), roundi(spirit.max_value)]
	if spirit.value != previous:
		if spirit_tweens[index] != null:
			spirit_tweens[index].kill()
		if spirit.value < previous:
			spirit_tweens[index] = create_tween()
			spirit_tweens[index].tween_property(spirit_trails[index], "value", spirit.value, GameBalance.get_number("ui_spirit_trail_s"))
		else:
			spirit_trails[index].value = spirit.value
	low_stamina[index] = stamina.value < GameBalance.get_number("ui_low_stamina_threshold")
	var color := Color("#FFAA66") if low_stamina[index] else Color("#E8BC65")
	var fill := stamina.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = color
	stamina_labels[index].text = "SỨC  %d / %d%s" % [roundi(stamina.value), roundi(stamina.max_value), " · SỨC THẤP" if low_stamina[index] else ""]
	stamina_labels[index].add_theme_color_override("font_color", color)
	var pulse := 0.5 + 0.5 * cos(warning_time * TAU * GameBalance.get_number("ui_low_stamina_pulse_hz"))
	stamina.modulate.a = lerpf(GameBalance.get_number("ui_low_stamina_pulse_min_alpha"), 1.0, pulse) if low_stamina[index] else 1.0


func _tutorial_enabled() -> bool:
	return controller.mode == &"SOLO" and controller.level_id == &"L01"


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
	tutorial_label.visible = true
	tutorial_label.modulate.a = 1.0
	if not _tutorial_enabled():
		tutorial_label.text = CONTROLS
		if not controller.paused:
			controls_hint_time += delta
		var duration := GameBalance.get_number("ui_controls_hint_s")
		var fade := GameBalance.get_number("ui_controls_hint_fade_s")
		tutorial_label.visible = controls_hint_time < duration
		if tutorial_label.visible and controls_hint_time > duration - fade:
			tutorial_label.modulate.a = (duration - controls_hint_time) / fade
		return
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
	tutorial_label.text = TUTORIAL[tutorial_current] if tutorial_current > 0 else CONTROLS


## Tug-of-war bar: the right half is always the local player's side.
func _update_clash() -> void:
	var clash: Dictionary = controller.active_clash
	clash_panel.visible = not clash.is_empty()
	if clash.is_empty():
		return
	var mirror := 1.0 if controller.local_slot == 1 else -1.0
	clash_bar.value = float(clash.get("lock_balance", 0.0)) * mirror
	var time_left := maxf(0.0, GameBalance.get_number("lock_max_s") - float(clash.get("time", 0.0)))
	clash_time_label.text = "ĐỐI PHƯƠNG  ←  %.1f s  →  BẠN" % time_left
	var hooking: Array[String] = []
	if controller.player.clash_hooked:
		hooking.append("ĐỎ đang móc")
	if controller.opponent.clash_hooked:
		hooking.append("XANH đang móc")
	clash_hook_label.text = " · ".join(hooking)


func show_result(winner_slot: int, reason: StringName) -> void:
	var winner := "ÔNG TRÂU ĐỎ" if winner_slot == 1 else "ÔNG TRÂU XANH"
	var reason_text: String = {
		&"FLEE": "THẮNG THẾ · ĐỐI PHƯƠNG LUI SỚI",
		&"TIME": "THẮNG THỜI GIAN · KHÍ THẾ CAO HƠN",
		&"LOT": "BỐC THĂM · LOT"
	}.get(reason, "TRẬN KẾT THÚC")
	# Shown by _process once the outro has played.
	result_label.text = "%s\n%s" % [winner, reason_text]
