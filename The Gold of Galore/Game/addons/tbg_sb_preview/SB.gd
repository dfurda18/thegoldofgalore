@tool
extends Node
class_name Sb

enum NODE_TYPE {
	SCENE,
	PANEL,
	JUMP
}

enum REQUEST {
	GET_DATA_FROM_GS = 0,
	SAVE_GS = 1,
	EXPORT_THUMBNAILS = 2,
	UPDATE_GS = 3,
	UPDATE_GS_QUEUED_UPDATE = 4,
	GET_SCENE_DATA_FROM_GS = 5,
	ADD_SCENE = 6,
	ADD_PANEL = 7,
	ADD_JUMP = 8,
	DELETE_SCENE = 9,
	DELETE_PANEL = 10,
	DELETE_JUMP = 11,
	MOVE_PANEL = 12,
	SYNC_UPDATE_DATA = 13,
	SYNC_ADD_DELETE_DATA = 14,
	GET_GS_DATA_BEFORE_SYNC = 15
}

enum TOAST_TYPE{
	SUCCESS,
	ERROR,
	INFO
}

var thumbnails_export_type := {
	"all" : "all",
	"scene" : "scene",
	"panel" : "panel",
	"none" : "none"
}

var operations := {
	"add" : "add",
	"edit" : "edit",
	"delete" : "delete",
	"move" : "move"
}

var preview_active = false
var inspector
var plugin
var drawing_from_jump_from = false
var storyboard_view
var auto_layout_enabled = true
var jump_auto_position_enabled = true
static var translations = preload("res://addons/tbg_sb_preview/translations/Translations.gd").new()

#Used for checking that no two pressables or SB Node is pressed at the same time
#example: clicking collapse button on scene will also trigger moving the scene
var obj_pressed = -1

var undo:EditorUndoRedoManager
var next_id:int = 0
var auto_layout = preload("res://addons/tbg_sb_preview/Editor/utilities/AutoLayout.gd").new()

signal sb_node_drag(drag_active)
signal change_cursor_shape(shape)
signal node_selected(node)
signal request_gs_update(node_type, scene_id, data, operation, args)
signal request_gs_add_delete(data, args, request_type)

func set_pressed(obj, pressed):
	if obj_pressed == -1 and pressed:
		obj_pressed = obj.get_instance_id()
	elif not pressed and obj_pressed == obj.get_instance_id():
		set_deferred("obj_pressed", -1)

func is_something_pressed()->bool:
	return obj_pressed != -1

func open_context_menu(options:Array, methods:Array):
	storyboard_view.context_menu.show_menu(options, methods)

func request_update(node_type, last_data, cur_data, scene_id, keep=[], skip=[], keep_all=false):
	var data = last_data
	
	if not keep_all:
		data = subtract_dictionaries(last_data, cur_data, keep, skip)
	else:
		data = cur_data
	
	var send_update = check_send_update(data, keep)
	
	if send_update:
		emit_signal("request_gs_update", node_type, scene_id, data)

func update_gs(data, args, request_type):
	storyboard_view.api_handler.update_gs(data, args, request_type)

func add_to_gs(scene_id, args, request_type, data={}):
	var total_data = storyboard_view.preview_exporter.get_default_data(scene_id, SB.operations.edit)
	
	match request_type:
		SB.REQUEST.ADD_SCENE:
			total_data = storyboard_view.preview_exporter.get_default_data(scene_id, SB.operations.add)
			total_data.results.scenes[0]["after"] = true
		SB.REQUEST.ADD_PANEL:
			data["operation"] = SB.operations.add
			total_data.results.scenes[0].panels.append(data)
		SB.REQUEST.ADD_JUMP:
			data["operation"] = SB.operations.add
			total_data.results.scenes[0].jumpInfos.append(data)
	
	emit_signal("request_gs_add_delete", total_data, args, request_type)

func delete_from_gs(scene_id, data, request_type, args={}):
	var total_data = storyboard_view.preview_exporter.get_default_data(scene_id, SB.operations.edit)
	
	match request_type:
		SB.REQUEST.DELETE_SCENE:
			total_data = storyboard_view.preview_exporter.get_default_data(scene_id, SB.operations.delete)
		SB.REQUEST.DELETE_PANEL:
			data["operation"] = SB.operations.delete
			total_data.results.scenes[0].panels.append(data)
		SB.REQUEST.DELETE_JUMP:
			data["operation"] = SB.operations.delete
			total_data.results.scenes[0].jumpInfos.append(data)
	
	args["scene_id"] = scene_id
	emit_signal("request_gs_add_delete", total_data, args, request_type)

#refactor to emit_signal, delete update_gs method
func move_in_gs(scene_id, data, request_type):
	var total_data = storyboard_view.preview_exporter.get_default_data(scene_id, SB.operations.edit)
	
	match request_type:
		SB.REQUEST.MOVE_PANEL:
			data["operation"] = SB.operations.move
			total_data.results.scenes[0].panels.append(data)
	
	update_gs(total_data, {"scene_id":scene_id}, request_type)

func check_send_update(data, keep):
	for key in data:
		if data[key] is Dictionary:
			var send_update = check_send_update(data[key], keep)
			if send_update:return send_update
		elif not key in keep:
			return true
	
	return false

