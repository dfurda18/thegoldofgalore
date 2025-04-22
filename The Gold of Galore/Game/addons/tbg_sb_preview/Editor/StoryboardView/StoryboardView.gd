@tool
extends Control

@onready var container = $View/SubViewportContainer/Viewport/World/Container
@onready var api_handler = $ApiHandler
@onready var preview_importer = $PreviewImporter
@onready var preview_exporter = $PreviewExporter
@onready var tooltip = $Tooltip
@onready var toast = $Toast
@onready var view = $View
@onready var grid = $View/SubViewportContainer/Viewport/World/Grid
@onready var zoom_percent = $HBoxContainer2/ZoomPercent
@onready var multiselect = $Multiselect
@onready var context_menu = $ContextMenu
@onready var constant_message = $ConstantMessage
@onready var enable_smart_auto_layout_btn = $UI/HBoxContainer/ButtonsPanel/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer2/EnableSmartLayout
@onready var mouse_tooltip_btn = $UI/HBoxContainer/ButtonsPanel/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer2/MouseTooltip
@onready var ui_visibility_btn = $UI/HBoxContainer/UIVisibilityBtn
@onready var ui_visibility_btn_tex = $UI/HBoxContainer/UIVisibilityBtn/TextureRect
@onready var buttons_panel = $UI/HBoxContainer/ButtonsPanel
@onready var enable_jumps_positions_btn = $UI/HBoxContainer/ButtonsPanel/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer2/EnableJumpsPoints

const CACHE_DIR_NAME = ".cache"
const CACHE_PATH = "res://addons/tbg_sb_preview/"+CACHE_DIR_NAME+"/cache.json"
const CACHE_DIR_PATH = "res://addons/tbg_sb_preview/" + CACHE_DIR_NAME

var SB_Node = load("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Node/SB_Node.tscn")
var SB_Panel = load("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Panel/SB_Panel.tscn")
var SB_Scene = load("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Scene/SB_Scene.tscn")
var Jump = load("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Jump/SB_Jump.tscn")

var mouse_tooltip_visible = true :set=set_mouse_tooltip_visible
var queued_update={}
var queued_update_args={}
var sent_queued_update={}
var previous_update_done = true
var save_gs_through_btn = false
var update_data_to_sync = {}
var add_data_to_sync = []
var loaded_gs_data_one_time = false
var ui_visible = true

func _ready():
	SB.storyboard_view = self
	SB.request_gs_update.connect(on_request_gs_update)
	SB.request_gs_add_delete.connect(on_request_gs_add_delete)
	
	if not load_cache():
		load_default()
	
	if not loaded_gs_data_one_time:
		SB.call_deferred("show_constant_message", "FORCE_GS_LOAD")
	
	connect_pressables()
	
	set_enable_auto_layout_btn_text()
	set_mouse_tooltip_btn_text()
	set_enable_jumps_points_btn_text()
	set_ui_visibility()

func connect_pressables():
	for pressable in get_tree().get_nodes_in_group("pressable"):
		connect_pressable_to_tooltip(pressable)

func connect_pressable_to_tooltip(pressable):
	if not pressable.is_connected("hover", tooltip.on_pressable_hover):
		pressable.hover.connect(tooltip.on_pressable_hover.bind(pressable.text_tooltip))
	if not pressable.is_connected("pressed", tooltip.on_pressable_pressed):
		pressable.pressed.connect(tooltip.on_pressable_pressed)
	if not pressable.is_connected("released", tooltip.on_pressable_released):
		pressable.released.connect(tooltip.on_pressable_released)

func load_cache():
	var cache_file = FileAccess.open(CACHE_PATH, FileAccess.READ)
	if cache_file == null:return false
	var dict = JSON.parse_string(cache_file.get_as_text())
	if dict == null:return false
	
	if dict.is_empty() or not dict.has("scenes") or dict["scenes"].is_empty():
		return false
	
	for scene_data in dict["scenes"]:
		var sb_scene = SB_Scene.instantiate()
		container.add_child(sb_scene)
		sb_scene.set_data(scene_data, true, true)
	
	for scene in container.get_children():
		for scene_data in dict["scenes"]:
			if scene_data.id == scene.id:
				for jump in scene_data.jumpInfos:
					scene.add_jump_from_data(jump)
	
	for key in dict["storyboard_view"]:
		set(key, dict["storyboard_view"][key])
	
	preview_importer.set_data(dict["preview_importer"])
	preview_importer.import_thumbnails()
	
	SB.next_id = dict.sb.next_id
	SB.auto_layout_enabled = dict.sb.auto_layout_enabled
	SB.jump_auto_position_enabled = dict.sb.jump_auto_position_enabled
	
	cache_file.close()
	
	return true

