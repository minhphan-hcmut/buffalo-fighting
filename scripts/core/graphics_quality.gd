class_name GraphicsQuality
extends RefCounted
## Graphics settings for weaker machines: a preset (Thấp / Vừa / Cao) that sets five detail
## options the player can also change one by one (khán giả, bóng đổ, môi trường, chi tiết
## model, độ phân giải 3D), plus an FPS limit and an optional FPS readout.
## Presentation only: it changes how much is drawn, never anything a match result depends on.
## Saved in its own file so it never races SessionState's settings file. With nothing saved,
## an integrated or software GPU starts on Thấp and every other GPU on Cao.
## Headless test scripts (`--script`) neither read nor write the player's file: they always
## start on Cao, so a player's saved choice can never change what a test sees.

const LOW := 0
const MEDIUM := 1
const HIGH := 2
const CUSTOM := 3
const PRESET_NAMES := ["Thấp", "Vừa", "Cao", "Tùy chỉnh"]
## Detail options in display order: key, label, the name of each choice (lowest first).
const DETAILS := [
	["crowd", "Khán giả", ["Thưa", "Vừa", "Đầy đủ"]],
	["shadows", "Bóng đổ", ["Tắt", "Thấp", "Cao"]],
	["scenery", "Môi trường", ["Gọn", "Đầy đủ"]],
	["models", "Chi tiết model (trâu, người)", ["Thấp", "Cao"]],
	["render_scale", "Độ phân giải 3D", ["70%", "85%", "100%"]],
]
## What each preset sets, per detail key (choice index).
const PRESETS := [
	{"crowd": 0, "shadows": 1, "scenery": 0, "models": 0, "render_scale": 0},
	{"crowd": 1, "shadows": 1, "scenery": 1, "models": 1, "render_scale": 2},
	{"crowd": 2, "shadows": 2, "scenery": 1, "models": 1, "render_scale": 2},
]
## FPS limit choices (independent of the preset): 0 follows the screen with VSync, -1 is
## unlimited, any other value caps the frame rate with VSync off.
const FPS_LIMITS := [0, 30, 60, 90, 120, 144, -1]
const FPS_LIMIT_NAMES := ["Theo màn hình", "30", "60", "90", "120", "144", "Không giới hạn"]
const DEFAULT_PATH := "user://graphics.cfg"

static var path := DEFAULT_PATH
static var _details := {}
static var _show_fps := false
static var _fps_limit := 0
static var _loaded := false
static var _lod_meshes := {}


## The preset the current details match, or CUSTOM.
static func preset() -> int:
	_load()
	for index in PRESETS.size():
		if PRESETS[index] == _details:
			return index
	return CUSTOM


## The chosen value (choice index) of a detail option.
static func detail(key: String) -> int:
	_load()
	return int(_details.get(key, PRESETS[HIGH][key]))


## Sets every detail from a preset, saves and applies what can change live.
static func set_preset(index: int) -> void:
	_load()
	_details = (PRESETS[clampi(index, LOW, HIGH)] as Dictionary).duplicate()
	_save()
	apply_live()


## Sets one detail option, saves and applies what can change live.
static func set_detail(key: String, value: int) -> void:
	_load()
	_details[key] = value
	_save()
	apply_live()


## Whether the FPS readout is on.
static func show_fps() -> bool:
	_load()
	return _show_fps


## Turns the FPS readout on or off and saves it.
static func set_show_fps(enabled: bool) -> void:
	_load()
	_show_fps = enabled
	_save()
	_ensure_fps_overlay()


## The chosen FPS limit (index into FPS_LIMITS).
static func fps_limit() -> int:
	_load()
	return _fps_limit


## Sets the FPS limit, saves it and applies it at once.
static func set_fps_limit(index: int) -> void:
	_load()
	_fps_limit = clampi(index, 0, FPS_LIMITS.size() - 1)
	_save()
	apply_fps_limit()


## Applies the FPS limit: VSync for "Theo màn hình", otherwise VSync off and `Engine.max_fps`
## set to the cap (0 = unlimited).
static func apply_fps_limit() -> void:
	var limit: int = FPS_LIMITS[fps_limit()]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if limit == 0 else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = maxi(limit, 0)


## The preset a machine gets before the player picks one.
static func auto_preset() -> int:
	var adapter := RenderingServer.get_video_adapter_type()
	if adapter == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU or adapter == RenderingDevice.DEVICE_TYPE_CPU:
		return LOW
	return HIGH


## Applies the live options (render scale, model detail, shadow atlas, FPS limit) to the main
## window and adds the FPS readout if it is on. Crowd, shadow and scenery changes to an arena
## already built show from the next one.
static func apply_live() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	apply_viewport(tree.root)
	tree.root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	tree.root.scaling_3d_scale = [0.7, 0.85, 1.0][detail("render_scale")]
	apply_fps_limit()
	RenderingServer.directional_shadow_atlas_set_size(GameBalance.get_int("graphics_shadow_atlas_low", 2048) if detail("shadows") < 2 else GameBalance.get_int("graphics_shadow_atlas_high", 4096), true)
	_ensure_fps_overlay()


