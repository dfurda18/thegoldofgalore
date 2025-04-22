@tool
## Used by DockPanel to get the relevant data
extends Tree
#class_name AssetTree

const TbgPlugin = preload("Plugin.gd")

signal context_menu(path, screen_position)
signal path_selected(path)
signal path_activated(path)
signal drag_start(path, struct)

@export var root = "res://"
@export var extension = "scn;tscn"
@export var selected_path: String:
	get = get_selected_path, set = set_selected_path

var drag

var content = null:
	set(value):
		if content == value:
			return
		# Get the difference
		var diff = []
		if content:
			for item in content:
				if item is Dictionary:
					item = item["text"]
				if not (value as Array).any(func(val):
					if val is Dictionary:
						val = val["text"]
					return val == item
				):
					diff.append(item)
		
		content = value
		_update.call_deferred(diff)

# this will be nil if not run from editor
var editor = TbgPlugin.instance


func _ready():
	# item_clicked.connect(_item_clicked)
	empty_clicked.connect(deselect_all.unbind(2))
	nothing_selected.connect(deselect_all)
	item_selected.connect(emit_path_selected)
	item_activated.connect(emit_path_activated)
	
	# only do this once
	clear()
	
	hide_root = true
	select_mode = Tree.SELECT_ROW
	
	columns = 2
	allow_rmb_select = true
	set_column_expand(1, false)
	#set_column_custom_minimum_width(1, 24)
	
	# we need 1 root
	create_item(null, 0).set_text(0,"All Assets")
	
	#var content = self.content
	#if content == null:
		#var extensions = extension.split(";")
		#if extensions.is_empty():
			#content = TbgPlugin.find_files(root)
		#else:
			#content = TbgPlugin.find_files(root, func(path) : return path.get_extension() in extensions )
		
		#content = content.map(func(path): return { "text": nameFromPath(path), "data": path } )
	
	#_update()


func _gui_input(event: InputEvent):
	if event is InputEventKey:
		if event.keycode == Key.KEY_ESCAPE:
			accept_event()
			if event.pressed:
				deselect_all.call_deferred()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not event.pressed:
				accept_event()
				context_menu.emit(get_selected_path(), get_screen_position() + get_local_mouse_position())


func _get_drag_data(pos):
	var path = get_selected_path()
	if path:
		var drag_data = {}
		drag_start.emit(path, drag_data)
		return drag_data


func get_item(path, create = false):
	if path.is_empty():
		return get_root()
	
	var parent = Array(path.split("/"))
	var leaf = parent.pop_back()
	
	var child = null
	
	var parent_item = get_item("/".join(parent), create)
	if parent_item:
		child = parent_item.get_first_child()
		while child and child.get_text(0) != leaf:
			child = child.get_next()
	
	# we didn't find it, so we add it
	if child == null and create:
		child = create_item(parent_item)
		child.set_text(0, leaf)
	
	# Sort itself with its siblings, for folder purposes
	if parent_item:
		var node = parent_item.get_prev()
		while node and (node.get_child_count() == 0 or
				node.get_text(0).nocasecmp_to(parent_item.get_text(0)) > 0):
			parent_item.move_before(node)
			node = parent_item.get_prev()
	
	return child


func set_item_tooltip(item, text):
	item.set_tooltip_text( 0, text )


func name_from_path(path):
	if path.begins_with(root):
		path = path.substr(root.length())
	
	return path.get_basename()


var data_to_item = {}
func _update(diff = null):
	# Not null and not empty
	if diff:
		# Erase the ones that have been deleted
		for temp_item in diff:
			var item = get_item(temp_item)
			# Shouldn't ever not exist, but better safe than sorry
			if item:
				item.free()
		
		# Now scan for empty folders
		var node: TreeItem = get_item("")
		while node:
			var next = node.get_next_in_tree()
			if not node.get_metadata(0) and node.get_child_count() == 0:
				next = node.get_parent()
				node.free()
			node = next
	
	var item: TreeItem = get_item("")
	for row in content:
		if not row is Array:
			row = [row]
		var column = 0
		for cell in row:
			if not cell is Dictionary:
				cell = { "text": cell }
			
			if column == 0:
				var temp_item : TreeItem = get_item(cell.text, true)
				# Make sure the tree is in order
				if item.get_parent() == temp_item.get_parent():
					temp_item.move_after(item)
				item = temp_item
				var data = cell.get("data", cell.text)
				item.set_metadata(0, data)
				data_to_item[data] = item
				item.set_tooltip_text(0, data)
				# Reset optional stuff
				item.clear_custom_bg_color(0)
				item.clear_custom_color(0)
				item.set_suffix(0, "")
				
				#if diff:
					#(diff as Array).erase(cell.text)
			else:
				if cell.get("text"):
					item.set_text(column, cell.text)
				if cell.get("data"):
					item.set_metadata(column, cell.data)
			
			if cell.get("tooltip"):
				item.set_tooltip_text(column, cell.tooltip)
			if cell.get("color"):
				item.set_custom_color(column, cell.color)
			if cell.get("bg_color"):
				item.set_custom_bg_color(column, cell.bg_color)
			if cell.get("suffix"):
				item.set_suffix(column, cell.suffix)
				
			column += 1


func emit_path_selected():
	path_selected.emit(get_selected_path())


func emit_path_activated():
	path_activated.emit(get_selected_path())


func _item_clicked(index, at_position, mouse_button_index):
	if mouse_button_index == MOUSE_BUTTON_RIGHT && index != -1:
		context_menu.emit(get_selected_path(), get_screen_transform().origin + at_position)


func get_selected_path():
	var selected = get_selected()
	if selected:
		return selected.get_metadata(0)


func set_selected_path(path):
	var item = data_to_item.get(path)
	if item:
		var parent = item.get_parent()
		while parent:
			parent.collapsed = false
			parent = parent.get_parent()
		
		set_selected(item, 0)
		ensure_cursor_is_visible()
	else:
		deselect_all()
		
	if is_inside_tree():
		queue_redraw()
