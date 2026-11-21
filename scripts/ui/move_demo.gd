class_name MoveDemo
extends HBoxContainer
## A self-contained tutorial stage: scripted poses and contact, with no match simulation.

signal tab_step_requested(direction: int)

const BUFFALO_SCENE := preload("res://scenes/buffalo.tscn")
const MOVES := [
	{"id": &"horn", "name": "Húc", "text": "Húc gần để làm đối thủ mất khí thế.", "cost": "horn_cost"},
	{"id": &"dash", "name": "Hổ lao", "text": "Lao nhanh về phía trước, đẩy lùi đối thủ.", "cost": "dash_cost"},
	{"id": &"guard", "name": "Ghìm", "text": "Đỡ phía trước, giảm khí thế mất và lực đẩy; không bị choáng.", "cost": "guard_stamina_per_s"},
	{"id": &"parry", "name": "Gạt sừng", "text": "Gạt đúng lúc, rồi húc ngay để phản đòn.", "cost": "parry_stamina_cost"},
	{"id": &"clash", "name": "Khóa sừng", "text": "Hai đòn đối đầu tạo khóa. Đẩy về đối thủ; nhả khi họ móc, nhả sai lúc mất khí thế.", "cost": "lock_stamina_per_s"},
	{"id": &"flank", "name": "Đánh sườn / lưng", "text": "Húc vào hông hoặc sau lưng khiến đối thủ mất khí thế nhiều hơn.", "cost": "horn_cost"},
]


## Key hint for a move from the current bindings ("G → Chuột trái" by default).
static func keys_for(id: StringName) -> String:
	match id:
		&"dash": return KeyBindings.label("dash")
		&"guard": return Language.t("Giữ ") + KeyBindings.inline_label("guard")
		&"parry": return "%s → %s" % [KeyBindings.label("parry"), KeyBindings.label("horn")]
		&"clash": return Language.t("%s Đẩy tới · %s Móc · %s Nhả") % [KeyBindings.move_label(), KeyBindings.short_label("horn"), KeyBindings.short_label("guard")]
	return KeyBindings.label("horn")


var selected_move: StringName = &"horn"
var elapsed := 0.0
var viewport: SubViewport
var world: Node3D
var red: Buffalo
var blue: Buffalo
var callout: Label3D
var vfx: MatchVFX
var player: Buffalo:
	get: return red
var opponent: Buffalo:
	get: return blue
var paused := false
var phase: StringName = &"PLAYING"
var finished := false
var active_clash: Dictionary = {}
var sampled_time := -1.0
var fired_events: Dictionary = {}
var contact_attacker: Buffalo
var contact_victim: Buffalo
var contact_flank := false
var move_buttons: Array[Button] = []
var keys: HBoxContainer
var description: Label
var cost: Label


func _ready() -> void:
	name = "MoveDemo"
	# Align contact after the animators have updated their visual transforms.
	process_priority = 1
	add_theme_constant_override("separation", GameBalance.get_int("ui_howto_column_gap"))
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = GameBalance.get_number("ui_howto_move_list_width")
	list.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_key_gap"))
	add_child(list)
	var group := ButtonGroup.new()
	for index in MOVES.size():
		var button := Button.new()
		button.theme_type_variation = &"QuietButton"
		button.text = MOVES[index].name
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = GameBalance.get_number("ui_howto_move_button_height")
		button.pressed.connect(select_move.bind(MOVES[index].id))
		button.gui_input.connect(_move_input.bind(index))
		move_buttons.append(button)
		list.add_child(button)
	var hint := ControlsDiagram.label("↑ ↓ Chọn đòn\n← → Đổi tab", "body")
	list.add_child(hint)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_key_gap"))
	add_child(right)
	var frame := SubViewportContainer.new()
	frame.name = "Stage"
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size.y = GameBalance.get_number("ui_howto_demo_height")
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(frame)
	viewport = SubViewport.new()
	viewport.name = "DemoViewport"
	viewport.own_world_3d = true
	GraphicsQuality.apply_viewport(viewport)
	frame.add_child(viewport)
	_build_stage()
	keys = HBoxContainer.new()
	keys.add_theme_constant_override("separation", GameBalance.get_int("ui_howto_key_gap"))
	right.add_child(keys)
	description = ControlsDiagram.label("")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(description)
	cost = ControlsDiagram.label("", "body", ControlsDiagram.GOLD)
	right.add_child(cost)
	select_move(&"horn")
	visibility_changed.connect(_sync_visibility)
	_sync_visibility()


