@tool
extends Node2D

#For a node to be considered for multiselect, it has to have MultiselectComponent under the root node
#For nodes to have position property set through multiselect, that node type has to have last_position var

@onready var selection_rect = $SelectionRect

var is_pressed = false
var selection_start_pos = Vector2.ZERO
var selected:Array = [] #holds multiselect components
var removed_with_shift_select = false

func _ready():
	SB.node_selected.connect(on_node_selected)

func on_node_selected(node):
	var multiselect_component = node.get_node_or_null("MultiselectComponent")
	if multiselect_component != null:
		if not multiselect_component in selected:
			if not Input.is_key_pressed(KEY_SHIFT):
				clear_selection()
			add_to_selected(multiselect_component)
		else:
			if Input.is_key_pressed(KEY_SHIFT) and not removed_with_shift_select:
				remove_from_selected(multiselect_component)
				removed_with_shift_select = true
				if selected.size() > 0:
					SB.emit_signal("node_selected", selected[0].parent)
			elif removed_with_shift_select:
				removed_with_shift_select = false
	else:
		clear_selection()

func _on_storyboard_view_gui_input(event):
	await get_tree().process_frame
	await get_tree().process_frame
	
	if SB.is_something_pressed():
		var obj = instance_from_id(SB.obj_pressed)
		if obj and obj.parent:
			var mc = obj.parent.get_node_or_null("MultiselectComponent")
			if mc != null and not mc in selected and not Input.is_key_pressed(KEY_SHIFT):
				clear_selection()
#			elif mc == null:
#				clear_selection()
		return
	
	if event is InputEventMouseButton and event.button_index == 1 and event.pressed or event is InputEventKey:
		clear_selection()
	if not is_pressed and event is InputEventMouseButton and event.button_index == 1 and event.pressed and not Input.is_key_pressed(KEY_SPACE):
		start_marquee()
	elif is_pressed and (event is InputEventMouseButton and not event.pressed or Input.is_key_pressed(KEY_SPACE)):
		end_marquee()
	elif is_pressed:
		update_marquee()

func on_node_property_changed(property, value, obj):
	var to_delete = []
	
	for node in selected:
		if node == obj:
			continue
		
		if property == "position":
			var last_position = obj.parent.get("last_position")
			if last_position != null and not property in node.do_not_update_list:
				node.parent.position += value - obj.parent.last_position
		elif property == "delete":
			to_delete.append(node)
		else:
			node.set_property_from_multiselect(property, value)
	
	for node in to_delete:
		node.set_property_from_multiselect(property, value)

func on_multiselect_request_update():
	for node in selected:
		node.parent.request_update()

func start_marquee():
	is_pressed = true
	selection_start_pos = get_global_mouse_position()
	selection_rect.global_position = selection_start_pos
	selection_rect.size = Vector2.ZERO
	selection_rect.show()

func update_marquee():
	var size = get_global_mouse_position() - selection_start_pos
	if size.x < 0:
		selection_rect.global_position.x = selection_start_pos.x + size.x
	if size.y < 0:
		selection_rect.global_position.y = selection_start_pos.y + size.y
	selection_rect.size = abs(size)

func end_marquee():
	is_pressed = false
	selection_rect.hide()
	
	var viewport_pos = SB.storyboard_view.grid.get_global_mouse_position()
	var rect_pos = viewport_pos
	var rect_size = selection_rect.size/SB.storyboard_view.view.view_scale
	var mouse_pos = get_global_mouse_position()
	
	if mouse_pos.x != selection_rect.global_position.x:
		rect_pos.x -= rect_size.x
	if mouse_pos.y != selection_rect.global_position.y:
		rect_pos.y -= rect_size.y
	
	var set_node_selected = false
	for scene in SB.storyboard_view.container.get_children():
		if Rect2(rect_pos, rect_size).intersects(Rect2(scene.global_position, scene.size)):
			add_to_selected(scene.multiselect_component)
			if not set_node_selected:
				SB.emit_signal("node_selected", scene)
				set_node_selected = true

func add_to_selected(node):
	node.show_multiselect_visual(true)
	selected.append(node)
	node.property_changed.connect(on_node_property_changed.bind(node))
	node.multiselect_request_update.connect(on_multiselect_request_update)
	node.remove_from_selection.connect(remove_from_selected.bind(node))
	node.in_multiselect = true

func remove_from_selected(node, erase=true):
	node.show_multiselect_visual(false)
	node.property_changed.disconnect(on_node_property_changed)
	node.multiselect_request_update.disconnect(on_multiselect_request_update)
	node.remove_from_selection.disconnect(remove_from_selected)
	node.in_multiselect = false
	if erase:
		selected.erase(node)

func clear_selection():
	for node in selected:
		remove_from_selected(node, false)
	
	selected.clear()

func selection_rect_has_point(rect_pos:Vector2, rect_size:Vector2, point:Vector2) -> bool:
	return Rect2(rect_pos, rect_size).has_point(point)
