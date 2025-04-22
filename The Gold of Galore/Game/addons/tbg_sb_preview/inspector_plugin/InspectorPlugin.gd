@tool
extends EditorInspectorPlugin

const INSPECTOR_BUTTON = preload("res://addons/tbg_sb_preview/inspector_plugin/InspectorButton.gd")

var button_text : String

func _can_handle(object) -> bool:
	return true

func _parse_property(
	object: Object, type: Variant.Type, 
	name: String, hint_type: PropertyHint, 
	hint_string: String, usage_flags, wide: bool):
	if name.begins_with("editor_button_"):
		var s = str(name.split("editor_button_")[1])
		s = s.capitalize()
		s = "%s" % s
		var inspector_btn = INSPECTOR_BUTTON.new()
		inspector_btn.init(object, s)
		add_custom_control(inspector_btn)
		return true #Returning true removes the built-in editor for this property
	return false # else leave it
