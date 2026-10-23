"""Run: blender --background --python tools/build_buffalo.py. No third-party modules."""

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / "assets/characters/buffalo"
SOURCE = Path(__file__).resolve().parents[1] / "assets/blender/buffalo.blend"
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "previews").mkdir(exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1


def material(name, color, roughness):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Roughness"].default_value = roughness
    return m


skin = material("Skin • charcoal", (0.055, 0.063, 0.068), 0.78)
horn = material("Horn • warm slate", (0.27, 0.235, 0.185), 0.58)
hoof = material("Hoof • graphite", (0.042, 0.047, 0.049), 0.54)
eye = material("Eye • dark umber", (0.014, 0.010, 0.007), 0.19)
rim = material("Muzzle • soft charcoal", (0.072, 0.079, 0.081), 0.57)
inner = material("Ear interior", (0.15, 0.125, 0.12), 0.85)
root = bpy.data.objects.new("BuffaloRoot", None)
scene.collection.objects.link(root)
root["orientation"] = "Blender +Y forward, +Z up; glTF -Z forward, +Y up; metres"
root["status"] = (
    "Unrigged neutral stance; continuous skin; separate horns, ears, hooves and tail"
)
parts = []


def mesh(name, verts, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    obj.parent = root
    for p in data.polygons:
        p.use_smooth = True
    parts.append(obj)
    return obj


def ellipsoid(name, center, scale, mat=skin):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=center)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    o.parent = root
    for p in o.data.polygons:
        p.use_smooth = True
    parts.append(o)
    return o


def tube(name, points, radii, mat=skin, sides=16):
    """Elliptical rings perpendicular to a centreline, capped at both ends."""
    verts, faces = [], []
    first = (Vector(points[1]) - Vector(points[0])).normalized()
    u = Vector((1, 0, 0)) if abs(first.x) < 0.9 else Vector((0, 1, 0))
    for i, p in enumerate(points):
        tangent = Vector(points[min(i + 1, len(points) - 1)]) - Vector(
            points[max(i - 1, 0)]
        )
        tangent.normalize()
        # Transport the ring frame to prevent flips at a horizontal centreline.
        u = (u - tangent * u.dot(tangent)).normalized()
        v = tangent.cross(u).normalized()
        r = radii[i]
        a, b = (r, r) if isinstance(r, (float, int)) else r
        for j in range(sides):
            t = 2 * math.pi * j / sides
            verts.append(Vector(p) + a * math.cos(t) * u + b * math.sin(t) * v)
    for i in range(len(points) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.extend(
        [
            tuple(reversed(range(sides))),
            tuple((len(points) - 1) * sides + j for j in range(sides)),
        ]
    )
    return mesh(name, verts, faces, mat)


# Longitudinal cross sections control the back and low belly independently.
body = tube(
    "Body",
    [
        (0, y, z)
        for y, z in [
            (-1.47, 1.40),
            (-1.32, 1.43),
            (-1.04, 1.43),
            (-0.65, 1.40),
            (-0.15, 1.40),
            (0.35, 1.45),
            (0.70, 1.49),
            (0.96, 1.47),
            (1.12, 1.43),
        ]
    ],
    [
        (0.12, 0.22),
        (0.40, 0.49),
        (0.58, 0.62),
        (0.67, 0.67),
        (0.69, 0.70),
        (0.64, 0.70),
        (0.55, 0.66),
        (0.43, 0.55),
        (0.22, 0.34),
    ],
    sides=32,
)
skin_parts = [body]
skin_parts.append(
    tube(
        "Neck",
        [(0, 0.60, 1.45), (0, 0.95, 1.50), (0, 1.25, 1.52), (0, 1.48, 1.54)],
        [(0.49, 0.55), (0.43, 0.49), (0.35, 0.42), (0.29, 0.36)],
        sides=24,
    )
)
skin_parts.append(
    tube(
        "Head",
        [
            (0, 1.35, 1.77),
            (0, 1.50, 1.79),
            (0, 1.69, 1.66),
            (0, 1.89, 1.43),
            (0, 2.08, 1.23),
            (0, 2.20, 1.18),
        ],
        [
            (0.27, 0.30),
            (0.33, 0.34),
            (0.30, 0.31),
            (0.235, 0.25),
            (0.235, 0.19),
            (0.20, 0.15),
        ],
        sides=24,
    )
)
for sign, label in [(-1, "L"), (1, "R")]:
    x = sign * 0.46
    skin_parts.append(
        tube(
            "FrontLeg_" + label,
            [
                (sign * 0.34, 0.66, 1.88),
                (x, 0.71, 1.52),
                (x, 0.77, 1.19),
                (x, 0.74, 0.91),
                (x, 0.79, 0.70),
                (x, 0.79, 0.39),
                (x, 0.83, 0.19),
                (x, 0.83, 0.09),
            ],
            [
                (0.13, 0.17),
                (0.24, 0.29),
                (0.205, 0.24),
                (0.145, 0.17),
                (0.12, 0.14),
                (0.082, 0.10),
                (0.115, 0.125),
                (0.10, 0.11),
            ],
        )
    )
    skin_parts.append(
        tube(
            "RearLeg_" + label,
            [
                (sign * 0.34, -1.03, 1.86),
                (x, -0.99, 1.51),
                (x, -0.93, 1.20),
                (x, -0.73, 0.91),
                (x, -1.12, 0.57),
                (x, -1.11, 0.39),
                (x, -1.04, 0.19),
                (x, -1.04, 0.09),
            ],
            [
                (0.14, 0.16),
                (0.285, 0.33),
                (0.235, 0.27),
                (0.16, 0.18),
                (0.105, 0.13),
                (0.076, 0.085),
                (0.11, 0.12),
                (0.10, 0.11),
            ],
        )
    )
    skin_parts.append(
        ellipsoid("Cheek_" + label, (sign * 0.235, 1.59, 1.49), (0.14, 0.23, 0.22))
    )
    skin_parts.append(
        ellipsoid("Brow_" + label, (sign * 0.27, 1.66, 1.80), (0.105, 0.16, 0.075))
    )

# Fuse anatomical masses so shoulder, neck, cheek and leg roots have no visible seams.
for o in skin_parts:
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new("Round anatomical lofts", "SUBSURF")
    mod.levels = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.select_all(action="DESELECT")
for o in skin_parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = "Body"
body.data.remesh_voxel_size = 0.035
bpy.ops.object.voxel_remesh()
mod = body.modifiers.new("Soften anatomical transitions", "SMOOTH")
mod.factor = 1.1
mod.iterations = 5
bpy.ops.object.modifier_apply(modifier=mod.name)
mod = body.modifiers.new("Game mesh", "DECIMATE")
mod.ratio = 0.34
bpy.ops.object.modifier_apply(modifier=mod.name)
for p in body.data.polygons:
    p.use_smooth = True
parts = [body]
# Named selection regions aid later skinning without pretending to supply a finished rig.
for name in [
    "Torso",
    "Neck",
    "Head",
    "FrontLeg_L",
    "FrontLeg_R",
    "RearLeg_L",
    "RearLeg_R",
]:
    body.vertex_groups.new(name=name)
for v in body.data.vertices:
    x, y, z = body.matrix_world @ v.co
    region = "Head" if y > 1.35 else "Neck" if y > 0.96 else "Torso"
    if z < 1.04 and abs(x) > 0.25:
        region = ("FrontLeg_" if y > 0 else "RearLeg_") + ("L" if x < 0 else "R")
    body.vertex_groups[region].add([v.index], 1, "REPLACE")

ellipsoid("Muzzle", (0, 2.15, 1.19), (0.255, 0.205, 0.157), rim)
for sign, label in [(-1, "L"), (1, "R")]:
    # Broad lateral sweep first, then a rising tip that hooks slightly inward.
    points = [
        (sign * x, y, z)
        for x, y, z in [
            (0.25, 1.45, 1.96),
            (0.43, 1.42, 1.96),
            (0.65, 1.37, 1.94),
            (0.88, 1.33, 1.99),
            (1.04, 1.34, 2.12),
            (1.09, 1.39, 2.30),
            (1.05, 1.46, 2.48),
            (0.94, 1.52, 2.61),
        ]
    ]
    h = tube(
        "Horn_" + label,
        points,
        [0.155, 0.15, 0.127, 0.105, 0.083, 0.057, 0.03, 0.002],
        horn,
        20,
    )
    sub = h.modifiers.new("Horn curvature", "SUBSURF")
    sub.levels = 2
    bpy.context.view_layer.objects.active = h
    bpy.ops.object.modifier_apply(modifier=sub.name)
    e = tube(
        "Ear_" + label,
        [
            (sign * 0.27, 1.38, 1.80),
            (sign * 0.42, 1.38, 1.77),
            (sign * 0.59, 1.35, 1.69),
            (sign * 0.70, 1.33, 1.65),
        ],
        [(0.055, 0.06), (0.07, 0.13), (0.04, 0.12), (0.003, 0.005)],
        skin,
        12,
    )
    sub = e.modifiers.new("Soft ear edge", "SUBSURF")
    sub.levels = 1
    bpy.context.view_layer.objects.active = e
    bpy.ops.object.modifier_apply(modifier=sub.name)
    ellipsoid(
        "EarInner_" + label, (sign * 0.51, 1.419, 1.73), (0.14, 0.015, 0.052), inner
    )
    ellipsoid(
        "EyeSocket_" + label, (sign * 0.275, 1.735, 1.735), (0.055, 0.072, 0.050), rim
    )
    ellipsoid("Eye_" + label, (sign * 0.306, 1.767, 1.743), (0.025, 0.038, 0.029), eye)
    ellipsoid(
        "Nostril_" + label, (sign * 0.158, 2.306, 1.244), (0.053, 0.016, 0.039), hoof
    )
    for y, kind in [(0.86, "Front"), (-1.02, "Rear")]:
        for offset, toe in [(-0.062, "Inner"), (0.062, "Outer")]:
            x = sign * 0.46 + offset
            verts = [
                (x + dx, y + dy, z)
                for z, w, d in [
                    (0, 0.056, 0.145),
                    (0.045, 0.063, 0.15),
                    (0.18, 0.047, 0.10),
                ]
                for dx, dy in [(-w, -d), (w, -d), (w, d), (-w, d)]
            ]
            faces = [(3, 2, 1, 0), (8, 9, 10, 11)]
            for k in [0, 4]:
                faces += [
                    (k + j, k + (j + 1) % 4, k + 4 + (j + 1) % 4, k + 4 + j)
                    for j in range(4)
                ]
            o = mesh(kind + "Hoof_" + label + "_" + toe, verts, faces, hoof)
            bevel = o.modifiers.new("Soft hoof edges", "BEVEL")
            bevel.width = 0.018
            bevel.segments = 2
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=bevel.name)
            for p in o.data.polygons:
                p.use_smooth = False
tube(
    "Mouth",
    [(-0.18, 2.265, 1.105), (0, 2.315, 1.09), (0.18, 2.265, 1.105)],
    [0.009, 0.01, 0.009],
    hoof,
    8,
)
tail = tube(
    "Tail",
    [
        (0, -1.36, 1.70),
        (0.02, -1.55, 1.53),
        (0.07, -1.65, 1.24),
        (0.13, -1.75, 0.91),
        (0.18, -1.78, 0.72),
    ],
    [0.055, 0.044, 0.033, 0.026, 0.02],
    skin,
    12,
)
tube(
    "TailTuft",
    [(0.14, -1.76, 0.85), (0.18, -1.79, 0.70), (0.20, -1.81, 0.56)],
    [0.028, 0.065, 0.003],
    hoof,
    12,
)

# Centre the complete character's horizontal bounds at the origin.
bounds = [o.matrix_world @ Vector(c) for o in parts for c in o.bound_box]
shift = (min(v.y for v in bounds) + max(v.y for v in bounds)) / 2
for o in parts:
    o.location.y -= shift
bpy.context.view_layer.update()
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
root.select_set(True)
triangles = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts)
assert triangles < 35000, triangles
assert len([o for o in parts if o.name.startswith("Horn_")]) == 2
assert len([o for o in parts if "Hoof_" in o.name]) == 8
bounds = [o.matrix_world @ Vector(c) for o in parts for c in o.bound_box]
assert abs(min(v.z for v in bounds)) < 0.001
assert all(abs(v) < 5 for p in bounds for v in p)
assert all(all(abs(s - 1) < 1e-5 for s in o.scale) for o in parts)
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "buffalo.glb"),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
    export_apply=True,
)
stats = {
    "triangles": triangles,
    "meshes": len(parts),
    "bounds_metres": {
        a: [min(getattr(v, a) for v in bounds), max(getattr(v, a) for v in bounds)]
        for a in "xyz"
    },
    "forward": "Godot -Z; Blender +Y",
    "rigged": False,
}
(OUT / "validation.json").write_text(json.dumps(stats, indent=2))

