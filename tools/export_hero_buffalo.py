"""Export bản HERO độc lập; chạy bằng Blender --background <nguồn.blend> --python script."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/buffalo_hero'
OUT.mkdir(parents=True, exist_ok=True)
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
body = bpy.data.objects['ancient_east_water_buffalo_HERO']
source_triangles = sum(len(p.vertices) - 2 for o in objects for p in o.data.polygons)
# Preserve proportions; place hooves on the arena floor at the existing visual height.
points = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
floor = min(p.z for p in points)
scale = 2.115 / (max(p.z for p in points) - floor)
for o in objects:
    for vertex in o.data.vertices:
        p = o.matrix_world @ vertex.co
        vertex.co = Vector((p.x * scale, p.y * scale, (p.z - floor) * scale))
    o.matrix_world.identity()
    bpy.context.view_layer.objects.active = o
    modifier = o.modifiers.new('Gameplay reduction', 'DECIMATE')
    modifier.ratio = 0.16 if o == body else 0.5
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    o.select_set(True)
body.name = 'HeroBody'
# Export the second faction texture for per-slot cloth selection in Godot.
image = bpy.data.images.get('Faction_Tay_BaseColor_2K.png')
if image:
    image.filepath_raw = str(OUT / 'faction_tay.png')
    image.file_format = 'PNG'
    image.save()
bpy.context.view_layer.objects.active = body
bpy.ops.export_scene.gltf(filepath=str(OUT / 'buffalo_hero.glb'), export_format='GLB', use_selection=True, export_animations=False, export_yup=True)
report = {'source_triangles': source_triangles, 'export_triangles': sum(len(p.vertices)-2 for o in objects for p in o.data.polygons), 'meshes': len(objects), 'rigged': False, 'scale': scale, 'textures_packed': all(i.packed_file is not None for i in bpy.data.images if i.type == 'IMAGE')}
(OUT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('HERO_EXPORT', report)
