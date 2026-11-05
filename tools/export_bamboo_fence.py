"""Export a reusable fence module from the downloaded Geometry Nodes asset.

Usage: blender --background --disable-autoexec SOURCE.blend --python
       tools/export_bamboo_fence.py -- --output assets/environment/bamboo_fence.glb
The source blend is never saved or modified on disk.
"""
import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    source = bpy.data.objects["BezierCurve"]
    source.data = source.data.copy()
    source.data.splines.clear()
    spline = source.data.splines.new("BEZIER")
    spline.bezier_points.add(1)
    for point, x in zip(spline.bezier_points, (0.0, 3.0)):
        point.co = (x, 0.0, 0.0)
        point.handle_left_type = "VECTOR"
        point.handle_right_type = "VECTOR"

    # Geometry Nodes instances must become real mesh geometry before glTF export.
    group = source.modifiers[0].node_group
    output = next(node for node in group.nodes if node.type == "GROUP_OUTPUT" and node.is_active_output)
    incoming = output.inputs["Geometry"].links[0].from_socket
    realize = group.nodes.new("GeometryNodeRealizeInstances")
    group.links.new(incoming, realize.inputs["Geometry"])
    group.links.new(realize.outputs["Geometry"], output.inputs["Geometry"])
    bpy.context.view_layer.update()
    evaluated = source.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = bpy.data.meshes.new_from_object(evaluated)
    if not mesh.vertices:
        raise RuntimeError("Geometry Nodes produced an empty fence")

    # Normalize X length and Z height to 1; preserve relative depth.
    lo = Vector(tuple(min(v.co[i] for v in mesh.vertices) for i in range(3)))
    hi = Vector(tuple(max(v.co[i] for v in mesh.vertices) for i in range(3)))
    size = hi - lo
    for vertex in mesh.vertices:
        vertex.co.x = (vertex.co.x - (lo.x + hi.x) * 0.5) / size.x
        vertex.co.y = (vertex.co.y - (lo.y + hi.y) * 0.5) / size.z
        vertex.co.z = (vertex.co.z - lo.z) / size.z

    # Blender procedural shaders are not supported by glTF. Replace only the
    # export mesh's material slots; keep the original bamboo/rope geometry.
    for index, original in enumerate(list(mesh.materials)):
        rope = original is not None and "rope" in original.name.lower()
        material = bpy.data.materials.new("Fence_Rope" if rope else "Fence_Bamboo")
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (0.24, 0.13, 0.055, 1.0) if rope else (0.48, 0.36, 0.13, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.9
        mesh.materials[index] = material

    fence = bpy.data.objects.new("BambooFence", mesh)
    bpy.context.collection.objects.link(fence)
    bpy.ops.object.select_all(action="DESELECT")
    fence.select_set(True)
    bpy.context.view_layer.objects.active = fence
    # The download includes densely tessellated rope. Reduce it offline rather
    # than multiplying half a million vertices by every arena segment.
    reduction = fence.modifiers.new("Game mesh reduction", "DECIMATE")
    reduction.ratio = 0.025
    bpy.ops.object.modifier_apply(modifier=reduction.name)
    fence.data.validate(clean_customdata=True)
    fence.data.update()
    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(output_path), export_format="GLB", use_selection=True)
    print(f"Exported {output_path}: {len(fence.data.vertices)} vertices, {len(fence.data.polygons)} polygons; source bounds {size}")


if __name__ == "__main__":
    main()
