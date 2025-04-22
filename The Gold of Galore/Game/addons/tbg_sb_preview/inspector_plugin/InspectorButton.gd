@tool
extends MarginContainer
class_name InspectorToolButton

var object: Object

func init(obj: Object, text:String):
	object = obj
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var button := Button.new()
	add_child(button)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.text = text
	button.button_down.connect(object._on_editor_button_pressed.bind(text))
