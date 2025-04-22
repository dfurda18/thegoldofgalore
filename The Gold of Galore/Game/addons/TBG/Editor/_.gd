@tool
## this is the Asset Editor name space TbgPlugin.Editor.*
# extends Node

const PropertiesView = preload("PropertiesView.gd")
const AssetTree = preload("AssetTree.gd")
const DockPanel = preload("DockPanel.gd")
const Grid = preload("Grid.gd")
const TbgPlugin = preload("Plugin.gd")

# components and resources
const EditorButton = preload("EditorButton.gd")
const PLUGIN_CONFIG_PATH = "res://addons/TBG/plugin.cfg"


static func create_plugin():
	if Engine.is_editor_hint():
		var script = load("res://addons/TBG/Editor/Plugin.gd")
		if script:
			return script.new()


static func create_asset_view():
	if Engine.is_editor_hint():
		var scene = load("res://addons/TBG/Editor/AssetView.tscn")
		if scene:
			return scene.instantiate()


static func create_dock_panel_UI():
	if Engine.is_editor_hint():
		var scene = load("res://addons/TBG/Editor/DockPanel.tscn")
		if scene:
			return scene.instantiate()


static func create_inspector_plugin():
	if Engine.is_editor_hint():
		var script = load("res://addons/TBG/Editor/InspectorPlugin.gd")
		if script:
			return script.new()


# key symbols
enum { TEXT, MENU, ACTION, CHECK }
static func menu_item(text: String, action = null, checked = null):
	if action is Array:
		# sub menu
		return { TEXT: text, MENU: menu_items(action) }
	return { TEXT: text, ACTION: action, CHECK: checked }


static func menu_items(array: Array):
	return array.map(func(e):
		if e is Array: # shorthand using array to avoid tedious labels
			e = menu_item(e[0], e[1] if e.size() > 1 else null, e[2] if e.size() > 2 else null)
		return e
		)


static func compute(v):
	while v is Callable:
		v = v.call()
	return v


static func set_menu_contents(menu, items = null):
	TbgPlugin.clear_connections(menu.index_pressed)
	menu.clear()
	for child in menu.get_children():
		child.queue_free()
	
	menu.size = Vector2i.ZERO
	items = compute(items)
	if items:
		var map = {}
		var _items = []
		for item in items: # build dynamic parts
			item = compute(item)
			if item is Array:
				if item:
					if item.front() is String:	# it's an item
						_items.append(item)
					else:
						_items.append_array(item)
			else:
				_items.append(item)
		
		_items = menu_items(_items)
		var lastItem
		for item in _items:
			if item:
				var idx = menu.item_count
				var _name = item.get(TEXT, str("#",idx))
				if item.get(MENU):
					var submenu = new_menu(_name, item.get(MENU))
					menu.add_child(submenu)
					# print("Submenu: %s -> %s" % [_name, submenu.name])
					menu.add_submenu_item(_name, submenu.name)
				else:
					var check = compute(item.get(CHECK))
					
					if check == null:
						menu.add_item(_name)
					else:
						menu.add_check_item(_name)
						menu.set_item_checked(idx, check)
						
					var action = item.get(ACTION)
					if action:
						map[idx] = item
					else:
						menu.set_item_disabled(idx, true)
			elif lastItem:
				menu.add_separator()
			lastItem = item
		
		menu.index_pressed.connect(TbgPlugin.Editor.menu_pressed_callback.bind(map))
	return menu


static func menu_pressed_callback(id: int, map) -> void:
	var item = map.get(id)
	if item and item[ACTION]:
		TbgPlugin.instance.defer(item[ACTION], 0.1)


static func new_menu(name = "Menu", items = null) -> PopupMenu:
	var menu = PopupMenu.new()
	menu.name = name
	menu.about_to_popup.connect(TbgPlugin.Editor.set_menu_contents.bind(menu, items))
	return menu


static func new_menu_button(label = null, items = null):
	# vertical elipsis, ie settings etc
	if label == ":":
		label = get_icon("GuiTabMenu")
	elif label is String and label.begins_with(":"):
		label = get_icon(label.substr(1))
	
	var button = MenuButton.new()
	
	if label is Texture2D:
		button.icon = label
	else:
		button.text = label
	
	var menu = button.get_popup()
	menu.about_to_popup.connect(TbgPlugin.Editor.set_menu_contents.bind(menu, items))
	return button


## Allows menu to be added to both MenuBar and toolbar style control.
## Menu data is best passed as arrays or callables.
## eg: ["File", [["Open...", func(): launchOpenFileDialog(".xyz")],null,["Quit", _exit]]]
static func set_menu(bar: Control, path = null, data = null):
	if bar:
		if path == ".": # replace the whole menu if we have no path here
			if data is Control:
				bar.replace_by(data)
			else:
				for menu in bar.get_children():
					menu.queue_free()
				if data is Callable:
					data = data.call()
				if data is Array:
					for item in data:
						if item is Array and item.size() > 1:
							set_menu(bar, item[0], item[1])
		else:
			var oldMenu = bar.get_node_or_null(path)
			# generate data from array
			if data is Array or data is Callable:
				if bar is MenuBar:
					data = TbgPlugin.Editor.new_menu(path, data)
				else:
					data = TbgPlugin.Editor.new_menu_button(path, data)
			if oldMenu:
				if data:
					oldMenu.replace_by(data)
				oldMenu.queue_free()
			elif data:
				bar.add_child(data)


static func get_icon(name : String, theme_type := "EditorIcons") -> Texture2D:
	if TbgPlugin.instance.theme.has_icon(name, theme_type):
		return TbgPlugin.instance.theme.get_icon(name, theme_type)
	return null


static func get_icon_list(theme_type := "EditorIcons") -> PackedStringArray:
	return TbgPlugin.instance.theme.get_icon_list(theme_type)
