@tool
## Plugin script to manage the various UI elements the addon adds
extends EditorPlugin
#class_name TbgPlugin

# Runtime types
#const Composite = preload("../Runtime/Composite.gd")
#const CompositeConfig = preload("../Runtime/CompositeConfig.gd")
#const Cutter = preload("../Runtime/Cutter.gd")
#const Drawing = preload("../Runtime/Drawing.gd")
#const DrawingCollider = preload("../Runtime/DrawingCollider.gd")
#const MotionCharacter = preload("../Runtime/MotionCharacter.gd")
#const MotionConfig = preload("../Runtime/MotionConfig.gd")
#const MotionCharacterConfig = preload("../Runtime/MotionCharacterConfig.gd")
#const PolygonConfig = preload("../Runtime/PolygonConfig.gd")
#const RemoteDrawingTransform = preload("../Runtime/RemoteDrawingTransform.gd")

# Editor and importing
const Editor = preload("_.gd")
const Data = preload("Data.gd")
const Templates = preload("../Templates/_.gd")

const PLUGIN_NAME = "Toon Boom"

## The preferred extension for saving scenes
const BASE_PATH = "res://addons/TBG"
const DEFAULT_SCENE_EXTENSION = "tscn"
const DEFAULT_RESOURCE_EXTENSION = "tres"

# Arbitrary symbolic constants for internal use as dictionary keys in 
# place of strings
# This is mainly to avoid typos, but may offer some small performance increase too
enum { 
	ZERO, ID, NAME, TYPE, VALUE, TEXT, ACTION, LABEL, CHECK, DESCRIPTION, 
	TRANSFORM, OBJECT, CONTROL, POLYGONS, RECT, MENU
}


signal toon_boom_editor_visibility_changed(visible)

static var instance: Editor.TbgPlugin = null
static var editor: EditorInterface = null
static var file_open_dialog : Variant = EditorFileDialog

# Resources
var _inspector_plugin
#var view2D
var dock_panel: Control
var asset_view: Control

var tbg_importer_plugin
static var translations = preload("../translations/Translations.gd").new()


func reload_scenes():
	var scene_paths = editor.get_open_scenes()
	for scene_path in scene_paths:
		print("Reloading: ", scene_path)
		editor.reload_scene_from_path(scene_path)


func reimport_assets():
	var asset_files = find_files_of_type("res://tbg", "tbg")
	var filesystem = editor.get_resource_filesystem()
	filesystem.reimport_files(asset_files)


func open_main_scene():
	var scene_path = ProjectSettings.get_setting("application/run/main_scene")
	if scene_path != null and editor:
		editor.set_main_screen_editor("2D")
		editor.open_scene_from_path(scene_path)


func error_dialog(message):
	var dialog = AcceptDialog.new()
	dialog.set_text(message)
	dialog.set_title("Error")
	add_child(dialog)
	dialog.popup()
	dialog.set_position(Vector2(
			get_viewport().get_size().x / 2 - dialog.get_size().x / 2
			+ get_viewport().get_position().x,
			get_viewport().get_size().y / 2 - dialog.get_size().y / 2
			+ get_viewport().get_position().y
	))


func _enter_tree():
	instance = self
	
	# Consider switching this out to use the singleton
	# The function is deprecated starting 4.2
	#editor = EditorInterface
	editor = get_editor_interface()
	trace("Plugin._enter_tree()")
	
	# TEMP: Disable threading, doesn't work with scene importing
	ProjectSettings.set_setting("editor/import/use_multiple_threads", false)
	
	var TbgImporterPlugin = preload("res://addons/TBG/Importer/TBGImporterPlugin.gd")
	tbg_importer_plugin = TbgImporterPlugin.new()
	tbg_importer_plugin.plugin = self
	add_import_plugin(tbg_importer_plugin)
	
	_inspector_plugin = Editor.create_inspector_plugin()
	add_inspector_plugin(_inspector_plugin)
	
	# Load dock
	dock_panel = Editor.create_dock_panel_UI()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock_panel)
	dock_panel.set_menu([
		[ get_tr("OPEN_MAIN_SCENE"), open_main_scene ],
		[ get_tr("RELOAD_SCENES"), reload_scenes ],
		null,
		[ get_tr("REIMPORT_ALL_ASSETS"), reimport_assets ],
		null,
		[ get_tr("RELOAD_PROJECT"), editor.restart_editor ] if editor else null,
	])
	
	if editor:
		var main_screen = editor.get_editor_main_screen()
		#view2D = mainScreen.get_children()[0]
		
		asset_view = Editor.create_asset_view()
		if asset_view:
			asset_view.visible = false
			asset_view.close_requested.connect(_on_close)
			# Add the main panel to the editor's main viewport.
			main_screen.add_child(asset_view)


var last_edited
func _handles(object): # note that this means single click edit, not ideal
	if current_asset and asset_view:
		if object is Node or object == null:
			last_edited = object
		if asset_view.visible:
			if find_containing(object, TBG.MotionCharacter):
				trace("Handling object %s" % object)
				return true
	# return object is MotionCharacter
	return false


