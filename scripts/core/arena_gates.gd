class_name ArenaGates
extends Node3D
## The two bamboo gates in the fence gaps (±X). Without them the gaps looked open, yet the
## arena oval still stopped and pinned a buffalo there, and the camera looked out through
## them. The gates stay shut while the match is played, so what the player sees matches
## the gameplay edge, and open while people walk through: before and during COUNTDOWN until
## the release handlers have left, and from RESULT for the outro. With no match (menu
## backdrop, ceremony) they stay open. Presentation only: reads the controller's phase
## (also replicated to a LAN client), never changes match state, and has no collision.

var controller: MatchController
## 0 shut, 1 fully open; eases toward `target_open()`.
var open_amount := 1.0
## Per leaf: pivot node at the hinge, yaw when shut, yaw when open, and its length.
var leaves: Array[Dictionary] = []


func _ready() -> void:
	name = "Gates"
	controller = get_parent() as MatchController
	var rx := GameBalance.get_number("arena_rx")
	var rz := GameBalance.get_number("arena_rz")
	var edge := gap_edge_angle()
	var open_turn := deg_to_rad(GameBalance.get_number("gate_open_deg", 110.0))
	for side in [1.0, -1.0]:
		# The two leaves meet on the oval itself, so the shut gate follows the fence curve.
		var meet := Vector3(side * rx, 0.0, 0.0)
		for z_sign in [1.0, -1.0]:
			var hinge := Vector3(side * rx * cos(edge), 0.0, z_sign * rz * sin(edge))
			var shut := meet - hinge
			var length := shut.length()
			var pivot := Node3D.new()
			pivot.name = "Leaf"
			pivot.position = hinge
			add_child(pivot)
			var panel := Node3D.new()
			panel.position = Vector3(length * 0.5, ArenaBuilder.FENCE_HEIGHT * 0.5, 0.0)
			pivot.add_child(panel)
			ArenaBuilder._add_bamboo_panel(panel, length)
			# A diagonal brace makes it read as a gate rather than a gap-filling fence panel.
			var brace := LowPoly.cylinder(panel, "Brace", 0.05, 0.05, Vector2(length, 0.9).length(), Vector3(0.0, -ArenaBuilder.FENCE_HEIGHT * 0.5 + 0.8, 0.06), ArenaBuilder.BAMBOO)
			brace.rotation.z = PI * 0.5 - atan2(0.9, length)
			var shut_yaw := atan2(-shut.z, shut.x)
			# Swing the free end outward, away from the arena, past the corridor edge.
			var open_yaw := shut_yaw - open_turn * signf(z_sign * side)
			leaves.append({"pivot": pivot, "shut": shut_yaw, "open": open_yaw, "length": length})
	update(INF)


## Angle (from +X) of the fence post at each side of the gate gap. Matches the segments
## ArenaBuilder skips, so the gate hangs exactly on the last fence post.
static func gap_edge_angle() -> float:
	var count := GameBalance.get_int("arena_fence_segments", 32)
	var half := GameBalance.get_number("gate_width") / (2.0 * GameBalance.get_number("arena_rz"))
	var step := TAU / count
	var index := 0
	while (index + 0.5) * step < half:
		index += 1
	return index * step


## 1 when the gate should be open now, 0 when shut.
func target_open() -> float:
	if controller == null:
		return 1.0
	if controller.phase == &"PLAYING":
		return 0.0
	if controller.phase == &"COUNTDOWN":
		var handlers := controller.get_node_or_null("ReleaseHandlers") as ReleaseHandlers
		return 0.0 if handlers == null or handlers.walk_progress() >= 1.0 else 1.0
	return 1.0


func _process(delta: float) -> void:
	update(delta)


## Moves the leaves toward `target_open()`; `delta` of INF snaps them.
func update(delta: float) -> void:
	var swing := maxf(GameBalance.get_number("gate_swing_s", 0.8), 0.01)
	open_amount = move_toward(open_amount, target_open(), delta / swing)
	var eased := smoothstep(0.0, 1.0, open_amount)
	for leaf in leaves:
		(leaf.pivot as Node3D).rotation.y = lerp_angle(float(leaf.shut), float(leaf.open), eased)