func _build_stage() -> void:
	world = Node3D.new()
	world.name = "DemoWorld"
	viewport.add_child(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * GameBalance.get_number("demo_ground_size")
	ground.mesh = plane
	ground.material_override = load("res://assets/environment/sparse_grass/ground.tres")
	world.add_child(ground)
	ArenaBuilder.add_lighting(world)
	var camera := Camera3D.new()
	camera.fov = GameBalance.get_number("demo_camera_fov_deg")
	camera.position = Vector3(GameBalance.get_number("demo_camera_offset_x"), GameBalance.get_number("demo_camera_height"), GameBalance.get_number("demo_camera_distance"))
	world.add_child(camera)
	camera.look_at(Vector3(0.0, GameBalance.get_number("demo_camera_target_height"), 0.0))
	camera.current = true
	red = BUFFALO_SCENE.instantiate() as Buffalo
	red.name = "RedBuffalo"
	world.add_child(red)
	blue = BUFFALO_SCENE.instantiate() as Buffalo
	blue.name = "BlueBuffalo"
	blue.slot = 2
	world.add_child(blue)
	Buffalo.add_team_outline(red, ArenaBuilder.OUTLINE_RED)
	Buffalo.add_team_outline(blue, ArenaBuilder.OUTLINE_BLUE)
	for actor in [red, blue]:
		actor.collision_layer = 0
		actor.collision_mask = 0
	callout = Label3D.new()
	callout.font_size = GameBalance.get_int("demo_callout_font_size")
	callout.pixel_size = GameBalance.get_number("demo_callout_pixel_size")
	callout.modulate = ControlsDiagram.GOLD
	callout.outline_modulate = ControlsDiagram.INK
	callout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	callout.no_depth_test = true
	world.add_child(callout)

	vfx = MatchVFX.new()
	vfx.name = "DemoVFX"
	vfx.controller = self
	world.add_child(vfx)


func presentation_pinned(_actor: Buffalo) -> bool:
	return false



## Select a named move, restarting its timeline while retaining the same scene.
func select_move(id: StringName) -> void:
	for index in MOVES.size():
		var move: Dictionary = MOVES[index]
		move_buttons[index].set_pressed_no_signal(move.id == id)
		if move.id != id:
			continue
		selected_move = id
		for child in keys.get_children():
			keys.remove_child(child)
			child.queue_free()
		keys.add_child(ControlsDiagram.keycap(keys_for(move.id)))
		description.text = move.text
		cost.text = Language.t("SỨC: %d") % GameBalance.get_int(move.cost)
		match id:
			&"guard":
				cost.text += Language.t("/giây khi giữ · cần ít nhất %d") % GameBalance.get_int("guard_min_stamina")
			&"parry":
				cost.text += Language.t(" gạt + %d húc phản đòn") % GameBalance.get_int("horn_cost")
			&"clash":
				cost.text += Language.t("/giây đẩy · %d mỗi lần móc") % GameBalance.get_int("horn_cost")
	elapsed = 0.0
	sampled_time = -1.0
	fired_events.clear()
	vfx.reset()
	sample_time(elapsed)
	for actor in [red, blue]:
		(actor.visual as BuffaloAnimator).reset_motion()


func _move_input(event: InputEvent, index: int) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		var next := wrapi(index + (1 if event.is_action_pressed("ui_down") else -1), 0, MOVES.size())
		select_move(MOVES[next].id)
		move_buttons[next].grab_focus()
		accept_event()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		tab_step_requested.emit(1 if event.is_action_pressed("ui_right") else -1)
		accept_event()


## Suspend the viewport, timeline and animators together when the tab is hidden.
func set_active(active: bool) -> void:
	paused = not active
	vfx.set_paused(paused)
	set_process(active)
	set_physics_process(active)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if active else SubViewport.UPDATE_DISABLED
	world.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _sync_visibility() -> void:
	set_active(is_visible_in_tree())


func _physics_process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, GameBalance.get_number("demo_loop_s"))
	sample_time(elapsed)


func _process(_delta: float) -> void:
	_align_contact()


## Sample the selected presentation timeline; also used by deterministic QA captures.
func sample_time(time: float) -> void:
	if time < sampled_time:
		vfx.reset()
		fired_events.clear()
	sampled_time = time
	var reset := GameBalance.get_number("demo_reset_at_s")
	var loop := GameBalance.get_number("demo_loop_s")
	var returning := smoothstep(reset, loop, time)
	contact_attacker = null
	contact_victim = null
	callout.text = ""
	_approach(minf(time, reset))
	call("_sample_%s" % selected_move, minf(time, reset))
	_align_contact()
	if returning > 0.0:
		var start := GameBalance.get_number("demo_start_half_gap")
		red.position = red.position.lerp(Vector3(-start, 0.0, 0.0), returning)
		blue.position = blue.position.lerp(Vector3(start, 0.0, 0.0), returning)
		red.state = Buffalo.State.NORMAL
		blue.state = Buffalo.State.NORMAL
		contact_attacker = null
		callout.text = ""

	_timeline_events(time)