func _edit(object):
	trace("Triggered edit callback for %s" % object)
	if asset_view:
		asset_view.edit_node(object)	
	pass 


func _save_external_data():
	if asset_view:
		#await get_tree().process_frame
		asset_view.invalidate()
	pass 


func _ready():
	main_screen_changed.connect(_on_main_screen_changed)
	# resource_saved.connect(func(resource) : trace("Resource Saved: %s" % resource))
	scene_changed.connect(_on_scene_changed)
	# scene_closed.connect(func(filepath) : print("Scene Closed: ", filepath))


func _exit_tree():
	if dock_panel:
		remove_control_from_docks(dock_panel)
		dock_panel.queue_free()
	
	if asset_view:
		asset_view.queue_free()
		asset_view = null
	
	remove_import_plugin(tbg_importer_plugin)
	remove_inspector_plugin(_inspector_plugin)
	
	font = null
	editor = null
	instance = null


func _on_scene_changed(node):
	trace("Scene Changed: %s" % node)
	if dock_panel:
		dock_panel._on_scene_changed(node)
	
	if asset_view:
		asset_view._on_scene_changed(node)
		if node is TBG.MotionCharacter:
			_on_main_screen_changed(_current_screen)
		#if node is MotionCharacter:
			#editor.set_main_screen_editor(pluginName)
		#elif asset_view.visible:
			#editor.set_main_screen_editor("2D")


func _has_main_screen():
	return true


func _make_visible(visible):
	if visible:
		if is_instance_valid(tb_telemetry):
			tb_telemetry.openView("Toon Boom View")      
	else:
		if is_instance_valid(tb_telemetry):
			tb_telemetry.closeView("Toon Boom View")  
	
	if asset_view:
		asset_view.visible = visible
		toon_boom_editor_visibility_changed.emit(visible)


func _on_close():
	trace("Plugin._on_close()")
	editor.set_main_screen_editor("2D")


func _get_plugin_name():
	return PLUGIN_NAME


var _current_screen: String
func _on_main_screen_changed(screen_name):
	trace("Main Screen Changed: %s" % screen_name)
	if asset_view:
		asset_view._on_main_screen_changed(screen_name)
	_current_screen = screen_name


func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")


## Global options. Primarily for use within Editor and Debugging contexts, this data is persistent within the session but not serialized.
static var options: Dictionary = {
	"show":{ "bones":false },
	"debug": { "logging": false },
}:
	get:
		return options
	set(_v):
		pass


static var project: Dictionary = { 
	"project_setting": 1, 
	"project_option": false,
}:
	get:
		return project
	set(_v):
		pass


##  the current theme for use withing Editor
var theme: Theme:
	get:
		if theme == null:
			# Godot 4.2.1
			if theme == null and editor and editor.has_method("get_editor_theme"):
				theme = editor.get_editor_theme()
			# Godot 4.1.2
			if theme == null and editor and editor.has_method("get_base_control"):
				theme = editor.get_base_control().theme
			# Fallback
			if theme == null:
				theme = ThemeDB.get_default_theme()
		return theme


var font: Font:
	get:
		if font == null:
			font = theme.get_font("font", "")	#.new().get_theme_font("font")
		return font


## (Editor only)
var selection: Object:
	get:
		if selection == null and editor:
			selection = editor.get_selection()
		return selection


## (Editor only)
var inspector: Control:
	get:
		if inspector == null and editor:
			inspector = editor.get_inspector()
		return inspector


## (Editor only)
var file_system: Node: 
	get:
		if file_system == null and editor:
			file_system = editor.get_resource_filesystem()
		return file_system


## (Editor only)
var file_system_dock: Control: 
	get:
		if file_system_dock == null and editor:
			file_system_dock = editor.get_file_system_dock()
		return file_system_dock


## The current scene root
var current_scene: Node: 
	get:
		if editor:
			return editor.get_edited_scene_root()
			
		return get_tree().current_scene


## The current scene root if it is a MotionCharacter
var current_asset: TBG.MotionCharacter:
	get:
		if is_instance_valid(current_scene) and current_scene is TBG.MotionCharacter:
			return current_scene
		return null


var undo_redo: EditorUndoRedoManager = null: 
	get:
		if undo_redo == null:
			undo_redo = get_undo_redo()
		return undo_redo


var close_request = ClassDB.instantiate("TBCloseRequest") if ClassDB.class_exists("TBCloseRequest") else null


var tb_telemetry = ClassDB.instantiate("TBTelemetry") if ClassDB.class_exists("TBTelemetry") else null

## adds to undo stack
func change_property(ob, key, value, text = null):
	while value is Callable: # allows for late binding
		value = value.call()
	
	var old_value = ob.get(key)
	if equivalent(old_value, value):
		instance.log("No change to %s" % key)
	elif undo_redo:
		if text == null:
			text = "Change %s" % key
		undo_redo.create_action(text)
		undo_redo.add_do_property(ob, key, value)
		undo_redo.add_undo_property(ob, key, old_value)
		if asset_view:
			undo_redo.add_undo_method(asset_view, "invalidate")
		undo_redo.commit_action()
	else:
		ob.set(key, value)


