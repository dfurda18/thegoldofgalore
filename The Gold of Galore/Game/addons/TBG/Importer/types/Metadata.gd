class_name Metadata
var name: String
var value: String
var node: String

func _init(node: String, name: String, value: String):
	self.node = node
	self.name = name
	self.value = value
