"""Apply once after restyle_buffalo.py, in the live Blender MCP scene."""

import math

import bpy
from mathutils import Vector

root = bpy.data.objects["BuffaloRoot"]
skin = bpy.data.objects["Body"].data.materials[0]


def center(o):
    return sum((v.co for v in o.data.vertices), Vector()) / len(o.data.vertices)


def replace(o, vertices, faces, material, smooth=True):
    data = bpy.data.meshes.new(o.name + "_Refined")
    data.from_pydata(vertices, [], faces)
    data.materials.append(material)
    data.update()
    o.data = data
    for f in data.polygons:
        f.use_smooth = smooth


# Broad anatomical relief: shoulder ridge, haunch taper and a soft flank hollow.
body = bpy.data.objects["Body"]
for v in body.data.vertices:
    x, y, z = v.co
    side = abs(x) / 0.75
    shoulder = 0.035 * math.exp(-(((y - 0.60) / 0.30) ** 2) - ((z - 1.25) / 0.35) ** 2)
    flank = 0.024 * math.exp(-(((y + 0.40) / 0.40) ** 2) - ((z - 1.18) / 0.28) ** 2)
    v.co.x += (1 if x > 0 else -1) * (shoulder - flank) * side
    cheek = 0.045 * math.exp(-(((y - 1.35) / 0.20) ** 2) - ((z - 1.25) / 0.18) ** 2)
    v.co.x -= (1 if x > 0 else -1) * cheek
    brow = 0.038 * math.exp(
        -(((abs(x) - 0.32) / 0.13) ** 2)
        - ((y - 1.48) / 0.16) ** 2
        - ((z - 1.59) / 0.065) ** 2
    )
    v.co.x += (1 if x > 0 else -1) * brow
    v.co.y += brow * 0.6
    if z > 1.55:
        v.co.z += (
            0.055 * math.exp(-(((y - 0.40) / 0.48) ** 2)) * min(1, (z - 1.55) / 0.18)
        )
body.data.update()

for label, sign in [("L", -1), ("R", 1)]:
    eye = bpy.data.objects["Eye_" + label]
    c = center(eye)
    normal = Vector((sign * 0.79, 0.61, 0)).normalized()
    horizontal = Vector((sign * 0.61, -0.79, 0)).normalized()
    # Seat the eye into the head, framed by an upper lid and a finer lower lid.
    c -= normal * 0.012
    old = center(eye)
    for v in eye.data.vertices:
        delta = v.co - old
        v.co = c + delta * 0.90
    ring = []
    faces = []
    rings = 28
    sides = 8
    for i in range(rings):
        t = 2 * math.pi * i / rings
        ct = (
            c + horizontal * (0.042 * math.cos(t)) + Vector((0, 0, 0.026 * math.sin(t)))
        )
        radial = (horizontal * math.cos(t) + Vector((0, 0, math.sin(t)))).normalized()
        radius = 0.013 + 0.008 * max(0, math.sin(t))
        for j in range(sides):
            a = 2 * math.pi * j / sides
            ring.append(
                ct
                + radius * (math.cos(a) * radial + math.sin(a) * normal)
                - normal * 0.008
            )
    for i in range(rings):
        for j in range(sides):
            faces.append(
                (
                    i * sides + j,
                    i * sides + (j + 1) % sides,
                    ((i + 1) % rings) * sides + (j + 1) % sides,
                    ((i + 1) % rings) * sides + j,
                )
            )
    replace(bpy.data.objects["EyeSocket_" + label], ring, faces, skin)

# Rounded cloven wedges, tall enough to meet the pastern instead of looking like sandals.
for o in list(root.children):
    if "Hoof_" not in o.name:
        continue
    c = center(o)
    vertices = []
    faces = []
    count = 12
    ankle_x = 0.5152 if c.x > 0 else -0.5152
    c.x = ankle_x + (c.x - ankle_x) * 0.91
    for z, wx, wy, yoffset in [
        (0, 0.080, 0.145, 0.018),
        (0.035, 0.082, 0.148, 0.016),
        (0.125, 0.071, 0.120, -0.012),
        (0.165, 0.063, 0.10, -0.024),
    ]:
        for j in range(count):
            t = 2 * math.pi * j / count
            dx = math.copysign(abs(math.cos(t)) ** 0.65, math.cos(t)) * wx
            dy = math.copysign(abs(math.sin(t)) ** 0.65, math.sin(t)) * wy
            vertices.append((c.x + dx, c.y + dy + yoffset, z))
    for k in range(3):
        for j in range(count):
            faces.append(
                (
                    k * count + j,
                    k * count + (j + 1) % count,
                    (k + 1) * count + (j + 1) % count,
                    (k + 1) * count + j,
                )
            )
    faces += [tuple(reversed(range(count))), tuple(3 * count + j for j in range(count))]
    mat = o.data.materials[0]
    replace(o, vertices, faces, mat, False)
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new("Hoof rim", "BEVEL")
    mod.width = 0.009
    mod.segments = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)

