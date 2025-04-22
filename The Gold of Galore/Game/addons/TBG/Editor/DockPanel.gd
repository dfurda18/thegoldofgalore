@tool
## Custom Docker that allows quick access to TBG related files
extends VBoxContainer
#class_name DockPanel

const TbgPlugin = preload("Plugin.gd")
const AssetView = preload("AssetView.gd")

const AssetFolderRoot = "res://art/"

# this will be nil if not run from editor
var asset_list: ItemList
var assets_list_title: Label
var asset_tree: Tree
var scene_tree: Tree

var _menubar: MenuBar

# _asset_map entries should be structured like this
# { "my/short/path": { tbg: AssetFolderRoot + "short/path.stg", source: "/Users/Docs/Project/Assets/my/short/path.stage" }
var _asset_map: Dictionary = {}


func _enter_tree():
	scene_tree = %Scenes/Tree
	asset_tree = %Assets/Tree
	asset_list = %Assets/List
	assets_list_title = %Assets/ListTitle

	set_translations()
	
	%Settings.object = TbgPlugin.options
	%Settings.changed.connect(settings_changed)
	
	# Rename the tabs, this is why we cache the node paths early on
	# Make sure you don't use node paths later on to avoid issues
	%Assets.name = TbgPlugin.get_tr("ASSETS")
	%Scenes.name = TbgPlugin.get_tr("SCENES")
	%Settings.name = TbgPlugin.get_tr("SETTINGS")
	
	if TbgPlugin.instance.file_system:
		TbgPlugin.instance.file_system.resources_reimported.connect(_on_resources_reimported)
		TbgPlugin.instance.file_system.filesystem_changed.connect(_on_filesystem_changed)
	
	if TbgPlugin.instance.selection:
		TbgPlugin.instance.selection.selection_changed.connect(_on_scene_selection_changed)
	
	process_mode = PROCESS_MODE_DISABLED
	await TbgPlugin.instance.file_system.sources_changed
	process_mode = PROCESS_MODE_ALWAYS


func _exit_tree():
	if TbgPlugin.instance.file_system:
		TbgPlugin.instance.file_system.resources_reimported.disconnect(_on_resources_reimported)
		TbgPlugin.instance.file_system.filesystem_changed.disconnect(_on_filesystem_changed)
	
	if TbgPlugin.instance.selection:
		TbgPlugin.instance.selection.selection_changed.disconnect(_on_scene_selection_changed)


func _process(_delta):
	validate()


func selected_asset_nodes():
	if TbgPlugin.instance.selection:
		return TbgPlugin.instance.selection.get_selected_nodes().filter(func(node):
			return node is TBG.MotionCharacter
		)


func set_menu(menu_data = null):
	TbgPlugin.Editor.set_menu(%Toolbar, ":", menu_data)


func is_scene_path(path):
	if path == null or not (path.get_extension() in ["tscn","scn"]):
		return false
	
	return FileAccess.file_exists(path)


func short_file_path(path, parts: int = 2):
	var array = path.split("/")
	if array.size() < parts:
		return path
	
	array = array.slice(-parts)
	return "/".join(array).get_basename()


func settings_changed():
	if TbgPlugin.instance:
		var root = TbgPlugin.editor.get_edited_scene_root()
		if root:  
			TbgPlugin.invalidate(root)
		
		if TbgPlugin.instance.asset_view:
			TbgPlugin.instance.asset_view.refresh()
		
	invalidate()


func set_translations():
	var tabs = $Container/Tabs
	var i = 0
	
	for c in tabs.get_children():
		tabs.set_tab_title(i, TbgPlugin.get_tr(c.name.to_upper()))
		i += 1
	
	$Container/Tabs/Assets/ProjectFilesLabel.text = TbgPlugin.get_tr("PROJECT_FILES")


func trim_path(path, prefix):
	if path.begins_with(prefix):
		path = path.substr(prefix.length())
	return path.get_basename()