class Action:
	var _do: Callable
	var _undo: Callable
	var _plugin
	
	func _init(do, undo, plugin):
		_do = do
		_undo = undo
		_plugin = plugin
	
	func do():
		if _do:
			_do.call()
			if _plugin and _plugin.asset_view:
				_plugin.asset_view.invalidate()
	
	func undo():
		if _undo:
			_undo.call()
			if _plugin and _plugin.asset_view:
				_plugin.asset_view.invalidate()


func do_action(_do : Callable, _undo : Callable, context = null, text = "Action"):
	trace("Do %s" % [text])
	if undo_redo and _undo:
		var action = Action.new(_do, _undo, self)
		undo_redo.create_action(text, 0, context)
		undo_redo.add_do_method(action, "do")
		undo_redo.add_undo_method(action, "undo")
		undo_redo.commit_action()
	else:
		_do.call()


func view_asset(asset):
	var asset_path
	if asset is Node:
		if asset.scene_file_path:
			asset_path = asset.scene_file_path
	else:
		asset_path = asset
		asset = null
	
	var show = asset_path != null
	if asset_path == null:
		asset_path = ""
	
	if asset_view:
		if show:
			trace("Open Asset " + asset_path)
			editor.set_main_screen_editor("Toon Boom")
		#else:
			#editor.set_main_screen_editor("2D")
		
		editor.open_scene_from_path(get_writable_scene_path(asset_path))
		# asset_view.assetPath = assetPath


enum CommandPos { LABEL, FN, TOOLTIP }
var popup: PopupMenu
var commands: Array = []
func _menu_callback(idx, submenu = -1):
	var command = commands[idx] if submenu < 0 else commands[submenu][CommandPos.FN][idx]
	if command == null:
		push_warning("Missing command at menu index:", idx)
	else:
		if command.size() > CommandPos.FN and command[CommandPos.FN]:
			trace("Executing: %s" % [command])
			defer(command[CommandPos.FN],0.1)
		else:
			push_warning("Not implemented:", command)


func make_popup_menu(position: Vector2i, new_commands = null):
	if popup:
		popup.queue_free()
	popup = PopupMenu.new()
	popup.size.y = 0
	
	if new_commands:
		commands = new_commands
	for id in commands.size():
		var command = commands[id]
		if command:
			if command.size() <= CommandPos.FN or command[CommandPos.FN] == null:
				popup.add_item(command[CommandPos.LABEL], id)
				popup.set_item_disabled(id, true)
			elif command[CommandPos.FN] is Array:
				_make_submenu(command[CommandPos.LABEL], command[CommandPos.FN], id)
			else:
				popup.add_item(command[CommandPos.LABEL], id)
			
			if command.size() > CommandPos.TOOLTIP:
				popup.set_item_tooltip(id, command[CommandPos.TOOLTIP])
		else:
			popup.add_separator()
	
	add_child(popup)
	popup.id_pressed.connect(_menu_callback)
	if position:
		popup.position = position
	popup.visible = true
	
	#var screen_size = DisplayServer.screen_get_size()
	#for i in DisplayServer.window_get_current_screen():
		#screen_size += DisplayServer.screen_get_size(i+1)
	var screen_size = DisplayServer.window_get_position() + DisplayServer.window_get_size()
	
	var popup_end_pos = popup.position + popup.size
	var offset = popup_end_pos - screen_size
	
	if popup_end_pos.x > screen_size.x:
		popup.position.x -= offset.x
	if popup_end_pos.y > screen_size.y:
		popup.position.y -= offset.y


func _make_submenu(label: String, data: Array, id: int):
	var menu: = PopupMenu.new()
	menu.name = label
	menu.size.y = 0
	# Make sure it's deleted with the original
	popup.add_child(menu)
	
	for entry in data:
		menu.add_item(entry[CommandPos.LABEL])
	
	menu.id_pressed.connect(_menu_callback.bind(id))
	
	popup.add_submenu_item(label, label, id)


func _init():
	if is_instance_valid(close_request):
		close_request.setChildLock()


#Doesn't work natively since it's not a node
#var currently_saving : bool = false
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		trace("_notification(NOTIFICATION_WM_CLOSE_REQUEST)")
		pass
	#elif what == NOTIFICATION_EDITOR_PRE_SAVE:
		#trace("_notification(NOTIFICATION_EDITOR_PRE_SAVE)")
		#currently_saving = true
	#elif what == NOTIFICATION_EDITOR_POST_SAVE:
		#trace("_notification(NOTIFICATION_EDITOR_POST_SAVE)")
		#currently_saving = false


static func get_tr(key : String)->String:
	return translations.get_translation(key)


static var _logfile
static func write_log(data, prefix = ""):
	if _logfile == null:
		_logfile = FileAccess.open("user://editor.log" if Engine.is_editor_hint() else "user://player.log", FileAccess.WRITE)
		
	_logfile.store_line("%s\t%s" % [prefix, data])
	_logfile.flush()


