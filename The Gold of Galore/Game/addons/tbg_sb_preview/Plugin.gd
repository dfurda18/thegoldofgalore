@tool
extends EditorPlugin

var StoryboardPreview = load("res://addons/tbg_sb_preview/Editor/StoryboardView/StoryboardView.tscn")

var storyboard_preview_instance
var inspector_plugin
var editor = get_editor_interface()
var plugin_name = "SB Preview"

var tbTelemetry = ClassDB.instantiate("TBTelemetry") if ClassDB.class_exists("TBTelemetry") else null

func _enter_tree():
	inspector_plugin = load("res://addons/tbg_sb_preview/inspector_plugin/InspectorPlugin.gd").new()
	add_inspector_plugin(inspector_plugin)
	SB.inspector = inspector_plugin
	
	if editor:
		storyboard_preview_instance = StoryboardPreview.instantiate()
		editor.get_editor_main_screen().add_child(storyboard_preview_instance)
		_make_visible(false)
		
		SB.node_selected.connect(_on_node_selected)
		SB.obj_pressed = -1
		SB.undo = get_undo_redo()
		SB.plugin = self

func _on_node_selected(node):
	get_editor_interface().inspect_object(node, "Text", true)

func _exit_tree():
	if storyboard_preview_instance:
		storyboard_preview_instance.queue_free()
	remove_inspector_plugin(inspector_plugin)

func _has_main_screen():
	return true

func _make_visible(visible):
	if visible:
		if is_instance_valid(tbTelemetry):
			tbTelemetry.openView(plugin_name)    
	else:
		if is_instance_valid(tbTelemetry):
			tbTelemetry.closeView(plugin_name)  
	
	if storyboard_preview_instance:
		storyboard_preview_instance.visible = visible
		SB.preview_active = visible

func _get_plugin_name():
	return plugin_name

func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")
