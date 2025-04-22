@tool
extends Control

@export var ButtonScene:PackedScene
@export var SeparatorScene:PackedScene

@export var minimum_size = Vector2(40,40) :
	set(value):
		var screen_scale = SB.get_screen_scale()
		custom_minimum_size.y = value.y * screen_scale * (1.5 if OS.get_name() == "macOS" else 0.8)
		custom_minimum_size.x = value.x * screen_scale * (1.2 if OS.get_name() == "macOS" else 1.0)

@onready var container = $VBoxContainer

func _ready():
	hide()

#Takes
func show_menu(options:Array, callback_methods:Array):
	for c in container.get_children():
		c.queue_free()
	
	if options.size() != callback_methods.size():
		return
	
	var min_height = 25
	var min_width = minimum_size.x
	
	for i in options.size():
		var button:Button = ButtonScene.instantiate()
		container.add_child(button)
		button.text = options[i]
		button.pressed.connect(callback_methods[i])
		button.pressed.connect(_on_button_pressed)
		
		if i != options.size()-1:
			var separator = SeparatorScene.instantiate()
			container.add_child(separator)
			min_height += separator.custom_minimum_size.y
		
		min_height += button.custom_minimum_size.y
		min_width = button.size.x
	
	minimum_size = Vector2(min_width, min_height)
	size.y = min_height
	size.x = min_width
	show()
	global_position = get_global_mouse_position()

func hide_menu():
	hide()

func _on_button_pressed():
	hide_menu()

func _on_storyboard_view_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index != 2:
			hide_menu()
