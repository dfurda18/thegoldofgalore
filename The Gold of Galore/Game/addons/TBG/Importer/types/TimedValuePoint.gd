class_name TimedValuePoint
var x: float
var y: float
var z: float
var lx: float
var ly: float
var rx: float
var ry: float
var locked_in_time: float
var const_seg: bool
var start: int

func _init(x: float, y: float, z: float, lx: float, ly: float, rx: float, ry: float, locked_in_time: float, const_seg: bool, start: int):
	self.x = x
	self.y = y
	self.z = z
	self.lx = lx
	self.ly = ly
	self.rx = rx
	self.ry = ry
	self.locked_in_time = locked_in_time
	self.const_seg = const_seg
	self.start = start
