# Vietnamese domestic water buffalo — modeling specification

Task 03 · 2026-10-09 · **Planning only; no 3D generation authorized in this task.**

## 1. Subject and design intent

Create **one coherent Vietnamese domestic water buffalo** suitable for the existing Godot 4 arena. The concept sheet is illustrative multi-view guidance, not an exact orthographic blueprint. Use one body plan, horn design, scale, and limb anatomy across all later views.

Mandatory priorities:

- Long, heavy torso and low belly; substantial mass without an obese sphere-shaped body.
- Thick neck, broad forehead and muzzle, relatively elongated face.
- Large horns extending outward and then curving upward, with thick roots and tapered tips.
- Four believable legs and visibly cloven hooves.
- Relatively small ears, slender tail with a modest tuft.
- Restrained shoulder/withers rise: **no bison hump, shaggy bison mane, fantasy musculature, oversized claws, or extra horns**.
- Warm charcoal/gray-brown hide; distinguish rough hide, horn, hoof, wet nose, and eyes without making the entire animal glossy.

Source: `references/vietnamese_buffalo_concept.png`. Crop provenance, limitations and inconsistencies: `REFERENCE_ANALYSIS.md`. A standalone silhouette reference is **unavailable**; do not invent one.

## 2. Coordinate system and export contract

### Blender authoring

- Right-handed axes, **+Z up**, **+Y animal forward**, **+X animal's right**.
- Metric units; unit scale **1.0**, one Blender unit = **1 metre**.
- Ground plane **Z=0**. Hoof contact surfaces rest on this plane in the neutral stance.
- Root `BuffaloRoot` at **(0,0,0)**, centered laterally, beneath the midpoint between shoulder and hip joint stations. This origin excludes head, horns and tail from centering, so changing their length will not move locomotion's root.
- Symmetry plane **X=0**. Build major anatomy symmetrically first; optional surface asymmetry must not compromise rigging.
- Head lies toward positive Y; tail toward negative Y.

Reference inspection cameras:

- Front: camera on **+Y**, looking toward −Y, +Z as screen-up. Animal's right (+X) appears on screen-left.
- Animal's right side: camera on **+X**, looking toward −X, +Z as screen-up; muzzle points screen-right.
- Animal's left side: camera on **−X**, looking toward +X, +Z as screen-up; muzzle points screen-left, matching the extracted side crop's screen direction.
- Rear: camera on −Y, looking toward +Y.

The sheet's **PHẢI/TRÁI** labels need not match this explicit camera convention. Do not silently mirror image files to reconcile labels.

### Godot 4 delivery

- Godot is Y-up; gameplay forward is **−Z**, right is **+X**.
- Standard Blender glTF/GLB Y-up conversion maps Blender `(x,y,z)` to Godot `(x,z,−y)`.
- Therefore Blender +Y forward becomes Godot −Z; Blender +Z up becomes Godot +Y.
- Do not add a second corrective 90-degree rotation after correct exporter conversion.
- Root remains at ground height; mesh and armature scales should be `(1,1,1)` and transforms intentional before rigging/export. Avoid negative scale/mirrored export transforms.
- Acceptance test later: head toward Godot −Z, feet at Y≈0, one metre remains one metre, no unexplained root offset. Verify on an exported test rather than assuming exporter settings.

This forward/up convention agrees with the existing asset documentation. The new origin policy and proposed dimensions still require a deliberate gameplay integration check; do not overwrite current assets.

## 3. Provisional proportions

**Art-direction estimates, not measured anatomy.** Let shoulder height **H = 1.35 m**. The sheet suggests H≈1.2–1.5 m and length≈2.5–3.0 m; use those only as broad plausibility checks. Overall head position changes measured length. Values below are neutral-standing targets, not rigid specifications or dimensions to sum indiscriminately.

