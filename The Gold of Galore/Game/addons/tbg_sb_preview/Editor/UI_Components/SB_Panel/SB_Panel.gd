@tool
extends "res://addons/tbg_sb_preview/Editor/UI_Components/SB_Node/SB_Node.gd"
class_name SBPanel

enum SHAPE {
	Rectangle,
	Oval
}

@onready var uncollapsed_thumbnail = $UncollapsedPanel/HBoxContainer/TextureRect
@onready var uncollapsed_big_thumbnail = $UncollapsedPanel/VBoxContainer/Thumbnail
@onready var collapsed_thumbnail = $Panel/HBoxContainer/TextureRect

## Change the shape of the panel
@export var shape:SHAPE = 0 :set=set_shape

@export_group("Captions")
@export_multiline var captions := {"notes":""} : set=set_captions

var delete = false : set=set_delete #used only for multiselect
var rectangle_style = preload("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Panel/shapes/rectangle.tres")
var oval_style = preload("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Panel/shapes/oval.tres")
var oval_uncollapsed_style = preload("res://addons/tbg_sb_preview/Editor/UI_Components/SB_Panel/shapes/oval_uncollapsed.tres")
var start_pos = position
var parent_scene
var order_in_scene = -1
var order_in_scene_before_move = -1
var pnl_hovering_over_during_move
var image
var collapsed_size = Vector2(250,70)
var uncollapsed_size = Vector2(250,250)
var thumbnail
var allow_request_update = true

signal order_changed
signal deleted

func _ready():
	super._ready()
	set_collapsed(false)
	node_type = SB.NODE_TYPE.PANEL

func set_shape(v):
	shape = v
	
	var style
	var uncollapsed_style
	
	match shape:
		SHAPE.Rectangle:
			style = rectangle_style
		SHAPE.Oval:
			style = oval_style
			uncollapsed_style = oval_uncollapsed_style
		_:
			style = rectangle_style
	
	set_style(style, uncollapsed_style)
	update_style()
	if is_ready:
		request_update()
		multiselect_component.set_property("shape", shape)

func set_captions(v):
	captions = v
	if is_ready:
		request_update()

func set_style(style:StyleBoxFlat, uncollapsed_style=null):
	var pnl:Panel = $Panel
	var uncollapsed_pnl = $UncollapsedPanel
	pnl.set("theme_override_styles/panel", style)
	uncollapsed_pnl.set("theme_override_styles/panel", uncollapsed_style if uncollapsed_style else style)

func set_image(path):
	if path == null or image == null:
		return
	
	var _image:Image = Image.new()
	var er = _image.load(path+"/"+image+".png")
	
	if er != OK:
		return
	
	var img_t = ImageTexture.new()
	img_t.set_image(_image)
	thumbnail = img_t
	uncollapsed_big_thumbnail.texture = img_t
	uncollapsed_thumbnail.texture = img_t
	collapsed_thumbnail.texture = img_t

func start_move():
	start_pos = position

func set_delete(v):
	if v:
		delete_panel()

func delete_panel():
	if parent_scene.sb_panel_container.get_child_count() == 1:
		return
	
	SB.emit_signal("sb_node_drag", false)
	parent_scene.sb_panel_container.remove_child(self)
	emit_signal("deleted")
	SB.delete_from_gs(parent_scene.id, {"id":id}, SB.REQUEST.DELETE_PANEL, {"panel":self})
	multiselect_component.set_property("delete", true)
	multiselect_component.remove_from_selected()
	hide()

#override
func node_press_released():
	super.node_press_released()
	if not parent_scene:return
	if not pnl_hovering_over_during_move:
		position = start_pos
		parent_scene.update_layout()
		SB.emit_signal("node_selected", self)
	emit_signal("order_changed")
	if order_in_scene != order_in_scene_before_move:
		request_move_update()
	order_in_scene_before_move = -1

func set_data(data:Dictionary, only_update=false):
	allow_request_update = !only_update
	for key in data:
		if key == "metadata":
			set_data(data[key])
		elif "color" in key:
			var c_string = data[key]
			c_string = SB.convert_string_color_from_argb_to_rgba(data[key])
			set(key, Color.html(c_string))
		elif key == "name":
			text = data[key]
#		elif key == "order_in_scene":
#			order_in_scene = data[key]
#			parent_scene.update_layout()
		else:
			set(key, data[key])
	
	allow_request_update = true
	set_deferred("last_data", get_data())

func get_data():
	return {
		"id" : id,
		"local_id" : local_id,
		"image" : image,
		"color" : SB.convert_string_color_from_rgba_to_argb("#"+color.to_html()),
		"name" : text,
		"metadata": {
			"shape" : shape,
			"collapsed" : collapsed,
			"text_color" : SB.convert_string_color_from_rgba_to_argb("#"+text_color.to_html()),
			"border_color" : SB.convert_string_color_from_rgba_to_argb("#"+border_color.to_html()),
			"order_in_scene" : order_in_scene
		},
		"captions" : captions
	}

func request_move_update():
	if parent_scene.sb_panel_container.get_child_count() <= 1:
		return
	
	var after = order_in_scene != 1
	var pnl_idx = order_in_scene - 2 if after else order_in_scene
	var previous_pnl_id = parent_scene.sb_panel_container.get_child(pnl_idx).id
	var data = {
		"id" : id,
		"destPanelId" : previous_pnl_id,
		"after" : after,
		"asNewScene" : false
	}
	
	SB.move_in_gs(parent_scene.id, data, SB.REQUEST.MOVE_PANEL)

func request_update(keep_all=false):
	if last_data == null or last_data.is_empty() or not allow_request_update:
		return
	
	SB.request_update(node_type, last_data, get_data(), parent_scene.id, ["id"], [], keep_all)
	last_data = get_data()

#override
func move():
	super.move()
	if not parent_scene:return
	if order_in_scene_before_move == -1:
		order_in_scene_before_move = order_in_scene
	var pnl_hovering_over_during_move = parent_scene.hovering_over_another_panel(self)

#override
func node_pressed():
	super.node_pressed()
	start_move()

#override
func _on_right_click():
	super._on_right_click()
	
	if drag_pressed:
		return
	
	var options = ["Delete panel"]
	var callback_methods = [Callable(self, "delete_panel")]
	SB.open_context_menu(options, callback_methods)

#override
func set_collapsed(v):
	super.set_collapsed(v)
	uncollapsed_thumbnail.visible = v
	size = collapsed_size if collapsed else uncollapsed_size

#override
func get_class():
	return "SBPanel"