# logging and debugging
static func trace(data):
	if options["debug"]["logging"]:
		print(">\t", data)
	write_log(data, ">")


static func log(data):
	print(data)
	write_log(data)


static func warn(data):
	print("WARNING: ", data)
	write_log(data, "!")


static func error(data):
	print("ERROR: ", data)
	write_log(data, "!!")


func deferred(callable):
	return func():
		if callable is Signal:
			callable.emit.call_deferred()
		if callable is Callable:
			callable.call_deferred()


func defer(callable, delay = 0.0):
	if not delay: # simple defer
		if callable is Signal:
			callable.emit.call_deferred()
		else:
			callable.call_deferred()
		return
	
	# for some reason this was calling back twice
	#var sceneTree = node.get_tree()
	#var timer = sceneTree.create_timer(delay)
	#if timer:
	#	timer.timeout.connect(callable)
	
	# Replaced with nodeless method below, also avoids the lambda
	#var timer = Timer.new()
	#timer.one_shot = true
	#timer.wait_time = delay
	#timer.timeout.connect(func(): 
		#if callable is Signal:
			#callable.emit()
		#else:
			#callable.call()
	#)
	#timer.autostart = true
	#add_child(timer)
	
	await get_tree().create_timer(delay).timeout
	if callable is Signal:
		callable.emit()
	else:
		callable.call()


# Static / Global

enum _ReadonlyAlts { read_only = 1, editable = 0, disabled = 1 }

## Generic method to set a control to read only, mapping to most appropriate propery to do so
static func set_read_only(control, on = true):
	for k in _ReadonlyAlts:
		if control.get(k) != null:
			if not _ReadonlyAlts[k]:
				on = not on
			control[k] = on
			return


## A test for equivalence which treats arrays and dictionaries the same if the contain matching 
## elements and keys. Different types will ALWAYS return false even comparing float(0.0) with int(0)
## floats will be compared using built-in function is_equal_approx(...)
static func equivalent(a,b):
	if typeof(a) != typeof(b):
		return false
	
	if a == b:
		return true
	
	if a is float:
		return is_equal_approx(a,b)
	
	if a is Array and a.size() == b.size():
		for i in a.size():
			if not equivalent(a[i],b[i]):
				return false
		return true
	
	if a is Dictionary and a.size() == b.size():
		for k in a:
			if not equivalent(a.get(k),b.get(k)):
				return false
		return true
	
	return a == b


## Converts snake case and camel case identifiers into readable space-delimited titles
static func format_label(name: String):
	return name.to_snake_case().replace("_", " ").capitalize()


static func _format_label(name: String):
	return name.to_snake_case().replace("_", " ").capitalize()


## Sets nodes and all children owner. If no owner provided this node will be made the owner 
## of all its descendants
static func set_owner_recursive(node, new_owner = null):
	if node:
		if new_owner:
			if node.owner == null:
				node.owner = new_owner
		else:
			new_owner = node
		for child in node.get_children():
			set_owner_recursive(child, new_owner)


## Returns the file containing this node or resource, if there is one
static func get_containing_file(item):
	if item is String:
		return item.split("::")[0]
	elif item is Resource:
		return get_containing_file(item.resource_path)
	elif item is Node:
		if item.scene_file_path:
			return item.scene_file_path
		return get_containing_file(item.get_parent())


# resource helpers	

## Returns true if the item is contained in a file and optionally is external to the second argument
static func is_external(item, comparedTo = null) -> bool:
	item = get_containing_file(item)
	if item:
		return item != get_containing_file(comparedTo)
	return false


static func load_resource(path):
	return ResourceLoader.load(path)


static func get_resource_path(ob):
	if ob is Resource:
		return ob.resource_path


## Returns an array of all dynamic assets that are linked to external files
static func find_assets(root, results = []):
	if root:
		if root is TBG.MotionCharacter and root.scene_file_path:
			results.append(root)
		else:
			for child in root.get_children():
				find_assets(child, results)
	return results


static func _get_paged_property_lists(ob):
	var map = {}
	if not map.has(null):
		map[null] = []
	var list = map[null]
	
	for prop in ob.get_property_list():
		if prop.usage == PROPERTY_USAGE_CATEGORY:
			# print_debug("# Category:", prop)
			if not map.has(prop.name):
				map[prop.name] = []
			list = map[prop.name]
			continue
		list.append(prop)
	
	var lists = []
	for category in map:
		list = map[category]
		if not list.is_empty():
			if category: # add category name at the front
				list.push_front({
					"name": category,
					"type": TYPE_NIL,
					"usage": PROPERTY_USAGE_CATEGORY
					})
			lists.append(list)
	return lists


static func clear_connections(_signal : Signal):
	for c in _signal.get_connections():
		_signal.disconnect(c.callable)


static func map_all_properties(script : Script):
	var result = {}
	if script:
		for prop in script.get_script_property_list():
			result[prop.name] = prop
	return result