| Feature / defined endpoints | Working target | Adjustment range | Relative to H |
|---|---:|---:|---:|
| Shoulder height, ground to withers | 1.35 m | 1.25–1.45 m | 1.00 |
| Hip height, ground to rump crest | 1.30 m | 1.22–1.40 m | ≈0.96 |
| Muzzle tip to rear rump, horizontal; tail/horns excluded | 2.80 m | 2.60–3.00 m | ≈2.07 |
| Torso length, shoulder mass front to rump; neck/head excluded | 1.80 m | 1.65–1.95 m | ≈1.33 |
| Shoulder-to-hip joint station distance | 1.40 m | 1.25–1.55 m | ≈1.04 |
| Widest torso width, hide-to-hide | 0.85 m | 0.75–0.95 m | ≈0.63 |
| Torso vertical depth, local back to belly | 0.82 m | 0.72–0.92 m | ≈0.61 |
| Lowest belly ground clearance | 0.48 m | 0.40–0.55 m | ≈0.36 |
| Head length, poll to muzzle along head axis | 0.65 m | 0.58–0.72 m | ≈0.48 |
| Skull width at cheek/temple, horns excluded | 0.36 m | 0.32–0.42 m | ≈0.27 |
| Muzzle width at nostrils | 0.29 m | 0.25–0.34 m | ≈0.21 |
| Visible neck length, shoulder transition to poll | 0.45 m | 0.35–0.55 m | ≈0.33 |
| Neck width/depth through thick lower section | 0.50 / 0.58 m | 0.44–0.60 / 0.50–0.68 m | ≈0.37 / 0.43 |
| Horn span, outermost points, neutral head | 1.55 m | 1.35–1.80 m | ≈1.15 |
| Horn centerline length per side, root to tip | 0.72 m | 0.60–0.90 m | ≈0.53 |
| Horn root diameter | 0.13 m | 0.11–0.17 m | ≈0.10 |
| Horn tip rise above root, neutral head | 0.30 m | 0.22–0.42 m | ≈0.22 |
| Ground to elbow region | 0.73 m | 0.65–0.82 m | ≈0.54 |
| Ground to front carpus / rear hock | 0.37 / 0.43 m | 0.30–0.44 / 0.36–0.51 m | ≈0.27 / 0.32 |
| Front hoof center spacing | 0.46 m | 0.40–0.56 m | ≈0.34 |
| Whole cloven foot width × fore/aft length | 0.15 × 0.19 m | 0.13–0.18 × 0.16–0.22 m | ≈0.11 × 0.14 |
| Ear length from attachment, excluding fur | 0.19 m | 0.16–0.23 m | ≈0.14 |
| Tail length along curve, including tuft | 0.85 m | 0.75–1.00 m | ≈0.63 |

Joint targets are particularly uncertain and must be checked in side/front views and a future walk pose. Belly clearance and torso depth refer to different longitudinal locations; don't subtract every table entry from shoulder height as if all maxima lie in one section. Do not multiply the independent widest range endpoints into an extreme animal.

### Mass and anatomy rules

- Ribcage forms a long barrel with transitions into shoulder and pelvis, not a row of isolated muscle balls.
- Neck merges broadly into the chest; keep sufficient throat mass but reduce the hero image's exaggerated hanging folds.
- Front chain: scapula/shoulder → upper arm → elbow → forearm → **carpus** → metacarpus → fetlock/pastern → hoof. The visible low front joint is not a human knee.
- Rear chain: pelvis/hip → thigh → forward-facing stifle → shin → rearward hock → metatarsus → fetlock/pastern → hoof. Do not reverse the entire hind leg or make it a straight tube.
- Two major weight-bearing digits per foot. Subtle rear dewclaws are optional at close-view detail; never replace the main cloven foot with four equal toes.
- Keep all four legs distinct from front/three-quarter views, even if the reference occludes one.
- Horn roots attach to the skull, not ears. Smooth structural curve with subtle growth ridges; no extra curl or razor fins. Left/right horns share a design rather than copying inconsistent panels independently.
- Eyes sit laterally in bony sockets; broad nostrils connect plausibly to the muzzle. Model mouths closed in the neutral asset; expression panels are not the resting shape.
- The depicted rope/nose-ring assembly is optional tack, not anatomy. Omit from the base animal unless explicitly requested; if added later, keep separately controllable.

