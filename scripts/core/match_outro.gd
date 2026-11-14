class_name MatchOutro
extends RefCounted
## RESULT presentation (GDD 2.5, SHOULD): after a LOT the draw is shown first; then the loser turns
## and walks out through the nearest gate while the winner turns to the crowd, and the camera rises
## to a high view of the arena. In SOLO the loser's own handler first runs in from the gate and
## leads it out on a rope; in LAN the loser walks out alone. Visual only: the result is already decided. The host and a LAN
## client each run it from the final positions, so nothing extra goes over the network.

var controller: MatchController
var time := 0.0
var running := false
var winner: Buffalo
var loser: Buffalo
var handler: Node3D
var rope: LeadRope
## SOLO handler stage: NONE (LAN, or gone), APPROACH (running in; the loser waits), LEAD.
var lead := Lead.NONE
## Handler's remaining route in from the gate, before it heads for the loser's head.
var handler_path: Array[Vector3] = []
## Loser's planar speed this tick, which paces the handler's walk clip.
var loser_speed := 0.0

enum Lead { NONE, APPROACH, LEAD }
## Remaining points of the loser's path, ending outside the gate.
var waypoints: Array[Vector3] = []


func _init(owner: MatchController) -> void:
	controller = owner


func start() -> void:
	if running:
		return
	time = 0.0
	waypoints.clear()
	lead = Lead.NONE
	if controller.winner_slot != 1 and controller.winner_slot != 2:
		return
	running = true
	winner = controller.player if controller.winner_slot == 1 else controller.opponent
	loser = controller.opponent if winner == controller.player else controller.player
	loser.mark_flee()
	winner.freeze()
	waypoints = exit_path(loser.global_position, winner.global_position, loser.slot)
	if controller.mode == &"SOLO":
		handler = ArenaBuilder.add_handler(controller, waypoints[-1], ReleaseHandlers.SHIRTS[loser.slot - 1])
		# In along the loser's exit route, reversed: corridor, gate, any detour, then the loser.
		handler_path = waypoints.duplicate()
		handler_path.reverse()
		handler_path.remove_at(0)
		lead = Lead.APPROACH
		if rope == null or not is_instance_valid(rope):
			rope = LeadRope.new()
			controller.add_child(rope)
		rope.hide()
	var camera := controller.get_node_or_null("CameraRig")
	if camera != null:
		camera.show_overview()


## True once the draw (if any) and the outro have played; the result screen waits for this.
func is_done() -> bool:
	if not running:
		return true
	var elapsed := time - reveal_duration()
	if controller.mode == &"SOLO":
		return elapsed >= GameBalance.get_number("result_outro_max_s", 16.0) or (elapsed >= GameBalance.get_number("result_outro_s", 4.0) and (waypoints.is_empty() or not is_instance_valid(loser) or not loser.visible))
	return elapsed >= GameBalance.get_number("result_outro_s", 4.0)


## True while a LOT result is still being drawn: nobody moves and the winner is not shown yet.
func is_revealing_lot() -> bool:
	return running and time < reveal_duration()


func reveal_duration() -> float:
	return GameBalance.get_number("result_lot_reveal_s", 1.5) if controller.end_reason == &"LOT" else 0.0


func process(delta: float) -> void:
	if not running:
		return
	time += delta
	if is_revealing_lot():
		return
	if controller.mode == &"SOLO" and time - reveal_duration() >= GameBalance.get_number("result_outro_max_s", 16.0):
		waypoints.clear()
	if lead == Lead.APPROACH and not waypoints.is_empty():
		_approach_handler(delta)
	else:
		_walk_loser(delta)
		if lead == Lead.LEAD:
			_follow_handler(delta)
	if controller.mode == &"SOLO" and waypoints.is_empty() and is_instance_valid(loser):
		loser.hide()
		loser.freeze()
		_dismiss_handler()
	_turn_winner(delta)


## Path from `from` out through the gate on its side of the arena, detouring around `obstacle`.
static func exit_path(from: Vector3, obstacle: Vector3, slot: int) -> Array[Vector3]:
	var rx := GameBalance.get_number("arena_rx")
	var side := signf(from.x)
	if is_zero_approx(side):
		side = -1.0 if slot == 1 else 1.0
	var inner := Vector3(side * (rx - 2.0), 0.0, 0.0)
	var outer := Vector3(side * (rx + GameBalance.get_number("gate_corridor_length", 6.0) - 1.5), 0.0, 0.0)
	var path: Array[Vector3] = []
	var flat_from := Vector3(from.x, 0.0, from.z)
	var flat_obstacle := Vector3(obstacle.x, 0.0, obstacle.z)
	var clearance := GameBalance.get_number("body_radius") * 2.0 + 1.0
	var closest := Geometry3D.get_closest_point_to_segment(flat_obstacle, flat_from, inner)
	if closest.distance_to(flat_obstacle) < clearance and closest.distance_to(inner) > 0.01:
		var along := (inner - flat_from).normalized()
		var normal := Vector3(-along.z, 0.0, along.x)
		if normal.dot(closest - flat_obstacle) < 0.0:
			normal = -normal
		var detour := flat_obstacle + normal * clearance
		# Keep the detour well inside the fence oval.
		var scaled := Vector2(detour.x / (rx - 2.0), detour.z / (GameBalance.get_number("arena_rz") - 2.0))
		if scaled.length() > 1.0:
			detour = flat_obstacle - normal * clearance
		path.append(detour)
	path.append(inner)
	path.append(outer)
	return path


