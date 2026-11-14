class_name ReleaseHandlers
extends Node3D
## The two handlers who bring the buffaloes to the release line (GDD 2.6, 4.6): each starts
## beside its buffalo and walks back out through its own gate during COUNTDOWN, so nobody
## is left in the arena at the signal. Presentation only: reads the controller's phase and
## countdown_time (also replicated to a LAN client), never changes match state.

## Handler shirt per slot (1 red, 2 blue); MatchOutro's exit handler wears the same.
const SHIRTS: Array[Color] = [Color("#8E2B22"), Color("#2E5E80")]

var controller: MatchController
var handlers: Array[Node3D] = []
var _from: Array[Vector3] = []
var _to: Array[Vector3] = []


## Places one handler per buffalo; call once both buffaloes are spawned.
func setup(owner: MatchController) -> void:
	controller = owner
	name = "ReleaseHandlers"
	var exit_x := GameBalance.get_number("arena_rx") + GameBalance.get_number("release_handler_exit_m", 3.0)
	for actor: Buffalo in [controller.player, controller.opponent]:
		var side := signf(actor.global_position.x)
		# Starts at the buffalo's head, as if it had just led it in, then walks out past it on the
		# buffalo's left: the follow camera rides the right shoulder, so it never walks through it.
		var start: Vector3 = actor.global_position + Vector3(-side * 1.8, 0.0, side * 1.3)
		var handler := LowPoly.villager(self, start, -side * PI * 0.5, SHIRTS[actor.slot - 1])
		handler.name = "Handler%d" % actor.slot
		handlers.append(handler)
		_from.append(start)
		_to.append(Vector3(side * exit_x, 0.0, side * 1.3))
	_update()


func _process(_delta: float) -> void:
	_update()


## 0 when the countdown starts, 1 once the handler has left through the gate.
func walk_progress() -> float:
	if controller == null or controller.phase != &"COUNTDOWN":
		return 1.0
	var total := GameBalance.get_number("countdown_s", 3.0)
	var lead := GameBalance.get_number("release_handler_wait_s", 0.4)
	return clampf((total - controller.countdown_time - lead) / maxf(total - lead * 2.0, 0.01), 0.0, 1.0)


func _update() -> void:
	var progress := walk_progress()
	for index in handlers.size():
		var handler := handlers[index]
		handler.visible = progress < 1.0
		handler.position = _path(index, progress)
		# Face along the path once walking, and switch to the walk clip.
		if progress > 0.0:
			var ahead := _path(index, minf(progress + 0.02, 1.0)) - _path(index, maxf(progress - 0.02, 0.0))
			handler.rotation.y = atan2(-ahead.x, -ahead.z)
		LowPoly.set_villager_animation(handler, &"Walk" if progress > 0.0 else &"Stand")


## The walk out bows away from the buffalo's line (`release_handler_bow_m` at mid-way) and
## comes back in to the gate, so it stays clear of the camera behind the buffalo.
func _path(index: int, progress: float) -> Vector3:
	var bow := signf(_from[index].z) * GameBalance.get_number("release_handler_bow_m") * sin(PI * progress)
	return _from[index].lerp(_to[index], progress) + Vector3(0.0, 0.0, bow)
