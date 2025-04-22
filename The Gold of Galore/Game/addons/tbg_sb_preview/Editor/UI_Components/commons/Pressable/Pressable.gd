@tool
extends Control
class_name Pressable

#Place this under any node that you want to be pressable

#In case of two pressables on top of each other you can set the "process" of one pressable to be lower
#than the other for it to receive the input first NOTE: its more desirable to achive this via tree ordering
#rather than changing process values, but sometimes that might not be possible

@export_multiline var text_tooltip = ""
@export var tooltip_priority = false

var parent
var is_pressed = false
var is_doubleclick = false
var is_hover = false
var idle_frames = false
var wait_for_doubleclick = false
var dc_register_time = 0.2
var cur_dc_register_time = 0.0
var event_active = false
var left_mouse_btn_just_pressed = false
var right_mouse_btn_just_pressed = false
var left_mouse_btn_press_pos = Vector2.ZERO
var is_shift_pressed = false

signal pressed
signal right_click
signal shift_pressed
signal doubleclick
signal released
signal hover

func _enter_tree():
	parent = get_parent()

func _ready():
	anchors_preset = Control.PRESET_FULL_RECT
	if SB.storyboard_view != null:
		SB.storyboard_view.gui_input.connect(on_storyboard_view_gui_input)

func on_storyboard_view_gui_input(event:InputEvent):
	event_active = true

func _process(delta):
	if wait_for_doubleclick:
		cur_dc_register_time += delta
	
	if not SB.preview_active or not event_active:
		return
	
	var has_press_pos
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not left_mouse_btn_just_pressed:
		left_mouse_btn_just_pressed = true
		left_mouse_btn_press_pos = get_global_mouse_position()
		has_press_pos = _has_point(left_mouse_btn_press_pos)
	elif left_mouse_btn_just_pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		left_mouse_btn_just_pressed = false
	
	if (is_pressed or is_shift_pressed) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_shift_pressed = false
		SB.set_pressed(self, false)
	
	if is_pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_pressed = false
		is_doubleclick = false
		emit_signal("released")
		wait_for_doubleclick = true
		cur_dc_register_time = 0.0
	
	if not is_visible_in_tree():
		return
	
	if not SB.is_something_pressed() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not right_mouse_btn_just_pressed and _has_point(get_global_mouse_position()):
		emit_signal("right_click")
		right_mouse_btn_just_pressed = true
		SB.set_pressed(self, true)
	elif right_mouse_btn_just_pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		right_mouse_btn_just_pressed = false
		SB.set_pressed(self, false)
	
	if not has_press_pos:
		has_press_pos = _has_point(left_mouse_btn_press_pos)
	var has_global_mouse_pos = _has_point(get_global_mouse_position())
	
	if has_global_mouse_pos:
		is_hover = true
		emit_signal("hover", true, tooltip_priority)
	elif is_hover and not has_global_mouse_pos:
		is_hover = false
		emit_signal("hover", false, tooltip_priority)
	
	if has_press_pos and not is_pressed and not SB.is_something_pressed():
		if left_mouse_btn_just_pressed:
			if not Input.is_key_pressed(KEY_SHIFT):
				emit_signal("pressed")
				is_pressed = true
				if wait_for_doubleclick and cur_dc_register_time < dc_register_time:
					is_doubleclick = true
					emit_signal("doubleclick")
			else:
				emit_signal("shift_pressed")
				is_shift_pressed = true
			SB.set_pressed(self, true)
	
	event_active = false

func set_idle_frames():
	idle_frames = true

func _has_point(point:Vector2) -> bool:
	var rotated_point = (point - global_position).rotated(parent.rotation - rotation) + global_position
	return Rect2(global_position, size).has_point(rotated_point)

func get_class():
	return "Pressable"