# Presentation objects are kept out of the GLB.
studio = bpy.data.collections.new("Preview Studio (not exported)")
scene.collection.children.link(studio)


def in_studio(o):
    for c in list(o.users_collection):
        c.objects.unlink(o)
    studio.objects.link(o)
    return o


bpy.ops.mesh.primitive_plane_add(size=200)
floor = in_studio(bpy.context.object)
floor.name = "StudioFloor"
floor.location.z = -0.012
floor.data.materials.append(material("Studio • warm gray", (0.23, 0.245, 0.26), 0.9))


def aim(o, point):
    o.rotation_euler = (Vector(point) - o.location).to_track_quat("-Z", "Y").to_euler()


for name, loc, power, size in [
    ("Key", (-3, 4, 6), 1000, 5),
    ("Fill", (4, 2, 4), 750, 4),
    ("Rim", (1, -4, 5), 1200, 3),
]:
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.shape = "DISK"
    data.size = size
    o = bpy.data.objects.new(name, data)
    studio.objects.link(o)
    o.location = loc
    aim(o, (0, 0, 1))
data = bpy.data.cameras.new("PreviewCamera")
camera = bpy.data.objects.new("PreviewCamera", data)
studio.objects.link(camera)
scene.camera = camera
data.type = "ORTHO"
data.ortho_scale = 4.8
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.render.resolution_x = 1100
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.world.color = (0.22, 0.22, 0.22)
scene.view_settings.view_transform = "AgX"
views = {"side": (6, 0, 1.30), "front": (0, 7, 1.30), "three_quarter": (6, 8, 2.6)}
for name, loc in views.items():
    camera.location = loc
    aim(camera, (0, 0, 1.30))
    scene.render.filepath = str(OUT / "previews" / f"{name}.png")
    bpy.ops.render.render(write_still=True)
camera.location = views["three_quarter"]
aim(camera, (0, 0, 1.3))
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
sil = material("Silhouette", (0.018, 0.018, 0.018), 1)
for o in parts:
    o.data.materials.clear()
    o.data.materials.append(sil)
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_shadows = False
scene.display.shading.show_cavity = False
scene.display.shading.show_specular_highlight = False
scene.display.shading.background_type = "WORLD"
scene.world.color = (0.75, 0.75, 0.75)
floor.hide_render = True
for name, loc in views.items():
    camera.location = loc
    aim(camera, (0, 0, 1.30))
    scene.render.filepath = str(
        OUT
        / "previews"
        / ("silhouette.png" if name == "front" else f"silhouette_{name}.png")
    )
    bpy.ops.render.render(write_still=True)
print("BUFFALO_VALIDATION " + json.dumps(stats))
