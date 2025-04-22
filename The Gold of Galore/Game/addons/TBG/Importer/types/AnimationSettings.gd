class_name  AnimationSettings
var name: String
var attr_links: Array
var timed_values: Dictionary  # Using Dictionary instead of ILookup

func _init(name: String, attr_links: Array, timed_values: Dictionary):
	self.name = name
	self.attr_links = attr_links
	self.timed_values = timed_values
