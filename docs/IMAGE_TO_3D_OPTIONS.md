# Image-to-3D options for Pi + Blender

Research date: **2026-10-09**. Public documentation and local source inspection only. **No reference images uploaded, credentials requested/read, generation jobs submitted, credits spent, packages installed, or integration code executed.**

## Recommendation

- **Primary: Meshy paid API, Multi-Image to 3D**, via a small reviewed local API client controlled by Pi; import its downloaded GLB through Blender MCP afterward. Its documented 1–4-image interface fits our partial, non-orthographic reference set better than a strictly labeled four-view input contract. Current API documentation, credit table, GLB/OBJ outputs, and paid-output terms were readable and explicit. This is an integration plan, **not an existing Meshy tool in Blender MCP**.
- **Fallback: Tripo paid API V3**, through a reviewed local client and then GLB import. It has a documented dedicated multi-view endpoint, current pricing, an official SDK, and commercial-output provisions. Pin a current model and verify the V3 payload before implementation; do **not** build against retiring V2. Tripo through Blender MCP Premium is a separate **single-image convenience route**, not the recommended multi-view fallback.

These are workflow recommendations, not quality rankings established by a benchmark. No provider has been tested on this buffalo. Generated results will still need anatomy repair, retopology, material cleanup, rigging and Godot validation.

## Verification boundaries

“API available” below means a public documented API/implementation was verified. It does **not** mean this account is provisioned, authenticated, funded, region-eligible, or that a paid call succeeded.

The configured web search failed with upstream timeout/model errors, and web-fetch was previously unavailable. Public pages were fetched directly over HTTPS; official GitHub sources and installed code were inspected where sites were blocked. Some initial Tripo pages returned HTTP 403, but its current developer site was subsequently readable. Tencent's attempted international documentation page returned a browser challenge; official SDK schemas establish its mainland API capabilities, but not current international prices or contract terms. Unknowns below are explicit approval blockers, not guessed facts.

Local research downloads were kept in the OS temporary directory, not committed as project sources. Source links below allow independent checking. Prices may change; reconfirm at approval time.

## Comparison at a glance

| Option | API / multi-view | Pi / Blender integration | Local GPU | GLB / OBJ | Main limitation |
|---|---|---|---|---|---|
| **Meshy cloud** | Documented REST API; 1–4 images | Separate Pi-controlled API client; downloaded GLB imported via Blender MCP | None for cloud generation | Both direct outputs | Not native to installed Blender MCP; paid-plan/privacy terms need account confirmation |
| **Tripo cloud** | Documented V3; dedicated multi-view endpoint. Older H3 docs specify front/left/back/right slots | Direct API/official SDK; MCP Premium exposes a separate one-image path | None | GLB; OBJ conversion available | V2 retirement imminent; cannot copy V2 schema unmodified into V3 |
| **Hunyuan cloud** | Tencent Pro multi-view verified in mainland `ai3d` SDK; regional APIs differ | Native MCP single-image path, or custom client for multi-view | None | Mainland Pro schema defaults include OBJ/GLB; MCP prefers GLB | Exact account/region pricing and cloud asset terms not verified |
| **Hunyuan local 2mv / 2.1** | Open-weight Python pipelines and local API; 2mv explicitly supports multi-view | Local service/custom client; MCP LOCAL_API currently sends one image | Substantial compatible GPU needed | Both via mesh export | This machine lacks a verified CUDA GPU; restrictive model license territories |
| **Hyper3D Rodin** | Direct/fal cloud APIs; fal Rodin v2 documents up to 5 images | Native MCP one-image wrapper; separate client needed to expose full multi-view | None | GLB/OBJ among formats on fal v2 | Installed own-key fal route is not the documented v2 URL; exact direct pricing/terms unresolved |

## 1. Installed Blender MCP: what it actually supports

Reviewed official checkout commit **`7a0373ec9199183cb460068c4f96aed9c579fb4f`**, package **`mcp-for-blender` 2.1.9**, and cached installed `blender_mcp/generation.py`. Installed add-on was previously verified against the same official source after line-ending normalization.

