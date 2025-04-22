@tool
extends Node2D
class_name SBJump

enum TYPE {
	Solid,
	Dashed
}

## Press to delete the jump
@export var editor_button_delete:String
## Jump option (description)
@export var option:String = "" : set=set_option
## Hide/show jump option
@export var option_visible:bool = true : set=set_option_visible
## Change the jump type
@export var type:TYPE = 0 : set=set_type
## Changes the color of the arror
@export var color:Color = Color.MEDIUM_AQUAMARINE : set=set_color
## Makes the jump both ways between the scenes
@export var two_way:bool = false : set=set_two_way

@onready var collision_rect = $Pressable
@onready var selected_visual = $Pressable/SelectedVisual
@onready var jump_from_collision = $JumpFromCollision
@onready var jump_to_collision = $JumpToCollision
@onready var jump_from_visual_indicator = $JumpFromVisualIndicator
@onready var jump_to_visual_indicator = $JumpToVisualIndicator
@onready var label_top:Label = $LabelTop
@onready var label_bottom = $LabelBottom
@onready var multiselect_component = $MultiselectComponent

var delete = false : set=set_delete #used only for multiselect
var index
var jump_from
var jump_to
var points:Array = [] : set=set_points
var curve:Curve2D
var point_from
var point_to
var drawing_to_mouse = false
var collision_rect_width = 25
var width = 5
var jump_from_border_point = Vector2.ZERO
var jump_to_border_point = Vector2.ZERO
var calculate_new_jump_from_border_point = false
var calculate_new_jump_to_border_point = false
var jump_from_col_hover = false
var jump_to_col_hover = false
var node_type = SB.NODE_TYPE.JUMP
var last_data = {}
var is_ready = false

signal connected(has_connected)

func _ready():
	is_ready = true
	SB.storyboard_view.connect_pressable_to_tooltip(collision_rect)
	SB.storyboard_view.connect_pressable_to_tooltip(jump_from_collision)
	SB.storyboard_view.connect_pressable_to_tooltip(jump_to_collision)

func _on_editor_button_pressed(text:String):
	if text.to_upper() == "DELETE":
		set_delete(true)

func set_delete(v):
	if v:
		SB.delete_from_gs(jump_from.id, {"jumpTo":jump_to.id,"index":index}, SB.REQUEST.DELETE_JUMP, {"jump":self})
		multiselect_component.set_property("delete", true)
		multiselect_component.remove_from_selected()
		hide()

func on_scene_deleted():
	multiselect_component.remove_from_selected()
	queue_free()

func set_option(v):
	option = v
	if is_ready:
		request_update()
		label_top.text = option
		label_bottom.text = option

func set_option_visible(v):
	option_visible = v
	if is_ready:
		request_update()
		multiselect_component.set_property("option_visible", option_visible)

func set_type(v):
	type = v
	if is_ready:
		request_update()
		multiselect_component.set_property("type", type)

func set_two_way(v):
	two_way = v
	if is_ready:
		request_update()
		multiselect_component.set_property("two_way", two_way)

func set_color(v):
	color = v
	if $JumpToVisualIndicator:
		$JumpToVisualIndicator.material.set_shader_parameter("color", color)
	if $JumpFromVisualIndicator:
		$JumpFromVisualIndicator.material.set_shader_parameter("color", color)
	
	if is_ready:
		request_update()
		multiselect_component.set_property("color", color)

func set_jump_from(node, mouse_pos=Vector2.ZERO):
	jump_from = node
	jump_from_border_point = jump_from.get_closest_border_point(mouse_pos)
	drawing_to_mouse = true
	jump_from.collapsed_changed.connect(on_scene_collapsed_changed.bind(jump_from))
	jump_from.scene_resized.connect(on_scene_resized.bind(jump_from))

func set_jump_to(node, mouse_pos=Vector2.ZERO):
	jump_to = node
	drawing_to_mouse = false
	if jump_to_border_point == Vector2.ZERO:
		jump_to_border_point = jump_to.get_closest_border_point(mouse_pos)
	check_and_adjust_border_points()
	jump_to.collapsed_changed.connect(on_scene_collapsed_changed.bind(jump_to))
	jump_to.scene_resized.connect(on_scene_resized.bind(jump_to))
	jump_to.deleted.connect(on_scene_deleted)
	last_data = get_data()

func set_points(v:Array):
	points = v

