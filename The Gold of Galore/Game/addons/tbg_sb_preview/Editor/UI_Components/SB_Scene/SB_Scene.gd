@tool
extends "res://addons/tbg_sb_preview/Editor/UI_Components/SB_Node/SB_Node.gd"
class_name SBScene

## Used to change which of the panels will scene show the thumbnail from
@export var panel_thumbnail_to_show = 1 : set=set_panel_thumbnail_to_show
## Sets how many panels will be shown in a single row
@export var panels_per_row = 5 : set=set_panels_per_row
## Horizontal separation between the panels in the row
@export var horizontal_panel_separation = 50 : set=set_horizontal_panel_separation
## Verical separation between the rows of panels
@export var vertical_panel_separation = 60 : set=set_vertical_panel_separation

@export_category("Sequence")
@export var show_sequence_name = false : set=set_show_sequence_name
@export var unique_properties_in_sequence = false

@onready var sb_panel_container = $UncollapsedPanel/SBPanelsContainer
@onready var background:Panel = $Panel
@onready var sb_jumps_container = $SBJumpsContainer
@onready var sb_panel_jumps_container = $SBPanelJumpsContainer
@onready var sb_jump_points = $SBJumpPoints
@onready var texture_rect = $Panel/HBoxContainer/TextureRect
@onready var collapsed_thumbnail = $Panel/HBoxContainer/TextureRect
@onready var uncollapsed_thumbnail = $UncollapsedPanel/HBoxContainer/TextureRect
@onready var sequence_name_lbl = $SequenceName

var delete = false : set=set_delete #used only for multiselect
var SB_Jump = load("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Jump/SB_Jump.tscn")
var SB_Panel = load("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Panel/SB_Panel.tscn")
var offset_from_end = 10
var collapsed_size = size
var uncollapsed_size = size
var allow_new_jump = true
var allow_request_update = true
var context_menu_opened_loc = Vector2.ZERO
var auto_generated_panel
var sequence = "0" : set=set_sequence

signal scene_resized(old_size)
signal deleted

func _get_property_list():
	var properties = []
	properties.append({
		"name": "text",
		"type": TYPE_STRING,
	})

	return properties

func _ready():
	super._ready()
	resize()
	set_collapsed(true)

func set_show_sequence_name(v):
	show_sequence_name = v
	if not sequence_name_lbl:
		return
	
	sequence_name_lbl.visible = v
	multiselect_component.set_property("show_sequence_name", show_sequence_name)

func set_sequence(v):
	sequence = v
	sequence_name_lbl.text = "Sequence: " + sequence

func set_color(_color):
	super.set_color(_color)
	apply_to_all_in_sequence("set_color", "color", _color)

func set_border_color(v):
	super.set_border_color(v)
	apply_to_all_in_sequence("set_border_color", "border_color", v)

func apply_to_all_in_sequence(method, param, arg):
	if not is_inside_tree():
		return
	
	if unique_properties_in_sequence:
		return
	
	for scene in get_tree().get_nodes_in_group("SB_Scene"):
		if scene == self:
			continue
		elif scene.sequence == sequence and scene.get(param) != arg and not scene.unique_properties_in_sequence:
			scene.call(method, arg)

func set_panels_per_row(v):
	if not sb_panel_container:return
	panels_per_row = max(v, 1)
	update_layout()
	multiselect_component.set_property("panels_per_row", panels_per_row)

func set_horizontal_panel_separation(v):
	if not sb_panel_container:return
	horizontal_panel_separation = max(0.0, v)
	update_layout()
	multiselect_component.set_property("horizontal_panel_separation", horizontal_panel_separation)

func set_vertical_panel_separation(v):
	if not sb_panel_container:return
	vertical_panel_separation = max(0.0, v)
	update_layout()
	multiselect_component.set_property("vertical_panel_separation", vertical_panel_separation)

func set_panel_thumbnail_to_show(v):
	panel_thumbnail_to_show = max(v, 1)
	if sb_panel_container and sb_panel_container.get_child_count() != 0:
		panel_thumbnail_to_show = clamp(v, 1, sb_panel_container.get_child_count())
		set_thumbnail()
		if is_ready:
			request_update()

func set_thumbnail():
	if sb_panel_container.get_child_count() == 0:
		return
	
	var thumbnail = sb_panel_container.get_child(panel_thumbnail_to_show-1).thumbnail
	if thumbnail == null:return
	collapsed_thumbnail.texture = thumbnail
	uncollapsed_thumbnail.texture = thumbnail