## Model detail and MSAA for any viewport that renders the 3D scene (main window, menu
## backdrop, Phần Lễ, how-to-play demo).
static func apply_viewport(viewport: Viewport) -> void:
	viewport.mesh_lod_threshold = GameBalance.get_number("graphics_model_lod_low", 8.0) if detail("models") == 0 else 1.0
	if viewport is SubViewport:
		viewport.msaa_3d = Viewport.MSAA_2X if preset() == HIGH else Viewport.MSAA_DISABLED


## Applies the shadow option to a sun.
static func apply_sun(light: DirectionalLight3D) -> void:
	var shadows := detail("shadows")
	light.shadow_enabled = shadows > 0
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if shadows == 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


## Share of crowd seats that get a villager, on top of the stands' own empty seats.
static func crowd_density() -> float:
	return GameBalance.get_number(["graphics_crowd_density_low", "graphics_crowd_density_medium", "graphics_crowd_density_high"][detail("crowd")], 1.0)


## How many trees the outer grove gets (0 on Gọn).
static func grove_count(full: int) -> int:
	return full if detail("scenery") == 1 else 0


## Small spatial batches retain fence culling; other presets keep the original mesh nodes.
static func fence_batch_size() -> int:
	return maxi(1, GameBalance.get_int("graphics_fence_batch_segments_low")) if preset() == LOW else 1


static func hud_refresh_interval() -> float:
	var hz := GameBalance.get_number("graphics_hud_refresh_hz_low") if preset() == LOW else 0.0
	return 1.0 / hz if hz > 0.0 else 0.0


static func vfx_particle_scale() -> float:
	return GameBalance.get_number("graphics_vfx_particle_scale_low", 1.0) if preset() == LOW else 1.0


static func vfx_dust_lifetime_scale() -> float:
	return GameBalance.get_number("graphics_vfx_dust_lifetime_scale_low", 1.0) if preset() == LOW else 1.0


static func vfx_secondary_enabled() -> bool:
	return preset() != LOW or GameBalance.get_int("graphics_vfx_secondary_enabled_low", 1) != 0


## The crowd villager mesh: the full bake on Đầy đủ, a simplified copy otherwise.
static func crowd_mesh(full: ArrayMesh) -> ArrayMesh:
	if detail("crowd") == 2 or full == null:
		return full
	if _lod_meshes.has(full):
		return _lod_meshes[full]
	var arrays := full.surface_get_arrays(0)
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(25.0, 60.0, [])
	var simplified := full
	if importer.get_surface_lod_count(0) > 0:
		arrays[Mesh.ARRAY_INDEX] = importer.get_surface_lod_indices(0, 0)
		simplified = ArrayMesh.new()
		simplified.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_lod_meshes[full] = simplified
	return simplified


## Forgets the loaded state so the next call reads `new_path` (tests).
static func reset(new_path: String = DEFAULT_PATH) -> void:
	path = new_path
	_loaded = false
	_details = {}
	_show_fps = false
	_fps_limit = 0


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if _scripted():
		_details = (PRESETS[HIGH] as Dictionary).duplicate()
		return
	_details = (PRESETS[auto_preset()] as Dictionary).duplicate()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for entry in DETAILS:
		var key: String = entry[0]
		var value: Variant = config.get_value("graphics", key, _details[key])
		if value is int and value >= 0 and value < (entry[2] as Array).size():
			_details[key] = value
	var fps: Variant = config.get_value("graphics", "show_fps", false)
	_show_fps = fps if fps is bool else false
	var limit: Variant = config.get_value("graphics", "fps_limit", 0)
	_fps_limit = limit if limit is int and limit >= 0 and limit < FPS_LIMITS.size() else 0


static func _save() -> void:
	if _scripted():
		return
	var config := ConfigFile.new()
	for key in _details:
		config.set_value("graphics", key, _details[key])
	config.set_value("graphics", "show_fps", _show_fps)
	config.set_value("graphics", "fps_limit", _fps_limit)
	config.save(path)


# A test script on the default path: keep the player's graphics file out of it.
static func _scripted() -> bool:
	return path == DEFAULT_PATH and OS.get_cmdline_args().has("--script")


static func _ensure_fps_overlay() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var overlay := tree.root.get_node_or_null("FpsOverlay")
	if overlay == null and _show_fps:
		overlay = FpsOverlay.new()
		overlay.name = "FpsOverlay"
		tree.root.add_child.call_deferred(overlay)
	elif overlay != null:
		overlay.visible = _show_fps
