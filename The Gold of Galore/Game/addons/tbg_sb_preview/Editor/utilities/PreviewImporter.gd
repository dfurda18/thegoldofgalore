@tool
extends Node

const api = "http://127.0.0.1"
const port = 2666
const api_all_data = "gameStoryboard/exportJson"

var SB_Node = load("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Node/SB_Node.tscn")
var SB_Panel = load("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Panel/SB_Panel.tscn")
var SB_Scene = load("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Scene/SB_Scene.tscn")
var Jump = load("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Jump/SB_Jump.tscn")
var thumbnails_path = ""
var thumbnails_folder = "images"

func import_preview(data):
	var gsb_data = FileAccess.open("user://test_gs.json", FileAccess.WRITE)
	gsb_data.store_line(JSON.stringify(data))
	gsb_data.close()
	
	var container = SB.storyboard_view.container
	
	var created_scenes = []
	
	thumbnails_folder = data["results"]["imagePath"]
	
	var all_current_scenes = container.get_children()
	
	#add scenes from gsb data
	for scene_data in data["results"]["scenes"]:
		var sb_scene
		var scene_deleted_id
		for scene in container.get_children():
			if scene.id == scene_data.id:
				sb_scene = scene
				all_current_scenes.erase(scene)
				break
		if not sb_scene:
			sb_scene = SB_Scene.instantiate()
			container.add_child(sb_scene)
			created_scenes.append(sb_scene)
		
		#panels are added in scene.set_data method
		sb_scene.set_data(scene_data, true)
	
	#delete scenes that no longer exist on gsb side
	for scene in all_current_scenes:
		scene.delete_scene()
	
	# position scenes around when loaded from gs data so they are not stacked on top of each other
	# if scenes dont already have a custom position set from sb preview
	var scene_idx = 0
	
	for scene in created_scenes:
		var scene_data:Dictionary = data["results"]["scenes"][scene_idx]
		scene_idx += 1
		if scene_data.has("metadata"):
			if scene_data.metadata.has("position_x"):
				scene.position.x = scene_data.metadata.position_x
			if scene_data.metadata.has("position_y"):
				scene.position.y = scene_data.metadata.position_y
	
	#add jumps from data
	for scene_data in data["results"]["scenes"]:
		var sb_scene
		for scene in container.get_children():
			if scene.id == scene_data.id:
				sb_scene = scene
				break
		
		if not sb_scene:
			continue
		
		if not scene_data.has("jumpInfos"):
			#if there are no jumps in data for particular scene, clear all jumps in case there is one left
			for jump in sb_scene.sb_jumps_container.get_children():
				jump.set_delete(true)
			continue
		
		var all_jumps = sb_scene.sb_jumps_container.get_children()
		
		for jump_data in scene_data["jumpInfos"]:
			if jump_data.has("hasValidDestination") and jump_data.hasValidDestination:
				var jump_exists = false
				for jump in sb_scene.sb_jumps_container.get_children():
					if jump.jump_to.id == jump_data.jumpTo and jump.index == jump_data.index:
						jump.set_data(jump_data)
						jump_exists = true
						all_jumps.erase(jump)
						break
						
				if not jump_exists:
					sb_scene.add_jump_from_data(jump_data)
		
		#delete jumps that no longer exist on gsb side
		for jump in all_jumps:
			jump.set_delete(true)
	
	SB.apply_auto_layout()

func sort_scenes_by_jumps_amount(a,b):
	return a.sb_jumps_container.get_child_count() > b.sb_jumps_container.get_child_count()

func import_thumbnails(result=null):
	if result != null:
		thumbnails_path = result["results"]
	
	for scene in SB.storyboard_view.container.get_children():
		for panel in scene.sb_panel_container.get_children():
			panel.set_image(thumbnails_path+"/"+thumbnails_folder)
		
		scene.set_thumbnail()

func get_scene_from_container(id, container):
	for scene in container.get_children():
		if scene.id == id:
			return scene

func get_data():
	return {
		"thumbnails_path" : thumbnails_path,
		"thumbnails_folder" : thumbnails_folder
	}

func set_data(data):
	for key in data:
		set(key, data[key])
