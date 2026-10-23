# Vietnamese water buffalo — reference analysis

Task 03 · 2026-10-09. Analysis concerns **one Vietnamese domestic water buffalo**, not separate animals to reproduce independently. No 3D generation was performed.

## Source and preservation

- Source: `references/vietnamese_buffalo_concept.png`, **1536 × 1024 pixels**.
- SHA-256: `7566a3b3b4cfb0bf245baccf9e17a83234df3598ddc94e8f06bf5eac1823e525`.
- Original file preserved byte-for-byte: hash verified before and after extraction.
- Crops are PNG rectangular extracts at native resolution. No AI regeneration, image enhancement, resampling, masking, mirroring, background removal, or recoloring.
- Reproduction script: `tools/crop_buffalo_references.ps1`, using Windows System.Drawing. The checked Python installations lacked Pillow; no dependency was installed.
- Every decoded output pixel was compared against its source rectangle and matched. PNG file encoding/metadata need not be identical to the original; preservation is of the source file and cropped artwork pixels.

## Panel inventory and crop manifest

Coordinates use a top-left origin. Boxes are **[left, top, right, bottom)**; right/bottom are exclusive.

| Requested view | Source panel | Crop box | Output / size | Reliability |
|---|---|---|---|---|
| Side | Top-right profile labeled **PHẢI**; animal faces screen-left | [1271, 40, 1533, 254) | `processed/buffalo_side.png`, 262 × 214 | Useful standing profile; ears, opposite limbs, and horn sweep overlap. Not calibrated orthographic. |
| Front | First small upper-right view, labeled **TRƯỚC** | [700, 40, 874, 254) | `processed/buffalo_front.png`, 174 × 214 | Both horn tips, face, body, and feet visible; too small for precise measurements. |
| Three-quarter | Large upper-left hero image | [160, 50, 680, 511) | `processed/buffalo_three_quarter.png`, 520 × 461 | Best mass/form reference. Strong perspective, uneven ground, partial text at upper-left, some limb occlusion. |
| Head | First expression panel labeled **THƯỜNG** | [705, 315, 903, 454) | `processed/buffalo_head.png`, 198 × 139 | Neutral face and broad muzzle. Original panel truncates outer horn/ear regions; **not a complete horn-span reference**. |
| Silhouette | **No standalone buffalo silhouette exists** | — | **`processed/buffalo_silhouette.png` not created** | Cannot extract the requested view reliably without manufacturing a new image. |

The adjacent top views include **SAU** (rear) and **TRÁI** (screen-right-facing side). Keep the complete source available to consult these; no additional exports were required. Their labels describe intended views, not proof of exact camera alignment.

Other sections:

- Expression/behavior row: neutral, eating grass, open-mouth/snorting, raised head.
- Lower pose row: walking, running, standing/resting, lying down. Useful motion suggestions, not a neutral rig blueprint.
- Detail tiles: eye, horn, nose, wet/muddy skin, hoof, ear, tail.
- Bottom-left scale panel: posed buffalo beside a **human** silhouette. The human is the only explicit filled silhouette in this section.
- Bottom-right: buffalo with a wireframe-like overlay, **not** a silhouette or downloadable topology.
- Bottom-center: PBR map illustrations. These are not verified usable maps, nor evidence that they share a valid UV layout.

**Missing silhouette:** no darkened render, traced mask, wireframe crop renamed as silhouette, or unrelated previous model preview was substituted. A clean silhouette must come from a separately supplied original reference, or a later explicitly approved derived tracing/render clearly labeled as such.

## Cross-view anatomical inconsistencies

These are visual inconsistencies in an illustrative sheet, not proof of separate breeds. Perspective, pose, and lighting account for some differences; do not force all pixels to agree.

| Region | Observation | Consistent modeling decision |
|---|---|---|
| Shoulder/back | Hero image exaggerates a high, hairy shoulder/neck crest; small profiles have different withers heights and back slopes. | Broad, gently varying topline with modest withers. Reject a bison-like hump and exaggerated shoulder mass. |
| Horns | Front view has a broad, nearly level lateral spread with upturned tips. Hero view shows a deeper crescent and large apparent bases; profiles look more swept back and narrow. Expression tiles change apparent curvature and tip visibility. | One symmetric primary horn design: thick bases, outward sweep, moderate rearward component, upward-curving tapered tips. Front controls span; hero guides curvature; side only limits fore/aft sweep. |
| Torso/belly | Hero looks exceptionally deep and barrel-shaped; profiles and walking/scale images vary in body length and belly clearance. | Long heavy torso, low belly, but enough clearance for believable gait. Do not shrink torso to fit the square hero image. |
| Neck/head | Hero has very thick neck folds and a hanging throat mass; small profiles show a less massive throat and different muzzle projection. | Thick integrated neck, restrained skin folds, broad blunt muzzle with a longer face than a bison. Avoid an oversized hanging dewlap. |
| Legs | Front legs differ in apparent thickness across views; walking images change stance and overlap. Some dark hoof boundaries are ambiguous at source resolution. | Four independently readable legs with anatomical joint chains. Never infer a missing limb or extra joint from overlap. |
| Hooves | Hero/detail panels emphasize a split toe; front/side views flatten or obscure the cleft. | Two principal weight-bearing toes per foot; keep a real cleft readable without oversized claws. |
| Ears | Hero and expression panels show relatively broad hairy ears; front looks smaller. | Small-to-moderate ears relative to skull, lateral below the horns; avoid oversized fantasy ears. |
| Tail | Profiles/rear suggest a slender hanging tail; hero partly hides it behind legs. Detail tile does not define the complete tail. | Thin flexible tail, modest terminal tuft; no broad or armored tail. |
| Stance/ground | Hero stands on uneven terrain; scale panel is walking; small standing panels do not share perfectly aligned feet. | Build a relaxed neutral stance on a flat plane; do not copy mismatched foot heights. |

## Evidence hierarchy

1. User's species/anatomical priorities override stylistic exaggeration.
2. Selected standing side: body length, belly profile, shoulder-to-hip relationship.
3. Selected front: bilateral width, spacing, horn span; small image means low precision.
4. Hero: volume transitions, skin character, muzzle and horn appearance, with perspective allowance.
5. Neutral head/detail tiles: facial features and local surface detail, not overall scale.
6. Pose, scale, wireframe, palette and map illustrations: secondary guidance only.

Do not directly overlay/trace the cropped views at equal image height and expect matching geometry. Camera angles, scale, stance, and implied lighting differ. No exact lens, focal length, projection matrix, animal age, sex, or breed subtype can be established from this sheet alone.

## Scale interpretation

The sheet labels approximate length **2.5–3.0 m**, shoulder height **1.2–1.5 m**, and a **1.7 m human**. Arrow endpoints and pose make “length” ambiguous. These are artist-provided hints, not measured biological data.

`BUFFALO_MODEL_SPEC.md` defines explicit endpoints and provisional working values. No photograph-based measurement or external zoological verification was performed. Confirm against real domestic buffalo photographs before anatomical sign-off, especially horn profile and hind-limb articulation.

## Outcome

Four useful panels extracted and visually reviewed; missing silhouette reported honestly. Original artwork preserved. Modeling dimensions and constraints are documented separately. No Blender scene, mesh, rig, material, or Godot asset was created or modified.
