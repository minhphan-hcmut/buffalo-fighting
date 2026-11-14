class_name LowPoly
extends RefCounted
## Builders for the game's low-poly props and people. Props are Godot primitive meshes;
## people use one rigged CC0 model (assets/characters/villager). Used by the arena (ArenaBuilder), the result outro and
## the Phần Lễ tableaux (CeremonyDiorama) so every scene shares one look.
##
## Materials are cached per colour and shared between meshes: never modify a material
## returned by `material()`; duplicate it first.

const SKIN := Color("#C99B74")
const TROUSERS := Color("#2B2420")
const STRAW_HAT := Color("#D2BA82")
const HAIR := Color("#1E1914")
const VILLAGER_MODEL: PackedScene = preload("res://assets/characters/villager/villager.glb")
const FLAG_SHADER: Shader = preload("res://assets/shaders/flag_wave.gdshader")
const VILLAGER_SCALE := 0.31
const HAT_RADIUS := 0.34
const HAT_HEIGHT := 0.2
# How far the hat's rim sits below the crown, in metres.
const HAT_SINK := 0.08
# Arm angles (upper-arm yaw, upper-arm pitch, forearm bend; radians on the asset's bone
# rest frames) that put each hand at DRUM_GRIP, found by a search over the rig.
const DRUM_POSE := {"Right": Vector3(-1.35, -1.8, -0.75), "Left": Vector3(-0.6, 1.35, 1.35)}
const DRUM_GRIP := Vector3(0.0, 1.05, -0.42)
const DRUM_LIFT := 0.45
# Euler turns (radians, on the bone rest frames) for the crowd's raised cheering arm.
const CHEER_POSE := {"RightArm": Vector3(-2.5, 0.0, 0.0)}

static var _materials: Dictionary = {}
# Part tags in the crowd mesh's UV.x (read by crowd_bob.gdshader).
const CROWD_SKIN := 0.0
const CROWD_HAIR := 0.1
const CROWD_SHIRT := 0.2
const CROWD_TROUSERS := 0.3
const CROWD_HAT := 0.4
static var _crowd_meshes: Array[ArrayMesh] = []


## Palette colour as plain materials should show it. On Compatibility a plain albedo renders
## much paler than the same hex fed through multi()'s instance colours, which washed hats,
## fences and banners out. `ui_palette_depth` (0..1) moves plain colours toward that deeper
## tone: 1 matches multi() exactly.
static func tone(color: Color) -> Color:
	return color.lerp(color.srgb_to_linear(), GameBalance.get_number("ui_palette_depth", 0.0))


## Shared matte material of `color` (shown through tone()).
static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = tone(color)
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


## Flat cloth for `flag_wave.gdshader`: an XY plane subdivided along the edge that waves.
## A `hanging` banner is tied along its top edge, otherwise along its left (pole) edge.
static func flag_cloth(size: Vector2, hanging := false) -> PlaneMesh:
	var cloth := PlaneMesh.new()
	cloth.orientation = PlaneMesh.FACE_Z
	cloth.size = size
	var along := GameBalance.get_int("flag_mesh_subdivisions")
	var across := GameBalance.get_int("flag_mesh_cross_subdivisions")
	cloth.subdivide_width = across if hanging else along
	cloth.subdivide_depth = along if hanging else across
	return cloth


## Waving-cloth material, tuned by the `flag_*` keys in presentation.json. With
## `instance_colors` the tint comes from MultiMesh custom data (linear); otherwise from `color`.
static func flag_material(hanging: bool, color := Color.WHITE, instance_colors := false, pennant := false) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = FLAG_SHADER
	result.set_shader_parameter("hanging", hanging)
	result.set_shader_parameter("pennant", pennant)
	result.set_shader_parameter("instance_colors", instance_colors)
	result.set_shader_parameter("cloth_color", tone(color))
	for key in ["amplitude", "speed", "cycles", "phase_spread"]:
		result.set_shader_parameter(key, GameBalance.get_number("flag_wave_" + key))
	result.set_shader_parameter("roughness", GameBalance.get_number("flag_roughness"))
	return result


