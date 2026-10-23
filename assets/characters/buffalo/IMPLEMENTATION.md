# Vietnamese domestic water buffalo

## Current revision — refined anatomy and shading, edited through Blender MCP

The current Blender source is stored in `assets/blender/buffalo.blend`; the runtime export is `assets/characters/buffalo/buffalo.glb`. The model retains the second concept's low body and wide horns while correcting the overly faceted previous version. Smooth skin, shoulder relief, flatter cheek masses, seated eyes with modeled eyelids, boolean-cut nostrils, tapered crescent horns and rounded cloven hoof wedges replace the coarse triangular shading and block feet. A subtle charcoal skin color wash is baked into a packed 1024px texture. All editing, baking, rendering and export ran through Blender MCP.

Current counts: **22,768 triangles, 25 meshes**. Bounds: **2.563 m wide, 4.054 m long, 2.115 m tall**. Ground and orientation are unchanged. Blender MCP checks passed for all closed surfaces and nonzero-area faces. Godot 4.7.2 import and scene-instantiation checks passed, including the embedded skin texture. Vertex colors alone did not activate as albedo in this Godot importer, so they were baked to an embedded texture instead. Previews include three lit views and three silhouettes.

To reproduce this revision, open `assets/blender/buffalo.blend` in Blender, then execute `tools/restyle_buffalo.py` followed by `tools/polish_buffalo.py` through MCP in a separate call. Save and export the selected BuffaloRoot hierarchy. `tools/build_buffalo.py` regenerates the source and GLB. No rig or animation was added; deformation and in-game performance remain untested.

The following sections record the original version's construction and measurements; the current revision above supersedes its counts and proportions.

Generated with Blender Python; editable source and a standalone Godot GLB. The arena's existing buffalo scene is unchanged.

## Files

- `buffalo.blend`: character plus a separately organized preview studio.
- `buffalo.glb`: character only, embedded materials, no external textures.
- `previews/`: side, front, three-quarter and flat grayscale silhouettes.
- `validation.json`, `mesh_validation.json`: measured dimensions and geometry checks.
- [build_buffalo.py](../../../tools/build_buffalo.py): reproducible generator in the project root's `tools` directory.

## Anatomy and construction

The requested reference PNG and optional specification were not present. The attached concept sheet guided the broad skull, elongated face, heavy torso, low belly, split hooves and lateral horn sweep. The back is intentionally flatter than the concept's pronounced hump. Two thick horn bases sweep outward, rise, then taper inward. Small eyes sit beneath brow masses; ears remain below the horn roots. Rear legs include the forward stifle and rearward hock bend.

Lofted cross sections establish the blockout. Smoothed anatomical masses are fused and reduced to a continuous skin surface; this avoids exposed shoulder and hip intersections. Separate horns, ears, eyes, muzzle, hooves and tail remain editable. Charcoal skin, warm gray-brown horns and dark hooves use simple roughness-based materials. Preview lighting lifts the dark skin substantially; the stored base color is dark charcoal.

31,394 triangles across 25 meshes. Bounds: 2.257 m wide including horns, 4.209 m long including tail and muzzle, 2.606 m tall including tips. Feet meet Z=0 in Blender and Y=0 in Godot. Horizontal bounds are centered at the origin. Blender +Y faces forward; the GLB faces Godot -Z. Applied mesh transforms, metre scale, no subdivision modifiers left in the exported model.

## Checks and iterations

Blender executed the generator and saved both deliverables. Visual review covered side, front, three-quarter and silhouette renders. Iterations corrected cross-section frame flips, flattened the back, blended shoulder/haunch roots, reduced eye protrusion, rounded ears and seated the legs into the hooves.

The saved Blender source was reopened independently: all 25 meshes have closed manifold edges and no zero-area faces. Godot 4.7.2 headless editor import and a scene-instantiation test passed, checking mesh count, materials, triangle budget, ground contact and forward orientation. Logs are included beside this report. The `.blend.import` file deliberately skips automatic Blender import; use the supplied GLB.

## Rebuild and validate

Run from the project directory, substituting installed executable paths:

```text
blender --background --python tools/build_buffalo.py
blender --background --python tools/validate_buffalo.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/buffalo_asset_test.gd
```

The generator replaces its own buffalo outputs. It runs in a separate Blender process and clears that process's scene. It does not modify an open interactive Blender session.

## Animation and integration limits

This is an unrigged asset, not an animated character. Seven named body vertex groups provide selection regions for torso, neck, head and limbs; they are not finished bone weights. The reduced skin is predominantly triangles, so an animator should inspect joint edge flow and add local retopology where deformation tests require it. Tail rings remain editable. No UV texture painting, LODs, collision shapes, skeleton or animation clips are included.

Import and geometry were tested; skeletal deformation, arena performance and target-device budgets were not. The current arena scene uses a different model with its own rotation and collision dimensions. Instance this GLB with no corrective yaw, then fit collisions and gameplay scale if replacing that model. Source geometry is suitable for editing and rig preparation; production animation readiness is not claimed.
