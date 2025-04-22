class_name LinkSettings
var node_in: int
var node_out: int
var port: int

func _init(node_in: int, node_out: int, port: int):
	self.node_in = node_in
	self.node_out = node_out
	self.port = port
