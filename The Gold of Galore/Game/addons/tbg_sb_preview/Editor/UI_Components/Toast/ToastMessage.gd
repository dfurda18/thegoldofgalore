@tool
extends Panel

@onready var text_label = $VBoxContainer/MarginContainer/HBoxContainer/Label
@onready var progress_bar = $VBoxContainer/MarginContainer2/ProgressBar
@onready var timer = $Timer

signal kill

var font_size = 14

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
		minimum_height = 38
	else:
		minimum_height = 10

func set_message_text(text):
	text_label.text = text

func set_color(color):
	text_label.set("theme_override_colors/font_color", color)
	text_label.set("theme_override_colors/font_outline_color", color)

func _process(delta):
	progress_bar.value = timer.time_left / timer.wait_time * 100

func _on_timer_timeout():
	emit_signal("kill")

func _on_pressable_pressed():
	emit_signal("kill")
	timer.paused = true
