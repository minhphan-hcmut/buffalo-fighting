class_name ArenaDressing
extends RefCounted
## Festival scenery around the sới (GDD 4.1, 4.6): earth floor and grass field, tiered
## wooden stands with a seated crowd, the elders' pavilion, five-colour flag poles with
## pennant strings, trees and low hills. Presentation only: nothing here has collision
## or affects a match. ArenaBuilder calls build() once per arena.
##
## Layout follows the oval fence (arena_rx × arena_rz). Positions around it use
## `_ring(angle, offset)`: the point on the fence at `angle`, pushed `offset` metres
## outward. Gates sit at angle 0 and PI (±X); the pavilion sits at -PI/2 (-Z).
## Crowd colours use a fixed seed, so every match looks the same.

const GROUND_MATERIAL: StandardMaterial3D = preload("res://assets/environment/sparse_grass/ground.tres")

# Palette (GDD Bảng 18) plus village clothing tones.
const EARTH_TINT := Color("#D2B08A")
const GRASS_TINT := Color("#86A84E")
const WOOD := Color("#7A5236")
const WOOD_DARK := Color("#5A3B27")
const LACQUER := Color("#8E2B22")
const TILE := Color("#4A3B36")
const GOLD := Color("#E8BC65")
const PAPER := Color("#F2E6CF")
const BAMBOO := Color("#C9B26B")
const LEAF := Color("#6F8F4E")
const LEAF_DARK := Color("#566F3E")
const FLAG_COLORS: Array[Color] = [Color("#C0392B"), Color("#E8BC65"), Color("#2E6E9E"), Color("#F2E6CF"), Color("#3E8E4E")]
const SHIRTS: Array[Color] = [Color("#5C4033"), Color("#6B4B2B"), Color("#33546D"), Color("#8A5A3B"), Color("#3F4F3A"), Color("#7D2E26"), Color("#B9A27A"), Color("#2F3A44")]
const CROWD_SEED := 6061

const STAND_OFFSET := 3.2        # first tier, metres outside the fence
const STAND_TIERS := 3
const TIER_DEPTH := 1.0
const TIER_RISE := 0.5
const SEAT_SPACING := 0.72
const GATE_CLEARANCE := 4.6      # half-width kept free in front of each gate
const PAVILION_HALF_WIDTH := 5.5
const POLE_OFFSET := 1.6
const POLE_HEIGHT := 5.2


