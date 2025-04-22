class_name DrawingAnimationSettings
var name: String
var spritesheet: String
var drawings: Dictionary

func _init(name: String, spritesheet: String, drawings: Dictionary):
	self.name = name
	self.spritesheet = spritesheet
	self.drawings = drawings
