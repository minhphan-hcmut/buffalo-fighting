extends Control
## Main menu (Solo, LAN, settings, quit) and the Solo flow around matches: the opening
## Phần Lễ before the first match, then a copy of this script stays on the root as
## "SoloSessionOverlay" to show the result panel, next match and the closing Phần Lễ.

const ARENA_SCENE := "res://scenes/arena.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

var menu_layout: VBoxContainer
var solo_flow: SoloFlow
var ceremony_layer: Control:
	get: return solo_flow.ceremony_layer if is_instance_valid(solo_flow) else null
var result_view: SoloResultView
var result_title: Label:
	get: return result_view.result_title if is_instance_valid(result_view) else null
var result_detail: Label:
	get: return result_view.result_detail if is_instance_valid(result_view) else null
var result_actions: VBoxContainer:
	get: return result_view.result_actions if is_instance_valid(result_view) else null
var result_panel: PanelContainer:
	get: return result_view.result_panel if is_instance_valid(result_view) else null
var result_stage: Control:
	get: return result_view.result_stage if is_instance_valid(result_view) else null
var displayed_result: String:
	get: return result_view.displayed_result if is_instance_valid(result_view) else ""
	set(value):
		if is_instance_valid(result_view): result_view.displayed_result = value
var result_tween: Tween:
	get: return result_view.result_tween if is_instance_valid(result_view) else null
	set(value):
		if is_instance_valid(result_view): result_view.result_tween = value
var menu_settings_layer: SettingsScreen
var mode_view: SoloModeView
var solo_page: Control:
	get:
		return mode_view.page if is_instance_valid(mode_view) else null
static var return_to_free_play := false
static var return_to_training := false
# The arena (buffalo model, grass textures) loads on a thread while the menu and the rites
# are on screen, so entering a match no longer freezes for ~1.5 s. Kept for retries.
static var _arena_scene: PackedScene


func _ready() -> void:
	MatchInput.configure_ui()
	_build_solo_flow()
	if get_meta("session_overlay", false):
		process_mode = Node.PROCESS_MODE_ALWAYS
		_build_session_overlay()
		return
	# The saved FPS limit, render scale and model detail apply from the menu on, not only in a match.
	GraphicsQuality.apply_live()
	(get_node("/root/GameAudio") as FestivalAudio).play_music("music_festival_loop", true)
	_prefetch_arena()
	_build_main_menu()
	if return_to_training:
		return_to_training = false
		_show_training()
	elif return_to_free_play:
		return_to_free_play = false
		_show_free_play()


func _process(_delta: float) -> void:
	if not get_meta("session_overlay", false):
		return
	var scene := get_tree().current_scene
	if not scene is MatchController:
		hide()
		return
	var is_solo_result: bool = SessionState.mode == &"SOLO" and scene.get("phase") == &"RESULT" and scene.get("result_ready")
	visible = is_solo_result
	scene.hud.visible = not is_solo_result and (scene.replay == null or not scene.replay.active)
	if is_solo_result:
		var result_key := "%s:%s:%s" % [
			SessionState.last_match_level,
			SessionState.last_winner,
			SessionState.last_reason
		]
		if result_key != displayed_result:
			_show_result(result_key)