## Adds all scenery under `parent` (the MatchController).
static func build(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Dressing"
	parent.add_child(root)
	_build_ground(root)
	_build_stands(root)
	_build_pavilion(root)
	_build_flags(root)
	_build_trees(root)


## Point on the fence oval at `angle`, moved `offset` metres outward along its normal.
static func ring(angle: float, offset: float) -> Vector3:
	var rx := GameBalance.get_number("arena_rx")
	var rz := GameBalance.get_number("arena_rz")
	var normal := Vector2(cos(angle) / rx, sin(angle) / rz).normalized()
	return Vector3(rx * cos(angle) + normal.x * offset, 0.0, rz * sin(angle) + normal.y * offset)


## Yaw that turns a -Z-facing node at `at` toward the arena centre.
static func face_centre(at: Vector3) -> float:
	var direction := -Vector3(at.x, 0.0, at.z).normalized()
	return atan2(-direction.x, -direction.z)


# Free in front of the gates (±X) and the pavilion (-Z)?
static func _is_open(at: Vector3) -> bool:
	if absf(at.z) < GATE_CLEARANCE and absf(at.x) > GameBalance.get_number("arena_rx"):
		return false
	return not (at.z < 0.0 and absf(at.x) < PAVILION_HALF_WIDTH)


static func _build_ground(root: Node3D) -> void:
	var field := MeshInstance3D.new()
	field.name = "Field"
	var field_plane := PlaneMesh.new()
	field_plane.size = Vector2.ONE * GameBalance.get_number("ui_outer_ground_size")
	field.mesh = field_plane
	field.position.y = -0.03
	var grass := GROUND_MATERIAL.duplicate() as StandardMaterial3D
	grass.albedo_color = GRASS_TINT
	field.material_override = grass
	root.add_child(field)
	# Trampled earth: the oval floor plus the two gate corridors.
	var earth := GROUND_MATERIAL.duplicate() as StandardMaterial3D
	earth.albedo_color = EARTH_TINT
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "EarthFloor"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 64
	disc.rings = 1
	floor_mesh.mesh = disc
	floor_mesh.scale = Vector3(GameBalance.get_number("arena_rx") + 1.2, 1.0, GameBalance.get_number("arena_rz") + 1.2)
	floor_mesh.position.y = -0.01
	floor_mesh.material_override = earth
	root.add_child(floor_mesh)
	var corridor_length := GameBalance.get_number("gate_corridor_length", 6.0)
	for side in [-1.0, 1.0]:
		var corridor := MeshInstance3D.new()
		corridor.name = "GateCorridor"
		var strip := PlaneMesh.new()
		strip.size = Vector2(corridor_length + 2.0, GameBalance.get_number("gate_width") + 1.4)
		corridor.mesh = strip
		corridor.position = Vector3(side * (GameBalance.get_number("arena_rx") + corridor_length * 0.5), -0.005, 0.0)
		corridor.material_override = earth
		root.add_child(corridor)


static func _build_stands(root: Node3D) -> void:
	var tier_transforms: Array[Transform3D] = []
	var tier_colors := PackedColorArray()
	var cloth_transforms: Array[Transform3D] = []
	var cloth_colors := PackedColorArray()
	var seats: Array[Transform3D] = []
	var steps := 72
	for index in steps:
		var a0 := TAU * index / steps
		var a1 := TAU * (index + 1) / steps
		for tier in STAND_TIERS:
			var offset := STAND_OFFSET + (tier + 0.5) * TIER_DEPTH
			var p0 := ring(a0, offset)
			var p1 := ring(a1, offset)
			var mid := (p0 + p1) * 0.5
			if not _is_open(mid):
				continue
			var height := TIER_RISE * (tier + 1)
			var basis := Basis(Vector3.UP, face_centre(mid))
			var chord := p0.distance_to(p1) + 0.04
			tier_transforms.append(Transform3D(_sized(basis, Vector3(chord, height, TIER_DEPTH)), mid + Vector3.UP * height * 0.5))
			tier_colors.append(WOOD if (index + tier) % 2 == 0 else WOOD.darkened(0.08))
			if tier == 0:
				# Red and gold cloth hung on the front of the lowest tier.
				var front := mid - (basis * Vector3(0, 0, 1)) * (TIER_DEPTH * 0.5 + 0.02)
				cloth_transforms.append(Transform3D(_sized(basis, Vector3(chord, height * 0.8, 0.03)), front + Vector3.UP * height * 0.5))
				cloth_colors.append(LACQUER if index % 2 == 0 else GOLD)
			var count := maxi(1, int(chord / SEAT_SPACING))
			for seat in count:
				var at := p0.lerp(p1, (seat + 0.5) / count) + Vector3.UP * height
				seats.append(Transform3D(basis, at))
	var cube := BoxMesh.new()
	LowPoly.multi(root, "StandTiers", cube, tier_transforms, tier_colors, true)
	LowPoly.multi(root, "StandCloth", cube, cloth_transforms, cloth_colors)
	_build_crowd(root, seats)


# Seated villagers: shirt, head and conical hat as three MultiMeshes.
static func _build_crowd(root: Node3D, seats: Array[Transform3D]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = CROWD_SEED
	var bodies: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var hats: Array[Transform3D] = []
	var body_colors := PackedColorArray()
	var head_colors := PackedColorArray()
	var hat_colors := PackedColorArray()
	for seat in seats:
		if rng.randf() < 0.12:
			continue
		var jitter := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.35, 0.35)), Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.08, 0.12)))
		var person := seat * jitter
		var lean := rng.randf_range(0.92, 1.06)
		bodies.append(person * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * lean), Vector3(0, 0.36 * lean, 0)))
		body_colors.append(SHIRTS[rng.randi() % SHIRTS.size()])
		heads.append(person * Transform3D(Basis.IDENTITY, Vector3(0, 0.86 * lean, 0)))
		head_colors.append(LowPoly.SKIN.darkened(rng.randf_range(0.0, 0.15)))
		var hat_on := rng.randf() < 0.7
		hats.append(person * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE if hat_on else Vector3.ZERO), Vector3(0, 1.05 * lean, 0)))
		hat_colors.append(LowPoly.STRAW_HAT.darkened(rng.randf_range(0.0, 0.12)))
	var shirt := CylinderMesh.new()
	shirt.top_radius = 0.17
	shirt.bottom_radius = 0.24
	shirt.height = 0.72
	shirt.radial_segments = 8
	shirt.rings = 1
	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.3  # height = 2 × radius keeps normals unit length
	head.radial_segments = 8
	head.rings = 4
	var hat := CylinderMesh.new()
	hat.top_radius = 0.0
	hat.bottom_radius = 0.33
	hat.height = 0.2
	hat.radial_segments = 10
	hat.rings = 1
	LowPoly.multi(root, "CrowdBodies", shirt, bodies, body_colors)
	LowPoly.multi(root, "CrowdHeads", head, heads, head_colors)
	LowPoly.multi(root, "CrowdHats", hat, hats, hat_colors)