#Returns only key/value pairs if values differ between the two dicts
#Both dicts MUST have the same structure and key/value pairs
#Value is returned from the second dict
func subtract_dictionaries(dict1, dict2, keep=[], skip=[]):
	var new_dict = {}
	for key in dict1:
		if dict1[key] is Dictionary:
			new_dict[key] = subtract_dictionaries(dict1[key], dict2[key])
		elif key in skip:
			continue
		elif dict1[key] != dict2[key]:
			new_dict[key] = dict2[key]
		elif key in keep:
			new_dict[key] = dict2[key]
	return new_dict

func merge_dictionaries(dict1:Dictionary, dict2:Dictionary, overwrite=true):
	var new_dict = {}
	
	for key in dict1:
		if dict2.has(key) and overwrite:
			new_dict[key] = dict2[key]
		if dict1[key] is Dictionary:
			if key in dict2:
				new_dict[key] = merge_dictionaries(dict1[key], dict2[key])
			else:
				new_dict[key] = dict1[key]
		else:
			new_dict[key] = dict1[key]
	
	for key in dict2:
		if not dict1.has(key):
			new_dict[key] = dict2[key]
		elif dict2[key] is Dictionary:
			if key in dict1:
				new_dict[key] = merge_dictionaries(dict2[key], dict1[key])
			else:
				new_dict[key] = dict1[key]
	
	return new_dict

func convert_string_color_from_argb_to_rgba(color:String):
	if color.length() != 9:
		return color
	
	var alpha = color.substr(1, 2)
	var rgb = color.substr(3)
	var new_color = "#"+rgb+alpha
	return new_color

func convert_string_color_from_rgba_to_argb(color:String):
	if color.length() != 9:
		return color
	
	var alpha = color.substr(7)
	var rgb = color.substr(1, 6)
	var new_color = "#"+alpha+rgb
	return new_color

func add_undo_action(obj, action:String, property:String, property_value, method_to_call="request_update"):
	var mc =  obj.get_node_or_null("MultiselectComponent")
	
	if mc and mc.in_multiselect:
		var added_action = false
		for multiselect_component in storyboard_view.multiselect.selected:
			var parent_node = multiselect_component.parent
			var prop_value = parent_node.get(property)
			if prop_value == null:continue
			if not added_action:
				undo.create_action(action)
				added_action = true
			undo.add_undo_property(parent_node, property, prop_value)
			undo.add_undo_method(parent_node, method_to_call)
		if added_action:
			undo.commit_action()
	else:
		undo.create_action(action)
		undo.add_undo_property(obj, property, property_value)
		undo.add_undo_method(obj, method_to_call)
		undo.commit_action()

func clear_children(node):
	for c in node.get_children():
		c.queue_free()

func generate_id():
	next_id += 1
	return str(next_id)

func get_screen_scale()->float:
	return maxf(DisplayServer.screen_get_size().x / 1920.0, 1.0)

func get_game_storyboard_path():
	var path;
	var file = FileAccess.open("res://.tb_paths.txt", FileAccess.READ)
	if file:
		# GameStoryboard path is on the second line
		path = file.get_line()
		path = file.get_line()
		if !path.is_empty():
			if OS.get_name() == "macOS":
				if !DirAccess.dir_exists_absolute(path):
					printerr(get_tr("ERR_FIND_GSB_APP") % path)
					return ""
			else:
				if !FileAccess.file_exists(path):
					printerr(get_tr("ERR_FIND_GSB_AT") % path)
					return ""
			return path

	var dir = OS.get_executable_path().get_base_dir();
	if OS.get_name() == "Windows":
		path = dir.get_base_dir().path_join("AssetEditor").path_join("win64").path_join("bin").path_join("GameStoryboard.exe")
		if !FileAccess.file_exists(path):
			printerr(get_tr("ERR_FIND_GSB_AT") % path)
			path = dir.get_base_dir().path_join("GameStoryboard.exe")
			if !FileAccess.file_exists(path):
				printerr(get_tr("ERR_FIND_GSB"))
				return ""
	elif OS.get_name() == "macOS":
		path = dir.get_base_dir().get_base_dir().get_base_dir().path_join("Asset Editor.app").path_join("Contents").path_join("Applications").path_join("Game Storyboard.app")
		if !DirAccess.dir_exists_absolute(path):
			printerr(get_tr("ERR_FIND_GSB_APP")  % path)
			path = dir.get_base_dir().get_base_dir().get_base_dir().path_join("Game Storyboard.app")
			if !DirAccess.dir_exists_absolute(path):
				printerr(get_tr("ERR_FIND_GSB_APP") % path)
				return ""
	else: # Linux
		path = dir.get_base_dir().path_join("AssetEditor").path_join("lnx86_64").path_join("bin").path_join("GameStoryboard")
		if !FileAccess.file_exists(path):
			printerr(get_tr("ERR_FIND_GSB_AT") % path)
			path = dir.get_base_dir().path_join("GameStoryboard")
			if !FileAccess.file_exists(path):
				printerr(get_tr("ERR_FIND_GSB"))
				return ""
	
	return path

static func get_tr(key:String):
	return translations.get_translation(key)

func show_constant_message(msg):
	storyboard_view.show_constant_message(msg)

func hide_tooltip():
	storyboard_view.tooltip.hide_tooltip()

func apply_auto_layout(on_all = false):
	auto_layout.apply_auto_layout(on_all)

func use_auto_layout(scene_to_ignore):
	auto_layout.use_auto_layout(scene_to_ignore)
