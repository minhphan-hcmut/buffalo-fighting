"""Run through Blender MCP; rebuilds the new concept revision from the preserved source."""

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / "assets/characters/buffalo"
# Open previous_version/buffalo.blend in a separate MCP call before executing this script.
scene = bpy.context.scene
root = bpy.data.objects["BuffaloRoot"]
parts = [o for o in root.children if o.type == "MESH"]


def shape(p):
    x, y, z = p
    # Shorter lower limbs, a broader barrel, and a shorter, broader facial profile.
    z = z * 0.70 if z < 0.9 else z - 0.27
    x *= 1.12
    if y > 1.0:
        y = 1 + (y - 1) * 0.86
        x *= 1.07
    z += 0.14 * max(0, min(1, (y - 1.15) / 0.75))
    return Vector((x, y, z))


for o in parts:
    if o.name.startswith("Horn_"):
        continue
    for v in o.data.vertices:
        p = v.co.copy()
        if (o.name == "Body" or "Hoof_" in o.name) and p.z < 1.02 and abs(p.x) > 0.25:
            factor = 1 + 0.32 * max(0, min(1, (1.02 - p.z) / 0.55))
            cx = 0.46 if p.x > 0 else -0.46
            cy = 0.57 if p.y > 0 else -1.29
            p.x = cx + (p.x - cx) * factor
            p.y = cy + (p.y - cy) * factor
        v.co = shape(p)
    o.data.update()

# Rebuild wide crescent horns, with most of their length sweeping laterally.
for sign, label in [(-1, "L"), (1, "R")]:
    o = bpy.data.objects["Horn_" + label]
    controls = [
        (0.28, 1.22, 1.73, 0.145),
        (0.45, 1.12, 1.69, 0.15),
        (0.70, 0.96, 1.66, 0.13),
        (0.99, 0.87, 1.72, 0.098),
        (1.21, 0.91, 1.86, 0.067),
        (1.27, 1.03, 2.00, 0.036),
        (1.19, 1.19, 2.12, 0.002),
    ]
    centers = [Vector((sign * x, y, z)) for x, y, z, r in controls]
    verts = []
    faces = []
    sides = 14
    u = Vector((0, 1, 0))
    for i, c in enumerate(centers):
        tangent = (
            centers[min(i + 1, len(centers) - 1)] - centers[max(0, i - 1)]
        ).normalized()
        u = (u - tangent * u.dot(tangent)).normalized()
        v = tangent.cross(u).normalized()
        radius = controls[i][3]
        for j in range(sides):
            angle = 2 * math.pi * j / sides
            verts.append(
                c + radius * (0.74 * math.cos(angle) * u + math.sin(angle) * v)
            )
    for i in range(len(centers) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.extend(
        [
            tuple(reversed(range(sides))),
            tuple((len(centers) - 1) * sides + j for j in range(sides)),
        ]
    )
    mat = o.data.materials[0]
    data = bpy.data.meshes.new(o.name + "_Crescent")
    data.from_pydata(verts, [], faces)
    data.materials.append(mat)
    data.update()
    o.data = data
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new("Crescent flow", "SUBSURF")
    mod.levels = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons:
        p.use_smooth = True

# Preserve the sculpted form; the reference's painted facets are not flat triangle normals.
body = bpy.data.objects["Body"]
bpy.context.view_layer.objects.active = body
mod = body.modifiers.new("Game topology", "DECIMATE")
mod.ratio = 0.60
bpy.ops.object.modifier_apply(modifier=mod.name)
for p in body.data.polygons:
    p.use_smooth = True
for name in ["Muzzle", "Ear_L", "Ear_R", "EarInner_L", "EarInner_R", "TailTuft"]:
    o = bpy.data.objects[name]
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new("Controlled surfaces", "DECIMATE")
    mod.ratio = 0.65
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons:
        p.use_smooth = True

colors = {
    "Skin": (0.026, 0.034, 0.037),
    "Horn": (0.070, 0.073, 0.062),
    "Hoof": (0.017, 0.018, 0.016),
    "Muzzle": (0.020, 0.024, 0.025),
    "Ear interior": (0.055, 0.041, 0.035),
}
for m in bpy.data.materials:
    for prefix, color in colors.items():
        if m.name.startswith(prefix):
            m.diffuse_color = (*color, 1)
            bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bs.inputs["Base Color"].default_value = (*color, 1)
            bs.inputs["Roughness"].default_value = 0.82

# Keep the pointed nostril inserts close to the muzzle instead of protruding buttons.
for name in ["Nostril_L", "Nostril_R"]:
    o = bpy.data.objects[name]
    center = sum((v.co for v in o.data.vertices), Vector()) / len(o.data.vertices)
    for v in o.data.vertices:
        v.co.y = center.y + (v.co.y - center.y) * 0.35 - 0.008
        v.co.x = center.x + (v.co.x - center.x) * 1.15

bpy.context.view_layer.update()
bounds = [o.matrix_world @ Vector(c) for o in parts for c in o.bound_box]
offset = (min(p.y for p in bounds) + max(p.y for p in bounds)) / 2
for o in parts:
    for v in o.data.vertices:
        v.co.y -= offset
    o.data.update()
scene.camera.location = (5.8, 8, 2.8)
scene.camera.rotation_euler = (
    (Vector((0, 0, 1.03)) - scene.camera.location).to_track_quat("-Z", "Y").to_euler()
)
scene.camera.data.ortho_scale = 4.55
for area in bpy.context.screen.areas:
    if area.type == "VIEW_3D":
        area.spaces.active.region_3d.view_perspective = "CAMERA"
        area.spaces.active.shading.color_type = "MATERIAL"
        area.spaces.active.overlay.show_overlays = False
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
root["revision"] = (
    "New concept: low heavy barrel, short legs, broad crescent horns, charcoal planar skin"
)
print(
    "RESTYLE_READY",
    sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts),
)