# Actual shallow nostril cavities; the dark inserts sit inside the depressions.
muzzle = bpy.data.objects["Muzzle"]
for label in ["L", "R"]:
    insert = bpy.data.objects["Nostril_" + label]
    c = center(insert)
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=24, ring_count=16, location=(c.x, c.y + 0.007, c.z)
    )
    cutter = bpy.context.object
    cutter.scale = (0.061, 0.050, 0.039)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.objects.active = muzzle
    mod = muzzle.modifiers.new("Nostril recess", "BOOLEAN")
    mod.object = cutter
    mod.operation = "DIFFERENCE"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    for v in insert.data.vertices:
        delta = v.co - c
        v.co = c + Vector((delta.x * 0.72, delta.y * 3 - 0.030, delta.z * 0.70))
for f in muzzle.data.polygons:
    f.use_smooth = True

# Broad color washes are stored as vertex colors so the GLB keeps them without textures.
from mathutils.noise import noise_vector

mat = skin.copy()
mat.name = "Skin • painted charcoal"
body.data.materials.clear()
body.data.materials.append(mat)
colors = body.data.color_attributes.new(
    name="SkinColor", type="FLOAT_COLOR", domain="POINT"
)
for v in body.data.vertices:
    x, y, z = v.co
    variation = noise_vector(v.co * 3.5)[0] * 0.10
    light = 0.82 + 0.25 * min(1, z / 1.8) + variation
    earth = max(0, 1 - z / 0.6) * 0.007
    colors.data[v.index].color = (
        0.026 * light + earth,
        0.034 * light + earth * 0.45,
        0.037 * light,
        1,
    )
bs = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
vc = mat.node_tree.nodes.new("ShaderNodeVertexColor")
vc.layer_name = "SkinColor"
mat.node_tree.links.new(vc.outputs["Color"], bs.inputs["Base Color"])
nostril_mat = bpy.data.materials.new("Nostril interior")
nostril_mat.use_nodes = True
bs = next(n for n in nostril_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
bs.inputs["Base Color"].default_value = (0.003, 0.004, 0.004, 1)
bs.inputs["Roughness"].default_value = 1
nostril_mat.diffuse_color = (0.003, 0.004, 0.004, 1)
for label in ["L", "R"]:
    o = bpy.data.objects["Nostril_" + label]
    o.data.materials.clear()
    o.data.materials.append(nostril_mat)

# Slightly lower gloss on skin, while keeping moist eyes and muzzle readable.
for prefix, roughness in [
    ("Skin", 0.78),
    ("Horn", 0.66),
    ("Hoof", 0.57),
    ("Muzzle", 0.52),
]:
    for mat in bpy.data.materials:
        if mat.name.startswith(prefix) and mat.use_nodes:
            bs = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bs.inputs["Roughness"].default_value = roughness

scene = bpy.context.scene
scene.view_settings.exposure = -0.7
# Bake the washes: this Godot importer does not enable vertex colors as albedo.
from pathlib import Path

out = Path(__file__).resolve().parents[1] / "assets/characters/buffalo"
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.015)
bpy.ops.object.mode_set(mode="OBJECT")
mat = body.data.materials[0]
image = bpy.data.images.new("Buffalo_Skin_BaseColor", width=1024, height=1024)
node = mat.node_tree.nodes.new("ShaderNodeTexImage")
node.image = image
for n in mat.node_tree.nodes:
    n.select = False
node.select = True
mat.node_tree.nodes.active = node
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True
scene.render.bake.margin = 12
bpy.ops.object.bake(type="DIFFUSE")
bs = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
mat.node_tree.links.new(node.outputs["Color"], bs.inputs["Base Color"])
for n in list(mat.node_tree.nodes):
    if n.type == "VERTEX_COLOR":
        mat.node_tree.nodes.remove(n)
for attr in list(body.data.color_attributes):
    body.data.color_attributes.remove(attr)
image.filepath_raw = str(out / "skin_basecolor.png")
image.file_format = "PNG"
image.save()
image.pack()
root["revision"] = (
    "Refined anatomy, seated eyes with eyelids, recessed nostrils, cloven hoof wedges, smooth charcoal skin"
)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
print("POLISH_READY")
