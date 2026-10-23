"""Reopen the saved source and check actual mesh integrity, not generator state."""

import json
from pathlib import Path

import bmesh
import bpy

project_root = Path(__file__).resolve().parents[1]
out = project_root / "assets/characters/buffalo"
bpy.ops.wm.open_mainfile(filepath=str(project_root / "assets/blender/buffalo.blend"))
root = bpy.data.objects["BuffaloRoot"]
meshes = [o for o in root.children if o.type == "MESH"]
assert len(meshes) == 25
results = {}
for obj in meshes:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = sum(not edge.is_manifold for edge in bm.edges)
    assert bad == 0, (obj.name, bad)
    assert all(face.calc_area() > 1e-12 for face in bm.faces), obj.name
    results[obj.name] = {
        "vertices": len(bm.verts),
        "faces": len(bm.faces),
        "nonmanifold_edges": bad,
    }
    bm.free()
assert len(bpy.data.objects["Body"].vertex_groups) == 7
body = bpy.data.objects["Body"]
assert body.data.uv_layers
skin_texture = next(
    n.image for n in body.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE"
)
assert skin_texture.packed_file and tuple(skin_texture.size) == (1024, 1024)
assert (
    next(
        n
        for n in bpy.data.materials["Skin • charcoal"].node_tree.nodes
        if n.type == "BSDF_PRINCIPLED"
    )
    .inputs["Base Color"]
    .default_value[0]
    < 0.06
)
assert (out / "buffalo.glb").stat().st_size > 10000
(out / "mesh_validation.json").write_text(json.dumps(results, indent=2))
print(
    "SOURCE_VALIDATION_PASS: 25 closed meshes, no zero-area faces, 7 skinning regions"
)