# returns a Dictionary of all serializable properties
static func get_properties(object, include_objects = true, include_null = false):
	# Create a dictionary to hold the property values
	var properties = {}
	
	# Iterate over each property
	for property in object.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE:
			var value = object.get(property.name)
			if value == null:
				if not include_null:
					continue
			if value is Object:
				if not include_objects:
					continue
				if property.name == "script":	# too dangerous to let this through
					continue
					
			properties[property.name] = value
	
	return properties


static func copy_properties_recursively(source, dest, include_objects = true, include_null = true):
	var props = get_properties(source,include_objects,include_null)
	#trace("copyProperties: %s" % [props.keys()])
	set_properties(dest, props)
	for source_child in source.get_children():
		var dest_child = dest.get_node_or_null(source.get_path_to(source_child))
		if dest_child:
			copy_properties_recursively(source_child, dest_child, include_objects, include_null)
		elif include_objects:
			dest_child = source_child.duplicate()
			dest.add_child(dest_child)
			dest_child.owner = dest
	
	if include_null:
		for dest_child in dest.get_children():
			var source_child = source.get_node_or_null(dest.get_path_to(dest_child))
			if not source_child:
				dest_child.queue_free()


static func copy_properties(source, dest, include_objects = true, include_null = false):
	var props = get_properties(source, include_objects, include_null)
	#trace("copyProperties: %s" % [props.keys()])
	set_properties(dest, props)	


static func copy_signals(source, dest, include_null = false):
	for signal_info in source.get_signal_list():
		for connection in source.get_signal_connection_list(signal_info.name):
			if connection.flags & CONNECT_PERSIST:
				var callable = connection.callable
				if callable.get_object() == source:
					callable = Callable(dest, callable.get_method())
					callable.bindv(connection.callable.get_bound_arguments())
					
				if not dest.is_connected(signal_info.name, callable):
					trace("connect: %s -> %s" % [signal_info.name, callable])
					dest.connect(signal_info.name, callable, connection.flags)


static func set_property(object : Object, key, value):
	var old_value = object.get(key)
	if not equivalent(old_value, value):
		trace("set_property: %s = %s" % [key, value])
		object.set(key, value)
		return true


static func set_properties(object : Object, properties : Dictionary):
	# Iterate over each property
	for key in properties:
		set_property(object, key, properties[key])
	
	object.notify_property_list_changed()


static func json_ify(ob, propertyMask = PROPERTY_USAGE_DEFAULT):
	if ob is Object:
		var object = ob
		ob = { ".class": ob.get_class() }
		for property in object.get_property_list():
			if property.usage & propertyMask: # includes editor values as well as serialized values
				var value = object.get(property.name)
				if value is Resource and value.resource_path:
					value = str("<", value.resource_path, ">")
				ob[property.name] = json_ify(value)
	
	elif ob is Dictionary: 
		ob = ob.duplicate()
		for k in ob:
			ob[k] = json_ify(ob[k])
	
	elif ob is Array:
		ob = ob.duplicate()
		for i in ob.size():
			ob[i] = json_ify(ob[i])
	
	return ob


static func save_json(filename, object):
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if not file.is_open():
		print("Can't open for writing: ", filename)
		return
	
	file.store_line(JSON.stringify(object, "\t"))
	file.close()


static func load_json(filename):
	var file = FileAccess.open(filename, FileAccess.READ)
	if not file.is_open():
		print("Can't open for reading: ", filename)
		return null
	
	var data = file.get_as_text()
	file.close()
	
	var object = JSON.parse_string(data)
	if object == null:
		print("Error parsing JSON from file: ", filename)
	
	return object


static func get_containing_scene(node)->PackedScene:
	if node:
		node = find_containing(node, func(node):return node.scene_file_path)
		if node:
			return load(node.scene_file_path)
	
	return null


## if scene is inherited, this will return the scene it inherits	
static func get_base_scene(scene)->PackedScene:
	if scene:
		if scene is Node:
			scene = get_containing_scene(scene)
		elif scene is String:
			scene = load(scene)
			
		if scene:
			var idx = scene._bundled.get("base_scene", -1) as int
			if idx > -1:
				return scene._bundled.variants[idx]
	
	return null


# there is currently no published method for doing this programmatically, 
# so we are obliged to use a hack instead
# see https://github.com/godotengine/godot-proposals/issues/3907#issuecomment-1219013739
static func create_inherited_scene(_inherits : PackedScene, _root_name : String = "")->PackedScene:
	if _root_name.is_empty():
		_root_name = _inherits._bundled["names"][0]
	var scene := PackedScene.new();
	scene._bundled = {
			"base_scene": 0, "conn_count": 0, "conns": [], "editable_instances": [], 
			"names": [_root_name], "node_count": 1, "node_paths": [], 
			"nodes": [-1, -1, 2147483647, 0, -1, 0, 0], 
			"variants": [_inherits], "version": 3
	}
	return scene