func get_file_tree(root, extensions):
	var items
	if extensions.is_empty():
		items = TbgPlugin.find_files(root)
	else:
		items = TbgPlugin.find_files_of_type(root, extensions)
	
	items.sort_custom(filesystem_style_sort)
	
	return items.map(func(path) : return [trim_path(path, root), path] )


var _validated
func invalidate():
	_validated = false


func validate():
	if _validated:
		return
	
	update_ui()
	_validated = true


func filesystem_style_sort(a, b):
	var a_slashes = (a as String).count("/")
	var b_slashes = (b as String).count("/")
	if a_slashes != b_slashes:
		if a_slashes == 0 or b_slashes == 0:
			return a_slashes != 0
		# Compare the lowest point
		var a_sub = ""
		for layer in min(a_slashes, b_slashes):
			var b_sub = b.substr(0, b.find("/", a_sub.length() + 1))
			a_sub = a.substr(0, a.find("/", a_sub.length() + 1))
			if a_sub != b_sub:
				return b.nocasecmp_to(a) > 0
		return a_slashes > b_slashes
	return b.nocasecmp_to(a) > 0


func update_ui():
	var scene_list = get_file_tree("res://", "scn;tscn").filter(func(item):
		return not item[0].begins_with("addons/")
		)
	
	scene_tree.content = scene_list.map(func(item):
		return {"text":item[0], "data":item[1] }
		)
	
	var tbg_assets = get_file_tree(AssetFolderRoot, "tbg")
	var source_assets = get_file_tree("res://../Assets/", "xstage;tgs")
	
	_asset_map = {}
	for asset in source_assets:
		var asset_entry = _asset_map.get(asset[0], {})
		asset_entry["source"] = asset[1]
		_asset_map[asset[0]] = asset_entry
	
	for asset in tbg_assets:
		var asset_entry = _asset_map.get(asset[0], {})
		#asset_entry["tbg"] = asset[1]
		var source = TbgPlugin.get_asset_source_path(asset[1])
		if source != null:
			# This takes precedence over similar issue from above
			asset_entry["source"] = source
			# Also check if it's in the same spot as the original asset
			if not _asset_map.has(asset[0]):
				asset_entry["tbg"] = "%s\t" % asset[1]
				var dock_path = trim_path(source, "res://../Assets/")
				# Only invalid if a user moved/renamed an asset, but didn't re-export
				if _asset_map.has(dock_path) and not _asset_map[dock_path].get("tbg"):
					_asset_map[dock_path]["tbg"] = "\t%s" % asset[1]
			else:
				# Overlapping so don't need any special colours
				asset_entry["tbg"] = asset[1]
		else:
			# if no source to edit, mark that too
			asset_entry["tbg"] = "\n%s" % asset[1]
		_asset_map[asset[0]] = asset_entry
	
	var asset_keys = _asset_map.keys()
	asset_keys.sort_custom(filesystem_style_sort)
	
	asset_tree.content = asset_keys.map(func(key): 
		var value = _asset_map[key]
		var result = { "text": key }
		if value.get("tbg"):
			if (value["tbg"] as String).ends_with("\t"):
				value["tbg"] = (value["tbg"] as String).trim_suffix("\t")
				# Means the export path is different, this is the exported tbg
				#result["color"] = Color(0.55, 0.55, 0.25, 1.0)
				result["color"] = TbgPlugin.instance.theme.get_color("font_hover_pressed_color", "Button")
				result["tooltip"] = "TBG of: %s" % trim_path(value["source"], "res://../Assets/")
			
			elif (value["tbg"] as String).begins_with("\t"):
				value["tbg"] = (value["tbg"] as String).trim_prefix("\t")
				# Means the export path is different, this is the source
				#result["color"] = Color(0.75, 0.5, 0.5, 1.0)
				result["color"] = TbgPlugin.instance.theme.get_color("font_pressed_color", "Button")
				result["tooltip"] = "Source asset for: %s" % trim_path(value["tbg"], AssetFolderRoot)
			
			elif (value["tbg"] as String).begins_with("\n"):
				value["tbg"] = (value["tbg"] as String).trim_prefix("\n")
				# Means no source tgs was found
				result["color"] = Color(1.0, 0.25, 0.25, 1.0)
				#result["color"] = TbgPlugin.instance.theme.get_color("font_focus_color", "Button")
				result["tooltip"] = "No source asset: %s" % key
			
		else:
			# Means it wasn't exported
			#result["color"] = Color(1, 0.5, 0.5, 0.5)
			result["color"] = TbgPlugin.instance.theme.get_color("font_disabled_color", "Button")
			result["tooltip"] = "Asset not exported: %s" % key
		return result
	)
	
	asset_list.clear()
	if TbgPlugin.instance:
		var root = TbgPlugin.editor.get_edited_scene_root()
		if root and not (root is TBG.MotionCharacter):
			assets_list_title.text = ("%s: \"%s\"" %
					[TbgPlugin.get_tr("SCENE"), root.scene_file_path.get_file()]
			) if root.scene_file_path else TbgPlugin.get_tr("CURRENT_SCENE")
			for node in TbgPlugin.find_assets(root):
				for asset_entry in _asset_map.values():
					if asset_entry.get("tbg") == AssetView.get_asset_import_path(node):
						TbgPlugin.trace("scene contains " + asset_entry["tbg"])
						if not asset_entry.has("nodes"):
							asset_entry["nodes"] = []
						asset_entry["nodes"].push_back(node)
		
		for key in _asset_map:
			if _asset_map[key].has("nodes"):
				asset_list.add_item(key)
		
	if asset_list.item_count:
		assets_list_title.visible = true
		asset_list.visible = true
	else:
		assets_list_title.visible = false
		asset_list.visible = false