func _walk_loser(delta: float) -> void:
	if not is_instance_valid(loser):
		waypoints.clear()
		return
	if waypoints.is_empty():
		return
	var position := Vector3(loser.global_position.x, 0.0, loser.global_position.z)
	var to_target := waypoints[0] - position
	if to_target.length() < 0.2:
		waypoints.remove_at(0)
		return
	var max_turn := GameBalance.get_angle("result_flee_turn_rate_deg_s", 240.0) * delta
	var target_yaw := atan2(-to_target.x, -to_target.z)
	loser.rotation.y = wrapf(loser.rotation.y + clampf(angle_difference(loser.rotation.y, target_yaw), -max_turn, max_turn), -PI, PI)
	loser.facing = YawBasis.forward(loser.rotation.y)
	# Walk only once roughly facing the gate, so the buffalo turns before it leaves.
	var aligned := clampf(loser.facing.dot(to_target.normalized()), 0.0, 1.0)
	var full_speed := GameBalance.get_number("result_lead_speed") if lead == Lead.LEAD else GameBalance.get_number("walk_speed") * GameBalance.get_number("result_flee_speed_multiplier", 0.6)
	var speed := full_speed * aligned * aligned
	var step := minf(speed * delta, to_target.length())
	loser.global_position += to_target.normalized() * step
	loser_speed = step / delta


## Where the handler walks while leading: beside the loser's left shoulder, ahead of the
## nose, so the rope runs from their right hand back to the nose ring.
func lead_spot() -> Vector3:
	var basis := loser.global_transform.basis.orthonormalized()
	var spot := loser.global_position + basis * Vector3(-GameBalance.get_number("result_handler_side_m"), 0.0, -GameBalance.get_number("result_handler_ahead_m"))
	return Vector3(spot.x, 0.0, spot.z)


## The handler runs in along `handler_path`, then to the loser's head; the loser waits.
func _approach_handler(delta: float) -> void:
	if not is_instance_valid(handler) or not is_instance_valid(loser):
		lead = Lead.NONE
		return
	var target := handler_path[0] if not handler_path.is_empty() else lead_spot()
	var to_target := target - Vector3(handler.global_position.x, 0.0, handler.global_position.z)
	if to_target.length() < 0.25:
		if not handler_path.is_empty():
			handler_path.remove_at(0)
			return
		lead = Lead.LEAD
		handler.rotation.y = loser.rotation.y
		LowPoly.set_villager_animation(handler, &"Stand")
		rope.show()
		_update_rope()
		return
	var speed := GameBalance.get_number("result_handler_run_speed")
	handler.global_position += to_target.normalized() * minf(speed * delta, to_target.length())
	handler.rotation.y = atan2(-to_target.x, -to_target.z)
	LowPoly.set_villager_animation(handler, &"Run", speed / GameBalance.get_number("result_handler_run_anim_mps"))


## While leading, the handler keeps to `lead_spot()`, faces the way the buffalo walks and
## steps at its pace.
func _follow_handler(delta: float) -> void:
	if not is_instance_valid(handler) or not is_instance_valid(loser):
		return
	var follow := 1.0 - exp(-GameBalance.get_number("result_handler_follow_rate") * delta)
	handler.global_position = handler.global_position.lerp(lead_spot(), follow)
	handler.rotation.y = lerp_angle(handler.rotation.y, loser.rotation.y, follow)
	if loser_speed > 0.2:
		LowPoly.set_villager_animation(handler, &"Walk", loser_speed / GameBalance.get_number("result_handler_walk_anim_mps"))
	else:
		LowPoly.set_villager_animation(handler, &"Stand")
	_update_rope()


func _update_rope() -> void:
	if rope == null or not rope.visible:
		return
	var skeleton := handler.find_child("Skeleton3D", true, false) as Skeleton3D
	var hand := skeleton.find_bone("RightHand") if skeleton != null else -1
	var from := skeleton.global_transform * skeleton.get_bone_global_pose(hand).origin if hand >= 0 else handler.global_position + Vector3.UP
	var nose := Vector3(0.0, GameBalance.get_number("result_rope_nose_y"), -GameBalance.get_number("result_rope_nose_ahead"))
	rope.stretch(from, loser.visual.global_transform * nose)


func _dismiss_handler() -> void:
	lead = Lead.NONE
	if is_instance_valid(handler):
		handler.hide()
	if rope != null and is_instance_valid(rope):
		rope.hide()


## The winner turns in place toward the overview camera, i.e. toward the crowd it salutes.
func _turn_winner(delta: float) -> void:
	var camera := controller.get_node_or_null("CameraRig")
	if camera == null:
		return
	var to_camera: Vector3 = camera.overview_camera_position() - winner.global_position
	to_camera.y = 0.0
	if to_camera.length_squared() < 0.01:
		return
	var max_turn := GameBalance.get_angle("turn_rate_deg_s") * 0.25 * delta
	var target_yaw := atan2(-to_camera.x, -to_camera.z)
	winner.rotation.y = wrapf(winner.rotation.y + clampf(angle_difference(winner.rotation.y, target_yaw), -max_turn, max_turn), -PI, PI)
	winner.facing = YawBasis.forward(winner.rotation.y)
