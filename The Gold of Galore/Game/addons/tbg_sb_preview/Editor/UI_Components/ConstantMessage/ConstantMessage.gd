@tool
extends Panel

@onready var text_label = $VBoxContainer/MarginContainer/HBoxContainer/Label

var font_size = 14
var last_msg

var minimum_height : int :
	get:
		return custom_minimum_size.y / SB.get_screen_scale()
	set(value):
		custom_minimum_size.y = value * SB.get_screen_scale()
		if custom_minimum_size.y < size.y:
			custom_minimum_size.y = size.y
		if text_label:
			text_label.set("theme_override_font_sizes/font_size", font_size * SB.get_screen_scale())

func _ready():
	if SB.get_screen_scale() > 1.0:
		minimum_height = 80
	else:
		minimum_height = 80

func set_message_text(text):
	if last_msg != null and last_msg == text:
		return
	text_label.text = text
	last_msg = text
	show()

func set_color(color):
	text_label.set("theme_override_colors/font_color", color)
	text_label.set("theme_override_colors/font_outline_color", color)

func _on_pressable_pressed():
	hide()
