"""Export Quaternius "Animated Human" (CC0) to assets/characters/villager/villager.glb.

Run from the repo root:
  blender --background --disable-autoexec "<extracted>/Blend/Animated Human.blend" \
      --python tools/export_villager.py -- assets/characters/villager/villager.glb
Keeps only the Idle, Walk, Run and Working actions; textures are recoloured in Godot.
"""
import sys
import bpy

out = sys.argv[sys.argv.index("--") + 1]
keep = {"Idle", "Walk", "Run", "Working"}
for action in list(bpy.data.actions):
    if action.name not in keep:
        bpy.data.actions.remove(action)
arm = bpy.data.objects["Human Armature"]
arm.animation_data_create()
arm.animation_data.action = None
for track in list(arm.animation_data.nla_tracks):
    arm.animation_data.nla_tracks.remove(track)
for action in bpy.data.actions:
    action.use_fake_user = True
    track = arm.animation_data.nla_tracks.new()
    track.name = action.name
    track.strips.new(action.name, 0, action)
bpy.ops.export_scene.gltf(
    filepath=out, export_format="GLB", export_animations=True,
    export_animation_mode="NLA_TRACKS", export_apply=False, export_yup=True,
)
print("EXPORTED", out)