func create_new_panel():
	var panel = SB_Panel.instantiate()
	add_panel(panel)
	
	if not collapsed:
		var pos_offset = panel.collapsed_size/2
		panel.global_position = get_global_mouse_position() - pos_offset
		panel.node_pressed()
		panel.order_changed.connect(on_panel_order_changed.bind(panel))
	else:
		var pnl_id = sb_panel_container.get_child(panel.order_in_scene-2).id
		request_add_new_panel(panel, pnl_id, true)

func on_panel_order_changed(panel):
	panel.order_changed.disconnect(on_panel_order_changed)
	var pnl_id = sb_panel_container.get_child(1).id
	var after = true
	if panel.order_in_scene != 1:
		pnl_id = sb_panel_container.get_child(panel.order_in_scene-2).id
	else:
		after = false
	request_add_new_panel(panel, pnl_id, after)

func request_add_new_panel(panel, pnl_id, after):
	var pnl_data = {
		"id" : pnl_id,
		"after" : after
	}
	SB.add_to_gs(id, {"panel":panel, "scene_id":id}, SB.REQUEST.ADD_PANEL, pnl_data)

func add_panel(sb_panel):
	sb_panel_container.add_child(sb_panel)
	sb_panel.set_text(str(sb_panel_container.get_child_count()))
	sb_panel.set_local_id(SB.generate_id())
	sb_panel.parent_scene = self
	sb_panel.order_in_scene = sb_panel_container.get_child_count()
	sb_panel.collapsed_changed.connect(_on_pnl_collapse_changed)
	sb_panel.deleted.connect(on_panel_deleted)
	update_layout()
	SB.storyboard_view.connect_pressables()

func on_panel_deleted():
	update_layout()

func get_panel_from_id(id):
	var pnl_without_id
	for c in sb_panel_container.get_children():
		if c.using_local_id():
			if not pnl_without_id:
				pnl_without_id = c
			continue
		if c.id == id:
			return c
	if pnl_without_id:
		return pnl_without_id

func _on_pnl_collapse_changed(v):
	update_layout()

func update_layout(r_update=true):
	update_panels_order_in_scene()
	position_panels()
	var old_size = size
	resize()
	emit_signal("scene_resized", old_size)
	if is_ready and r_update:
		request_update()
	#connect_panels()

func resize():
	var _panels_per_row = panels_per_row 
	if not sb_panel_container.get_child_count() >= panels_per_row:
		_panels_per_row = max(1, sb_panel_container.get_child_count())
	
	var pnl_size = get_panel_size_to_use()
	
	uncollapsed_size.x = offset_from_end*2 + pnl_size.x * _panels_per_row + horizontal_panel_separation * (_panels_per_row-1)
	
	var rows_based_panel_height = 0
	var rows = get_total_rows()
	for i in rows:
		rows_based_panel_height += get_panel_height_per_row(i+1)
	
	#print(rows_based_panel_height)
	if sb_panel_container.get_child_count() > 0:
		uncollapsed_size.y = sb_panel_container.position.y + offset_from_end + rows_based_panel_height\
		+ vertical_panel_separation * (rows-1)
	else:
		uncollapsed_size.y = 70
	
	if not collapsed:
		size = uncollapsed_size

func get_panel_height_per_row(row):
	var i = 1
	var rows_based_panel_height = 0.0
	var all_panels_in_row_collapsed = true
	var cur_row = 1
	var pnl_counter = 1
	var child_count = sb_panel_container.get_child_count()
	
	for panel in sb_panel_container.get_children():
		if cur_row == row:
			if not panel.collapsed:
				all_panels_in_row_collapsed = false
			
			if i >= panels_per_row or pnl_counter >= child_count:
				if not all_panels_in_row_collapsed:
					rows_based_panel_height += panel.uncollapsed_size.y
				else:
					rows_based_panel_height += panel.collapsed_size.y
			
				all_panels_in_row_collapsed = true
	
		if i >= panels_per_row:
			i = 1
			cur_row += 1
		else:
			i += 1
		
		pnl_counter += 1
	
	return rows_based_panel_height

func get_total_rows():
	var i = 0
	var rows = 1
	
	#Position panels
	for panel in sb_panel_container.get_children():
		if i >= panels_per_row:
			rows += 1
			i = 0
		i += 1
	
	return rows

func position_panels():
	var i = 0
	var cur_number_of_rows = 1
	
	for panel in sb_panel_container.get_children():
		sb_panel_container.move_child(panel, panel.order_in_scene-1)
	
	var pnl_size = get_panel_size_to_use()
	var rows_height = 0.0
	
	#Position panels
	for panel in sb_panel_container.get_children():
		if i >= panels_per_row:
			cur_number_of_rows += 1
			i = 0
			rows_height += get_panel_height_per_row(cur_number_of_rows-1)
		
		panel.position.x = i * pnl_size.x + horizontal_panel_separation * i + offset_from_end
		panel.position.y = rows_height + vertical_panel_separation * (cur_number_of_rows-1)
		
		i += 1