func save_cache():
	if not DirAccess.dir_exists_absolute(CACHE_DIR_PATH):
		DirAccess.make_dir_absolute(CACHE_DIR_PATH)
	
	var cache_file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	cache_file.store_line(JSON.stringify(get_all_data()))
	cache_file.close()

func load_default():
	var sb_scene = SB_Scene.instantiate()
	container.add_child(sb_scene)
	sb_scene.global_position = Vector2(100,100)
	sb_scene.local_id = SB.generate_id()
	
	var sb_panel = SB_Panel.instantiate()
	sb_scene.add_panel(sb_panel)

func get_all_data():
	var dict := {}
	var scenes_arr := []
	
	for sb_scene in container.get_children():
		scenes_arr.append(sb_scene.get_data())
	
	dict["scenes"] = scenes_arr
	
	dict["storyboard_view"] = {
		"mouse_tooltip_visible" : mouse_tooltip_visible,
		"loaded_gs_data_one_time" : loaded_gs_data_one_time,
		"ui_visible" : ui_visible
	}
	
	dict["preview_importer"] = preview_importer.get_data()
	
	dict["sb"] = {
		"next_id" : SB.next_id,
		"auto_layout_enabled" : SB.auto_layout_enabled,
		"jump_auto_position_enabled" : SB.jump_auto_position_enabled
	}
	
	return dict

func _exit_tree():
	save_cache()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == 2:
			var options = ["Add scene"]
			var callback_methods = [Callable(self, "add_scene")]
			SB.open_context_menu(options, callback_methods)

func add_scene():
	if not loaded_gs_data_one_time:
		SB.show_constant_message("FORCE_GS_LOAD")
		return
	
	var last_scene_id = get_last_scene_id()
	var sb_scene = SB_Scene.instantiate()
	var sb_panel = SB_Panel.instantiate()
	container.add_child(sb_scene)
	sb_scene.set_text(str(container.get_child_count()))
	sb_scene.add_panel(sb_panel)
	sb_scene.auto_generated_panel = sb_panel
	sb_scene.global_position = SB.storyboard_view.grid.get_global_mouse_position()
	sb_scene.local_id = SB.generate_id()
	SB.add_to_gs(last_scene_id, {"scene":sb_scene}, SB.REQUEST.ADD_SCENE)
	connect_pressables()

func get_last_scene_id():
	var last_scene_with_valid_id = container.get_child(0)
	for scene in container.get_children():
		if scene.using_local_id():
			continue
		last_scene_with_valid_id = scene
	return last_scene_with_valid_id.id

func _on_load_data_pressed():
	if add_data_to_sync.is_empty() and update_data_to_sync.is_empty():
		api_handler.get_data_from_gs()
	else:
		_on_push_changes_pressed()
		#toast.show_toast("GET_DATA_FROM_GS_ERR", SB.TOAST_TYPE.ERROR)

func _on_save_gs_pressed():
	save_gs_through_btn = true
	api_handler.save_gs()

func _on_push_changes_pressed():
	if add_data_to_sync.size() > 0:
		sync_add_delete_data()
	else:
		sync_update_data()