## creates a mew scene if necessary
static func get_writable_scene_path(path):
	if path.get_extension() == DEFAULT_SCENE_EXTENSION:
		return path
		
	var readonlyScene = load(path)
	if readonlyScene is PackedScene:
		var filename = "%s.%s" % [path.get_basename(), DEFAULT_SCENE_EXTENSION]
		if FileAccess.file_exists(filename): # we need to copy/create here
			var scene = load(filename)
			if scene is PackedScene:
				if get_base_scene(scene) == readonlyScene:
					return filename
			warn("%s is not direct descendant of %s, will be overwritten" % [filename.get_file(), path.get_file()])
		
		instance.log("Creating writable scene: %s" % filename)		
		var writableScene = create_inherited_scene(readonlyScene)
		if Error.OK == ResourceSaver.save(writableScene, filename):
			return filename


# script helpers

# swaps scripts but keeps properties
static func set_object_script(ob, script):
	if script is String:
		script = load(script)
	
	if script != ob.script:
		trace("Replacing script in %s (from %s to %s)" % [ob, ob.script, script])
		var props = get_properties(ob, true, true)
		ob.set_script(script)
		set_properties(ob, props)


static func is_script_editable(script):
	if script is Resource:
		script = script.resource_path
	
	if script:
		if FileAccess.file_exists(script):
			return not script.begins_with(BASE_PATH)
	
	return false


## returns either a nice type name or a quoted path string	
static func get_class_name(script: Script):
	## TODO: Update to support 4.3 get_global_class() when updating Godot version
	if script.resource_name:
		return script.resource_name
	
	var map = script.get_script_constant_map()
	for k in map:
		var value = map[k]
		if value is Script:
			if script == map[k]:
				return str("", k)
	
	if script.resource_path:
		return str('"', script.resource_path, '"')
	
	return script.resource_path


static func create_script(path, base_type = null):
	if base_type is String:
		base_type = load(base_type)
	
	if base_type is Script:
		base_type = get_class_name(base_type)
	
	elif base_type:
		base_type = str(base_type)
	
	instance.log("Creating new script \"%s\" (extends %s)" % [path, base_type])
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_line("@tool")
		if base_type:
			file.store_line("extends %s" % base_type)
		
		file.store_line("# Add custom code here")
		
		file.close()
		instance.log("Script created: " + path)


# this lets us save arbitrary variant as a resource (preserving native types)
# in most cases data would probably be a dictionary
func save_as_resource(filename, data):
	var res = Data.new()
	res.data = data
	ResourceSaver.save(res, filename)


func load_as_resource(filename):
	var res = load(filename)
	if res is Data:
		return res.data


static func dump(node, prefix = ""):
	var text = node.get_class()
	if "text" in node and node.text:
		text += " \"" + node.text + "\""
	elif "name" in node and node.name:
		text += " {" + node.name + "}"
	
	if node is Viewport:
		text += str(node.get_visible_rect())
	
	instance.log("%s+%s" % [prefix, text])


static func dump_parents(_node, prefix = ""):
	var lineage = []
	while _node:
		lineage.push_front(_node)
		_node = _node.get_parent()
		
	for node in lineage:
		dump(node,prefix)
		prefix += " "


static func dump_recursive(node, prefix = ""):
	dump(node, prefix)
	prefix += " "
	for child in node.get_children(true):
		dump_recursive(child, prefix)


static func normalize_path(path):
	var separator = "/"
	path = ProjectSettings.globalize_path(path).replace("\"", separator)
	
	var path2 = []
	for part in path.split(separator):
		if part == "..":
			path2.pop_back()
		elif part == ".":
			pass
		else:
			path2.push_back(part)
	
	return separator.join(path2)


static func open_externally(path):
	path = normalize_path(path)
	if not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path):	
		warn("Path not found: %s" % path)
		return
	
	path = "file://" + path
	instance.log("Opening: %s" % path)
	OS.shell_open(path)	


## opens parent folder	
static func show_in_file_manager(path):
	path = path.get_base_dir()	
	open_externally(path)


static func get_asset_editor_path():
	var path;
	var file = FileAccess.open("res://.tb_paths.txt", FileAccess.READ)
	if file:
		path = file.get_line()
		if not path.is_empty():
			if OS.get_name() == "macOS":
				if not DirAccess.dir_exists_absolute(path):
					printerr(get_tr("ERR_FIND_ASSET_EDITOR_APP") % path)	
					return ""
			else:
				if OS.get_name() == "Windows":
					path = path.get_base_dir().path_join("AssetEditor.exe")
				if not FileAccess.file_exists(path):
					printerr(get_tr("ERR_FIND_ASSET_EDITOR_AT") % path)	
					return ""
			return path
	
	var dir = OS.get_executable_path().get_base_dir();
	if OS.get_name() == "Windows":
		path = dir.get_base_dir().path_join("AssetEditor").path_join("win64").path_join("bin").path_join("AssetEditor.exe")
		if not FileAccess.file_exists(path):
			printerr(get_tr("ERR_FIND_ASSET_EDITOR_AT") % path)
			path = dir.get_base_dir().path_join("AssetEditor.exe")
			instance.log("Trying fallback location: %s" % path)
			if not FileAccess.file_exists(path):
				printerr(get_tr("ERR_FIND_ASSET_EDITOR"))
				return ""
	elif OS.get_name() == "macOS":
		# Asset Editor.app is expected to be in the same folder as Game Engine (Godot) app 
		path = dir.get_base_dir().get_base_dir().get_base_dir().path_join("Asset Editor.app")
		if not DirAccess.dir_exists_absolute(path):
			printerr(get_tr("ERR_FIND_ASSET_EDITOR_APP") % path)	
			return ""
	else: # Linux
		path = dir.get_base_dir().path_join("AssetEditor").path_join("lnx86_64").path_join("bin").path_join("AssetEditor")
		if not FileAccess.file_exists(path):
			printerr(get_tr("ERR_FIND_ASSET_EDITOR_AT") % path)
			path = dir.get_base_dir().path_join("AssetEditor")
			instance.log("Trying fallback location: %s" % path)
			if not FileAccess.file_exists(path):
				printerr(get_tr("ERR_FIND_ASSET_EDITOR"))
				return ""
	
	return path