func _process(delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and drawing_to_mouse:
		end_drawing_from_mouse()
		queue_free()
		emit_signal("connected", false)
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if drawing_to_mouse:
			try_connect()
		if jump_from and jump_to:
			if calculate_new_jump_from_border_point:
				jump_from_border_point = jump_from.get_closest_border_point(jump_from.get_local_mouse_position())
			if calculate_new_jump_to_border_point:
				jump_to_border_point = jump_to.get_closest_border_point(jump_to.get_local_mouse_position())
	
	if calculate_new_jump_from_border_point or jump_from_col_hover:
		jump_from_visual_indicator.position = jump_from_border_point + jump_from.global_position - jump_from_visual_indicator.size/2
		jump_from_visual_indicator.show()
	elif jump_from_visual_indicator:
		jump_from_visual_indicator.hide()
	
	if calculate_new_jump_to_border_point or jump_to_col_hover:
		jump_to_visual_indicator.position = jump_to_border_point + jump_to.global_position - jump_to_visual_indicator.size/2
		jump_to_visual_indicator.show()
	elif jump_to_visual_indicator:
		jump_to_visual_indicator.hide()
	
	if drawing_to_mouse and jump_from:
		SB.drawing_from_jump_from = true
		draw_arrow_to_mouse()
		queue_redraw()
	elif jump_from and jump_to and not drawing_to_mouse:
		draw_arrow_to_jump_to()
		queue_redraw()
	elif not points.is_empty() and points.size() >= 2:
		draw_arrow_by_points()
		queue_redraw()

func update_label_position():
	var start_point:Vector2 = point_from
	var end_point:Vector2 = point_to
	var offset = 80 * label_top.get_line_count()
	offset *= 1.5 if SB.get_screen_scale() > 1.0 else 1.0
	
	if not points.is_empty():
		if points.size() == 4:
			start_point = points[1].global_position
			end_point = points[2].global_position
		else:
			start_point = points[0].global_position
	
	var flip_offset = 1
	if abs(label_top.rotation) > 1.5:
		flip_offset = -1
	
	label_top.global_position = start_point - Vector2(0, offset)
	label_bottom.global_position = end_point - Vector2(0,offset)
	
	var size = Vector2(start_point.distance_to(end_point), 20)
	label_top.size = size
	label_bottom.size = size
	label_top.update_font_scale(size)
	label_bottom.update_font_scale(size)
	label_top.pivot_offset = Vector2(0, offset)
	label_bottom.pivot_offset = Vector2(0, offset)
	label_top.rotation = start_point.angle_to_point(end_point)
	label_bottom.rotation = end_point.angle_to_point(start_point)
	
	var show_bottom_label = abs(label_top.rotation) > PI/2
	label_top.visible = !show_bottom_label and option_visible
	label_bottom.visible = show_bottom_label and option_visible
	
	var label_true_width = label_top.get_theme_font("").get_string_size(label_top.text).x
	if label_top.get_line_count() > 2 and start_point.distance_to(end_point) < label_true_width + 25:
		label_top.hide()
		label_bottom.hide()

func try_connect():
	for scene in SB.storyboard_view.container.get_children():
		if scene.has_point(get_global_mouse_position()) and not scene == jump_from:
			set_jump_to(scene, scene.get_local_mouse_position())
			SB.add_to_gs(jump_from.id, {}, SB.REQUEST.ADD_JUMP, get_data())
			end_drawing_from_mouse()
			emit_signal("connected", true)
			return

func check_and_adjust_border_points(ov_check=false):
	if (jump_from_border_point != Vector2.ZERO or jump_to_border_point != Vector2.ZERO) and not ov_check:
		return
	
	var samples_per_edge: int = 2
	var points = find_closest_border_points(jump_from, jump_to, samples_per_edge)
	jump_from_border_point = points[0]
	jump_to_border_point = points[1]
	request_update()

func find_closest_border_points(scene_from, scene_to, samples_per_edge) -> Array:
	# get the edge points of the first scene
	var scene_from_edge_points = get_edge_points(scene_from.global_position, scene_from.size, samples_per_edge)
	# get the edge points of the second scene
	var scene_to_edge_points = get_edge_points(scene_to.global_position, scene_to.size, samples_per_edge)
	
	# initialize minimum distance and closests points
	var min_dist = INF
	var scene_from_closest_point: Vector2
	var scene_to_closest_point: Vector2
	var scene_from_middle_point = scene_from.global_position + scene_from.size / 2
	var scene_to_middle_point = scene_to.global_position + scene_to.size / 2
	
	# iterate over all pairs of points and find the closests ones
	for scene_from_point in scene_from_edge_points:
		for scene_to_point in scene_to_edge_points:
			var dist = scene_to_point.distance_to(scene_from_point)
			#if dist == min_dist:
				#if scene_from_point.distance_to(scene_from_middle_point) < scene_from_closest_point.distance_to(scene_from_middle_point):
					#scene_from_closest_point = scene_from_point
				#if scene_to_point.distance_to(scene_to_middle_point) < scene_to_closest_point.distance_to(scene_to_middle_point):
					#scene_to_closest_point = scene_to_point
			if dist+5 < min_dist:
				min_dist = dist
				scene_from_closest_point = scene_from_point
				scene_to_closest_point = scene_to_point
	
	return [scene_from_closest_point - scene_from.global_position, scene_to_closest_point - scene_to.global_position]

func get_edge_points(pos, size, samples_per_edge):
	var edge_points = []
	
	for i in range(1, samples_per_edge, 1):
		var interval = i / float(samples_per_edge)
		edge_points.append(pos + Vector2(size.x * interval, 0))  
		edge_points.append(pos + Vector2(size.x * interval, size.y))
		edge_points.append(pos + Vector2(0, size.y * interval)) 
		edge_points.append(pos + Vector2(size.x, size.y * interval))
	
	return edge_points

func on_scene_collapsed_changed(collapsed:bool, scene):
	var border_point = jump_from_border_point
	
	if scene == jump_to:
		border_point = jump_to_border_point
	
	var previous_scene_size = scene.uncollapsed_size
	if collapsed:
		previous_scene_size = scene.collapsed_size
	
	var pos_percent = border_point / scene.size
	var new_pos = previous_scene_size * pos_percent
	
	if scene == jump_to:
		jump_to_border_point = new_pos
	else:
		jump_from_border_point = new_pos
	
	request_update()

func on_scene_resized(old_size:Vector2, scene):
	var border_point = jump_from_border_point
	
	if scene == jump_to:
		border_point = jump_to_border_point
	
	var pos_percent = border_point / old_size
	var new_pos = scene.size * pos_percent
	
	if scene == jump_to:
		jump_to_border_point = new_pos
	else:
		jump_from_border_point = new_pos
	
	request_update()

func clamp_border_points():
	jump_from_border_point = jump_from.get_closest_border_point(jump_from_border_point)
	jump_to_border_point = jump_to.get_closest_border_point(jump_to_border_point)

func jumps_not_on_same_scene(_jump_to):
	return jump_from.get_parent().get_child(0) == _jump_to

func end_drawing_from_mouse():
	drawing_to_mouse = false
	SB.set_deferred("drawing_from_jump_from", false)

func draw_arrow_to_mouse():
	curve = Curve2D.new()
	point_from = jump_from_border_point + jump_from.global_position
	point_to = get_local_mouse_position()
	curve.add_point(point_from)
	curve.add_point(point_to)
	update_label_position()

func draw_arrow_to_jump_to():
	curve = Curve2D.new()
	point_from = jump_from_border_point + jump_from.global_position
	point_to = jump_to_border_point + jump_to.global_position
	curve.add_point(point_from)
	curve.add_point(point_to)
	setup_collision_rects()
	update_label_position()

func draw_arrow_by_points():
	curve = Curve2D.new()
	for point in points:
		curve.add_point(point.global_position)
	point_from = points[points.size()-2].global_position
	point_to = points[points.size()-1].global_position
	setup_collision_rects()
	update_label_position()

func setup_collision_rects():
	#Setup for main collision rect that is used to show jump data in inspector
	var start_point:Vector2 = point_from
	var end_point:Vector2 = point_to
	
	if not points.is_empty():
		if points.size() == 4:
			start_point = points[1].global_position
			end_point = points[2].global_position
		else:
			start_point = points[0].global_position
	
	collision_rect.rotation = start_point.angle_to_point(end_point)
	
	var flip_offset = 1
	if abs(collision_rect.rotation) > 1.5:
		flip_offset = -1
	
	collision_rect.global_position = start_point - Vector2(0, collision_rect_width/2*flip_offset)
	
	var size = Vector2(start_point.distance_to(end_point), collision_rect_width)
	collision_rect.size = size
	selected_visual.size = Vector2(size.x, size.y/3)
	selected_visual.position.y = selected_visual.size.y
	
	#setup endpoints to move the arrow along scene border
	jump_from_collision.global_position = start_point - jump_from_collision.size/2
	jump_to_collision.global_position = end_point - jump_to_collision.size/2

func _draw():
	if not curve:return
	
	match type:
		TYPE.Solid:
			_draw_solid_arrow()
		TYPE.Dashed:
			_draw_dashed_arrow()

func _draw_solid_arrow():
	var points = PackedVector2Array()
	points.append_array(curve.get_baked_points())
	draw_polyline(points, color, width, true)
	_draw_arrow_head()

func _draw_dashed_arrow():
	var to = point_to
	var from = point_from
	var dash_length = 5
	var length = (to - from).length()
	var normal = (to - from).normalized()
	var dash_step = normal * dash_length
	
	if length < dash_length:
		draw_line(from, to, color, width, true)
		return

	else:
		var draw_flag = true
		var segment_start = from
		var steps = length/dash_length
		for start_length in range(0, steps + 1):
			var segment_end = segment_start + dash_step
			if draw_flag:
				draw_line(segment_start, segment_end, color, width, true)
			
			segment_start = segment_end
			draw_flag = !draw_flag
		
	_draw_arrow_head()

func _draw_arrow_head():
	var length = 15
	var angle = 150
	var dir:Vector2 = point_to - point_from
	var offset_v = -1
	var sidedir = dir.normalized().rotated(deg_to_rad(angle)) * length
	var offset = dir.normalized().rotated(deg_to_rad(angle)) * offset_v
	draw_line(point_to - offset, point_to+sidedir, color, width-2, true)
	sidedir = dir.normalized().rotated(deg_to_rad(-angle)) * length
	offset = dir.normalized().rotated(deg_to_rad(-angle)) * offset_v
	draw_line(point_to - offset, point_to+sidedir, color, width-2, true)
	var _points = [point_to, point_to+sidedir]
	
	if two_way:
		dir = point_from - point_to 
		#draw_polyline(points, color, width, true)
		sidedir = dir.normalized().rotated(deg_to_rad(angle)) * length
		offset = dir.normalized().rotated(deg_to_rad(angle)) * offset_v
		draw_line(point_from - offset, point_from+sidedir, color, width-2, true)
		sidedir = dir.normalized().rotated(deg_to_rad(-angle)) * length
		offset = dir.normalized().rotated(deg_to_rad(-angle)) * offset_v
		draw_line(point_from - offset, point_from+sidedir, color, width-2, true)

func _on_pressed():
	SB.emit_signal("node_selected", self)

func _on_jump_from_collision_pressed():
	calculate_new_jump_from_border_point = true
	SB.add_undo_action(self, "Move start of the jump", "jump_from_border_point", jump_from_border_point)

func _on_jump_from_collision_released():
	calculate_new_jump_from_border_point = false
	request_update()

func _on_jump_to_collision_pressed():
	calculate_new_jump_to_border_point = true
	SB.add_undo_action(self, "Move end of the jump", "jump_to_border_point", jump_to_border_point)

func _on_jump_to_collision_released():
	calculate_new_jump_to_border_point = false
	request_update()

func _on_jump_from_collision_hover(v, priority):
	jump_from_col_hover = v

func _on_jump_to_collision_hover(v, priority):
	jump_to_col_hover = v

func set_data(data, set_last_data=true):
	if data.has("metadata"):
		set_data(data["metadata"], false)
	
	for key in data:
		if "color" in key:
			set(key, Color.html(data[key]))
		elif key == "jumpTo":
			if jump_to != null:
				continue
			for scene in SB.storyboard_view.container.get_children():
				if scene.id == data[key]:
					set_jump_to(scene)
		elif key == "twoWay":
			two_way = data[key]
		elif key == "jump_from_border_point_x":
			jump_from_border_point.x = data[key]
		elif key == "jump_from_border_point_y":
			jump_from_border_point.y = data[key]
		elif key == "jump_to_border_point_x":
			jump_to_border_point.x = data[key]
		elif key == "jump_to_border_point_y":
			jump_to_border_point.y = data[key]
		else:
			set(key, data[key])
	
	if set_last_data:
		set_deferred("last_data", get_data())

func get_data():
	return {
		"index" : index,
		"twoWay" : two_way,
		"jumpTo" : jump_to.id,
		"option" : option,
		"metadata" : {
			"jump_from_border_point_x" : int(jump_from_border_point.x),
			"jump_from_border_point_y" : int(jump_from_border_point.y),
			"jump_to_border_point_x" : int(jump_to_border_point.x),
			"jump_to_border_point_y" : int(jump_to_border_point.y),
			"type" : type,
			"color" : "#"+color.to_html(true),
			"option_visible" : option_visible
		}
	}

func request_update(keep_all=false):
	if last_data.is_empty():return
	SB.request_update(node_type, last_data, get_data(), jump_from.id, ["index", "jumpTo"], [], keep_all)
	last_data = get_data()

func apply_selected_visuals(apply):
	$Pressable/SelectedVisual.visible = apply

func _on_released():
	pass # Replace with function body.

func get_class():
	return "SBJump"

func _on_shift_pressed():
	SB.emit_signal("node_selected", self)
