@tool
## Allows for zooming in and out of the ToonBoom view
extends MarginContainer

const TbgPlugin = preload("Plugin.gd")

signal zoom_in
signal zoom_out

var tb_editor_visible = false


func _ready():
	TbgPlugin.instance.toon_boom_editor_visibility_changed.connect(_toon_boom_editor_visibility_changed)


func _input(event):
	if event is InputEventMouseButton and mouse_inside() and tb_editor_visible:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in.emit()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out.emit()


func mouse_inside():
	var rect = get_global_rect()
	return rect.has_point(get_global_mouse_position())


func _toon_boom_editor_visibility_changed(v):
	tb_editor_visible = v