static func quote(string):
	return '"' + string + '"'


static func get_asset_source_path(tbg_path:String):
	# Should be a tbg file
	var scene = load(tbg_path) as PackedScene
	if scene == null:
		return null
	var path = ""
	for i in scene.get_state().get_node_property_count(0):
		#print(scene.get_state().get_node_property_name(0, i), ": ", scene.get_state().get_node_property_value(0, i))
		if (scene.get_state().get_node_property_name(0, i) == "metadata/tgsPath"):
			path = scene.get_state().get_node_property_value(0, i)
			break
	if path:
		path = "res://../Assets".path_join(path)
		if FileAccess.open(path, FileAccess.READ):
			return path
	
	# print("No source found for asset: ", path)


static func cog_xy(cog):
	if cog.z != 0:
		return Vector2(cog.x, cog.y) / cog.z
	
	return Vector2.ZERO


static func cog_transform(cog, tx):
	if cog.z != 0:
		var v = Vector2(cog.x, cog.y) / cog.z
		v = tx * v
		cog.z *= tx.x.cross(tx.y)
		v *= cog.z
		cog.x = v.x
		cog.y = v.y
		
	if cog.z < 0:
		cog = -cog
	
	return cog


static func get_polygon_cog(points):
	var cog = Vector3.ZERO # homogenous value, cog = (x,y)/z
	
	if points:
		var a = points[points.size()-1]
		for b in points:
			var _area = a.cross(b) * 0.5 # triangle area is half the cross
			var _center = (a+b)/3 	# c is implied, it is always zero here
			cog += Vector3(_center.x, _center.y, 1) * _area
			a = b
	
	return cog


static func get_cog(node):
	var cog = Vector3.ZERO
#
#	if node is Polygon2D:
#		if node.visible:
#			if node is Element:
#				node.validate()
#				var polygons = node.getMaskGeometry()
#				if polygons:
#					for loop in polygons:
#						cog += get_polygon_cog(loop)
#			else:
#				cog += get_polygon_cog(node.polygon)
#
#	for child in node.get_children():
#		cog += get_cog(child)
#
#	if cog.z:
#		cog = cog_transform(cog, node.transform)
	
	return cog


## Returns bounding rect of all Polygons under this node
static func bounding_rect(node, tx := Transform2D.IDENTITY, rc = null):
	if "transform" in node:
		tx = tx * node.transform
	
	if node is Polygon2D:
		# Ignore skinned polygons
		if node.skeleton.is_empty():
			for vertex in node.polygon:
				vertex = tx * vertex
				if rc == null:
					rc = Rect2(vertex, Vector2.ZERO)
				else:
					rc = (rc as Rect2).expand(vertex)
	elif node is Sprite2D:
		if node.visible:
			var rect: Rect2 = (node as Sprite2D).get_rect()
			# We need to rotate, scale, and move this rect then figure out the result rect
			var edges: Array[Vector2] = [
				tx * (rect.position),
				tx * (rect.position + Vector2.RIGHT * rect.size),
				tx * (rect.position + Vector2.DOWN * rect.size),
				tx * (rect.position + rect.size)
			]
			rect = Rect2(
				min(edges[0].x, edges[1].x, edges[2].x, edges[3].x),
				min(edges[0].y, edges[1].y, edges[2].y, edges[3].y),
				max(edges[0].x, edges[1].x, edges[2].x, edges[3].x),
				max(edges[0].y, edges[1].y, edges[2].y, edges[3].y)
			)
			rect.size -= rect.position
			
			if rc == null:
				rc = rect
			else:
				rc = (rc as Rect2).merge(rect)
	
	# Semi-wasted since all sprites are direct children of the composite
	# but still a helper function if needed
	for child in node.get_children():
		rc = bounding_rect(child, tx, rc)
	
	return rc


static func open_in_asset_editor(path):
	path = normalize_path(path)
	if not FileAccess.file_exists(path):	
		warn("Path does not exist: %s" % path)
		return
	var app = get_asset_editor_path()
	if app.is_empty():
		printerr(get_tr("OPEN_GAME_ENGINE_FROM_JUMP"))
		return
	var args = ["-tbg", path]
	#print("Creating process: ", app, args)
	return OS.create_process(app, args)