## 4. Blender modeling constraints

- Use native-resolution reference crops without pretending they contain more detail. Keep the whole sheet accessible for context.
- Build proportion blockout first; inspect front, side, rear and three-quarter before details. A later model-rendered silhouette is validation output, not a missing original reference.
- Preserve editable `.blend` source and export a distinct `.glb`; do not run existing destructive generation scripts on current assets.
- Apply intended scale before rigging; evaluate modifiers/export visibility deliberately. Avoid baking hidden preview meshes into delivery.
- Use coherent surface topology with loops around limb joints, neck, eyelids, mouth and tail base. No nonmanifold cracks or zero-area faces in intended closed solids; overlaps only where intentional (eyes, horns, hooves, accessories).
- Use smooth body shading; hard boundaries only where justified. Bake fine wrinkles/horn ridges to normal maps rather than modeling every mark.
- Keep future deformation in mind: neck/head movement, elbow/stifle/hock articulation, ear and tail motion. Rigging is a later task, not part of reference preparation.

## 5. Godot 4 constraints and budgets

The existing project targets **Godot 4.7**, GDScript, GL Compatibility, Jolt Physics. Its gameplay scene (`scenes/buffalo.tscn`) references `assets/characters/buffalo/buffalo.glb`; the legacy `assets/water-buffalo.glb` has been removed.

Provisional production targets, subject to actual two-buffalo arena profiling:

- LOD0 starting budget: **15k–25k triangles** total visible buffalo, including horns/hooves/eyes; aim near 20k. The sheet's “8k–15k tris” and “10k–20k quads” captions describe different illustrative budgets, not equivalent verified topology.
- Optional later LOD1 **8k–12k tris**, LOD2 **3k–5k tris**; preserve muzzle, belly, horn and hoof silhouettes. No LODs generated now.
- Start with one **2K** body atlas and a small shared material set (approximately 2–4 materials). Consider 4K only if camera distance and profiling justify it.
- Use glTF-compatible Principled materials: base color, roughness, normal; skin/horn/hoof nonmetallic. Check color-space and normal orientation in Godot. Avoid reliance on procedural Blender nodes, displacement or render-engine-only features.
- PBR thumbnails in the concept sheet are **not production textures**; do not crop them and claim a usable UV-matched set.
- Use GLB embedded/packaged resources deliberately; confirm imported material appearance under actual arena lighting. Check shadows and per-instance cost with two actors.
- Keep `.blend` source out of automatic Godot import, consistent with the project's current skip policy, or store source outside its resource tree.
- Collision and combat hitboxes should be simple gameplay shapes, not the high-detail visual mesh. Horns and tail do not automatically define the locomotion collider.
- If rigging is later approved, verify supported skeletal animation export, sensible bone influences, and names; choose in-place versus root-motion explicitly. Do not assume root-motion matches current controller code.
- Do not silently resize the current game actor to these real-world estimates; camera, speed, collider and arena dimensions must be reconciled in a later integration task.

## 6. Future acceptance checklist

- [ ] One domestic water buffalo, not bison/fantasy anatomy.
- [ ] Long heavy torso, low belly, broad muzzle, no shoulder hump.
- [ ] Consistent horn roots, lateral spread and upward sweep in all views.
- [ ] Four articulated legs, paired cloven digits, believable ground contact.
- [ ] Small ears and slender tufted tail.
- [ ] Blender +Y / +Z correctly becomes Godot −Z / +Y, metre scale retained.
- [ ] Front/side/three-quarter views agree as one 3D animal, without trying to match inconsistent reference pixels exactly.
- [ ] Source/export revisions preserved; budgets and Godot appearance tested, not merely asserted.

**Current state:** reference analysis and four source-preserving crops complete. Silhouette source missing. No modeling, rigging, texture generation, export or engine changes performed.