func sync_add_delete_data():
	if not loaded_gs_data_one_time:
		api_handler.custom_request(SB.REQUEST.GET_GS_DATA_BEFORE_SYNC, api_handler.API_GET_DATA_FROM_GS, {"scene":container.get_child(0)})
		return
	
	var sync_data = add_data_to_sync.pop_front()
	var data = sync_data.data
	var args = sync_data.args
	var rt = sync_data.args.request_type
	
	#First we convert any local ids into gsb valid ids
	if rt == SB.REQUEST.ADD_SCENE:
		data.results.scenes[0].id = get_last_scene_id()
	elif rt == SB.REQUEST.ADD_PANEL:
		var pnl_id = data.results.scenes[0].panels[0].id
		var scene = get_scene_by_id(args.scene_id, true)
		if scene:
			var pnl = get_panel_by_local_id(scene, pnl_id)
			if pnl:
				data.results.scenes[0].panels[0].id = pnl.id
			data.results.scenes[0].id = scene.id
			args.scene_id = scene.id
	elif rt == SB.REQUEST.ADD_JUMP:
		var jump_to_id = data.results.scenes[0].jumpInfos[0].jumpTo
		var jump_to = get_scene_by_id(jump_to_id, true)
		var scene = get_scene_by_id(data.results.scenes[0].id, true)
		if jump_to:
			data.results.scenes[0].jumpInfos[0].jumpTo = jump_to.id
		if scene:
			data.results.scenes[0].id = scene.id
	elif rt == SB.REQUEST.DELETE_SCENE:
		data.results.scenes[0].id = args.scene.id
	elif rt == SB.REQUEST.DELETE_PANEL:
		data.results.scenes[0].panels[0].id = args.panel.id
	elif rt == SB.REQUEST.DELETE_JUMP:
		data.results.scenes[0].jumpInfos[0].jumpTo = args.jump.jump_to.id
		data.results.scenes[0].id = args.jump.jump_from.id
	
	api_handler.update_gs(data, args, SB.REQUEST.SYNC_ADD_DELETE_DATA)

func sync_update_data():
	if update_data_to_sync.is_empty():
		return
	
	#First we convert any local ids into gsb valid ids
	for scene_data in update_data_to_sync.results.scenes:
		var scene = get_scene_by_id(scene_data.id, true)
		if scene:
			scene_data.id = scene.id
		for panel_data in scene_data.panels:
			panel_data["operation"] = "edit"
			if scene:
				var panel = get_panel_by_local_id(scene, panel_data.id)
				if panel:
					panel_data.id = panel.id
		for jump_data in scene_data.jumpInfos:
			jump_data["operation"] = "edit"
			var jump_to = get_scene_by_id(jump_data.jumpTo, true)
			if jump_to:
				jump_data.jumpTo = jump_to.id
	
	api_handler.update_gs(update_data_to_sync, {}, SB.REQUEST.SYNC_UPDATE_DATA)

func on_open_gsb():
	open_gsb()
	toast.show_toast("OPENING_GSB")

func _on_mouse_tooltip_pressed():
	mouse_tooltip_visible = !mouse_tooltip_visible
	set_mouse_tooltip_btn_text()

func set_mouse_tooltip_visible(v):
	mouse_tooltip_visible = v
	tooltip.visible = v

func on_request_gs_add_delete(data, args, request_type):
	args["request_type"] = request_type
	add_data_to_sync.append({
		"data":data,
		"args":args,
		"request_type":SB.REQUEST.SYNC_ADD_DELETE_DATA
	})
	
	api_handler.update_gs(data, args, request_type)

func on_request_gs_update(node_type, scene_id, data):
	var changeset = preview_exporter.get_changeset_data(node_type, scene_id, data, queued_update)
	update_data_to_sync = preview_exporter.get_changeset_data(node_type, scene_id, data, update_data_to_sync)
	if not previous_update_done:
		queued_update = changeset
		return
	
	api_handler.update_gs(changeset)
	previous_update_done = false

