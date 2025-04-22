@tool
## Custom button type that allows fetching icons by name and self-resizing
extends Button
#class_name EditorButton

const TbgPlugin = preload("Plugin.gd")

var icon_name: String :
	set(value):
		if icon_name != value:
			icon_name = value
			var _icon
			if theme:
				_icon = theme.get_icon(icon_name, "EditorIcons")
			else:
				_icon = TbgPlugin.Editor.get_icon(icon_name)
			
			if _icon:
				icon = _icon


var icon_size: int:
	get:
		return custom_minimum_size.y / get_screen_scale()
	set(value):
		custom_minimum_size = Vector2.ONE * (value * get_screen_scale())


func _get_property_list():
	return [{ 
		"name": "icon_name",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT, 
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": " ," + ",".join(
			theme.get_icon_list("EditorIcons") if theme else 
			TbgPlugin.Editor.get_icon_list()
		)
	},
	{ 
		"name": "icon_size",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, 
	}]


func _notification(what):
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		icon = null
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		var iname = icon_name
		icon_name = ""
		icon_name = iname


func _init():
	icon_size = 48
	expand_icon = true
	flat = true


func get_screen_scale()->float:
	return maxf(DisplayServer.screen_get_size().x / 1920.0, 1.0)