func _build_main_menu() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	menu_layout = VBoxContainer.new()
	menu_layout.anchor_top = 0.5
	menu_layout.anchor_bottom = 0.5
	menu_layout.offset_left = GameBalance.get_number("ui_menu_left")
	menu_layout.offset_right = menu_layout.offset_left + GameBalance.get_number("ui_menu_width")
	menu_layout.offset_top = -GameBalance.get_number("ui_menu_half_height")
	menu_layout.offset_bottom = GameBalance.get_number("ui_menu_half_height")
	menu_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_layout.add_theme_constant_override("separation", GameBalance.get_int("ui_menu_gap"))
	add_child(menu_layout)
	var title := _make_label("CHỌI TRÂU", 72, Color("#E8BC65"))
	title.add_theme_color_override("font_outline_color", Color("#241D18"))
	title.add_theme_constant_override("outline_size", 10)
	menu_layout.add_child(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var subtitle := _make_label("ĐẤU TRƯỜNG LỄ HỘI", 24, Color("#F2E6CF"))
	menu_layout.add_child(subtitle)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var solo := _button("SOLO · MÙA HỘI")
	solo.theme_type_variation = &"MenuPrimary"
	solo.name = "SoloButton"
	solo.pressed.connect(_show_solo_chooser)
	menu_layout.add_child(solo)
	var lan := _button("LAN")
	lan.pressed.connect(_start_lan)
	menu_layout.add_child(lan)
	var howto := _button("CÁCH CHƠI")
	howto.name = "HowToPlayButton"
	howto.pressed.connect(_show_how_to_play)
	menu_layout.add_child(howto)
	var settings := _button("CÀI ĐẶT")
	settings.name = "SettingsButton"
	settings.pressed.connect(_show_settings)
	menu_layout.add_child(settings)
	var quit := _button("THOÁT")
	quit.pressed.connect(func(): get_tree().quit())
	menu_layout.add_child(quit)
	for item in [solo, lan, howto, settings, quit]:
		item.theme_type_variation = &"MenuPrimary" if item == solo else &"MenuSecondary"
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.set_meta("menu_item", true)
	quit.theme_type_variation = &"QuietButton"
	var footer := _make_label("Mùa hội: Vòng loại · Vòng hai · Tứ kết · Bán kết · Chung kết", GameBalance.get_int("ui_menu_footer_size"), SettingsControls.MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu_layout.add_child(footer)
	solo.grab_focus()


## The festival arena in 3D (MenuBackdrop) behind the menu, darkened on the left so the
## menu column stays readable.
func _build_backdrop() -> void:
	var container := SubViewportContainer.new()
	container.name = "Backdrop"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	GraphicsQuality.apply_viewport(viewport)
	container.add_child(viewport)
	var backdrop := MenuBackdrop.new()
	backdrop.name = "MenuBackdrop"
	viewport.add_child(backdrop)
	add_child(_make_left_shade())


## Full-screen shade, dark on the left fading to clear past the middle: keeps a left
## column of text readable over a 3D scene (menu backdrop, Solo result winner shot).
func _make_left_shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 0.62])
	gradient.colors = PackedColorArray([Color("#17120EE6"), Color("#17120EB0"), Color("#17120E00")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	var shade := TextureRect.new()
	shade.name = "LeftShade"
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade


func _show_settings() -> void:
	if not is_instance_valid(menu_settings_layer):
		menu_settings_layer = SettingsScreen.new()
		menu_settings_layer.closed.connect(func(): menu_layout.show())
		add_child(menu_settings_layer)
	menu_layout.hide()
	menu_settings_layer.open(menu_layout.get_node("SettingsButton"))


func _show_how_to_play() -> void:
	if get_node_or_null("HowToPlay") != null:
		return
	menu_layout.hide()
	var howto := HowToPlay.new()
	howto.closed.connect(func():
		menu_layout.show()
		menu_layout.get_node("HowToPlayButton").grab_focus()
	)
	add_child(howto)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_instance_valid(menu_settings_layer) and menu_settings_layer.visible:
		menu_settings_layer.close()
	elif is_instance_valid(solo_page):
		(solo_page.find_child("SoloBack", true, false) as Button).pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, tier: StringName = &"SecondaryButton") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = tier
	button.custom_minimum_size = Vector2(GameBalance.get_number("ui_action_width"), GameBalance.get_number("ui_action_height"))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	UiMotion.attach(button)
	return button


func _build_solo_flow() -> void:
	solo_flow = SoloFlow.new()
	solo_flow.name = "SoloFlow"
	add_child(solo_flow)
	solo_flow.setup(self, _enter_arena, _go_to_arena, _prepare_solo_entry, _hide_result, _leave_solo, _request_free_play_return)


func _prepare_solo_entry() -> void:
	_close_solo_page()
	if is_instance_valid(menu_layout):
		menu_layout.hide()


func _hide_result() -> void:
	result_panel.hide()


func _request_free_play_return() -> void:
	return_to_free_play = true


func _leave_solo() -> void:
	displayed_result = ""
	hide()
	UiMotion.change_scene(get_tree(), load(MENU_SCENE))


func _start_solo() -> void:
	solo_flow.start_season()


func _close_solo_page() -> void:
	if is_instance_valid(mode_view):
		mode_view.close()


func _ensure_mode_view() -> void:
	if is_instance_valid(mode_view):
		return
	mode_view = SoloModeView.new()
	mode_view.name = "SoloModeView"
	add_child(mode_view)
	mode_view.setup(solo_flow.start_season, solo_flow.select_free_play, solo_flow.select_training, solo_flow.set_unlimited_stamina, _back_to_main)


func _select_free_play(level: StringName) -> void:
	solo_flow.select_free_play(level)


func _select_training(drill: StringName) -> void:
	solo_flow.select_training(drill)


func _set_unlimited_stamina(enabled: bool) -> void:
	solo_flow.set_unlimited_stamina(enabled)


func _back_to_main() -> void:
	_close_solo_page()
	menu_layout.show()
	menu_layout.get_node("SoloButton").grab_focus()


func _show_solo_chooser() -> void:
	_ensure_mode_view()
	menu_layout.hide()
	mode_view.show_chooser()


func _show_free_play() -> void:
	_ensure_mode_view()
	menu_layout.hide()
	mode_view.show_free_play()


func _show_training() -> void:
	_ensure_mode_view()
	menu_layout.hide()
	mode_view.show_training()


## Plays the Phần Lễ screens in `rites` one after another, then calls `done`.
func _play_rites(rites: Array[StringName], done: Callable) -> void:
	solo_flow.play_rites(rites, done)


func _enter_arena() -> void:
	solo_flow.clear_rite()
	if is_instance_valid(menu_layout):
		menu_layout.hide()
	_ensure_session_overlay()
	_go_to_arena()


static func _prefetch_arena() -> void:
	if _arena_scene == null and ResourceLoader.load_threaded_get_status(ARENA_SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(ARENA_SCENE)
	var tree := Engine.get_main_loop() as SceneTree
	if _arena_scene == null and not tree.process_frame.is_connected(_finish_prefetch):
		tree.process_frame.connect(_finish_prefetch)


## Collect the request even when the menu leaves for LAN; no coroutine owns a freed menu.
static func _finish_prefetch() -> void:
	var status := ResourceLoader.load_threaded_get_status(ARENA_SCENE)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_arena_scene = ResourceLoader.load_threaded_get(ARENA_SCENE)
	(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_finish_prefetch)


func _go_to_arena() -> void:
	if _arena_scene == null:
		var requested := ResourceLoader.load_threaded_get_status(ARENA_SCENE) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		# load_threaded_get() waits for a load still in flight.
		_arena_scene = ResourceLoader.load_threaded_get(ARENA_SCENE) if requested else load(ARENA_SCENE)
	UiMotion.change_scene(get_tree(), _arena_scene)


func _ensure_session_overlay() -> void:
	var root := get_tree().root
	var overlay := root.get_node_or_null("SoloSessionOverlay")
	if overlay != null:
		return
	overlay = Control.new()
	overlay.name = "SoloSessionOverlay"
	overlay.set_script(get_script())
	overlay.set_meta("session_overlay", true)
	root.add_child(overlay)


func _build_session_overlay() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	hide()
	result_view = SoloResultView.new()
	result_view.name = "SoloResultView"
	add_child(result_view)
	result_view.setup(solo_flow.retry, solo_flow.next_match, solo_flow.return_to_menu, solo_flow.change_free_play_match, solo_flow.closing, solo_flow.result_data, solo_flow.select_card)
	result_view.show()
	result_view.card_visible.connect(solo_flow.card_visible)


func _show_result(result_key: String) -> void:
	result_view._show_result(result_key)


func _show_culture_card(final_win: bool) -> void:
	result_view._show_culture_card(final_win)


func _fade_culture_card() -> void:
	result_view._fade_culture_card()


func _show_closing_ceremony(done: Callable) -> void:
	solo_flow.closing(done)


func _round_name(level: StringName) -> String:
	var levels := DataFile.load_json("res://data/levels.json")
	return String(levels.get(String(level), {}).get("title", "Mùa hội")).to_upper()


func _retry_match() -> void:
	solo_flow.retry()


func _start_next_match() -> void:
	solo_flow.next_match()


func _return_to_menu() -> void:
	solo_flow.return_to_menu()


func _change_free_play_match() -> void:
	solo_flow.change_free_play_match()


func _start_lan() -> void:
	SessionState.mode = &"LAN"
	SessionState.level_id = &"LAN01"
	get_tree().change_scene_to_file(LOBBY_SCENE)
