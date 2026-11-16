class_name MatchReplay
extends Node3D
## A bounded presentation recording. Playback animates separate, non-colliding buffaloes;
## the finished match, its actors and its statistics are never rewound.

signal completed

const MOTION_FIELDS := [
	"speed", "local_velocity", "forward_speed", "forward_accel", "turn_rate", "gait_phase",
	"time", "pose_offset", "pose_pitch", "pose_roll", "pose_yaw", "ear_back", "tail_lift",
	"victory_weight", "defeat_weight", "ear_flick_time", "ear_flick_side", "next_ear_flick",
	"clash_gait_weight"
]

var controller: MatchController
var samples: Array[Dictionary] = []
var write_index := 0
var sample_count := 0
var clock := 0.0
var active := false
var elapsed := 0.0
var cursor := 0.0
var frame_index := 0
var clip: Array[Dictionary] = []
var actors: Array[Buffalo] = []
var context: MatchController
var camera: Camera3D
var tag: CanvasLayer
var saved_visibility: Array[bool] = []
var rig_process_mode: ProcessMode
var vfx_visible := true
var side_direction := Vector3.BACK
var hud_visible := true


func _ready() -> void:
	controller = get_parent() as MatchController
	process_physics_priority = 20
	samples.resize(ceili(GameBalance.get_number("replay_seconds") * Engine.physics_ticks_per_second) + 1)


func eligible() -> bool:
	return controller.mode == &"SOLO" and controller.training.is_empty() and SessionState.replay_enabled


func _physics_process(delta: float) -> void:
	if not eligible():
		sample_count = 0
		write_index = 0
		clock = 0.0
		return
	if controller.phase == &"PLAYING" and not controller.paused:
		capture(delta)


func capture(delta: float) -> void:
	clock += delta
	var recorded: Array[Dictionary] = []
	for actor: Buffalo in [controller.player, controller.opponent]:
		var animator := actor.visual as BuffaloAnimator
		var motion := {}
		for field: String in MOTION_FIELDS:
			motion[field] = animator.get(field)
		recorded.append({"transform": actor.global_transform, "state": actor.state,
			"state_time": actor.state_time, "state_duration": actor.state_duration,
			"motion": motion, "rng": animator.rng.state})
	var clash := controller.active_clash
	samples[write_index] = {"time": clock, "actors": recorded, "hitstop": controller.hitstop_ticks > 0,
		"clash": not clash.is_empty(), "balance": float(clash.get("lock_balance", 0.0)),
		"clash_a": (clash.a as Buffalo).slot if not clash.is_empty() else 1}
	write_index = (write_index + 1) % samples.size()
	sample_count = mini(sample_count + 1, samples.size())


func history() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in sample_count:
		var frame := samples[posmod(write_index - sample_count + index, samples.size())]
		if frame.time >= clock - GameBalance.get_number("replay_seconds"):
			result.append(frame)
	return result


