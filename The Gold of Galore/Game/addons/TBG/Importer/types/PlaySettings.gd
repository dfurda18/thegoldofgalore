class_name PlaySettings
var name: String
var skeleton: String
var animation: String
var drawing_animation: String
var framerate: int
var length: int
var loop: bool
var facing: String
var mode: String


func _init(
	name: String,
	animation: String,
	drawing_animation: String,
	skeleton: String,
	framerate: int,
	length: int,
	loop: bool,
	facing: String,
	mode: String
):
	self.name = name
	self.skeleton = skeleton
	self.animation = animation
	self.drawing_animation = drawing_animation
	self.framerate = framerate
	self.length = length
	self.loop = loop
	self.facing = facing
	self.mode = mode