func _on_api_handler_request_completed(result, request_type, args):
	match request_type:
		SB.REQUEST.GET_GS_DATA_BEFORE_SYNC:
			var scene = args.scene
			var scene_data = result.results.scenes[0]
			scene.id = scene_data.id
			sync_add_delete_data()
			loaded_gs_data_one_time = true
		SB.REQUEST.GET_DATA_FROM_GS:
			multiselect.clear_selection()
			preview_importer.import_preview(result)
			connect_pressables()
			toast.show_toast("GET_DATA_FROM_GSB")
			api_handler.save_gs()
			api_handler.get_thumbnails(SB.thumbnails_export_type.all)
			save_cache()
			clear_data_dicts()
			loaded_gs_data_one_time = true
		SB.REQUEST.GET_SCENE_DATA_FROM_GS:
			multiselect.clear_selection()
			update_specific_scene(result["results"]["scenes"][0])
		SB.REQUEST.SAVE_GS:
			if save_gs_through_btn:
				toast.show_toast("SAVE_GS")
				save_gs_through_btn = false
		SB.REQUEST.EXPORT_THUMBNAILS:
			preview_importer.import_thumbnails(result)
			#toast.show_toast("Thumbnails loaded.")
		SB.REQUEST.UPDATE_GS_QUEUED_UPDATE:
			if queued_update == sent_queued_update:
				queued_update = {}
			
			if not queued_update.is_empty():
				sent_queued_update = queued_update.duplicate(true)
				api_handler.update_gs(queued_update, {}, SB.REQUEST.UPDATE_GS_QUEUED_UPDATE)
			else:
				previous_update_done = true
		SB.REQUEST.UPDATE_GS:
			if add_data_to_sync.is_empty() and update_data_to_sync.is_empty():
				clear_data_dicts(true)
			update_data_to_sync = {}
			
			if not queued_update.is_empty():
				sent_queued_update = queued_update.duplicate(true)
				api_handler.update_gs(queued_update, {}, SB.REQUEST.UPDATE_GS_QUEUED_UPDATE)
			else:
				previous_update_done = true
		SB.REQUEST.ADD_SCENE:
			clear_data_dicts(true)
			var id = result.results
			args.scene.id = id
			update_scene_data(id, SB.thumbnails_export_type.scene, id)
		SB.REQUEST.ADD_PANEL:
			clear_data_dicts(true)
			var id = result.results
			args.panel.id = id
			update_scene_data(args.scene_id, SB.thumbnails_export_type.panel, id)
		SB.REQUEST.ADD_JUMP:
			clear_data_dicts(true)
		SB.REQUEST.MOVE_PANEL:
			clear_data_dicts(true)
			update_scene_data(args.scene_id)
		SB.REQUEST.DELETE_SCENE:
			clear_data_dicts(true)
			args.scene.queue_free()
		SB.REQUEST.DELETE_PANEL:
			clear_data_dicts(true)
			update_scene_data(args.scene_id)
		SB.REQUEST.DELETE_JUMP:
			clear_data_dicts(true)
			args.jump.queue_free()
		SB.REQUEST.SYNC_UPDATE_DATA:
			toast.show_toast("SYNC_UPDATE_DATA", SB.TOAST_TYPE.SUCCESS)
			api_handler.sync_required = false
			clear_data_dicts()
			previous_update_done = true
			api_handler.save_gs()
			api_handler.get_data_from_gs()
		SB.REQUEST.SYNC_ADD_DELETE_DATA:
			api_handler.sync_required = false
			previous_update_done = true
			var scene_id
			var wait_for_scene_update = false
			
			api_handler.save_gs()
			
			if args.request_type == SB.REQUEST.ADD_SCENE:
				var id = result.results
				args.scene.id = id
				scene_id = id 
				var url_postfix = api_handler.API_GET_DATA_FROM_GS + "?sceneId="+scene_id
				api_handler.custom_request(SB.REQUEST.SYNC_ADD_DELETE_DATA, url_postfix, {"request_type":SB.REQUEST.GET_SCENE_DATA_FROM_GS})
				wait_for_scene_update = true
			elif args.request_type == SB.REQUEST.ADD_PANEL:
				var id = result.results
				var pnl = args.panel
				pnl.id = id
				scene_id = args.scene_id
			elif args.request_type == SB.REQUEST.GET_SCENE_DATA_FROM_GS:
				update_specific_scene(result["results"]["scenes"][0])
			elif args.request_type == SB.REQUEST.DELETE_SCENE:
				args.scene.queue_free()
			
			if not wait_for_scene_update:
				if add_data_to_sync.size() > 0 :
					sync_add_delete_data()
				elif not update_data_to_sync.is_empty():
					sync_update_data()
				else:
					api_handler.call_deferred("save_gs")
					api_handler.call_deferred("get_data_from_gs")

func _on_api_handler_request_failed(result, request_type, args):
	match request_type:
		SB.REQUEST.GET_DATA_FROM_GS:
			toast.show_toast("GET_DATA_FROM_GS_ERR", SB.TOAST_TYPE.ERROR)
		SB.REQUEST.GET_SCENE_DATA_FROM_GS:
			pass
		SB.REQUEST.SAVE_GS:
			save_gs_through_btn = false
		SB.REQUEST.UPDATE_GS:
			previous_update_done = true
		SB.REQUEST.UPDATE_GS_QUEUED_UPDATE:
			previous_update_done = true
		SB.REQUEST.SYNC_ADD_DELETE_DATA:
			previous_update_done = true
			api_handler.get_data_from_gs()
		SB.REQUEST.SYNC_UPDATE_DATA:
			api_handler.get_data_from_gs()
			toast.show_toast("SYNC_UPDATE_DATA_ERR", SB.TOAST_TYPE.ERROR)

