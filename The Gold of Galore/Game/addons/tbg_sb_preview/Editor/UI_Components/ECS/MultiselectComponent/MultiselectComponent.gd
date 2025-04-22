@tool
extends Node

@export var do_not_update_list:Array[String] = []

signal property_changed(property, value)
signal multiselect_request_update
signal remove_from_selection

var property_set_from_multiselect = false
var parent
var in_multiselect = false

func _ready():
	parent = get_parent()

func remove_from_selected():
	emit_signal("remove_from_selection")

func show_multiselect_visual(v):
	if parent.has_method("apply_selected_visuals"):
		parent.apply_selected_visuals(v)

func set_property(property, value):
	if not property_set_from_multiselect:
		emit_signal("property_changed", property, value)
	else:
		property_set_from_multiselect = false

func set_property_from_multiselect(property, value):
	if not parent or property in do_not_update_list:return
	property_set_from_multiselect = true
	parent.set(property, value)

func request_update():
	emit_signal("multiselect_request_update")
