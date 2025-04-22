class_name StageNodeSettings
var drw_id: int
var name: String
var group_id: int
var skin_ids: Array

func _init(drw_id: int, name: String, group_id: int, skin_ids: Array):
	self.drw_id = drw_id
	self.name = name
	self.group_id = group_id
	self.skin_ids = skin_ids