## A villager about 1.7 m tall in a conical straw hat (nón lá), facing -Z before `yaw`
## is applied. Uses the rigged Quaternius "Animated Human" (CC0, see docs/ASSET_CREDITS.csv):
## the shirt is recoloured per call, trousers are dark indigo, feet are bare. `animation`
## is one of Stand, Walk, Run, Working (or the asset's wide-stance Idle) and loops, started at a random point so a crowd
## never moves in lockstep. Visual meshes only: no collision.
static func villager(parent: Node3D, at: Vector3, yaw: float, shirt: Color, animation := &"Stand") -> Node3D:
	var person := Node3D.new()
	person.name = "Villager"
	person.position = at
	person.rotation.y = yaw
	parent.add_child(person)
	var model := VILLAGER_MODEL.instantiate() as Node3D
	model.name = "Model"
	# The asset faces +Z; the game's people face -Z.
	model.rotation.y = PI
	model.scale = Vector3.ONE * VILLAGER_SCALE
	person.add_child(model)
	var body := model.find_child("Human_Mesh", true, false) as MeshInstance3D
	if body != null:
		body.material_override = _villager_material(shirt)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		_villager_hat(model, skeleton)
	set_villager_animation(person, animation)
	return person


## Switches a `villager()` to another looping clip (Stand, Idle, Walk, Run, Working); `speed`
## scales its playback. Does nothing if that clip is already playing.
static func set_villager_animation(person: Node3D, animation: StringName, speed := 1.0) -> void:
	var player := person.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	if animation == &"Stand":
		_add_stand_clip(player)
	if not player.has_animation(animation):
		return
	player.speed_scale = speed
	if player.current_animation == animation:
		return
	var clip := player.get_animation(animation)
	clip.loop_mode = Animation.LOOP_LINEAR
	player.play(animation, 0.25)
	player.seek(randf() * clip.length, true)


## Turns a `villager()` into a drummer: both hands held forward at chest height, a
## mallet in each, clip paused so `drum_swing()` owns the arms. Also used for flag
## dancers, who grip their pole at the same point (`DRUM_GRIP`, person space).
static func make_drummer(person: Node3D, mallets := true) -> void:
	var player := person.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		player.pause()
	drum_swing(person, 0.0, 0.0)
	var skeleton := person.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or not mallets:
		return
	var to_person := _to_ancestor(skeleton, person)
	for side in ["Right", "Left"]:
		var hand := skeleton.find_bone(side + "Hand")
		if hand < 0:
			continue
		var hand_pose := to_person * skeleton.get_bone_global_pose(hand)
		var attachment := BoneAttachment3D.new()
		attachment.name = side + "Mallet"
		attachment.bone_name = side + "Hand"
		skeleton.add_child(attachment)
		var mallet := MeshInstance3D.new()
		mallet.name = "Mallet"
		var stick := CylinderMesh.new()
		stick.top_radius = 0.015
		stick.bottom_radius = 0.02
		stick.height = 0.42
		stick.radial_segments = 6
		stick.rings = 1
		mallet.mesh = stick
		mallet.material_override = material(Color("#6E4A33"))
		# Pole along the person's forward axis, tipped down towards the drum.
		var basis := Basis(Vector3.RIGHT, -PI * 0.5 - 0.35)
		var wanted := Transform3D(basis, hand_pose.origin + basis.y * 0.16)
		attachment.add_child(mallet)
		mallet.transform = hand_pose.affine_inverse() * wanted


## Sets a `make_drummer()` villager's arms: 0 = hands at the drum face, 1 = raised for
## the next beat, per hand.
static func drum_swing(person: Node3D, right: float, left: float) -> void:
	var skeleton := person.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	for side in DRUM_POSE:
		var arm := skeleton.find_bone(side + "Arm")
		var fore := skeleton.find_bone(side + "ForeArm")
		if arm < 0 or fore < 0:
			continue
		var pose: Vector3 = DRUM_POSE[side]
		var lift := (right if side == "Right" else left) * DRUM_LIFT
		var sign_b := signf(pose.y)
		skeleton.set_bone_pose_rotation(arm, skeleton.get_bone_rest(arm).basis.get_rotation_quaternion() * Quaternion(Vector3.UP, pose.x) * Quaternion(Vector3.RIGHT, pose.y - sign_b * lift))
		skeleton.set_bone_pose_rotation(fore, skeleton.get_bone_rest(fore).basis.get_rotation_quaternion() * Quaternion(Vector3.BACK, pose.z + signf(pose.z) * lift * 0.8))


