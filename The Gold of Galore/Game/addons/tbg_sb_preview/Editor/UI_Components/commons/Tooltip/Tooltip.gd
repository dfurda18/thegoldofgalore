@tool
extends Control

@export var offset := Vector2(10,-7)

@onready var label = $Label

var is_press_active = false
var font_size = 11

var height : int :
	get:
		return custom_minimum_size.y / SB.get_screen_scale()
	set(value):
		custom_minimum_size = Vector2.ONE * (value * SB.get_screen_scale())
		size = custom_minimum_size
		if label:
			label.set("theme_override_font_sizes/font_size", font_size * SB.get_screen_scale())

func _ready():
	height = 20

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_position = get_global_mouse_position() + offset - label.position - Vector2(0,label.size.y)

func on_pressable_hover(show, ov, text):
	if is_press_active:
		return
	
	if label.visible and show and not ov:
		return
	
	if text == null or text.is_empty():
		return
	
	label.visible = show
	label.text = SB.get_tr(text)
	global_position = get_global_mouse_position() + offset - label.position - Vector2(0,label.size.y)

func on_pressable_pressed():
	is_press_active = true
	label.visible = false

func on_pressable_released():
	is_press_active = false

func hide_tooltip():
	label.visible = false