func get_panel_size_to_use():
	var pnl_size = Vector2.ZERO
	
	if sb_panel_container.get_child_count() > 0:
		pnl_size = sb_panel_container.get_child(0).collapsed_size
		
		for pnl in sb_panel_container.get_children():
			if not pnl.collapsed:
				pnl_size = pnl.uncollapsed_size
				break
	
	return pnl_size

func connect_panels():
	if collapsed:
		return
	
	SB.clear_children(sb_panel_jumps_container)
	
	var i = 1
	var row_counter = 0
	
	for panel in sb_panel_container.get_children():
		#check its not the first or last panel
		if i != sb_panel_container.get_child_count():
			var next_panel = sb_panel_container.get_child(i)
			var sb_jump = SB_Jump.instantiate()
			sb_panel_jumps_container.add_child(sb_jump)
			
			var temp_points = []
			var points = []
			var pnl_container_pos = sb_panel_container.position
			
			#in case its the last panel in the row we add different points
			if row_counter+1 >= panels_per_row:
				row_counter = 0
				
				var start = Vector2(panel.size.x/2, panel.size.y)
				var middle1 = Vector2(panel.size.x/2, panel.size.y + vertical_panel_separation/2)
				var middle2 = Vector2(next_panel.size.x/2, -vertical_panel_separation/2)
				var end = Vector2(next_panel.size.x/2, 0)
				
				temp_points.append(pnl_container_pos + panel.position + start)
				temp_points.append(pnl_container_pos + panel.position + middle1)
				temp_points.append(pnl_container_pos + next_panel.position + middle2)
				temp_points.append(pnl_container_pos + next_panel.position + end)
			
			#when in the same row
			else:
				var start = pnl_container_pos + panel.position + panel.jump_from.position + panel.jump_from.size/2
				var end = pnl_container_pos + next_panel.position + next_panel.jump_to.position + next_panel.jump_to.size/2
				
				temp_points.append(start)
				temp_points.append(end)
				
				row_counter += 1
				
			for point in temp_points:
				var point_2d = Node2D.new()
				point_2d.global_position = point
				points.append(point_2d)
				sb_jump_points.add_child(point_2d)
			
			sb_jump.set_points(points)
		
		i += 1

func hovering_over_another_panel(pnl_moving):
	for pnl in sb_panel_container.get_children():
		if pnl == pnl_moving:
			continue
		
		if pnl.has_point(get_global_mouse_position()):
			sb_panel_container.move_child(pnl_moving, pnl.order_in_scene-1)
			update_panels_order_in_scene()
			position_panels()
			resize()
			set_thumbnail()
			return pnl
	
	return null

func update_panels_order_in_scene():
	var i = 1
	for pnl in sb_panel_container.get_children():
		pnl.order_in_scene = i
		i += 1

func sort_by_scene_order(a, b):
	return a.order_in_scene < b.order_in_scene

func add_jump_from_data(jump_data):
	#If already connected by a two way jump, dont connect again
	if jump_data.has("jumpTo"):
		for scene in SB.storyboard_view.container.get_children():
			if scene.id == jump_data["jumpTo"]:
				for jump in scene.sb_jumps_container.get_children():
					if jump.two_way and jump.jump_to.id == id:
						return
					if jump_data["twoWay"] == true and jump.jump_to.id == id:
						jump.queue_free()
	
	var sb_jump = SB_Jump.instantiate()
	sb_jumps_container.add_child(sb_jump)
	sb_jump.set_jump_from(self)
	sb_jump.set_data(jump_data)
	sb_jump.clamp_border_points()

func has_jump(jump_data):
	for jump in sb_jumps_container.get_children():
		if jump.jump_to.id == jump_data["jumpTo"]:
			return true
	
	return false

func get_closest_border_point(point):
	point = Vector2(clamp(point.x, 0.0, size.x), clamp(point.y, 0.0, size.y))
	var closest_point = Vector2(0, point.y)
	
	if Vector2(point.x, 0).distance_to(point) < closest_point.distance_to(point):
		closest_point = Vector2(point.x, 0)
	if Vector2(size.x, point.y).distance_to(point) < closest_point.distance_to(point):
		closest_point = Vector2(size.x, point.y)
	if Vector2(point.x, size.y).distance_to(point) < closest_point.distance_to(point):
		closest_point = Vector2(point.x, size.y)
	
	return closest_point

