@tool
extends Control
class_name JumpDot

@export var color:Color = "ffffff" : set=set_color

signal pressed

var sb_jumps_connected = []
var parent_scene

func set_color(v):
	color = v
	$ColorRect.color = color

func has_point(global_point:Vector2):
	return Rect2(global_position, size).has_point(global_point)

func _on_pressed():
	if SB.drawing_from_jump_from:return
	
	for jump in sb_jumps_connected:
		jump.queue_free()
	
	sb_jumps_connected.clear()

func get_parent_scene_id():
	return parent_scene.id if parent_scene else null
