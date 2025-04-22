class_name DrwSettings
var skin_id: int
var name: String
var frame: int
var repeat: int

func _init(skin_id: int, name: String, frame: int, repeat: int):
	self.skin_id = skin_id
	self.name = name
	self.frame = frame
	self.repeat = repeat