func start() -> bool:
	if not eligible() or controller.end_reason != &"FLEE" or active:
		return false
	clip = history()
	if clip.size() < 2 or clip[-1].time <= clip[0].time:
		return false
	active = true
	elapsed = 0.0
	cursor = clip[0].time
	frame_index = 0
	var first_separation: Vector3 = clip[0].actors[1].transform.origin - clip[0].actors[0].transform.origin
	first_separation.y = 0.0
	side_direction = first_separation.normalized().cross(Vector3.UP) if first_separation.length_squared() > 0.0 else Vector3.BACK
	# A detached read-only animation context avoids exposing the locked result to the clones.
	# It never enters the scene tree, starts a simulation, or sends events.
	context = MatchController.new()
	for index in 2:
		var real: Buffalo = [controller.player, controller.opponent][index]
		var actor := MatchController.BUFFALO.instantiate() as Buffalo
		actor.slot = real.slot
		add_child(actor)
		actor.collision_layer = 0
		actor.collision_mask = 0
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		Buffalo.add_team_outline(actor, ArenaBuilder.OUTLINE_RED if index == 0 else ArenaBuilder.OUTLINE_BLUE)
		actors.append(actor)
		actor.global_transform = clip[0].actors[index].transform
		var animator := actor.visual as BuffaloAnimator
		animator.controller = context
		animator.reset_motion()
		for field: String in MOTION_FIELDS:
			animator.set(field, clip[0].actors[index].motion[field])
		animator.rng.state = clip[0].actors[index].rng
		saved_visibility.append(real.visible)
		real.hide()
	context.player = actors[0]
	context.opponent = actors[1]
	vfx_visible = controller.vfx.visible
	controller.vfx.hide()
	hud_visible = controller.hud.visible
	controller.hud.hide()
	var rig := controller.get_node("CameraRig") as Node3D
	rig_process_mode = rig.process_mode
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	camera.fov = GameBalance.get_number("replay_camera_fov_deg")
	add_child(camera)
	camera.make_current()
	tag = CanvasLayer.new()
	add_child(tag)
	var label := Label.new()
	label.text = "XEM LẠI"
	label.position = Vector2.ONE * GameBalance.get_number("replay_tag_margin")
	label.add_theme_font_size_override("font_size", GameBalance.get_int("replay_tag_font_size"))
	label.add_theme_color_override("font_color", ControlsDiagram.GOLD)
	label.add_theme_color_override("font_outline_color", ControlsDiagram.INK)
	label.add_theme_constant_override("outline_size", GameBalance.get_int("screenshot_toast_outline"))
	tag.add_child(label)
	_apply_frame(0.0)
	return true


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	var recorded_delta := delta * GameBalance.get_number("replay_speed")
	cursor = minf(cursor + recorded_delta, clip[-1].time)
	_apply_frame(recorded_delta)
	if cursor >= clip[-1].time:
		finish()


func _apply_frame(delta: float) -> void:
	while frame_index + 1 < clip.size() and clip[frame_index + 1].time <= cursor:
		frame_index += 1
	var frame := clip[frame_index]
	var next := clip[mini(frame_index + 1, clip.size() - 1)]
	var weight := inverse_lerp(frame.time, next.time, cursor) if next.time > frame.time else 0.0
	context.active_clash = {"a": actors[int(frame.clash_a) - 1], "lock_balance": frame.balance} if frame.clash else {}
	for index in 2:
		var from: Dictionary = frame.actors[index]
		var to: Dictionary = next.actors[index]
		var actor := actors[index]
		actor.global_transform = (from.transform as Transform3D).interpolate_with(to.transform, weight)
		actor.state = from.state
		actor.state_duration = from.state_duration
		actor.state_time = lerpf(from.state_time, to.state_time, weight) if from.state == to.state else from.state_time
		if not frame.hitstop:
			var animator := actor.visual as BuffaloAnimator
			animator.sample_motion(delta)
			animator.update_pose(delta)
	var center := (actors[0].global_position + actors[1].global_position) * 0.5
	var separation := actors[1].global_position - actors[0].global_position
	separation.y = 0.0
	var distance := maxf(GameBalance.get_number("replay_camera_distance"), separation.length() * GameBalance.get_number("replay_camera_spread_scale"))
	camera.global_position = center + side_direction * distance + Vector3.UP * GameBalance.get_number("replay_camera_height")
	camera.look_at(center + Vector3.UP * GameBalance.get_number("replay_camera_target_height"))


func skip(event: InputEvent) -> bool:
	if not active or elapsed < GameBalance.get_number("result_skip_grace_s") or not MatchOutro.is_skip_press(event):
		return false
	finish()
	return true


func finish() -> void:
	if not active:
		return
	active = false
	for index in 2:
		[controller.player, controller.opponent][index].visible = saved_visibility[index]
		remove_child(actors[index])
		actors[index].queue_free()
	actors.clear()
	saved_visibility.clear()
	camera.queue_free()
	tag.queue_free()
	context.free()
	context = null
	controller.vfx.visible = vfx_visible
	controller.hud.visible = hud_visible
	var rig := controller.get_node("CameraRig")
	rig.process_mode = rig_process_mode
	rig.camera.make_current()
	completed.emit()


func _exit_tree() -> void:
	if is_instance_valid(context):
		context.free()
