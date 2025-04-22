@tool
extends Control
class_name SBNode

## Text color of the scene/panel
@export var text_color:Color = "ffffff" : set=set_text_color
## Inner color of the scene/panel
@export var color:Color = "a0baff" : set=set_color
## Border color of the scene/panel
@export var border_color:Color = "c99f00" : set=set_border_color

@onready var name_lbl = $%Name
@onready var panel = $Panel
@onready var h_container = $%HBoxContainer
@onready var uncollapsed_panel = $UncollapsedPanel
@onready var uncollapsed_name_lbl = $UncollapsedPanel/HBoxContainer/Control/Name
@onready var multiselect_component = $MultiselectComponent
@onready var dropdown_btn_collapsed = $Panel/HBoxContainer/DropdownButton
@onready var dropdown_btn_uncollapsed = $UncollapsedPanel/HBoxContainer/DropdownButton

var text = "" : set=set_text
var collapsed = true : set=set_collapsed
var drag_pressed = false
var drag_offset:Vector2 = Vector2.ZERO
var id = "-1"
var local_id = "-1" : set=set_local_id
var node_type = SB.NODE_TYPE.SCENE
var last_data = {}
var is_ready = false
var last_position = Vector2.ZERO
var shadow_size = 0

signal collapsed_changed(collapsed)

func _ready():
	set_dropdown_icons_size()
	is_ready = true
	#SB.node_selected.connect(on_node_selected)

func set_dropdown_icons_size():
	var icon_size = dropdown_btn_collapsed.icon_size
	dropdown_btn_collapsed.icon_size = icon_size / SB.get_screen_scale()
	dropdown_btn_uncollapsed.icon_size = icon_size / SB.get_screen_scale()

func set_local_id(v):
	local_id = v
	if using_local_id():
		id = local_id

func _process(delta):
	if drag_pressed:
		move()

func on_node_selected(node):
	if node == self:
		apply_selected_visuals(true)
	elif not multiselect_component.in_multiselect:
		apply_selected_visuals(false)

func _on_pressed():
	call_deferred("node_pressed")

func _on_shift_pressed():
	SB.emit_signal("node_selected", self)

func _on_released():
	call_deferred("node_press_released")

func _on_doubleclick():
	pass

func _on_right_click():
	SB.emit_signal("node_selected", self)

func node_pressed():
	toggle_dragging(true)
	SB.emit_signal("node_selected", self)

func node_press_released():
	toggle_dragging(false)

func set_text(new_text):
	if not name_lbl: return
	text = new_text
	name_lbl.set_text(text)
	uncollapsed_name_lbl.set_text(text)
	if is_ready:
		request_update()

func set_text_color(v):
	if not name_lbl: return
	text_color = v
	name_lbl.set("theme_override_colors/font_color", text_color)
	uncollapsed_name_lbl.set("theme_override_colors/font_color", text_color)
	if is_ready:
		request_update()
		multiselect_component.set_property("text_color", text_color)

func set_color(_color):
	color = _color
	update_style()
	if is_ready:
		request_update()
		multiselect_component.set_property("color", color)

func set_border_color(v):
	border_color = v
	$Panel/HBoxContainer/DropdownButton.material.set_shader_parameter("color", border_color)
	$UncollapsedPanel/HBoxContainer/DropdownButton.material.set_shader_parameter("color", border_color)
	update_style()
	if is_ready:
		request_update()
		multiselect_component.set_property("border_color", border_color)

func set_collapsed(v):
	collapsed = v
	panel.visible = collapsed
	uncollapsed_panel.visible = !collapsed
	z_index = !collapsed
	emit_signal("collapsed_changed", collapsed)
	if is_ready:
		request_update()
		multiselect_component.set_property("collapsed", collapsed)

func toggle_dragging(drag_enabled):
	drag_pressed = drag_enabled
	drag_offset = get_global_mouse_position() - position
	SB.emit_signal("sb_node_drag", drag_enabled)
	SB.emit_signal("change_cursor_shape", Control.CURSOR_CAN_DROP if drag_enabled else Control.CURSOR_ARROW)

func move():
	last_position = position
	position = get_global_mouse_position() - drag_offset

func update_style():
	var pnl:Panel = $Panel
	var uncollapsed_pnl = $UncollapsedPanel
	var pnl_style:StyleBoxFlat
	var uncollapsed_pnl_style:StyleBoxFlat
	pnl_style = pnl.get("theme_override_styles/panel").duplicate()
	uncollapsed_pnl_style = uncollapsed_pnl.get("theme_override_styles/panel").duplicate()
	pnl_style.bg_color = color
	uncollapsed_pnl_style.bg_color = color
	pnl_style.border_color = border_color
	uncollapsed_pnl_style.border_color = border_color
	pnl_style.shadow_size = shadow_size
	uncollapsed_pnl_style.shadow_size = shadow_size
	pnl.set("theme_override_styles/panel", pnl_style)
	uncollapsed_pnl.set("theme_override_styles/panel", uncollapsed_pnl_style)

func apply_selected_visuals(apply):
	shadow_size = 7 if apply else 0
	update_style()

func using_local_id():
	return id.is_valid_int()

func request_update():
	pass

func get_data():
	pass

func has_point(point:Vector2) -> bool:
	return Rect2(global_position, size).has_point(point)

func _on_dropdown_button_pressed():
	SB.add_undo_action(self, "Uncollapse/Collapse node", "collapsed", collapsed)
	collapsed = !collapsed
