class_name InputFrame
extends RefCounted

var player_slot := 1
var move := Vector2.ZERO
var camera_yaw := 0.0
var horn_pressed := false
var dash_pressed := false
var guard_held := false
var guard_pressed := false
var clash_action: StringName = &"PUSH"
var seq := 0


func _init(slot: int = 1) -> void:
	player_slot = slot
