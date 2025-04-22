class_name SpriteSheetSettings

var name: String
var filename: String
var resolution: String
var width: int
var height: int
var sprites: Array

func _init(name: String, filename: String, resolution: String, width: int, height: int, sprites: Array):
	self.name = name
	self.filename = filename
	self.resolution = resolution
	self.width = width
	self.height = height
	self.sprites = sprites
