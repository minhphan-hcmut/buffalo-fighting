class_name LeadRope
extends Node3D
## A slack rope (dây thừng) between two world points, drawn as a few thin cylinders along a
## sagging curve. Visual only. Call `stretch()` every frame with the hand and the nose ring.

const ROPE_COLOR := Color("#8A6A3E")

var _segments: Array[MeshInstance3D] = []


func _init() -> void:
	name = "LeadRope"
	var mesh := CylinderMesh.new()
	mesh.top_radius = GameBalance.get_number("result_rope_radius")
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 1.0
	mesh.radial_segments = 5
	mesh.rings = 1
	var material := LowPoly.material(ROPE_COLOR)
	for index in GameBalance.get_int("result_rope_segments"):
		var segment := MeshInstance3D.new()
		segment.mesh = mesh
		segment.material_override = material
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(segment)
		_segments.append(segment)


## Hangs the rope from `from` to `to` (world space), sagging by `result_rope_sag` per metre of span.
func stretch(from: Vector3, to: Vector3) -> void:
	var sag := GameBalance.get_number("result_rope_sag") * from.distance_to(to)
	var count := _segments.size()
	for index in count:
		var a := _point(from, to, sag, float(index) / count)
		var b := _point(from, to, sag, float(index + 1) / count)
		var segment := _segments[index]
		var length := a.distance_to(b)
		segment.visible = length > 0.001
		if not segment.visible:
			continue
		var up := (b - a) / length
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		# Local Y runs along the segment and is stretched to its length.
		var basis := Basis(side, up * length, side.cross(up))
		segment.global_transform = Transform3D(basis, (a + b) * 0.5)


static func _point(from: Vector3, to: Vector3, sag: float, t: float) -> Vector3:
	return from.lerp(to, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