# returns an array of full paths
static func find_files(root:String, predicate = true, folderPredicate = true):
	var files = []
	
	var override = false
	
	var dir = DirAccess.open(root)
	
	if not root.ends_with("/"):
		root += "/"
	
	# Using .. to acces parent dir from res:// does not work on windows, this is a workaround using absolute path instead
	if dir == null:
		if root.begins_with("res://../"):
			var path = ProjectSettings.globalize_path("res://")+root.replace("res://","")
			dir = DirAccess.open(path)
			if dir.dir_exists(path):
				override = true
	
	if dir and (dir.dir_exists(root) or override):
		dir.list_dir_begin()
		var filename = dir.get_next()
		while not filename.is_empty():
			if not filename.begins_with("."):	# always skip dot paths
				var fullpath = dir.get_current_dir().path_join(filename)
				# We do not want to use the fullpath directly if its not a res:// path since it will not be parsed correctly since its an absoulte path
				# Instead we want to use the res:// path that was given as an argument
				if not fullpath.begins_with("res://"):
					fullpath = root + filename
				if dir.current_is_dir(): # recurse?
					if folderPredicate.call(fullpath) if folderPredicate is Callable else folderPredicate:
						files.append_array(find_files(fullpath, predicate, folderPredicate))
				else:
					if predicate.call(fullpath) if predicate is Callable else predicate:
						files.push_back(fullpath)
			
			filename = dir.get_next()
			
		dir.list_dir_end()
	
	return files


static func find_files_of_type(root, extensions):
	if extensions is String:
		extensions = extensions.split(";")
	
	return find_files(root, func(path) : return path.get_extension() in extensions)


static func get_value(item, path):
	if path is Array:
		for key in path:
			item = item.get(key)
			if item == null or item.is_empty():
				return null
	else:
		item = item.get(path)
	
	return item	


static func null_or_empty(item):
	return not item or item.empty()


static func find_skeleton(node):
	while node and not node is Skeleton2D:
		node = node.get_parent()
	return node


static func resolve(v):
	while v is Callable:
		v = v.call()
	return v


static func map(array, fn:Callable):
	var result = []
	for item in array:
		result.push_back(fn.call(item))
	return result


static func get_ascendants(node):
	var result = []
	node = node.get_parent()
	while node:
		result.append(node)
		node = node.get_parent()
	return result	


static func find_element(array, pred:Callable):
	for item in array:
		if pred.call(item):
			return item


static func find_element_index(array, pred:Callable):
	for idx in array.size():
		if pred.call(array[idx]):
			return idx
	
	return -1


# using a predicate or type
static func find_topmost(node, predOrType):
	if node:
		var result = find_topmost(node.get_parent(), predOrType)
		if result == null:
			if predOrType.call(node) if predOrType is Callable else is_instance_of(node, predOrType):
				result = node
		return result


static func contains(parent:Node, child:Node):
	if child and parent:
		if child == parent:
			return true
		return contains(parent, child.get_parent())


static func find_containing(node, rhs):
	if node is Node:
		if TBG.node_matches(node, rhs):
			return node
		
		return find_containing(node.get_parent(), rhs)


static func invalidate(node:Node):
	if node and node.is_inside_tree():
		if node.has_method("invalidate"):
			node.invalidate()
		
		for child in node.get_children():
			invalidate(child)


static func validate(node:Node):
	if node and node.is_inside_tree():
		if node.has_method("validate"):
			node.validate()
		
		for child in node.get_children():
			validate(child)


static func quantize_t(t: float, hz = 60) -> float:
	if hz:
		t = int(t * hz + 0.00001) / hz # small offset is to make sure we don't fall below frame
	return t


static func find_depth_to_asset(node:Node, root:TBG.MotionCharacter):
	var depth = 0
	if node == root:
		return depth
	if node.get_parent() == null:
		return -1 #Here it should be an error... we're using this function for runtime processing
	var node_class = node.get_class()
	var rootNodes = TBG.find_nodes(root, func(node2): return node2.name == node.name)
	if node not in rootNodes: # Check if the node is a child of the root
		return -1
	#TODO: Finish to process the relative path computing
	return 1 + find_depth_to_asset(node.get_parent(), root)
	
	pass


static func get_relative_path_to_asset(node:Node, root:TBG.MotionCharacter):
	var depth = find_depth_to_asset(node, root)
	var relPath = ""
	while depth > 0:
		relPath = "../" + relPath
		depth = depth - 1
	return relPath


static func value_at(animation:Animation, track_idx, t = 0.0):
	match animation.track_get_type(track_idx):
		Animation.TYPE_VALUE:
			return animation.value_track_interpolate(track_idx, t)
		Animation.TYPE_BEZIER:
			return animation.bezier_track_get_key_value (track_idx, t)
	return null


static func current_import_version():
	return 4


static func minimum_import_version():
	return 4
