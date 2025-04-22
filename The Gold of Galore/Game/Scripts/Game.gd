extends Node2D

@onready var LEVEL:Node = preload("res://Scenes/Level5.tscn").instantiate()

var curr_level

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Title.show()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_title_play():
	$Title.hide()
	curr_level = LEVEL
	add_child(LEVEL)