# Elders' pavilion behind the -Z fence: raised floor, red columns, tiled roof, drum.
static func _build_pavilion(root: Node3D) -> void:
	var pavilion := Node3D.new()
	pavilion.name = "Pavilion"
	pavilion.position = ring(-PI * 0.5, 4.6)
	root.add_child(pavilion)
	LowPoly.box(pavilion, "Floor", Vector3(8.4, 0.7, 4.2), Vector3(0, 0.35, 0), Color("#6E5A46"))
	LowPoly.box(pavilion, "Step", Vector3(2.4, 0.35, 0.8), Vector3(0, 0.175, 2.4), Color("#8C806C"))
	for x in [-3.6, -1.2, 1.2, 3.6]:
		for z in [-1.6, 1.6]:
			LowPoly.cylinder(pavilion, "Column", 0.15, 0.15, 2.6, Vector3(x, 2.0, z), LACQUER)
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var prism := PrismMesh.new()
	prism.size = Vector3(5.6, 1.6, 9.6)
	roof.mesh = prism
	roof.position = Vector3(0, 4.1, 0)
	roof.rotation.y = PI * 0.5
	roof.material_override = LowPoly.material(TILE)
	pavilion.add_child(roof)
	LowPoly.box(pavilion, "Ridge", Vector3(10.0, 0.16, 0.3), Vector3(0, 4.95, 0), GOLD.darkened(0.2))
	LowPoly.box(pavilion, "Banner", Vector3(3.2, 0.5, 0.06), Vector3(0, 3.0, 1.75), LACQUER)
	LowPoly.box(pavilion, "BannerText", Vector3(2.8, 0.12, 0.07), Vector3(0, 3.0, 1.76), GOLD)
	for x in [-2.4, 2.4]:
		var drum := LowPoly.cylinder(pavilion, "Drum", 0.55, 0.55, 0.7, Vector3(x, 1.25, 1.2), LACQUER)
		drum.rotation.x = PI * 0.5
		LowPoly.cylinder(drum, "Skin", 0.5, 0.5, 0.72, Vector3.ZERO, PAPER)
	for x in [-1.6, -0.6, 0.6, 1.6]:
		LowPoly.villager(pavilion, Vector3(x, 0.7, -0.4), PI, Color("#5C2A22") if absf(x) < 1.0 else Color("#33546D"))
	pavilion.rotation.y = face_centre(pavilion.position) + PI


# Tall bamboo poles with five-colour flags, joined by strings of pennants.
static func _build_flags(root: Node3D) -> void:
	var poles: Array[Vector3] = []
	var count := 16
	for index in count:
		var at := ring(TAU * (index + 0.5) / count, POLE_OFFSET)
		if absf(at.z) < GATE_CLEARANCE and absf(at.x) > 6.0:
			at = ring(TAU * (index + 0.5) / count, POLE_OFFSET) + Vector3(0, 0, signf(at.z) * GATE_CLEARANCE)
		poles.append(at)
	var pole_transforms: Array[Transform3D] = []
	var pole_colors := PackedColorArray()
	var flag_transforms: Array[Transform3D] = []
	var flag_colors := PackedColorArray()
	for index in poles.size():
		var at := poles[index]
		pole_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.09, POLE_HEIGHT, 0.09)), at + Vector3.UP * POLE_HEIGHT * 0.5))
		pole_colors.append(BAMBOO)
		var yaw := face_centre(at) + PI * 0.5
		for band in FLAG_COLORS.size():
			var y := POLE_HEIGHT - 0.25 - band * 0.32
			flag_transforms.append(Transform3D(_sized(Basis(Vector3.UP, yaw), Vector3(1.0, 0.32, 0.03)), at + Vector3(0, y, 0) + Basis(Vector3.UP, yaw) * Vector3(0.52, 0, 0)))
			flag_colors.append(FLAG_COLORS[band])
	var pennant_transforms: Array[Transform3D] = []
	var pennant_colors := PackedColorArray()
	var line_transforms: Array[Transform3D] = []
	var line_colors := PackedColorArray()
	for index in poles.size():
		var a := poles[index] + Vector3.UP * (POLE_HEIGHT - 0.1)
		var b := poles[(index + 1) % poles.size()] + Vector3.UP * (POLE_HEIGHT - 0.1)
		var span := a.distance_to(b)
		var along := (b - a).normalized()
		var flags := int(span / 0.55)
		for step in flags:
			var t := (step + 0.5) / flags
			var sag := 0.9 * 4.0 * t * (1.0 - t)
			var at := a.lerp(b, t) + Vector3.DOWN * sag
			var basis := _sized(Basis.looking_at(Vector3(along.z, 0, -along.x), Vector3.UP), Vector3(0.32, 0.36, 0.02))
			pennant_transforms.append(Transform3D(basis.rotated(along, PI), at + Vector3.DOWN * 0.16))
			pennant_colors.append(FLAG_COLORS[(step + index) % FLAG_COLORS.size()])
			var t2 := (step + 1.0) / flags
			var next := a.lerp(b, t2) + Vector3.DOWN * (0.9 * 4.0 * t2 * (1.0 - t2))
			var prev := a.lerp(b, float(step) / flags) + Vector3.DOWN * (0.9 * 4.0 * (float(step) / flags) * (1.0 - float(step) / flags))
			var seg := next - prev
			line_transforms.append(Transform3D(_sized(Basis.looking_at(seg.normalized(), Vector3.UP), Vector3(0.02, 0.02, seg.length())), (prev + next) * 0.5))
			line_colors.append(WOOD_DARK)
	var cube := BoxMesh.new()
	var pennant := PrismMesh.new()
	pennant.size = Vector3.ONE
	LowPoly.multi(root, "FlagPoles", cube, pole_transforms, pole_colors, true)
	LowPoly.multi(root, "PoleFlags", cube, flag_transforms, flag_colors)
	LowPoly.multi(root, "Pennants", pennant, pennant_transforms, pennant_colors)
	LowPoly.multi(root, "PennantLines", cube, line_transforms, line_colors)