func _on_resources_reimported(resources):
	TbgPlugin.trace("resources_reimported: %s" % [resources])
	invalidate()


func _on_filesystem_changed():
	invalidate()


func _on_scene_changed(node):
	invalidate()


func show_menu(screen_position = null, commands = null):
	TbgPlugin.instance.make_popup_menu(screen_position, commands)


func _on_tree_context_menu(path, screen_position):
	var asset_entry = _asset_map.get(path)
	var tbg_plugin = TbgPlugin.instance
	var commands
	if asset_entry == null:
		if is_scene_path(path):
			commands = [
				{
					TbgPlugin.CommandPos.LABEL: tbg_plugin.get_tr("OPEN"),
					TbgPlugin.CommandPos.FN: TbgPlugin.editor.open_scene_from_path.bind(path)
				},
				null,
				{
					TbgPlugin.CommandPos.LABEL: tbg_plugin.get_tr("SHOW_IN_FS"),
					TbgPlugin.CommandPos.FN: TbgPlugin.editor.get_file_system_dock().navigate_to_path.bind(path)
				},
			]
			show_menu(screen_position, commands)
		return
	
	var tbg_path = asset_entry.get("tbg")
	var asset_source = asset_entry.get("source")
	
	commands = []
	
	if tbg_path:
		var tbgfilename = trim_path(tbg_path, AssetFolderRoot)
		if asset_source and path != tbgfilename and trim_path(asset_source, "res://../Assets/") != tbgfilename:
			tbgfilename = "%s (%s)" % [tbg_plugin.get_tr("OPEN"), tbgfilename]
		else:
			tbgfilename = tbg_plugin.get_tr("OPEN")
		commands += [
			[
				tbgfilename,
				TbgPlugin.instance.view_asset.bind(tbg_path),
			],
			[
				tbg_plugin.get_tr("REIMPORT"),
				TbgPlugin.editor.get_resource_filesystem().reimport_files.bind([ tbg_path ]),
			],
			[
				tbg_plugin.get_tr("SHOW_TBG_IN_F_M"),
				TbgPlugin.show_in_file_manager.bind(tbg_path),
			]
		]
	else:
		commands += [
			[
				tbg_plugin.get_tr("SOURCE_ASSET_NOT_EX"),
				null,
			],
		]
	
	commands += [ null ]
	
	if asset_source:
		var tgsfilename = trim_path(asset_source, "res://../Assets/")
		if tbg_path and path != tgsfilename and trim_path(tbg_path, AssetFolderRoot) != tgsfilename:
			tgsfilename = "%s (%s)" % [tbg_plugin.get_tr("EDIT_SOURCE_ASSET"), tgsfilename]
		else:
			tgsfilename = tbg_plugin.get_tr("EDIT_SOURCE_ASSET")
		commands += [
			[
				tgsfilename,
				TbgPlugin.open_in_asset_editor.bind(asset_source),
			],
			[
				tbg_plugin.get_tr("SHOW_SOURCE_ASSET_IN_F_M"),
				TbgPlugin.show_in_file_manager.bind(asset_source),
			],
		]
	else:
		commands += [
			[
				tbg_plugin.get_tr("ORG_ASSET_UNKNOWN"),
				null,
			],
		]
	
	show_menu(screen_position, commands)