func _timeline_events(time: float) -> void:
	var windup := GameBalance.get_number("demo_windup_at_s")
	var hit := GameBalance.get_number("demo_hit_at_s")
	var counter := GameBalance.get_number("demo_counter_at_s")
	active_clash = {"demo": true} if selected_move == &"clash" and time >= hit and time < GameBalance.get_number("demo_clash_release_at_s") else {}
	match selected_move:
		&"horn", &"flank":
			_event_at(time, windup, &"HORN_START", 1, 2)
			_event_at(time, hit, &"HORN_HIT", 1, 2)
			if selected_move == &"flank":
				_event_at(time, hit, &"FLANK_HIT", 1, 2)
		&"dash":
			_event_at(time, windup, &"DASH_START", 1, 2)
			_event_at(time, hit, &"DASH_HIT", 1, 2)
		&"guard":
			_event_at(time, windup, &"HORN_START", 2, 1)
			_event_at(time, hit, &"GUARD_HIT", 2, 1)
		&"parry":
			_event_at(time, windup - GameBalance.get_number("demo_parry_attack_lead_s"), &"HORN_START", 2, 1)
			_event_at(time, hit, &"PARRY_SUCCESS", 1, 2)
			_event_at(time, counter, &"COUNTER_START", 1, 2)
			_event_at(time, counter, &"COUNTER_HIT", 1, 2)
		&"clash":
			_event_at(time, windup, &"HORN_START", 1, 2)
			_event_at(time, windup, &"HORN_START", 2, 1)
			_event_at(time, hit, &"CLASH_START", 1, 2)
			_event_at(time, counter, &"CLASH_HOOK", 2, 1)


func _event_at(time: float, at: float, event: StringName, source: int, target: int) -> void:
	var id := "%s:%d" % [event, source]
	if time >= at and not fired_events.has(id):
		fired_events[id] = true
		# Emphasize the tutorial's flank bonus while preserving the match's existing strength.
		vfx.on_combat_event(event, source, target, selected_move == &"flank")


func _approach(time: float) -> void:
	var start := GameBalance.get_number("demo_start_half_gap")
	var gap := lerpf(start, GameBalance.get_number("demo_contact_half_gap"), smoothstep(0.0, GameBalance.get_number("demo_windup_at_s"), time))
	red.position = Vector3(-gap, 0.0, 0.0)
	blue.position = Vector3(gap, 0.0, 0.0)
	_pose(red, Buffalo.State.NORMAL, time, GameBalance.get_number("demo_loop_s"), -PI * 0.5)
	_pose(blue, Buffalo.State.NORMAL, time, GameBalance.get_number("demo_loop_s"), PI * 0.5)


func _sample_horn(time: float) -> void:
	_horn_pose(red, time)
	if time >= GameBalance.get_number("demo_hit_at_s"):
		_hit(red, blue, time - GameBalance.get_number("demo_hit_at_s"), "TRÚNG ĐÒN")


func _sample_dash(time: float) -> void:
	var windup := GameBalance.get_number("demo_windup_at_s")
	if time < windup:
		red.position.x = -GameBalance.get_number("demo_start_half_gap")
		return
	var hit := GameBalance.get_number("demo_hit_at_s")
	red.position.x = lerpf(-GameBalance.get_number("demo_start_half_gap"), -GameBalance.get_number("demo_contact_half_gap"), smoothstep(windup, hit, time))
	_pose(red, Buffalo.State.DASH_ACTIVE if time < GameBalance.get_number("demo_recover_at_s") else Buffalo.State.DASH_RECOVERY, time - windup, GameBalance.get_number("demo_reset_at_s") - windup, red.rotation.y)
	if time >= hit:
		_hit(red, blue, time - hit, "HỔ LAO!")


func _sample_guard(time: float) -> void:
	_pose(red, Buffalo.State.GUARD, time, GameBalance.get_number("demo_reset_at_s"), red.rotation.y)
	_horn_pose(blue, time)
	if time >= GameBalance.get_number("demo_hit_at_s"):
		_hit(blue, red, time - GameBalance.get_number("demo_hit_at_s"), "ĐỠ ĐƯỢC", GameBalance.get_number("demo_guard_recoil_ratio"), false)


