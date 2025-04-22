@tool
extends Label

@export var visible_chars = 8

func set_text(v:String):
	if v.length() > visible_chars:
		text = v.substr(0, visible_chars) + "..."
	else:
		text = v