static func _to_ancestor(node: Node3D, ancestor: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != ancestor and current is Node3D:
		result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


# "Stand": the asset's Idle (breathing, small sway) has a wide, bent-knee stance that
# reads as mid-stride, so the leg tracks and the hip height are dropped and the legs stay
# at the straight rest pose (the hip keeps its turn). Built once and shared through the imported library.
static func _add_stand_clip(player: AnimationPlayer) -> void:
	if player.has_animation(&"Stand") or not player.has_animation(&"Idle"):
		return
	var stand := player.get_animation(&"Idle").duplicate() as Animation
	for track in range(stand.get_track_count() - 1, -1, -1):
		var path := String(stand.track_get_path(track))
		var hips_height := path.ends_with(":Hips") and stand.track_get_type(track) == Animation.TYPE_POSITION_3D
		if path.contains("Leg") or path.contains("Foot") or path.contains("Toe") or hips_height:
			stand.remove_track(track)
	var library := player.get_animation_library(&"")
	if library != null:
		library.add_animation(&"Stand", stand)


# One palette texture per shirt colour: the asset maps every part to a 32x32 colour
# strip (rows 0-5 skin, 6-10 hair, 11-16 eyes, 17-22 shirt, 23-31 trousers).
static func _villager_material(shirt: Color) -> StandardMaterial3D:
	var key := "villager:" + shirt.to_html()
	if not _materials.has(key):
		var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
		var bands := [[0, 5, SKIN], [6, 10, HAIR], [11, 16, HAIR], [17, 22, shirt], [23, 31, TROUSERS]]
		for band in bands:
			for y in range(band[0], band[1] + 1):
				for x in 32:
					image.set_pixel(x, y, tone(band[2]))
		var result := StandardMaterial3D.new()
		result.albedo_texture = ImageTexture.create_from_image(image)
		result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		result.roughness = 0.9
		_materials[key] = result
	return _materials[key]


# Nón lá on the head bone, so it follows every nod and step. The bone's rest frame is
# not upright, so the hat's pose is solved from the rest pose in model space.
static func _villager_hat(model: Node3D, skeleton: Skeleton3D) -> void:
	var head := skeleton.find_bone("Head")
	var top := skeleton.find_bone("HeadTop_End")
	if head < 0 or top < 0:
		return
	var to_model := _to_ancestor(skeleton, model)
	var head_rest := to_model * skeleton.get_bone_global_rest(head)
	var crown := to_model * skeleton.get_bone_global_rest(top).origin
	var attachment := BoneAttachment3D.new()
	attachment.name = "HatMount"
	attachment.bone_name = "Head"
	skeleton.add_child(attachment)
	var hat := MeshInstance3D.new()
	hat.name = "Hat"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = HAT_RADIUS / VILLAGER_SCALE
	cone.height = HAT_HEIGHT / VILLAGER_SCALE
	cone.radial_segments = 14
	cone.rings = 1
	hat.mesh = cone
	hat.material_override = material(STRAW_HAT)
	var wanted := Transform3D(Basis(), crown + Vector3.UP * (cone.height * 0.5 - HAT_SINK / VILLAGER_SCALE))
	# Bone-local pose = inverse(head rest in model space) * wanted pose in model space.
	attachment.add_child(hat)
	hat.transform = head_rest.affine_inverse() * wanted


## Static crowd version of `villager()` for MultiMesh stands: the model baked in its Stand
## pose with a hat, facing -Z, feet at the origin, 1.7 m tall. `variant` 0 has the arms
## down, 1 raises the right arm. UV.x tags each vertex's part for `crowd_bob.gdshader`
## (CROWD_SKIN … CROWD_HAT), which colours it. Baked once and shared.
static func crowd_villager_mesh(variant: int) -> ArrayMesh:
	if _crowd_meshes.is_empty():
		for cheer in [false, true]:
			_crowd_meshes.append(_bake_crowd_villager(cheer))
	return _crowd_meshes[clampi(variant, 0, _crowd_meshes.size() - 1)]


static func _bake_crowd_villager(cheer: bool) -> ArrayMesh:
	# Baked outside the scene tree: the stands are built from _ready callbacks, some while the
	# root is still adding the main scene and refuses new children. Skin and bone poses are
	# all readable on the detached instance.
	var model := VILLAGER_MODEL.instantiate() as Node3D
	var body := model.find_child("Human_Mesh", true, false) as MeshInstance3D
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_add_stand_clip(player)
	var clip := player.get_animation(&"Stand")
	for track in clip.get_track_count():
		var bone := skeleton.find_bone(clip.track_get_path(track).get_concatenated_subnames())
		if bone < 0:
			continue
		match clip.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, clip.rotation_track_interpolate(track, 0.0))
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, clip.position_track_interpolate(track, 0.0))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone, clip.scale_track_interpolate(track, 0.0))
	if cheer:
		for side in CHEER_POSE:
			var arm := skeleton.find_bone(side)
			if arm >= 0:
				var turn: Vector3 = CHEER_POSE[side]
				skeleton.set_bone_pose_rotation(arm, skeleton.get_bone_rest(arm).basis.get_rotation_quaternion() * Quaternion.from_euler(turn))
	# Linear-blend skinning by hand: each vertex moved by its weighted bone pose x bind.
	var skin := body.skin
	var bind_poses: Array[Transform3D] = []
	for bind in skin.get_bind_count():
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		bind_poses.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
	# Same placement as villager(): turned to face -Z and scaled to 1.7 m.
	var placement := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * VILLAGER_SCALE), Vector3.ZERO)
	var to_person := placement * _to_ancestor(skeleton, model)
	var crown := to_person * skeleton.get_bone_global_pose(skeleton.find_bone("HeadTop_End")).origin
	var source := body.mesh.surface_get_arrays(0)
	model.free()

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var parts := PackedVector2Array()
	var indices := PackedInt32Array(source[Mesh.ARRAY_INDEX])
	var uvs: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
	var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var source_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var bones := PackedInt32Array(source[Mesh.ARRAY_BONES])
	var weights := PackedFloat32Array(source[Mesh.ARRAY_WEIGHTS])
	var per_vertex := bones.size() / source_vertices.size()
	for index in source_vertices.size():
		var position := Vector3.ZERO
		var normal := Vector3.ZERO
		for slot in per_vertex:
			var weight := weights[index * per_vertex + slot]
			if weight > 0.0:
				var pose := bind_poses[bones[index * per_vertex + slot]]
				position += (pose * source_vertices[index]) * weight
				normal += (pose.basis * source_normals[index]) * weight
		vertices.append(to_person * position)
		normals.append((to_person.basis * normal).normalized())
		# Palette rows (see _villager_material): 0-5 skin, 6-16 hair/eyes, 17-22 shirt, rest trousers.
		var row := int(uvs[index].y * 32.0)
		var part := CROWD_TROUSERS
		if row <= 5:
			part = CROWD_SKIN
		elif row <= 16:
			part = CROWD_HAIR
		elif row <= 22:
			part = CROWD_SHIRT
		parts.append(Vector2(part, 0.0))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = HAT_RADIUS
	cone.height = HAT_HEIGHT
	cone.radial_segments = 12
	cone.rings = 1
	var hat := cone.get_mesh_arrays()
	var hat_at := crown + Vector3.UP * (HAT_HEIGHT * 0.5 - HAT_SINK)
	var offset := vertices.size()
	for index in (hat[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		vertices.append(hat[Mesh.ARRAY_VERTEX][index] + hat_at)
		normals.append(hat[Mesh.ARRAY_NORMAL][index])
		parts.append(Vector2(CROWD_HAT, 0.0))
	for index in hat[Mesh.ARRAY_INDEX]:
		indices.append(index + offset)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = parts
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


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