#func _on_tree_path_selected(path):
	#print("_on_tree_path_selected: ", path)


func _on_tree_path_activated(path):
	var asset = _asset_map.get(path)
	if asset:
		var tbg = asset.get("tbg")
		var source = asset.get("source")
		if tbg:
			TbgPlugin.instance.view_asset(tbg)
		elif source:
			TbgPlugin.open_in_asset_editor(source)
	
	else:
		# TbgPlugin.viewAsset(null)
		if is_scene_path(path):
			#TbgPlugin.editor.set_main_screen_editor("2D")
			TbgPlugin.editor.open_scene_from_path(path)


func _on_tree_drag_start(path, struct):
	var asset = _asset_map.get(path)
	if asset and asset.get("tbg"):
		var asset_source = asset["tbg"]
		asset_source = TbgPlugin.get_writable_scene_path(asset_source)
		struct.merge({ "type": "files", "files": [asset_source] })
	elif is_scene_path(path):
		struct.merge({ "type": "files", "files": [path] })


func asset_item_from_index(index):
	var key = asset_list.get_item_text(index)
	if key:
		return _asset_map.get(key)


func _on_asset_list_item_activated(index):
	var asset = asset_item_from_index(index)
	if asset:
		var tbg = asset.get("tbg")
		if tbg:
			TbgPlugin.instance.view_asset(tbg)
			return
		var source = asset.get("source")
		if source:
			TbgPlugin.open_in_asset_editor(source)


func _on_scene_selection_changed():
	var selected = to_set(TbgPlugin.instance.selection.get_selected_nodes())
	for index in asset_list.item_count:
		var item = asset_item_from_index(index)
		if intersects(selected, item["nodes"]):
			asset_list.select(index, false)
		else:
			asset_list.deselect(index)


func _on_scene_asset_list_item_selected(index):
	var asset = asset_item_from_index(index)
	if asset and asset["nodes"]:
		var node: Node = asset["nodes"].front()
		# Only edit if they're actually going to be saved
		if node.owner and node.owner == get_tree().edited_scene_root:
			TbgPlugin.editor.edit_node(node)


func to_set(a):
	var c = {}
	for k in a:
		if k in c:
			c[k] += 1
		else:
			c[k] = 1 
	return c


func intersects(_set,b):
	for k in b:
		if k in _set:
			return true


func intersect(a,b):
	var c = {}
	for k in a:
		if k in b:
			c[k] = min(a[k], b[k])
	
	return c


func union(a,b):
	var c = a.duplicate()
	for k in b:
		if k in a:
			c[k] = a[k] + b[k]
		else:
			c[k] = b[k]
	
	return c