Sources: [official repository](https://github.com/ahujasid/blender-mcp), especially `README.md`, `src/blender_mcp/server.py`, `src/blender_mcp/generation.py`, and `addon.py`.

- Provider enum is exactly **`tripo`, `hunyuan3d`, `hyper3d`**. **Meshy is absent.** Poly Haven, Sketchfab and Poly Pizza are asset libraries, not image-to-3D generation services.
- `generate_3d` accepts a single **`image: str`** (absolute local path or URL), not an image list. The Rodin helper wraps that one image in a list of length one. Provider multi-view capability does not imply MCP tool multi-view support.
- Submitting through the tool can **upload the image, charge the provider and import the result automatically**. It is not a harmless preview or estimate action.
- **Tripo is Premium-only through this MCP version**. A direct Tripo API key cannot simply be added to this tool's configuration.
- Own-key options: Tencent Hunyuan and Hyper3D direct/fal. Hunyuan also has `LOCAL_API` mode.
- `provider="auto"` prefers Premium Tripo, then Premium Hunyuan, then Premium Hyper3D; own-key selection differs. For cost control, choose a provider explicitly.
- Pending jobs can return a handle after bounded waiting. Resume that handle; do not automatically resubmit a possibly paid job after timeout.
- Hunyuan mainland profile uses `ai3d` (2025-05-13), `ap-guangzhou`; international Pro profile uses `hunyuan` (2023-09-01), `ap-singapore`. Accounts and endpoint families are not interchangeable.
- Local Hunyuan mode expects its compatible local HTTP generation server, not an arbitrary hosted API URL.

### MCP Premium pricing and auth

[Official Premium page](https://www.mcp-for-blender.com/premium), monthly USD prices as read:

| Tier | Monthly price | Included generation allowance |
|---|---:|---|
| Free add-on | $0 | Own provider credentials and provider billing required |
| Hobby | $10 | 25 standard; no high-quality allowance |
| Pro | $20 | 40 standard + 10 high-quality |
| Max | $100 | 100 standard + 40 high-quality; up to 3 concurrent generations |

Page identifies standard as Hunyuan3D v3.1 Rapid or Tripo; high quality as Hunyuan3D v3.1 Pro, Tripo HD textures or Rodin. Pro/Max also advertise Tripo P2. Allowances reset monthly, unused allowance does not roll over, failed generations are not counted per that page; tax extra. Activation uses a **Premium license key** in Blender add-on preferences, up to three computers. No provider key is required on this route, but it is still an external service and upload.

Premium subscription permission is **not verified asset-license clearance**. Confirm the applicable underlying provider/output terms and the Premium contract before shipping commercial assets. No Premium activation or provider configuration was performed.

## 2. Meshy AI

### API and multi-view

Verified current [Multi-Image to 3D documentation](https://docs.meshy.ai/en/api/multi-image-to-3d):

- `POST https://api.meshy.ai/openapi/v1/multi-image-to-3d` creates a task; GET by task ID retrieves status/results.
- `image_urls`: **1–4 images of the same object**, from different angles. Accepts public image URLs or base64 data URIs.
- Inputs: **JPG/JPEG/PNG**; do not assume WebP support for this endpoint.
- Outputs include **GLB, OBJ, FBX, USDZ**; request only required `target_formats` to avoid unnecessary work. GLB preferred for Godot; OBJ requires accompanying material/texture files and is unsuitable for preserving a rig.
- Geometry and texture inputs/options are distinct. A head-only crop is not a full-body fourth view. Multi-view texture controls are model-specific.
- Bearer authentication: `Authorization: Bearer <API key>`. API credit balance must be funded; web app and API entitlements should not be assumed interchangeable.

### Integration

No native Meshy provider was found in installed Blender MCP. Proposed route: Pi runs an explicitly approved local API client → submit once → store job ID → poll → download GLB → import local file through Blender MCP → review and save a new `.blend`. A reviewed Pi tool could wrap the client later; do not install an unverified third-party Meshy MCP server just because its name matches.

No local generation GPU required; local Blender still needs normal viewport resources.

### Credits

[Current API price table](https://docs.meshy.ai/en/api/pricing):

- `meshy-7.1` (current `latest`) multi-image geometry only: **20 credits**.
- With **2K or 4K textures: 30 credits**; 8K: **35 credits**.
- Ultra geometry: **+5 credits** when applicable.
- Remesh: **5 credits**; conversion: **1 credit**. Do not trigger extra steps by default.
- `meshy-6-lite` offers lower-cost options, but that is a different model/quality choice.

The page requires prepaid API credits; a reliable USD-per-credit purchase quote for this account was **not verified**. Do not equate Meshy credits with Tripo credits. Pin `meshy-7.1` rather than `latest`. Documentation warns `meshy-5` retires **2026-10-10**, and legacy `lowpoly` retires **2026-10-30**.

### Game-asset rights and privacy

[Meshy Terms of Use](https://www.meshy.ai/terms-of-use), sections 2.3–2.9 and 3.2–3.3:

- Users must have rights to uploaded inputs.
- Free-plan output is supplied under **CC BY 4.0**, requiring appropriate credit; it is not identical to paid private ownership.
- Paid customers own their output **to the extent possible under applicable law**, subject to the terms; paid privacy settings still need confirmation.
- Publishing to Meshy Community changes the applicable public licensing; **do not publish our references or assets there**.
- Terms address training use, privacy/account choices, AI identifiers and third-party rights. Do not promise unique or infringement-free output.
- Non-enterprise API outputs are stated to be deleted after **3 days**; download and archive promptly.

A paid API account with confirmed private handling is the proposed production route. Confirm how the purchased account is classified under these terms before generation.

## 3. Tripo AI

### API availability and migration

Verified [current V3 migration documentation](https://developers.tripo3d.ai/en/docs/migration-v2-to-v3):

- V3 base: `https://openapi.tripo3d.ai/v3/`.
- Multi-view route: **`POST /v3/generation/multiview-to-model`**.
- V2 stopped maintenance on **2026-10-01** and is scheduled to stop serving requests **2026-11-01**. A model called v3.1 does **not** imply its surrounding API is V3.
- V3 changes task endpoints, parameters and response formats. Review exact current endpoint schema before implementing; do not merely substitute a hostname.
- Official [Python SDK](https://github.com/VAST-AI-Research/tripo-python-sdk) exists, with image/multi-view methods and `TRIPO_API_KEY` environment support. Package/API-generation compatibility must be checked before choosing a release; an SDK README alone does not certify V3 migration.

### Multi-view and formats

The published [H3 multi-view documentation](https://docs.tripo3d.ai/model-generation/multiview-to-model-v3-0-v3-1.html) specifies four ordered slots **[front, left, back, right]**; front required, omitted other slots allowed, at least two supplied images. This is verified behavior of that documented API/model path, **not an assertion that V3 uses the identical JSON payload**.

- URL images: **JPEG/PNG**, up to 20 MB per the H3 page.
- [Direct upload docs](https://docs.tripo3d.ai/file-upload/quick-upload-directly.html) accept **WebP/JPEG/PNG**. Transport differences matter; use PNG for our planned request.
- Generated model export is GLB; [conversion documentation](https://docs.tripo3d.ai/export/conversion.html) includes GLTF, FBX, USDZ, **OBJ**, STL and 3MF. OBJ is not supported for rigged output on the documented route.
- Keep automatic image correction/generation off unless separately approved; the old H3 field is `enable_image_autofix` (default false), but verify its V3 equivalent.

### Integration and authentication

- Direct API: provider-issued API key; keep in `TRIPO_API_KEY` outside source/config files. Use the documented authentication mechanism in the selected V3 client.
- Pi orchestrates a reviewed API client and Blender MCP imports downloaded GLB.
- Existing Blender MCP: Premium license only for Tripo, **one image**. Not a direct-key multi-view integration.
- No local GPU needed for cloud generation. Open-source TripoSR/TripoSG are different products, not proof of local access to the commercial API models.

### Price

[Current V3 pricing](https://developers.tripo3d.ai/en/pricing): **1 credit = $0.01 USD**.

The page's displayed **H-series** table lists image/multi-view:

- Geometry only: **20 credits ($0.20)**.
- Standard texture: **30 credits ($0.30)**.
- Add-ons: HD texture +10, 8K texture +20, HD geometry +20, quad mesh +5, smart low-poly +10, parts +20.
- Basic conversion 5 credits; advanced conversion 10.

These are the displayed H-series prices, not universal P-series/P2 quotes. Confirm chosen model and final estimate before submission; purchase minimums/taxes may exceed one job's marginal cost. Avoid relying on older V2 trial-credit promises.

### Game rights

[Current developer Terms](https://developers.tripo3d.ai/en/terms), sections 3.2 and 5.2:

- Lawful commercial/noncommercial use of output is permitted subject to restrictions, including no competing model/service use and no infringement.
- Free and paid users have materially different rights. Paid users generally receive output rights under stated conditions; provider retains service-provision rights.
- Paid-user section states inputs/outputs will not be used as AI training data; still review privacy/access settings and applicable account contract.
- No promise of uniqueness, factual/anatomical accuracy, or non-infringement.

Use a confirmed **paid API** account and retain a dated terms/billing record. Do not assume a Premium intermediary subscription automatically provides identical direct-account rights without checking.

## 4. Hunyuan3D

Treat local open-weight versions, Tencent mainland cloud, Tencent international cloud and MCP Premium as **different deployments with different rights and capabilities**.

### Cloud API

Verified official [Tencent AI3D SDK request schemas](https://github.com/TencentCloud/tencentcloud-sdk-python/blob/master/tencentcloud/ai3d/v20250513/models.py):

- `SubmitHunyuanTo3DProJobRequest` exposes a primary image and **`MultiViewImages`**. Named additional views include left/right/back, with top/bottom and 45-degree views noted for version 3.1.
- Multi-view inputs: JPG/PNG, one image per view; docs in schema specify >128 and <5000 pixels per side and total encoded size limits (8 MB encoded; approximately 6 MB before base64 expansion).
- Default Pro file group includes **OBJ/GLB**; geometry-only defaults to GLB. Other requested result formats include STL/USDZ/FBX.
- Authentication: Tencent **SecretId + SecretKey**, signed requests, appropriate region/account/service activation. Use restricted credentials rather than the account owner's broad key.
- Installed MCP's own-key path sends one `ImageUrl` or `ImageBase64`; it does **not** expose `MultiViewImages`.

Cloud generation needs no local GPU. **Current direct Tencent prices, international multi-view entitlement, and cloud game-output license terms were not fully verified** due documentation access limitations. Mainland schema support must not be projected onto the international endpoint. Obtain official region-specific terms/price confirmation before use. MCP Premium prices above are verified independently, but do not resolve cloud-output legal terms.

### Local open-weight pipeline

Official sources:

- [Hunyuan3D-2 README](https://github.com/Tencent-Hunyuan/Hunyuan3D-2)
- [2mv multi-view example](https://github.com/Tencent-Hunyuan/Hunyuan3D-2/blob/main/examples/shape_gen_multiview.py)
- [Hunyuan3D-2.1 README](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1)

Verified:

- **Hunyuan3D-2mv** is an explicit multi-view shape model. The example accepts a dictionary of front/left/back images through Pillow and exports GLB. PNG/RGBA illustrated; Pillow-readable JPEG can be decoded, but transparency/background preparation is a separate step.
- Hunyuan3D-2 exposes a Python API, example local HTTP server, and mesh objects exportable to **GLB/OBJ**. A normal 2.1 single-image example is not proof that 2.1 itself accepts the 2mv dictionary.
- Published memory figures: 2.0 **6 GB VRAM shape / 16 GB shape+texture**; 2.1 **10 GB shape / 21 GB texture / 29 GB combined**. These are documented configurations, not guarantees for every resolution/multi-view variant; low-VRAM modes have tradeoffs.
- No per-call provider credits for self-hosted inference. Hardware/rental, electricity, storage, environment setup and model-license compliance remain costs.
- Local authentication can be unnecessary on a private loopback service; model download access may have separate account/license requirements. Never expose an unauthenticated inference server publicly.

Local hardware check: Windows reports **AMD Radeon 780M Graphics**. `nvidia-smi` is not on PATH and no NVIDIA GPU appeared in the video-controller query. WMI reported ~4 GiB AdapterRAM, which is **not a trustworthy dedicated-VRAM measurement for an integrated GPU**. There is no verified supported CUDA deployment here. Do not install multi-gigabyte CUDA dependencies or assume shared RAM satisfies the documented VRAM requirements. A tested remote CUDA machine would be a separate approved plan.

### Licensing warning

Reviewed [2.0 license](https://github.com/Tencent-Hunyuan/Hunyuan3D-2/blob/main/LICENSE) and [2.1 license](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1/blob/main/LICENSE):

- These are **Tencent community licenses, not unrestricted MIT/Apache licenses**.
- They exclude **EU, UK and South Korea** from the defined territory. Clauses explicitly address use/distribution/display of outputs outside that territory.
- Additional commercial permission applies at the stated **more-than-1-million-MAU** threshold, assessed as specified in the license.
- Tencent's lack of ownership claim over generated outputs does **not** remove other restrictions.

This is a major concern for a globally distributed game. **Do not approve worldwide game distribution of locally generated 2.0/2.1 assets without suitable licensing/legal clearance.** These conclusions are specific to the inspected versions; do not automatically apply their license to separately contracted cloud generations.

## 5. Hyper3D Rodin — additional installed MCP service

Included because the installed server supports it, even though it was not separately named in the requested shortlist.

- Installed add-on implements direct Hyper3D jobs and a fal route, plus Premium. Direct endpoint in source: `https://hyperhuman.deemos.com/api/v2/rodin`; own-key fal submission route: `fal-ai/hyper3d/rodin`.
- [fal's Rodin v2 API page](https://fal.ai/models/fal-ai/hyper3d/rodin/v2/api) is publicly available and documents **up to 5 input image URLs**, base64 data-URI file handling, output mesh/textures, and geometry formats **GLB/USDZ/FBX/OBJ/STL**. PNG examples are present; a full MIME/size allowlist was not verified from that page.
- **Do not conflate that `/v2` model with the older own-key fal route hardcoded in the installed add-on.** Full v2 multi-view use needs a separately reviewed client or confirmed integration update.
- Auth: direct Hyper3D API key or fal key; Premium uses its own license activation. No local generation GPU needed.
- Installed `generate_3d` only passes one image, despite lower-level/provider image-list capabilities.
- Exact direct/fal per-generation price was **not verified** from accessible documentation. Through MCP Premium, every Rodin job counts as high-quality; Pro/Max include the allowances above.
- fal's v2 model page is marked **Commercial use**, but that alone is not a complete review of direct Hyper3D/fal/Premium terms, attribution and redistribution. Commercial game clearance remains conditional on the selected service contract.

Not selected as the first fallback because of endpoint/version mismatch and unresolved direct cost/terms—not because quality was benchmarked as inferior.

## 6. Reference suitability for our buffalo

Consult `REFERENCE_ANALYSIS.md` and `BUFFALO_MODEL_SPEC.md` before upload approval:

- Use separate full-body front and side crops, optionally the hero three-quarter image. **Never submit the complete multi-panel sheet as one animal photo**; it can produce duplicated heads, legs or animals.
- Exclude the head close-up from whole-body multi-view inputs unless the chosen API explicitly supports detail conditioning.
- The source has no standalone buffalo silhouette; none will be invented or uploaded as a supposed reference.
- Front is only **174×214**, side **262×214**, hero **520×461**. Horn/body anatomy disagrees between panels, the hero contains background/text, and stance differs. Multi-view support cannot make inconsistent drawings geometrically exact.
- Do not label the three-quarter image as a true left/right orthographic view. Tripo's labeled-slot approach needs careful side assignment and possibly a better reference before spending money.
- Keep original and processed art unchanged. Background masking/padding or other upload preparation requires separate approval and should produce derivative files, not overwrite Task 03 crops. No AI regeneration of missing views.
- Confirm ownership/permission to upload this concept and use derivative commercial assets; possession of a local file is not proof of rights.

## 7. Prepared integration plan — no implementation or generation yet

### Approval gates

1. Select provider/account, exact model and region; confirm paid-output rights, private handling, retention, and intended game markets.
2. Approve the exact reference files and any non-generative cleanup. Resolve whether a low-resolution two-view pilot is worthwhile.
3. Confirm API credit quote and a **hard job/budget cap**. Suggested first request: **one Meshy 7.1 standard geometry + 2K texture job, documented 30 credits**, no Ultra/remesh/rigging extras. This is a proposed cap, not permission to purchase credits.
4. Approve implementation of the small local client and any dependencies. No third-party extension is necessary just to make authenticated HTTPS requests.
5. Complete the pending Pi↔Blender MCP connection/cube validation before using MCP to import/edit results. Task 02 currently records that connection as unverified.

### Credential handling

- Never put actual keys in `.mcp.json`, source files, `.env` files under this project, prompts, command-line arguments, test fixtures, or logs.
- Use an OS credential store or externally injected **process environment** such as `MESHY_API_KEY` / `TRIPO_API_KEY`. If Pi receives tool access, client code should read credentials internally; the model need not see their values.
- For native provider add-on modes, prefer documented environment injection over scene properties that could be saved in a `.blend`. Keep any user-level credential configuration outside source control, with restricted permissions. Blender preferences are not automatically an encrypted vault.
- Redact Authorization headers, Tencent secrets, signed download URLs and base64 image data from logs. Never ask the user to paste a real key into this chat.

### Proposed client behavior

- Default **dry-run** validates image list, selected model, options and estimated cost without upload.
- Separate explicit submit action only after approval; no submission as a side effect of status checks.
- Persist a non-secret job manifest: provider/model, image hashes, options, timestamp, job ID, expected/actual credits, output hashes and applicable license record.
- Poll by ID with bounded retries/backoff. On timeout or restart **resume**, never silently create a duplicate paid job. Stop on changed pricing or unclear status.
- Download outputs promptly into a new staging directory **outside Godot's import tree**. Treat downloaded archives/files as untrusted: prevent archive path traversal, validate format and sizes, never execute embedded scripts.
- Import GLB into a separate Blender collection through MCP after connection verification; inspect scene and screenshot, check dimensions, normals/materials and duplicate/fused anatomy. Save a versioned `.blend`, never overwrite the existing buffalo.
- Correct manually to the agreed species proportions; enforce four legs/cloven hooves, paired lateral/upturned horns and no bison hump. Export a separately reviewed GLB for Godot later.

### Fallback procedure

If Meshy fails the pilot's anatomy/quality review, stop and request approval for **one Tripo V3 H-series multi-view request**. Recheck exact V3 slot schema, model availability and pricing. No automatic provider switching, new subscriptions, Premium activation, extra jobs or credit top-ups.

## 8. Outstanding verification before production

- Paid account status, actual purchase quote/minimum and credit balance for the selected provider.
- Concept-art rights and approved privacy/data handling.
- Exact Tripo V3 multi-view request schema and supported SDK release if selecting fallback.
- Tencent region-specific cloud prices/output rights if reconsidering Hunyuan cloud.
- Hyper3D selected-version price and complete game-asset terms if reconsidering Rodin.
- Pi↔Blender MCP live connection and tool discovery (not established by this research).
- Generated quality, performance and commercial distribution suitability; none can be guaranteed from documentation.

**Stop: awaiting approval before any external image upload, purchase, generation, or integration implementation.**