func _on_api_handler_request_not_sent():
	if not add_data_to_sync.is_empty() or not update_data_to_sync.is_empty():
		api_handler.sync_required = true

func update_scene_data(scene_id, thumbnails_export_type=SB.thumbnails_export_type.none, thumbnail_for_id=null):
	api_handler.save_gs()
	api_handler.get_scene_data_from_gs(scene_id)
	if not thumbnails_export_type == SB.thumbnails_export_type.none and not thumbnail_for_id == null:
		api_handler.get_thumbnails(thumbnails_export_type, thumbnail_for_id)

func clear_data_dicts(only_sync = false):
	if not only_sync:
		queued_update = {}
		queued_update_args = {}
	update_data_to_sync = {}
	add_data_to_sync = []

func _on_zoom_out_pressed():
	view._zoom_out()
	update_hud()

func _on_zoom_in_pressed():
	view._zoom_in()
	update_hud()

func _on_zoom_percent_pressed():
	view.reset_zoom()
	update_hud()

func update_hud():
	zoom_percent.text = "%d %%" % int(view.view_scale * 100)

func update_specific_scene(scene_data):
	var scene
	
	for s in container.get_children():
		if s.using_local_id():
			continue
		if s.id == scene_data.id:
			scene = s
			break
	
	if not scene:return 
	
	if scene_data == null:return
	
	if scene.auto_generated_panel and scene_data.panels.size() == 1:
		scene.auto_generated_panel.set_data(scene_data.panels[0], true)
	
	scene.set_data(scene_data, true)
	scene.call_deferred("update_layout", false) 

func get_scene_by_id(scene_id, search_local):
	var s
	if search_local:
		s = get_scene_by_local_id(scene_id)
	
	if s:
		return s
	
	for scene in container.get_children():
		if scene.id == scene_id:
			return scene

func get_scene_by_local_id(local_id):
	for scene in container.get_children():
		if scene.using_local_id() and scene.id == local_id:
			return scene
		elif scene.local_id == local_id:
			return scene

func get_panel_by_local_id(scene, local_id):
	for panel in scene.sb_panel_container.get_children():
		if panel.using_local_id() and panel.id == local_id:
			return panel
		elif panel.local_id == local_id:
			return panel

func open_gsb():
	var path = SB.get_game_storyboard_path()
	
	if path.is_empty():
		printerr(SB.get_tr("OPEN_GAME_ENGINE_FROM_JUMP"))
		toast.show_toast("GSB_NOT_FOUND", SB.TOAST_TYPE.ERROR)
		return
	
	var args = PackedStringArray()
	var proj_path = ProjectSettings.globalize_path("res://")
	var sb_file_path = proj_path.replace("/Game", "") + "Storyboard.tgsb"
	args.append(sb_file_path)
	OS.create_process(path, args)

func show_constant_message(msg):
	constant_message.set_message_text(SB.get_tr(msg))

func _on_use_smart_layout_pressed():
	SB.apply_auto_layout(true)

func _on_enable_smart_layout_pressed():
	SB.auto_layout_enabled = !SB.auto_layout_enabled
	set_enable_auto_layout_btn_text()

func set_enable_auto_layout_btn_text():
	if SB.auto_layout_enabled:
		enable_smart_auto_layout_btn.text = "Disable Smart Layout On Move"
	else:
		enable_smart_auto_layout_btn.text = "Enable Smart Layout On Move"

func set_mouse_tooltip_btn_text():
	if mouse_tooltip_visible:
		mouse_tooltip_btn.text = "Disable Tooltips On Hover"
	else:
		mouse_tooltip_btn.text = "Enable Tooltips On Hover"

func _on_ui_visibility_btn_pressed():
	ui_visible = !ui_visible
	set_ui_visibility()

func set_ui_visibility():
	if ui_visible:
		ui_visibility_btn.text = ""
		ui_visibility_btn_tex.show()
		buttons_panel.show()
	else:
		ui_visibility_btn.text = "Open UI Panel"
		ui_visibility_btn_tex.hide()
		buttons_panel.hide()

func _on_enable_jumps_points_pressed():
	SB.jump_auto_position_enabled = !SB.jump_auto_position_enabled
	set_enable_jumps_points_btn_text()

func set_enable_jumps_points_btn_text():
	if SB.jump_auto_position_enabled:
		enable_jumps_positions_btn.text = "Disable Auto Jump Reposition"
	else:
		enable_jumps_positions_btn.text = "Enable Auto Jump Reposition"