# A ring of round trees behind the stands, and low hills on the horizon.
static func _build_trees(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = CROWD_SEED + 1
	var trunks: Array[Transform3D] = []
	var trunk_colors := PackedColorArray()
	var crowns: Array[Transform3D] = []
	var crown_colors := PackedColorArray()
	var count := 46
	for index in count:
		var angle := TAU * (index + rng.randf_range(-0.3, 0.3)) / count
		var at := ring(angle, STAND_OFFSET + STAND_TIERS * TIER_DEPTH + rng.randf_range(2.5, 7.0))
		if absf(at.z) < GATE_CLEARANCE + 1.0 and absf(at.x) > 10.0:
			continue
		var height := rng.randf_range(2.4, 3.6)
		trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.28, height, 0.28)), at + Vector3.UP * height * 0.5))
		trunk_colors.append(WOOD_DARK)
		for blob in 2:
			var size := rng.randf_range(1.6, 2.4) * (1.0 - blob * 0.3)
			crowns.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), at + Vector3(rng.randf_range(-0.4, 0.4), height + size * 0.35 + blob * 0.9, rng.randf_range(-0.4, 0.4))))
			crown_colors.append(LEAF if rng.randf() < 0.6 else LEAF_DARK)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35
	trunk.bottom_radius = 0.5
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var crown := SphereMesh.new()
	crown.radius = 0.5
	crown.height = 1.0
	crown.radial_segments = 8
	crown.rings = 4
	LowPoly.multi(root, "TreeTrunks", trunk, trunks, trunk_colors, true)
	LowPoly.multi(root, "TreeCrowns", crown, crowns, crown_colors, true)
	# Hills: spheres sunk into the ground so only a low dome shows. They lie beyond
	# the sun's shadow distance, so they use ArenaBuilder.FAR_SCENERY_LAYER and are
	# lit by the sky only (the sun would burn them out white on Compatibility).
	for index in 9:
		var angle := TAU * index / 9.0 + rng.randf_range(-0.2, 0.2)
		var distance := rng.randf_range(75.0, 100.0)
		var hill := SphereMesh.new()
		hill.radius = rng.randf_range(24.0, 36.0)
		hill.height = hill.radius * 2.0
		hill.radial_segments = 20
		hill.rings = 10
		var instance := MeshInstance3D.new()
		instance.name = "Hill"
		instance.mesh = hill
		instance.position = Vector3(cos(angle) * distance, -hill.radius + rng.randf_range(6.0, 11.0), sin(angle) * distance)
		instance.material_override = LowPoly.material(Color("#5E7A45").lerp(Color("#7F96A6"), rng.randf_range(0.2, 0.45)))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.layers = ArenaBuilder.FAR_SCENERY_LAYER
		root.add_child(instance)


# `basis` with each local axis stretched by `size` (Basis.scaled() would stretch the
# world axes and shear a rotated box).
static func _sized(basis: Basis, size: Vector3) -> Basis:
	return basis * Basis.from_scale(size)
