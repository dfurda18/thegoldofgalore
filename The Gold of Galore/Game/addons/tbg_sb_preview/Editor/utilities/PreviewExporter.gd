@tool
extends Node

func get_changeset_data(node_type, scene_id, data, queued_update={}):
	var changeset = queued_update
	
	if changeset.is_empty():
		changeset = get_default_data(scene_id)
	
	match node_type:
		SB.NODE_TYPE.SCENE:
			add_scene_data(changeset, scene_id, data)
		SB.NODE_TYPE.PANEL:
			add_panel_data(changeset, scene_id, data)
		SB.NODE_TYPE.JUMP:
			add_jump_data(changeset, scene_id, data)
	
	return changeset

func add_scene_data(changeset, scene_id, data):
	var scenes = changeset.results.scenes
	
	data["operation"] = SB.operations.edit
	
	var i = 0
	for scene in scenes:
		if scene.id == scene_id:
			changeset.results.scenes[i] = SB.merge_dictionaries(changeset.results.scenes[i], data)
			for panel in changeset.results.scenes[i].panels:
				panel["operation"] = "edit"
			return
		i += 1
	
	data.merge({
		"jumpInfos" : [],
		"panels" : []
	})
	
	changeset.results.scenes.append(data)

func add_panel_data(changeset, scene_id, data):
	var panels
	var append_new_scene = false
	var scenes = changeset.results.scenes
	
	data["operation"] = SB.operations.edit
	
	var scene_idx = 0
	for scene in scenes:
		if scene.id == scene_id:
			panels = scene.panels
			break
		scene_idx += 1
	
	if panels == null:
		panels = []
		append_new_scene = true
	
	var i = 0
	for panel in panels:
		if panel.id == data.id:
			var dict = changeset.results.scenes[scene_idx].panels[i]
			changeset.results.scenes[scene_idx].panels[i] = SB.merge_dictionaries(dict, data)
			return
		i += 1
	
	if append_new_scene:
		changeset.results.scenes.append({
			"id" : scene_id,
			"jumpInfos" : [],
			"panels" : [data],
			"operation":"edit"
		})
	else:
		changeset.results.scenes[scene_idx].panels.append(data)

func add_jump_data(changeset, scene_id, data):
	var jumps
	var append_new_scene = false
	var scenes = changeset.results.scenes
	
	data["operation"] = SB.operations.edit
	
	var scene_idx = 0
	for scene in scenes:
		if scene.id == scene_id:
			jumps = scene.jumpInfos
			break
		scene_idx += 1
	
	if jumps == null:
		jumps = []
		append_new_scene = true
	
	var i = 0
	for jump in jumps:
		if jump.index == data.index:
			var dict = changeset.results.scenes[scene_idx].jumpInfos[i]
			changeset.results.scenes[scene_idx].jumpInfos[i] = SB.merge_dictionaries(dict, data)
			return
		i += 1
	
	if append_new_scene:
		changeset.results.scenes.append({
			"id" : scene_id,
			"jumpInfos" : [data],
			"panels" : [],
			"operation":"edit"
		})
	else:
		changeset.results.scenes[scene_idx].jumpInfos.append(data)

func get_default_data(scene_id, op=SB.operations.edit):
	return {
		"error" : "",
		"results" : {
			"scenes": [
				{
					"id" : scene_id,
					"jumpInfos" : [],
					"panels" : [],
					"operation":op
				}
			]
		},
		"success" : true
	}
