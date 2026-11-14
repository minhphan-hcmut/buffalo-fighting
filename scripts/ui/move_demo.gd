class_name MoveDemo
extends HBoxContainer
## A self-contained tutorial stage: scripted poses and contact, with no match simulation.

signal tab_step_requested(direction: int)

const BUFFALO_SCENE := preload("res://scenes/buffalo.tscn")
const MOVES := [
	{"id": &"horn", "name": "Húc", "keys": "Chuột trái", "text": "Húc gần để làm đối thủ mất khí thế.", "cost": "horn_cost"},
	{"id": &"dash", "name": "Hổ lao", "keys": "Space", "text": "Lao nhanh về phía trước, đẩy lùi đối thủ.", "cost": "dash_cost"},
	{"id": &"guard", "name": "Ghìm", "keys": "Giữ chuột phải", "text": "Đỡ phía trước, giảm khí thế mất và lực đẩy; không bị choáng.", "cost": "guard_stamina_per_s"},
	{"id": &"parry", "name": "Gạt sừng", "keys": "G → Chuột trái", "text": "Gạt đúng lúc, rồi húc ngay để phản đòn.", "cost": "parry_stamina_cost"},
	{"id": &"clash", "name": "Khóa sừng", "keys": "W A S D · Đẩy   /   Trái · Móc   /   Phải · Nhả", "text": "Hai đòn chạm sừng tạo khóa; nhả đúng lúc đối thủ đang móc.", "cost": "lock_stamina_per_s"},
	{"id": &"flank", "name": "Đánh sườn / lưng", "keys": "Chuột trái", "text": "Húc vào hông hoặc sau lưng khiến đối thủ mất khí thế nhiều hơn.", "cost": "horn_cost"},
]

var selected_move: StringName = &"horn"
var elapsed := 0.0
var viewport: SubViewport
var world: Node3D
var red: Buffalo
var blue: Buffalo
var callout: Label3D
var impact: Node3D
var spark_material: StandardMaterial3D
var contact_attacker: Buffalo
var contact_victim: Buffalo
var contact_flank := false
var impact_age := 0.0
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
		button.text = MOVES[index].name
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = GameBalance.get_number("ui_howto_move_button_height")
		button.pressed.connect(select_move.bind(MOVES[index].id))
		button.gui_input.connect(_move_input.bind(index))
		move_buttons.append(button)
		list.add_child(button)
	var hint := ControlsDiagram.label("↑ ↓ Chọn đòn\n← → Đổi tab", "body")
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
	viewport.msaa_3d = Viewport.MSAA_2X
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

	impact = Node3D.new()
	impact.name = "ContactSparks"
	world.add_child(impact)
	spark_material = StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.no_depth_test = true
	var spark := BoxMesh.new()
	spark.size = Vector3(GameBalance.get_number("demo_spark_thickness"), GameBalance.get_number("demo_spark_thickness"), GameBalance.get_number("demo_spark_length"))
	spark.material = spark_material
	for index in GameBalance.get_int("demo_spark_count"):
		var ray := MeshInstance3D.new()
		ray.mesh = spark
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * index / GameBalance.get_int("demo_spark_count")
		var direction := Vector3(cos(angle), sin(angle), sin(angle)).normalized()
		ray.position = direction * GameBalance.get_number("demo_spark_radius")
		ray.basis = Basis.looking_at(direction)
		impact.add_child(ray)


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
		keys.add_child(ControlsDiagram.keycap(move.keys))
		description.text = move.text
		cost.text = "SỨC: %d" % GameBalance.get_int(move.cost)
		match id:
			&"guard":
				cost.text += "/giây khi giữ · cần ít nhất %d" % GameBalance.get_int("guard_min_stamina")
			&"parry":
				cost.text += " gạt + %d húc phản đòn" % GameBalance.get_int("horn_cost")
			&"clash":
				cost.text += "/giây đẩy · %d mỗi lần móc" % GameBalance.get_int("horn_cost")
	elapsed = 0.0
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
	var reset := GameBalance.get_number("demo_reset_at_s")
	var loop := GameBalance.get_number("demo_loop_s")
	var returning := smoothstep(reset, loop, time)
	contact_attacker = null
	contact_victim = null
	callout.text = ""
	impact.visible = false
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
		impact.visible = false


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
	impact_age = fposmod(time - hit, GameBalance.get_number("demo_spark_interval_s"))
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
	impact_age = age
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
	impact.position = contact
	var progress := clampf(impact_age / GameBalance.get_number("demo_spark_duration_s"), 0.0, 1.0)
	impact.visible = progress < 1.0
	impact.scale = Vector3.ONE * (1.0 + progress)
	spark_material.albedo_color = Color(ControlsDiagram.GOLD, 1.0 - progress)


func _pose(actor: Buffalo, state: Buffalo.State, time: float, duration: float, yaw: float) -> void:
	actor.state = state
	actor.state_time = time
	actor.state_duration = duration
	actor.rotation.y = yaw
	actor.facing = -actor.basis.z
