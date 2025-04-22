@tool
## Button used in the custom viewport to create collasible sections (Motion and Skin lists)
extends Button

const TbgPlugin = preload("res://addons/TBG/Editor/Plugin.gd")

@export var translation_key:String = "" : set=set_translated_text

var _siblings
var _parent_size_flags

var expanded = true:
	set(value):
		if value == expanded:
			return
		expanded = value
		var parent : Control = get_parent()
		if parent:
			if value:
				parent.size_flags_vertical = _parent_size_flags
				# HACK: Buffer to make sure the ui works
				var total_size = size.y + 50.0
				for node in _siblings:
					node.visible = true
					total_size += node.custom_minimum_size.y if \
							node.custom_minimum_size.y else node.size.y
				parent.custom_minimum_size.y = total_size
			else:
				_parent_size_flags = parent.size_flags_vertical
				_siblings = parent.get_children().filter(func(e):
					return e != self and e.get("visible")
				)
				parent.size_flags_vertical &= ~SIZE_EXPAND
				parent.custom_minimum_size.y = 0.0
				for node in _siblings:
					node.visible = false


func _ready():
	update_size()


func _pressed():
	expanded = not expanded


func update_size():
	var parent : Control = get_parent()
	if not expanded:
		parent.custom_minimum_size.y = 0.0
		return
	
	if _siblings == null:
		_siblings = parent.get_children().filter(func(e):
			return e != self and e.get("visible")
		)
	
	var total_size = size.y + 50.0
	for node in _siblings:
		total_size += node.custom_minimum_size.y if \
				node.custom_minimum_size.y else node.size.y
	parent.custom_minimum_size.y = total_size


func set_translated_text(v):
	translation_key = v
	text = TbgPlugin.get_tr(translation_key)
