@tool
extends Label

@export var font_size = 18
@export var start_size = Vector2(92, 70)
@export var start_scale = Vector2.ONE
@export var scale_font = 3.0

var updated_size = true

func _ready():
	update_scale()

func _process(delta):
	if not updated_size:
		updated_size = true
		set_deferred("size", start_size * scale_font)

func update_scale():
	scale = start_scale / scale_font
	set("theme_override_font_sizes/font_size", font_size*scale_font)
	updated_size = false

func update_font_scale(s):
	start_size = s
	update_scale()
