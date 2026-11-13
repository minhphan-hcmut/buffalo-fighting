class_name LowPoly
extends RefCounted
## Builders for the game's low-poly props and people, made only from Godot primitive
## meshes (no imported models). Used by the arena (ArenaBuilder), the result outro and
## the Phần Lễ tableaux (CeremonyDiorama) so every scene shares one look.
##
## Materials are cached per colour and shared between meshes: never modify a material
## returned by `material()`; duplicate it first.

const SKIN := Color("#C99B74")
const TROUSERS := Color("#2B2420")
const STRAW_HAT := Color("#D2BA82")

static var _materials: Dictionary = {}


## Shared matte material of `color`.
static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.88
		_materials[color] = result
	return _materials[color]


## Box mesh named `node_name`, centred at `at` inside `parent`.
static func box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(parent, node_name, mesh, at, color)


## Cylinder (or cone when `top` is 0) named `node_name`, centred at `at` inside `parent`.
static func cylinder(parent: Node3D, node_name: String, top: float, bottom: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return _instance(parent, node_name, mesh, at, color)


## Sphere named `node_name`, centred at `at` inside `parent`.
static func sphere(parent: Node3D, node_name: String, radius: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return _instance(parent, node_name, mesh, at, color)


## A standing villager about 1.9 m tall with a conical straw hat, facing -Z before
## `yaw` is applied. Visual meshes only: no collision.
static func villager(parent: Node3D, at: Vector3, yaw: float, shirt: Color) -> Node3D:
	var person := Node3D.new()
	person.name = "Villager"
	person.position = at
	person.rotation.y = yaw
	parent.add_child(person)
	cylinder(person, "Legs", 0.16, 0.2, 0.75, Vector3(0.0, 0.375, 0.0), TROUSERS)
	cylinder(person, "Shirt", 0.2, 0.26, 0.75, Vector3(0.0, 1.1, 0.0), shirt)
	sphere(person, "Head", 0.16, Vector3(0.0, 1.62, 0.0), SKIN)
	cylinder(person, "Hat", 0.0, 0.36, 0.22, Vector3(0.0, 1.82, 0.0), STRAW_HAT)
	return person


## Draws `mesh` once per transform in a single MultiMesh (one draw call), tinted per
## instance by `colors` (same length as `transforms`). For crowds and repeated props.
## The mesh's own material is replaced by a shared one that uses the instance colour.
static func multi(parent: Node3D, node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: PackedColorArray, cast_shadow := false) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		# Palette colours are sRGB; the Compatibility renderer reads instance colours as linear.
		multimesh.set_instance_color(index, colors[index].srgb_to_linear())
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = _instance_color_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func _instance_color_material() -> StandardMaterial3D:
	if not _materials.has("instance_color"):
		var result := StandardMaterial3D.new()
		result.vertex_color_use_as_albedo = true
		result.roughness = 0.88
		_materials["instance_color"] = result
	return _materials["instance_color"]


static func _instance(parent: Node3D, node_name: String, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material(color)
	parent.add_child(instance)
	return instance
