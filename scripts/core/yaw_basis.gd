class_name YawBasis
extends RefCounted
## Horizontal basis vectors for a yaw angle (radians, Godot's -Z forward convention).
## Shared by camera, movement, AI and CLASH so they agree on what "forward" means.


## Unit vector on XZ pointing forward for `yaw`.
static func forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Unit vector on XZ pointing right for `yaw`.
static func right(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))
