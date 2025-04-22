@tool
extends PanelContainer

@export var max_zoom_in = 4
@export var max_zoom_out = 0.5
@export var zoom_step = 0.1

var _drag_start
var _custom_viewport_origin
var viewport
var pixel_scale : int : set = set_pixel_scale, get = get_pixel_scale
var view_scale : float = 1.0 : set = set_view_scale, get = get_view_scale
var point_scale : float : set = set_point_scale, get = get_point_scale
var panning_enabled = true
var _temp_space_event

const DragMoveThreshold = 8

signal update_hud

func _enter_tree():
	viewport = $SubViewportContainer/Viewport

func _ready():
	SB.sb_node_drag.connect(_on_sb_node_drag)
	SB.change_cursor_shape.connect(func(v) : mouse_default_cursor_shape = v)

func set_point_scale(value):
	pixel_scale = value * DisplayServer.screen_get_scale() as int

func get_point_scale():
	return 1.0 * pixel_scale / DisplayServer.screen_get_scale()

func set_view_scale(value):
	if view_scale != value:
		viewport.canvas_transform.x = Vector2.RIGHT * (value / point_scale)
		viewport.canvas_transform.y = Vector2.DOWN * (value / point_scale)

func get_view_scale():
	return viewport.canvas_transform.x.length() * point_scale

func set_pixel_scale(value):
	if viewport:
		value = max(1, value)
		if pixel_scale != value:
			viewport.canvas_transform = viewport.canvas_transform.scaled(Vector2.ONE * pixel_scale / value)
			viewport.get_parent().stretch_shrink = value

func get_pixel_scale():
	if viewport:
		return viewport.get_parent().stretch_shrink
	return 1

func _on_sb_node_drag(v):
	panning_enabled = !v

func _unhandled_input(event):
	if event is InputEventKey:
		if event.keycode == KEY_SPACE:
			if event.pressed:
				if not _temp_space_event:
					_temp_space_event = InputEventMouseButton.new()
				_temp_space_event.position = get_local_mouse_position()
				start_camera_panning(_temp_space_event)
			else:
				_temp_space_event = null
				end_camera_panning()

func _gui_input(event):
	if not panning_enabled:
		_drag_start = null
		return
	
	if event is InputEventMouse:
		if event is InputEventMouseButton:
			if event.button_index == 3:
				if event.pressed:
					start_camera_panning(event)
				else:
					end_camera_panning()

			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_in()
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_out()

		elif event is InputEventMouseMotion:
			if _drag_start:
				var offset = event.position - _drag_start.position
				if offset.length() < DragMoveThreshold:
					offset = Vector2.ZERO
				viewport.canvas_transform.origin = _custom_viewport_origin + offset / pixel_scale

func start_camera_panning(event):
	_drag_start = event
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	_custom_viewport_origin = viewport.canvas_transform.origin
func end_camera_panning():
	_custom_viewport_origin = viewport.canvas_transform.origin
	_drag_start = null
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func _zoom_in():
	view_scale = min(pow(2, ceil(ln2(view_scale) * 2 + 0.1) * 0.5), 4.0)
	emit_signal("update_hud")

func _zoom_out():
	view_scale = max(pow(2, floor(ln2(view_scale) * 2 - 0.1) * 0.5), 0.5)
	emit_signal("update_hud")

func reset_zoom():
	view_scale = 1
	_custom_viewport_origin = null
	emit_signal("update_hud")

static func ln2(x) -> float:
	return log(x) / log(2)