func add_new_jump(jump_pos=get_local_mouse_position()):
	if not allow_new_jump:
		return
	
	var sb_jump = SB_Jump.instantiate()
	sb_jumps_container.add_child(sb_jump)
	sb_jump.set_jump_from(self, jump_pos)
	sb_jump.index = sb_jumps_container.get_child_count()-1
	sb_jump.connected.connect(on_jump_connected)
	allow_new_jump = false

func on_jump_connected(has_connected):
	allow_new_jump = true

func set_data(data:Dictionary, only_update=false, force_all_panels=false):
	allow_request_update = !only_update
	for key in data:
		if key == "metadata":
			set_data(data[key])
		elif key == "panels":
			var all_panels = sb_panel_container.get_children()
			for pnl_data in data[key]:
				var sb_pnl
				sb_pnl = get_panel_from_id(pnl_data.id)
				if not sb_pnl or force_all_panels:
					sb_pnl = SB_Panel.instantiate()
					add_panel(sb_pnl)
				else:
					all_panels.erase(sb_pnl)
				sb_pnl.set_data(pnl_data, only_update)
		elif key == "name":
			text = data[key]
		elif "color" in key:
			set(key, Color.html(data[key]))
		elif key == "position_x":
			position.x = data[key]
		elif key == "position_y":
			position.y = data[key]
		elif key == "sequenceName":
			sequence = data[key]
#		elif key == "size_width":
#			size.x = data[key]
#		elif key == "size_height":
#			size.y = data[key]
		else:
			set(key, data[key])
	
	set_deferred("last_data", get_data())
	allow_request_update = true

func get_data():
	var panels = []
	
	for panel in sb_panel_container.get_children():
		panels.append(panel.get_data())
	
	var jumps = []
	
	for jump in sb_jumps_container.get_children():
		if not jump.jump_to:continue
		jumps.append(jump.get_data())
	
	return {
		"id" : id,
		"local_id" : local_id,
		"name" : text,
		"panels" : panels,
		"jumpInfos" : jumps,
		"sequenceName" : sequence,
		"show_sequence_name" : show_sequence_name,
		"unique_properties_in_sequence" : unique_properties_in_sequence,
		"metadata": {
			"panel_thumbnail_to_show": panel_thumbnail_to_show,
			"text_color" : "#"+text_color.to_html(true),
			"collapsed" : collapsed,
			"panels_per_row" : panels_per_row,
			"horizontal_panel_separation" : horizontal_panel_separation,
			"vertical_panel_separation" : vertical_panel_separation,
			"position_x" : int(position.x),
			"position_y" : int(position.y),
			"size_width" : size.x,
			"size_height" : size.y,
			"border_color" : "#"+border_color.to_html(true),
			"color" : "#"+color.to_html(true)
		}
	}

func set_delete(v):
	if v:
		delete_scene()

func delete_scene():
	if SB.storyboard_view.container.get_child_count() == 1:
		return
	
	SB.storyboard_view.container.remove_child(self)
	SB.delete_from_gs(id, {}, SB.REQUEST.DELETE_SCENE, {"scene":self})
	multiselect_component.set_property("delete", true)
	multiselect_component.remove_from_selected()
	emit_signal("deleted")
	hide()
	SB.hide_tooltip()

func request_update(keep_all=false):
	if last_data == null or last_data.is_empty() or not allow_request_update:
		return
	
	SB.request_update(node_type, last_data, get_data(), id, ["id"], ["panels", "jumpInfos"], keep_all)
	last_data = get_data()

#Override
func set_collapsed(v):
	super.set_collapsed(v)
	size = collapsed_size if collapsed else uncollapsed_size

#Override
func move():
	super.move()
	multiselect_component.set_property("position", position)
	if SB.auto_layout_enabled:
		SB.use_auto_layout(self)
	elif SB.jump_auto_position_enabled:
		for jump in sb_jumps_container.get_children():
			jump.check_and_adjust_border_points(true)
		for scene in SB.storyboard_view.container.get_children():
			for jump in scene.sb_jumps_container.get_children():
				jump.check_and_adjust_border_points(true)

#Override
func node_pressed():
	super.node_pressed()
	SB.add_undo_action(self, "Move scene", "position", position)

#Override
func node_press_released():
	super.node_press_released()
	multiselect_component.request_update()

#Override
func _on_right_click():
	super._on_right_click()
	context_menu_opened_loc = get_local_mouse_position()
	var options = ["Add panel", "Add Jump", "Delete scene"]
	var callback_methods = [Callable(self, "create_new_panel"), Callable(self, "add_new_jump").bind(context_menu_opened_loc), Callable(self, "delete_scene")]
	SB.open_context_menu(options, callback_methods)

#Override
func get_class():
	return "SBScene"