func _sample_parry(time: float) -> void:
	var hit := GameBalance.get_number("demo_hit_at_s")
	var counter := GameBalance.get_number("demo_counter_at_s")
	if time < hit:
		_pose(red, Buffalo.State.PARRY_ACTIVE, time, hit, red.rotation.y)
		_horn_pose(blue, time + GameBalance.get_number("demo_parry_attack_lead_s"))
	elif time < counter:
		_pose(red, Buffalo.State.GUARD, time - hit, counter - hit, red.rotation.y)
		_hit(red, blue, time - hit, "GẠT SỪNG!", GameBalance.get_number("demo_guard_recoil_ratio"))
	else:
		_horn_pose(red, time - counter + hit)
		_hit(red, blue, time - counter, "PHẢN ĐÒN!")


func _sample_clash(time: float) -> void:
	var hit := GameBalance.get_number("demo_hit_at_s")
	if time < hit:
		_horn_pose(red, time)
		_horn_pose(blue, time)
		return
	var reset := GameBalance.get_number("demo_reset_at_s")
	var push := GameBalance.get_number("demo_clash_push_distance") * smoothstep(hit, reset, time)
	red.position.x += push
	blue.position.x += push
	for actor in [red, blue]:
		_pose(actor, Buffalo.State.CLASH, time - hit, reset - hit, actor.rotation.y)
	contact_attacker = red
	contact_victim = blue
	contact_flank = false
	callout.text = "ĐẨY" if time < GameBalance.get_number("demo_counter_at_s") else "MÓC → NHẢ"
	var release := GameBalance.get_number("demo_clash_release_at_s")
	if time >= release:
		_hit(red, blue, time - release, "NHẢ ĐÚNG LÚC!")


func _sample_flank(time: float) -> void:
	_pose(blue, Buffalo.State.NORMAL, time, GameBalance.get_number("demo_loop_s"), 0.0)
	blue.position.x = lerpf(GameBalance.get_number("demo_start_half_gap"), GameBalance.get_number("demo_flank_target_x"), smoothstep(0.0, GameBalance.get_number("demo_windup_at_s"), time))
	_horn_pose(red, time)
	if time >= GameBalance.get_number("demo_hit_at_s"):
		_hit(red, blue, time - GameBalance.get_number("demo_hit_at_s"), "SƯỜN +", 1.0, true, true)


func _horn_pose(actor: Buffalo, time: float) -> void:
	var windup := GameBalance.get_number("demo_windup_at_s")
	if time < windup:
		return
	var hit := GameBalance.get_number("demo_hit_at_s")
	var recover := GameBalance.get_number("demo_recover_at_s")
	var start := windup if time < hit else (hit if time < recover else recover)
	var end := hit if time < hit else (recover if time < recover else GameBalance.get_number("demo_reset_at_s"))
	var state := Buffalo.State.HORN_STARTUP if time < hit else (Buffalo.State.HORN_ACTIVE if time < recover else Buffalo.State.HORN_RECOVERY)
	_pose(actor, state, time - start, end - start, actor.rotation.y)


func _hit(attacker: Buffalo, victim: Buffalo, age: float, word: String, strength := 1.0, stun := true, flank := false) -> void:
	# Move the pair together during recoil so the contact does not open into a gap.
	var recoil := attacker.facing * GameBalance.get_number("demo_recoil_distance") * strength * smoothstep(0.0, GameBalance.get_number("demo_recoil_s"), age)
	attacker.position += recoil
	victim.position += recoil
	if stun:
		_pose(victim, Buffalo.State.STUNNED, age, GameBalance.get_number("demo_reset_at_s") - GameBalance.get_number("demo_hit_at_s"), victim.rotation.y)
	contact_attacker = attacker
	contact_victim = victim
	contact_flank = flank
	callout.text = word


func _align_contact() -> void:
	if contact_attacker == null:
		return
	var head := Vector3(0.0, GameBalance.get_number("demo_contact_head_height"), -GameBalance.get_number("demo_contact_head_forward"))
	var target := Vector3(-GameBalance.get_number("demo_contact_flank_width"), GameBalance.get_number("demo_contact_head_height"), GameBalance.get_number("demo_contact_flank_z")) if contact_flank else head
	var at := contact_attacker.visual.to_global(head)
	var to := contact_victim.visual.to_global(target)
	# Keep the hooves on the ground; the head surfaces have vertical thickness.
	contact_attacker.position += Vector3(to.x - at.x, 0.0, to.z - at.z)
	var contact := contact_attacker.visual.to_global(head).lerp(to, 0.5)
	callout.position = contact + Vector3.UP * GameBalance.get_number("demo_callout_height")


func _pose(actor: Buffalo, state: Buffalo.State, time: float, duration: float, yaw: float) -> void:
	actor.state = state
	actor.state_time = time
	actor.state_duration = duration
	actor.rotation.y = yaw
	actor.facing = -actor.basis.z
