class_name MenuBackdrop
extends Node3D
## 3D scene behind the main menu: the festival arena (ArenaBuilder + ArenaDressing) with
## the red and blue buffaloes squaring up mid-arena and their handlers waiting behind
## them. The camera sways slowly in front of the pavilion. Presentation only; meant to
## live in its own SubViewport (see MainMenu).

const BUFFALO_MODEL: PackedScene = preload("res://assets/characters/buffalo_hero/buffalo_hero.glb")
## Half the gap between the two buffaloes' centres, in metres.
const STANCE_HALF_GAP := 1.6

var camera: Camera3D
var elapsed := 0.0
var _buffaloes: Array[Node3D] = []


func _ready() -> void:
	var no_mud: Array[StringName] = []
	ArenaBuilder.build(self, no_mud)
	for side in [-1.0, 1.0]:
		var buffalo := Node3D.new()
		buffalo.name = "RedBuffalo" if side < 0.0 else "BlueBuffalo"
		buffalo.position = Vector3(side * STANCE_HALF_GAP, 0.0, 0.0)
		# The model faces -Z; turn each one toward the other.
		buffalo.rotation.y = side * PI * 0.5
		add_child(buffalo)
		var model := BUFFALO_MODEL.instantiate()
		buffalo.add_child(model)
		BuffaloAnimator.make_matte(model)
		if side > 0.0:
			Buffalo.dress_west(model)
		_buffaloes.append(buffalo)
		var handler := LowPoly.villager(self, Vector3(side * (STANCE_HALF_GAP + 2.2), 0.0, -3.8), side * PI * 0.5, Color("#8E2B22") if side < 0.0 else Color("#2E5E80"))
		handler.name = "Handler"
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = GameBalance.get_number("ui_menu_camera_fov_deg")
	# Shift the picture so the buffaloes sit right of the menu column.
	camera.h_offset = GameBalance.get_number("ui_menu_camera_h_offset")
	add_child(camera)
	camera.current = true
	_place_camera()


func _process(delta: float) -> void:
	elapsed += delta
	_place_camera()
	# Slow breathing, out of step between the two buffaloes.
	for index in _buffaloes.size():
		var breath := sin(elapsed * TAU / GameBalance.get_number("ui_menu_breath_s") + index * 1.7)
		_buffaloes[index].scale = Vector3(1.0, 1.0 + breath * 0.012, 1.0 + breath * 0.006)


## Camera on an arc in front of the pavilion (+Z side), swinging back and forth.
func _place_camera() -> void:
	var period := maxf(1.0, GameBalance.get_number("ui_menu_camera_period_s"))
	var angle := deg_to_rad(GameBalance.get_number("ui_menu_camera_swing_deg")) * sin(elapsed * TAU / period)
	var radius := GameBalance.get_number("ui_menu_camera_radius")
	camera.position = Vector3(sin(angle) * radius, GameBalance.get_number("ui_menu_camera_height"), cos(angle) * radius)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
