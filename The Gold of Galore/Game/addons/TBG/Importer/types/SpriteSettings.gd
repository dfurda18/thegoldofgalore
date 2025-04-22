class_name SpriteSettings

var filename: String
var rect: Array
var scale_x: float
var scale_y: float
var offset_x: float
var offset_y: float
var name: String

func _init(rect: Array, scale_x: float, scale_y: float, offset_x: float, offset_y: float, name: String):
	self.rect = rect
	self.scale_x = scale_x
	self.scale_y = scale_y
	self.offset_x = offset_x
	self.offset_y = offset_y
	self.name = name
