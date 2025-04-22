@tool
#class_name AssetView
extends VBoxContainer

const TbgPlugin = preload("Plugin.gd")

# Experimental features
const FEATURE_MANUAL_IMPORT = false

const TIME_EPSILON = 0.00000001
const DRAG_MOVE_TRESHOLD = 8

signal asset_changed
signal close_requested


## represents the path to the current asset (or derived asset)
var asset_path: String:
	get:
		if is_instance_valid(asset_node):
			return asset_node.scene_file_path
		return ""
	set(path):
		if asset_path == path:
			return
		
		TbgPlugin.log("Asset Path: %s" % path)
		
		scene_node = null
		var node = null
		if not path.is_empty():
			var packedScene = load(path)
			if packedScene is PackedScene:
				node = packedScene.instantiate()
		
		asset_node = node

var asset_node: TBG.MotionCharacter:
	set = set_asset_node

## the path to the original imported asset (tbg file usually)
var asset_import_path:
	get:
		if is_instance_valid(asset_node):
			return get_asset_import_path(asset_node)

# connect to named elements
var menubar: Control :
	get: return %Menu

var controls: Control :
	get: return %Controls

var slider: Slider :
	get: return %Controls/Seek

# viewport origin when drag was started
# this is null by default, so view is always centered, but can be overridden
var _custom_viewport_origin

## screen pixels per viewport pixel
var pixel_scale: int:
	get:
		if viewport:
			return viewport.get_parent().stretch_shrink
		return 1
	set(value):
		if viewport:
			value = max(1, value)
			if pixel_scale != value:
				viewport.canvas_transform = viewport.canvas_transform.scaled(Vector2.ONE * pixel_scale / value)
				viewport.get_parent().stretch_shrink = value

## screen pixels per logical viewport pixel (factors in HDPI display)
var point_scale: float:
	get:
		return 1.0 * pixel_scale / DisplayServer.screen_get_scale()
	set(value):
		pixel_scale = value * DisplayServer.screen_get_scale() as int

var view_scale: float = 1.0:
	get:
		return viewport.canvas_transform.x.length() * point_scale
	set(value):
		if view_scale != value:
			viewport.canvas_transform.x = Vector2.RIGHT * (value / point_scale)
			viewport.canvas_transform.y = Vector2.DOWN * (value / point_scale)
			invalidate()
			#reset_view()

var play_button: TbgPlugin.Editor.EditorButton:
	get: return %Controls/Buttons/Play

var motion: TBG.MotionConfig:
	get:
		if asset_node:
			return asset_node.current_motion
		return null

var is_playing: bool:
	get:
		if is_instance_valid(asset_node):
			if asset_node.current_motion and asset_node.current_motion.animation_name == "RESET":
				return false
			return asset_node.is_playing
		return false

	set(value):
		if is_instance_valid(asset_node):
			asset_node.is_playing = value

var asset_title:
	get:
		return asset_path.get_file()

# when set this represents the editable scene root of the asset
# note that we don't own this node, it could be freed at any time
var __editor_parent
var __scene_node
## If non-null, this represents the root of the asset scene that is currently being edited
var scene_node: TBG.MotionCharacter:
	get:
		if not is_instance_valid(__scene_node): # we'll try to return scene root if it is the same as the asset we are editing
			if is_instance_valid(asset_node):
				__scene_node = TbgPlugin.instance.current_scene
				if __scene_node.scene_file_path != asset_node.scene_file_path:
					__scene_node = null
			else:
				__scene_node = null
		return __scene_node
	set(value):
		if __scene_node == value:
			if not (__scene_node and value == null):
				return
		
		if TBG.node_post_save.is_connected(_instance_post_save):
			TBG.node_post_save.disconnect(_instance_post_save)
		
		asset_node = null
		
		# if changing scenes, make sure no __editor_parent value is stored
		if __scene_node != TbgPlugin.instance.current_scene:
			__editor_parent = null
		
		if value:
			if value.scene_file_path:
				TbgPlugin.log("Editing asset %s" % value.scene_file_path)
				# here we actually reparent the scene root, so the 2d view will appear empty
				# but the scene tree will reflect the true state of the asset in the viewer
				#__editor_parent = value.get_parent()
				#__editor_parent.remove_child(value)
				asset_node = value
			else:
				TbgPlugin.error("Can't find asset file to load! Save the scene to access it.")
				TBG.node_post_save.connect(_instance_post_save)
				# asset_node = value.duplicate()
				
		__scene_node = value

var editable:
	get:
		if scene_node:
			var extension = scene_node.scene_file_path.get_extension();
			return is_instance_valid(scene_node) and is_instance_valid(asset_node) and extension != "tbg"
		return false

var animation_list: ItemList
var animation_properties: TbgPlugin.Editor.PropertiesView
var node_tree: Tree
var skin_list: VBoxContainer
var grid_node: Node2D
var inspector: TbgPlugin.Editor.PropertiesView

# UI bindings

## The main viewport
var viewport: Viewport:
	get:
		return %Viewport

## Returns the visible rectangle in viewport units
var viewport_rect: Rect2:
	get:
		return viewport.get_visible_rect()

## the top node for all spatial 2D elements in the viewport	(zoom is applied here)
var world: Node2D:
	get:
		if !world:
			world = %World
		return world

## this scene + all inherited scenes
var _scene_stack: Array:
	get:
		if is_instance_valid(asset_node):
			var scene = TbgPlugin.get_containing_scene(asset_node)
			if _scene_stack.find(scene) == -1: # if the current stack does not contain scene, replace it
				_scene_stack = []
				while scene:
					_scene_stack.append(scene)
					scene = TbgPlugin.get_base_scene(scene)
		
		return _scene_stack

## this script + all inherited scripts
var _script_stack: Array:
	get:
		_script_stack = []
		if is_instance_valid(asset_node):
			var _script = (asset_node as TBG.MotionCharacter).script
			while _script:
				_script_stack.append(_script)
				_script = _script.get_base_script()
		
		return _script_stack

var _inspecting:
	get:
		if not is_instance_valid(_inspecting):
			_inspecting = null
		return _inspecting


func _enter_tree():
	inspector = %Inspector
	animation_list = %Motion/List
	animation_properties = %Motion/Properties
	
	node_tree = %Heirarchy/Tree
	
	skin_list = %Skin/ScrollContainer/List
	
	grid_node = %Grid
	
	%View["theme_override_styles/panel"].bg_color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")

	%Options.object = TbgPlugin.options
	%Options.changed.connect(func() :
		if asset_node and asset_node.is_inside_tree():
			TbgPlugin.invalidate(asset_node)
		)
	
	var tbg_plugin = TbgPlugin.instance
	var main_menu = [
		[tbg_plugin.get_tr("ASSET"), assets_popup.bind(tbg_plugin)],
		[tbg_plugin.get_tr("SCRIPT"), scripts_popup.bind(tbg_plugin)],
		[tbg_plugin.get_tr("MOTION"), motion_popup.bind(tbg_plugin)],
		[tbg_plugin.get_tr("VIEW"), view_popup.bind(tbg_plugin)],
		["#"+tbg_plugin.get_tr("DEBUG"), debug_popup.bind(tbg_plugin)]
	]
	
	TbgPlugin.Editor.set_menu(menubar, ".", main_menu)
	
	%UnusedWarning/Button.tooltip_text = tbg_plugin.get_tr("UNUSED_WARNING_TOOLTIP")
	%UnusedWarning/Button/Button2.text = tbg_plugin.get_tr("UNUSED_WARNING_TEXT")
	%View/AssetContainer/Overlay/Top/FrameAll.tooltip_text = tbg_plugin.get_tr("FRAME_ALL")
	%ZoomPercent.tooltip_text = tbg_plugin.get_tr("ZOOM_RESET")
	
	asset_changed.connect(asset_changed_response)
	
	if TbgPlugin.instance.file_system:
		TbgPlugin.instance.file_system.resources_reimported.connect(_on_resources_reimported)


func _exit_tree():
	if TbgPlugin.instance and TbgPlugin.instance.file_system:
		TbgPlugin.instance.file_system.resources_reimported.disconnect(_on_resources_reimported)
	
	if is_instance_valid(asset_node):
		asset_node.queue_free()


# Called when the node enters the scene tree for the first time.
func _ready():
	world.transform = Transform2D.IDENTITY
	# setting this to 1 means uniform resolution (pixel-doubles on HDPI screen)
	#point_scale = 1
	# 200% size
	view_scale = 2
	reset_view()


func _process(_delta):
	validate()
	if visible and is_playing:
		slider.value = asset_node.animation_position


func open_asset(path):
	#if path.get_extension() == "tbg":
		#asset_path = path
	#else:
		if TbgPlugin.editor.get_edited_scene_root().scene_file_path == path:
			_on_scene_changed(TbgPlugin.editor.get_edited_scene_root())
		else:
			TbgPlugin.editor.open_scene_from_path(path)


## Path to the source for the original asset, editable in Toon Boom Jump! (and exportable to tbg).
func external_asset_path(_asset_node):
	var external_asset_path = _asset_node.get_meta("xstage", "")
	if external_asset_path.is_empty() || not FileAccess.file_exists(external_asset_path):
		external_asset_path = TbgPlugin.get_asset_source_path(_asset_node.scene_file_path)
	return external_asset_path


## Path to the original scene exported from Toon Boom Jump!. Usually a *.tbg file
static func get_asset_import_path(_asset_node):
	var path = _asset_node.get_meta("TBG","")
	if path.is_empty():
		path = _asset_node.scene_file_path
	return path


func assets_popup(tbg_plugin):
	return [
			func(): if editable: return [tbg_plugin.get_tr("RELOAD"), _asset_revert],
			func(): if editable and scene_node == null: return [tbg_plugin.get_tr("OPEN_IN_ST"), _asset_open_scene],
			null,
			[tbg_plugin.get_tr("SHOW_IN_FS"), _asset_show_in_filesystem],
			[tbg_plugin.get_tr("SHOW_FOLDER"), _asset_browse_folder],
			null,
			func(): if editable: return [ tbg_plugin.get_tr("RESET_ALL_CHANGES") + " " + asset_title, _reset_to_base ],
			func(): if asset_path: return [ tbg_plugin.get_tr("NEW_FROM") + " %s ..." % asset_import_path.get_file(), _new_inherited ],
			null,
			func():
				return _scene_stack.map(func(e):
					var path = e.resource_path
					if path:
						return [path.get_file(), open_asset.bind(path), asset_path == path]
					return ["???"]
				),
			null,
			func(): if asset_import_path: return [tbg_plugin.get_tr("REIMPORT"), _asset_reimport ],
			null,
			func(): if asset_node and external_asset_path(asset_node):
				return [tbg_plugin.get_tr("ORG_ASSET"), [
					[tbg_plugin.get_tr("EDIT") + " ...", func(): TbgPlugin.open_in_asset_editor(external_asset_path(asset_node)) ],
					[tbg_plugin.get_tr("EDIT") + " ...", func(): TbgPlugin.show_in_file_manager(external_asset_path(asset_node)) ],
				]],
			func(): if editable: return [
				null,
				[tbg_plugin.get_tr("PREVIEW"), _preview_asset_node ]
			],
			# null,
			# ["Close", _on_close ],
	]


func scripts_popup(tbg_plugin):
	return [
			func():
				return _script_stack.filter(TbgPlugin.is_script_editable).map(func(e):
					var path = e.resource_path
					if path:
						return [tbg_plugin.get_tr("EDIT") + " \"%s\"" % path.get_file(), func():
							TbgPlugin.editor.edit_script(e)
							TbgPlugin.editor.set_main_screen_editor("Script")
							]
					return ["???"]
				),
			null,
			func():
				if editable and asset_node.script and asset_node.script != TBG.MotionCharacter:
					return [tbg_plugin.get_tr("DETACH") + " \"%s\"" % asset_node.script.resource_path.get_file(), _detach_script],
			null,
			func():
				if editable and get_custom_script(asset_node) == null:
					return [
						[tbg_plugin.get_tr("NEW") + " ...", _create_new_script],
						["Add AnimationTree", func():
							var animtree = asset_node.get_node_or_null("AnimationTree")
							if animtree == null:
								animtree = AnimationTree.new()
								animtree.name = "AnimationTree"
								asset_node.animation_player.add_sibling(animtree)
								animtree.owner = asset_node
								animtree.anim_player = "../AnimationPlayer"
							self._create_new_script((TbgPlugin.Templates as Script).resource_path.get_base_dir() + "/AnimTreeCharacter.gd", true)
							]
					]
	]


func motion_popup(tbg_plugin):
	return [
			[tbg_plugin.get_tr("STOP"), func(): is_playing = false ],
			func(): if editable: return [
				null,
				[tbg_plugin.get_tr("NEW"), _on_animation_new],
				[tbg_plugin.get_tr("DUPLICATE"), _on_duplicate_pressed],
				[tbg_plugin.get_tr("DELETE"), _on_delete_pressed],
				null,
				[tbg_plugin.get_tr("CREATE_F_P"), _create_flipped_permutation ],
				[tbg_plugin.get_tr("UNUSED_WARNING_TEXT"), _add_unused_motions ],
				null,
				[ tbg_plugin.get_tr("VIEW_MM_LIST"), func(): inspect(TBG.MotionModes) ],
				[ tbg_plugin.get_tr("DELETE_MM"),
					TBG.MotionModes.modes.reduce(func(a, e):
						a.append([e, func():
							TBG.MotionModes.modes.erase(e)
							ResourceSaver.save(TBG.MotionModes)
						])
						return a
						, [[&"ALL", func(): TBG.MotionModes.modes.clear()]])]
					,
				null,
				[tbg_plugin.get_tr("DELETE_ALL"), _on_delete_all_motions ]
			]
	]


func view_popup(tbg_plugin):
	return [
			[tbg_plugin.get_tr("FRAME_ALL"), _frame_all ],
			null,
			[tbg_plugin.get_tr("ZOOM_LEVEL"), [0.5,1,2,4,8,16].map(func(k):
				return ["%d%%" % [k * 100], func(): _view_zoom_reset(k), view_scale == k])],
			null,
			[tbg_plugin.get_tr("ZOOM_IN"), _on_view_zoom_in_button ],
			[tbg_plugin.get_tr("ZOOM_OUT"), _on_view_zoom_out_button ],
	]


func debug_popup(tbg_plugin):
	return [
			[ tbg_plugin.get_tr("DUMP_TO_JSON") + " ...", _debug_dump ],
			null,
			func(): return [ tbg_plugin.get_tr("PIXEL_SIZE"), [0.5,1,2,4,8].map(func(k):
				var label = "%d%%" % [k * 100]
				if k < 1.0:
					label += " (HDPI)"
				var action = null
				if k >= 1.0/DisplayServer.screen_get_scale():
					action = func(): point_scale = k
				return [label, action, point_scale == k])],
			null,
			[ tbg_plugin.get_tr("LOAD_CONFIG") + " ...", _on_import_properties ],
			[ tbg_plugin.get_tr("SAVE_CONFIG") + " ...", _on_export_properties ],
			null,
			[tbg_plugin.get_tr("EXPORT"), [[tbg_plugin.get_tr("SCENE_SS") + " ...", _on_save_snapshot]]]
	]


func asset_changed_response():
	var title
	if asset_path:
		title = asset_title
	if title:
		title = str('"', title, '"')
	else:
		title = "Asset"
	menubar.set_menu_title(0, title)
	
	can_see_unused = true
	
	if asset_node:
		var group_to_skin = asset_node.composite.config.group_to_skin_to_nodes
		%Skin/Expander.expanded = not group_to_skin.is_empty()


func refresh():
	if asset_node:
		TbgPlugin.invalidate(asset_node)
		TbgPlugin.validate(asset_node)
	
	invalidate()


var _validated = false
func invalidate():
	# TbgPlugin.trace("AssetView.invalidate")
	_validated = false


func validate():
	if _validated:
		return
	
	# Reload if freed
	if not is_instance_valid(asset_node) and \
			TbgPlugin.instance.current_asset and \
			TbgPlugin.instance.current_asset.scene_file_path:
		TbgPlugin.trace("Asset invalid, reloading...")
		scene_node = TbgPlugin.instance.current_asset
	
	if not is_inside_tree():
		return
	
	update_ui()
	_validated = true


## selects a node for editing
func edit_node(node: Node):
	if is_instance_valid(asset_node) and node:
		TbgPlugin.trace("Editing node %s" % node)
		var asset = TbgPlugin.find_containing(node, TBG.MotionCharacter)
		if asset and asset != asset_node:
			var nodepath = asset.get_path_to(node)
			TbgPlugin.trace("Remapping node path %s" % nodepath)
			node = asset_node.get_node_or_null(nodepath)
			if node:
				inspect.call_deferred(node)
			else:
				TbgPlugin.warn("Asset does not contain %s" % nodepath)


func inspect(ob):
	if is_instance_valid(_inspecting) and _inspecting.has_signal("changed"):
		_inspecting.changed.disconnect(invalidate)
	
	_inspecting = ob
	
	invalidate()
	
	# ignore if just freed
	if not is_instance_valid(ob):
		return
	
	if ob and ob is TBG.MotionConfig:
		ob._property_reference_character = asset_node
	
	if ob:
		TbgPlugin.editor.inspect_object(ob)
	
	if ob and "changed" in ob:
		ob.changed.connect(invalidate)
	
	invalidate()


func _on_resources_reimported(list):
	var import_path : String = ""
	if TbgPlugin.instance.current_asset:
		import_path = get_asset_import_path(TbgPlugin.instance.current_asset)
	if import_path in list:
		TbgPlugin.trace("Asset was reimported: %s" % import_path)
		
		# This shouldn't happen
		if TbgPlugin.instance.current_asset.get_parent() == world:
			TbgPlugin.instance.current_asset.reparent(__editor_parent)
			__editor_parent = null
		
		#The node is guaranteed to self-destruct, so get rid of references to it
		__scene_node = null
		asset_node = null
		
		scene_node = TbgPlugin.instance.current_asset
		TbgPlugin.instance.last_edited = null
		#_on_main_screen_changed(TbgPlugin.instance._current_screen)


func _on_scene_changed(node: Node):
	if node is TBG.MotionCharacter:
		TbgPlugin.trace("TbgPlugin.MotionCharacter loaded: %s" % node.scene_file_path)
		scene_node = node
		
		# Because the nodes act weird if moved around, we need to reassign this
		#if TbgPlugin.editor.get_inspector().get_edited_object() is AnimationPlayer:
		#	var inspectedNode = TbgPlugin.editor.get_inspector().get_edited_object()
		#	await get_tree().process_frame
		#	TbgPlugin.editor.inspect_object(inspectedNode)
		if is_instance_valid(TbgPlugin.editor.get_inspector().get_edited_object()):
			if TbgPlugin.editor.get_inspector().get_edited_object() is Node:
				TbgPlugin.instance.last_edited = TbgPlugin.editor.get_inspector().get_edited_object()
			else:
				TbgPlugin.instance.last_edited = asset_node
	else:
		scene_node = null


func _on_main_screen_changed(menu: String):
	if menu == TbgPlugin.PLUGIN_NAME:
		if scene_node and scene_node.get_parent() and __editor_parent == null:
			__editor_parent = scene_node.get_parent()
			scene_node.reparent(world)
			#if is_instance_valid(TbgPlugin.instance.last_edited):
			#	TbgPlugin.editor.inspect_object(TbgPlugin.instance.last_edited)
	elif is_instance_valid(__editor_parent):
		scene_node.reparent(__editor_parent)
		__editor_parent = null
		if menu == "2D" and is_instance_valid(TbgPlugin.instance.last_edited):
			TbgPlugin.editor.inspect_object(TbgPlugin.instance.last_edited)


var can_see_unused = true
var last_motion_data = [null, null, null]
func update_ui():
	var text = "%d %%" % int(view_scale * 100)
	#Assume user isn't zooming and changing something in the same frame
	if text != %ZoomPercent.text:
		%ZoomPercent.text = text
		return
	
	var has_selected = animation_list.is_anything_selected()
	animation_list.clear()
	animation_properties.object = null
	
	for child in skin_list.get_children():
		child.queue_free()
	node_tree.clear()
	grid_node.motion = Vector2.ZERO
	
	if is_instance_valid(asset_node):
		asset_node.set_bones(asset_node, TbgPlugin.options.show.bones)
		
		var motion = asset_node.current_motion
		var was_playing = is_playing
		var cur_pos = asset_node.animation_position
		asset_node.current_motion = motion # Force the motion to update (set transform)
		asset_node.animation_position = cur_pos
		asset_node.is_playing = was_playing
		
		if motion and motion.loop:
			grid_node.motion = motion.travel * asset_node.speed_scale
		
		var motions = asset_node.config.motions
		
		var used = motions.reduce(func(a,e): a[e.animation_name] = true; return a, {})
		var unused = asset_node.animation_names.filter(func(e): return not used.has(e))
		%UnusedWarning.visible = (not unused.is_empty()) and can_see_unused
		
		motions.sort_custom(func(a,b):
			if a.animation_name != b.animation_name and \
					(a.animation_name == "RESET" or b.animation_name == "RESET"):
				return b.animation_name == "RESET"
			if a.mode != "" and b.mode == "":
				return true
			if b.mode != "" and a.mode == "":
				return false
			if a.mode.naturalnocasecmp_to(b.mode) > 0:
				return false
			if b.mode.naturalnocasecmp_to(a.mode) > 0:
				return true
			elif a.facing < b.facing:
				return true
			elif b.facing < a.facing:
				return false
			
			return a.animation_name.naturalnocasecmp_to(b.animation_name) < 0
		)
		
		for item in motions:
			var idx
			if item is TBG.MotionConfig and not asset_node.animation_names.has(item.animation_name):
				idx = animation_list.add_item("(!) " + item.to_string())
			else:
				idx = animation_list.add_item(item.to_string())
			if has_selected and item == motion:
				animation_list.select(idx)
		
		animation_properties.whitelist = asset_node.get_property_list().filter(
			func(entry):
				return entry["name"] in ["speed_scale"]
		)
		animation_properties.object = asset_node
		%Motion/Expander.update_size()
		
		var group_to_skin = asset_node.composite.config.group_to_skin_to_nodes
		for group: String in group_to_skin:
			var hbox: Control = HBoxContainer.new()
			hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.tooltip_text = group
			
			var label = Label.new()
			label.text = group
			label.clip_text = true
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.size_flags_stretch_ratio = 1.0
			
			var option_button: = OptionButton.new()
			option_button.text = group
			option_button.add_item("None")
			option_button.selected = 0
			option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			option_button.size_flags_stretch_ratio = 2.0
			
			#option_button.focus_mode = Control.FOCUS_NONE
			var skins = group_to_skin[group].keys()
			for skin in skins:
				option_button.add_item(skin)
				if asset_node.get(group) == skin:
					option_button.selected = option_button.get_item_count() - 1
			
			option_button.item_selected.connect(func(idx):
				var skin = option_button.get_item_text(idx)
				var cur_skin = asset_node._get(group)
				TbgPlugin.instance.do_action(
					asset_node.set.bind(group, skin),
					asset_node.set.bind(group, cur_skin),
					asset_node, "Changed Skin")
			)
			hbox.add_child(label)
			hbox.add_child(option_button)
			skin_list.add_child(hbox)
		
		if not motion or not asset_node.animation_names.has(motion.animation_name):
			controls.visible = false
			return
		
		#slider.editable = !is_playing
		var animation = asset_node.animation_player.get_animation(motion.animation_name) if motion else null
		if motion and animation.length:
			var frameCount = ceil(animation.length * asset_node.frame_rate)
			slider.min_value = 0
			slider.max_value = animation.length - TIME_EPSILON
			slider.tick_count = frameCount + 1
			slider.value = asset_node.animation_position
			slider.step = 0.0 if is_playing else 1.0 / asset_node.frame_rate
			play_button.icon_name = "Pause" if is_playing else "Play"
			controls.visible = true
		else:
			controls.visible = false
			if scene_node:
				scene_node.animation_player.stop()
				if not motion and (
						last_motion_data[0] != scene_node.facing or
						last_motion_data[1] != scene_node.mode or
						last_motion_data[2] != scene_node.scene_file_path
				):
					var direction = ""
					for dir in TBG.Direction:
						if scene_node.facing & TBG.Direction[dir]:
							direction += dir
					if direction == "":
						direction = "None"
					TbgPlugin.warn("No MotionMode [%s] and facing [%s] motion found!" % [scene_node.mode, direction])
					
					#Only set this on errors
					last_motion_data[0] = scene_node.facing
					last_motion_data[1] = scene_node.mode
					last_motion_data[2] = scene_node.scene_file_path


func set_asset_node(node: TBG.MotionCharacter):
	if asset_node == node:
		if not (asset_node and node == null):
			return
	
	#inspect(null)
	
	# this can also clear out any generated nodes that got displaced by an import
	# Though might cause a memory leak!
	for child in world.get_children(true):
		if child != grid_node:
			world.remove_child(child)
	
	if is_instance_valid(asset_node):
		TbgPlugin.trace("Releasing: %s" % asset_node)
		#asset_node.animation_changed.disconnect(invalidate)
	
	asset_node = node
	invalidate()
	
	if node is TBG.MotionCharacter:
		#world.add_child(node)
		TbgPlugin.trace("Asset Node: %s" % node.get_path())
		
		TbgPlugin.instance.defer(func():
			if is_instance_valid(node):	# may have since been deleted
				node.config = node.config.duplicate(true)
				if node.config.motions.is_empty():
					node.config.generate_default_motions(node.animation_names, node.animation_player)
				
				#if not node.animation_changed.is_connected(invalidate):
					#node.animation_changed.connect(invalidate)
				
				if node.current_motion:
					# Force a selection
					animation_list.add_item("")
					animation_list.select(0)
					invalidate()
			else:
				TbgPlugin.warn("Node was deleted before setup completed")
				inspect(null)
			
			asset_changed.emit()
		)
	
	asset_changed.emit()


func _frame_all():
	var rect = Rect2(-100, -100, 200, 200)
	if asset_node:
		TbgPlugin.validate(world)
		var box = TbgPlugin.bounding_rect(asset_node.composite)
		if box and box.size.length() > 0:
			rect = box
	#TbgPlugin.log("Bounds: %s" % [rect])
	
	# Fit the view to the largest side
	var dim = max(10, rect.size.x, rect.size.y)
	var k = viewport_rect.size / dim
	view_scale = min(k.x, k.y) * 0.75 * point_scale
	rect.position = rect.position * view_scale / point_scale
	rect.size = rect.size * view_scale / point_scale
	# TbgPlugin.log("Bounds (* %s): %s" % [view_scale, rect])
	viewport.canvas_transform.origin = viewport_rect.size * 0.5 - rect.get_center()


static func ln2(x) -> float:
	return log(x) / log(2)


func _on_view_zoom_in():
	view_scale = min(128, view_scale * 1.05)


func _on_view_zoom_out():
	view_scale = max(0.1, view_scale * 0.95)


func _on_view_zoom_in_button():
	view_scale = min(128, pow(2, ln2(view_scale) + 0.5))


func _on_view_zoom_out_button():
	view_scale = max(0.1, pow(2, ln2(view_scale) - 0.5))


func _view_zoom_reset(scale = 1):
	view_scale = scale
	reset_view()


func reset_view():
	_custom_viewport_origin = null
	viewport.canvas_transform.origin = viewport_rect.get_center() # - box.get_center()
	grid_node.motion = Vector2.ZERO
	# %World/Grid.queue_redraw()


func _make_popup(at_position: Vector2, popup_func: Callable):
	var commands: Array = popup_func.call(TbgPlugin.instance)
	var id = 0
	while id < commands.size():
		if commands[id] != null:
			# Handle functions that add in arrays, funcs should only create arrays
			if commands[id] is Callable:
				var res: Array = commands[id].call()
				commands.remove_at(id)
				for index in range(res.size() -1, -1, -1):
					commands.insert(id, res[index])
				continue
			# Remove submenues
			#elif commands[id][1] is Array:
				#commands.remove_at(id)
				#continue
		id += 1
	
	TbgPlugin.instance.make_popup_menu(at_position, commands)


func _on_animation_item_selected(index, at_position = null, mouse_button_index = 1):
	if asset_node and (mouse_button_index == 1 or mouse_button_index == 2):
		if index != -1:
			var motion = asset_node.config.motions[index]
			# If it's invalid, set it to our error key for safety
			if not asset_node.animation_names.has(motion.animation_name):
				motion.animation_name = ""
			asset_node.current_motion = motion
			inspect(asset_node.current_motion)
			
			# Right mouse should also have a menu
			if mouse_button_index == 2:
				_make_popup(animation_list.get_screen_position() + at_position, motion_popup)
		else:
			animation_list.deselect_all()
			asset_node.current_motion = null
			inspect(asset_node)


func _on_skin_item_selected(index):
	if asset_node != null:
		if index != -1:
			asset_node.skin = skin_list.get_item_text(index)


func _asset_open_scene():
	TbgPlugin.editor.open_scene_from_path(asset_path)


func _asset_revert():
	if asset_path:
		TbgPlugin.editor.reload_scene_from_path(asset_path)


func _asset_show_in_filesystem():
	if asset_path:
		TbgPlugin.trace(_asset_show_in_filesystem)
		TbgPlugin.instance.file_system_dock.navigate_to_path(asset_path)


func _asset_browse_folder():
	if asset_path:
		TbgPlugin.trace(_asset_browse_folder)
		TbgPlugin.show_in_file_manager(asset_path)


func _asset_reimport():
	if  asset_node and get_asset_import_path(asset_node):
		var import_path = get_asset_import_path(asset_node)
		
		if TbgPlugin.instance.tbg_importer_plugin and FEATURE_MANUAL_IMPORT:
			TbgPlugin.log("Manually Reimporting: %s" % import_path)
			TbgPlugin.instance.tbg_importer_plugin.import(import_path)
		else:
			TbgPlugin.editor.get_resource_filesystem().reimport_files([ import_path ])


static func polygon_from_array(arr):
	if arr[0] is Vector2:
		return PackedVector2Array(arr)
	
	var result = PackedVector2Array()
	result.resize(arr.size() >> 1)
	for i in result.size():
		result[i] = Vector2(arr[i * 2], arr[i * 2 + 1])
	
	return result


func _preview_asset_node():
	if TbgPlugin.instance and asset_node:
		var asset: Node2D = asset_node.duplicate()
		if asset:
			var player := preload("../Templates/PlatformPlayer.gd").new()
			var shape = CollisionShape2D.new()
			shape.shape = RectangleShape2D.new()
			player.add_child(shape)
			player.add_child(asset)
			player.tbg_scene_path = NodePath(asset.name)
			asset.z_index = 10
			
			var world := Node2D.new()
			world.name = "Preview"
			world.add_child(player)
			player.position = Vector2(0,-800)
			
			var bg := StaticBody2D.new()
			bg.name = "bg"
			world.add_child(bg)
			shape = CollisionPolygon2D.new()
			bg.add_child(shape)
			var polygon = polygon_from_array([-10000,0,10000,0,10000,1000,-10000,1000])
			shape.polygon = polygon
			shape = Polygon2D.new()
			shape.modulate = Color(0.125,0.25,0.125)
			bg.add_child(shape)
			shape.polygon = polygon
			
			for x in 20:
				var d = randi_range(2,10) * 10
				polygon = polygon_from_array([-d,-d,d,-d,d,d,-d,d])
				var position = Vector2(randf_range(-5000,5000), -d)
				shape = CollisionPolygon2D.new()
				bg.add_child(shape)
				shape.polygon = polygon
				shape.position = position
				
				shape = Polygon2D.new()
				bg.add_child(shape)
				shape.polygon = polygon
				shape.position = position
				shape.modulate = Color(0.25,0.25,0.25)
			
			var grid = TbgPlugin.Editor.Grid.new()
			grid.name = "Grid"
			world.add_child(grid)
			
			var camera = Camera2D.new()
			camera.name = "Camera"
			player.add_child(camera)
			
			TbgPlugin.set_owner_recursive(world)
			var packed_scene := PackedScene.new()
			packed_scene.pack(world)
			if packed_scene:
				var filename = "%s/.preview.%s.scn" % [asset_path.get_base_dir(), asset_title]
				ResourceSaver.save(packed_scene, filename)
				TbgPlugin.log("Preview scene created %s" % filename)
				#TbgPlugin.open_externally(filename)
				TbgPlugin.editor.play_custom_scene(filename)
			else:
				TbgPlugin.log("Failed to create scene")
			world.free()


func _detach_script():
	if asset_node and asset_node.script:
		TbgPlugin.trace(_detach_script)
		var script = asset_node.script.get_base_script()
		TbgPlugin.set_object_script(asset_node, script)


func _create_new_script(attach = true, overwrite_existing = null):
	if asset_node and not get_custom_script(asset_node):
		TbgPlugin.trace(_create_new_script)
		
		var script = get_custom_script(asset_node, attach, overwrite_existing)
		if script and TbgPlugin.editor:
			script.reload(true)
			TbgPlugin.editor.edit_script(script)
			TbgPlugin.editor.set_main_screen_editor("Script")


func confirm(text, on_yes = null, on_no = null):
	var dlg = ConfirmationDialog.new()
	dlg.dialog_text = text
	dlg.ok_button_text = "Yes"
	dlg.cancel_button_text = "No"
	add_child(dlg)
	# dlg.file_selected.connect(callback)
	
	dlg.canceled.connect(func():
		if on_no:
			on_no.call_deferred()
		dlg.queue_free()
		)
	
	dlg.confirmed.connect(func():
		if on_yes:
			on_yes.call_deferred()
		dlg.queue_free()
		)
	
	dlg.popup_centered()


func open_file_dialog(filename = null, filter = null, mode = FileDialog.FILE_MODE_OPEN_FILE, callback = null):
	var dlg = TbgPlugin.file_open_dialog.new()
	dlg.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	dlg.size = self.size * 0.5
	#dlg.popup_window = true
	#dlg.always_on_top = true
	dlg.file_mode = mode
	dlg.mode = Window.MODE_WINDOWED
	add_child(dlg)
	
	if filename:
		var path = filename.get_base_dir()
		dlg.current_dir = path
		dlg.current_file = filename
		if filter == null:
			filter = str("*.%s" % filename.get_extension())
		
		TbgPlugin.trace([path,filename,filter])
	
	if filter:
		dlg.add_filter(filter)
	
	dlg.canceled.connect(func():
		dlg.queue_free()
	)
	
	dlg.file_selected.connect(func(path):
		TbgPlugin.trace("File selected: %s" % path)
		if callback:
			if !path.is_absolute_path():
				path = dlg.current_path
			callback.call(path)
		dlg.queue_free()
	)
	
	dlg.popup_centered()
	return dlg


func _new_inherited():
	if asset_import_path:
		var packed_scene = load(asset_import_path)
		if packed_scene is PackedScene:
			packed_scene = TbgPlugin.create_inherited_scene(packed_scene, asset_node.name)
			var filename = "%s.%s" % [asset_path.get_basename(), TbgPlugin.DEFAULT_SCENE_EXTENSION]
			var dlg = open_file_dialog(filename, "*.scn, *.tscn", EditorFileDialog.FILE_MODE_SAVE_FILE, func(filename):
				if Error.OK == ResourceSaver.save(packed_scene, filename):
					print("Saving derived scene to ", filename)
					TbgPlugin.editor.open_scene_from_path(filename)
			)


func _reset_to_base():
	if scene_node:
		var base_scene = TbgPlugin.get_base_scene(scene_node)
		if base_scene is PackedScene:
			TbgPlugin.log("Resetting to %s ..." % base_scene.resource_path)
			var packed_scene = TbgPlugin.create_inherited_scene(base_scene)
			var filename = scene_node.scene_file_path
			var err = ResourceSaver.save(packed_scene, filename)
			if err == Error.OK:
				TbgPlugin.log("Ok")
				packed_scene.take_over_path(filename)
				TbgPlugin.editor.reload_scene_from_path(filename)
			else:
				TbgPlugin.error("Failed (Error = %s)" % err)


func _on_import_properties():
	if asset_node:
		var filename = "%s.%s" % [asset_path.get_basename(), TbgPlugin.DEFAULT_RESOURCE_EXTENSION]
		var dlg = open_file_dialog(filename, "*.res, *.tres", EditorFileDialog.FILE_MODE_OPEN_FILE, func(filename):
			TbgPlugin.log("Loading properties from %s" % filename)
			if is_instance_valid(asset_node):
				var props = TbgPlugin.instance.load_as_resource(filename)
				if props:
					TbgPlugin.set_properties(asset_node, props)
				else:
					TbgPlugin.error("Couldn't load properties from %s" % filename)
		)


func _on_export_properties():
	if asset_node:
		var props = TbgPlugin.get_properties(asset_node, true, true)
		if props:
			var filename = "%s.%s" % [asset_path.get_basename(), TbgPlugin.DEFAULT_RESOURCE_EXTENSION]
			var dlg = open_file_dialog(filename, "*.res, *.tres", EditorFileDialog.FILE_MODE_SAVE_FILE, func(filename):
				TbgPlugin.instance.save_as_resource(filename, props)
				TbgPlugin.log("Saved properties to %s" % filename)
			)


func _on_save_snapshot():
	if asset_node:
		var packed_scene = PackedScene.new()
		if OK == packed_scene.pack(asset_node.duplicate()):
			var filename = "%s.%s" % [asset_path.get_basename(), TbgPlugin.DEFAULT_SCENE_EXTENSION]
			var dlg = open_file_dialog(filename, "*.scn, *.tscn", EditorFileDialog.FILE_MODE_SAVE_FILE, func(filename):
				print("Saved snapshot to ", filename)
				ResourceSaver.save(packed_scene, filename)
			)


#func instance_about_to_save(node):
	#if editable and visible:
		#if asset_node:
			#if scene_node == node: # special case, we may have to copy properties back
				#TbgPlugin.log("Saving asset scene: %s" % node.scene_file_path)
				#if TbgPlugin.get_base_scene(scene_node):
					#if asset_node == scene_node:
						#TbgPlugin.trace("Editing in place; Nothing to change")
					#else:
						#if node.script != asset_node.script:
							#TbgPlugin.log("Updating script: %s" % asset_node.script)
							#node.script = asset_node.script
						#TbgPlugin.copy_properties(asset_node, scene_node, true, true)
						#TbgPlugin.copy_signals(asset_node, scene_node, true)
				#else:
					#TbgPlugin.warn("Can't modify original import")
	#elif visible:
		# chances are, the node is not linked, make it try again?
		#await get_tree().process_frame
		#__scene_node = null
		#open_asset(node.scene_file_path)


func _instance_post_save(node : Node):
	if not editable:
		_on_main_screen_changed("2D")
		__scene_node = null
		scene_node = node
		_on_main_screen_changed(TbgPlugin.instance._current_screen)


func _on_close():
	scene_node = null
	asset_node = null
	close_requested.emit()
	# visible = false


func _on_asset_viewer_close_requested():
	var window = get_parent()
	if window:
		window.visible = false


func _on_animation_new():
	if asset_node:
		var motion = TBG.MotionConfig.new()
		TbgPlugin.instance.change_property(asset_node.config, "motions", asset_node.config.motions + [motion], "New Motion")
		asset_node.current_motion = motion
		inspect(motion)
		
		# Make sure we have something to select, gets cleared anyways
		if animation_list.item_count == 0:
			animation_list.add_item("")
		animation_list.select(0)


func _on_delete_pressed():
	var motion = asset_node.current_motion
	if motion:
		TbgPlugin.instance.change_property(asset_node.config, "motions", asset_node.config.motions.filter(func(e): return e != motion), "Delete Motion")
		asset_node.current_motion = null
		inspect(asset_node)


func _on_duplicate_pressed():
	var motion = asset_node.current_motion
	if motion:
		motion = motion.duplicate()
		TbgPlugin.instance.change_property(asset_node.config, "motions", asset_node.config.motions + [motion], "Duplicate Motion")
		asset_node.current_motion = motion
		inspect(motion)


func _add_unused_motions():
	if asset_node:
		TbgPlugin.instance.change_property(asset_node.config, "motions", asset_node.config.generate_default_motions(asset_node.animation_names, asset_node.animation_player, true), "Add Unused Motions")
		invalidate()


func _hide_unused_motions():
	# Gets reset on asset node change
	can_see_unused = false
	%UnusedWarning.visible = false


func _on_delete_all_motions():
	if asset_node:
		TbgPlugin.instance.change_property(asset_node.config, "motions", [], "Delete All Motions")
		inspect(null)


func _create_flipped_permutation():
	var _motions = asset_node.config.motions.duplicate()
	for anim in asset_node.config.motions:
		if anim.mode and anim.mode != "":
			var facing = anim.facing
			var left = facing & TBG.Direction.Left as bool
			var right = facing & TBG.Direction.Right as bool
			if left or right:
				facing = facing & ~(TBG.Direction.Left | TBG.Direction.Right)
				if left:
					facing = facing | TBG.Direction.Right
				if right:
					facing = facing | TBG.Direction.Left
				
				if asset_node.config.match_motion_config(anim.mode, facing) == null:
					anim = anim.duplicate()
					anim.scale.x = -anim.scale.x
					anim.rotation = -anim.rotation
					anim.facing = facing
					anim.travel.x = -anim.travel.x
					_motions.append(anim)
	
	TbgPlugin.instance.change_property(asset_node.config, "motions", _motions, "Create Flipped Permutations")
	invalidate()


func _debug_dump():
	var path = "user://%s.json" % asset_node.name
	TbgPlugin.save_json(path, TbgPlugin.json_ify(asset_node))
	print("Saved data to ", path)
	TbgPlugin.open_externally(path)


# if set it is the mouse press event that started a drag
var _drag_start
func _on_view_gui_input(event):
	if event is InputEventMouse:
		if event is InputEventMouseButton:
			# TbgPlugin.log(event)
			# left or middle mouse button
			#if event.button_index & MOUSE_BUTTON_LEFT or event.button_index & MOUSE_BUTTON_MIDDLE:
			if event.button_index == 1 or event.button_index == 3:
				if event.pressed: # button down
					_drag_start = event
					%View.mouse_default_cursor_shape = Input.CURSOR_MOVE
					_custom_viewport_origin = viewport.canvas_transform.origin
				else: # button up
					#inspect if just clicking (no mouse movement)
					if event.button_index == 1 and viewport.canvas_transform.origin == _custom_viewport_origin:
						inspect(asset_node)
					# commit the new position
					_custom_viewport_origin = viewport.canvas_transform.origin
					_drag_start = null
					%View.mouse_default_cursor_shape = Input.CURSOR_MOVE
			elif event.button_index == 2:
				if event.pressed:
					_make_popup(%View.get_screen_position() + event.position, view_popup)
		
		elif event is InputEventMouseMotion:
			if _drag_start:
				var offset = event.position - _drag_start.position
				if offset.length() < DRAG_MOVE_TRESHOLD:
					offset = Vector2.ZERO
				
				viewport.canvas_transform.origin = _custom_viewport_origin + offset / pixel_scale


func _on_anim_list_empty_clicked(at_position, mouse_button_index):
	if mouse_button_index == 1:
		_on_animation_item_selected(-1)
	elif mouse_button_index == 2 and animation_list.is_anything_selected():
		_make_popup(animation_list.get_screen_position() + at_position, motion_popup)


func _on_animation_expander_pressed():
	animation_list.visible = not animation_list.visible


func _on_skins_expander_pressed():
	skin_list.visible = not skin_list.visible
	pass # Replace with function body.


func _on_seek_value_changed(value):
	if asset_node and not is_playing:
		asset_node.animation_position = value


func _on_seek_drag_started():
	if is_playing:
		is_playing = false
		asset_node.animation_position = slider.value
		slider.value = asset_node.animation_position


func _on_play_pressed():
	is_playing = not is_playing
	if asset_node:
		grid_node.motion = motion.travel * asset_node.speed_scale * int(is_playing)
		play_button.icon_name = "Pause" if is_playing else "Play"


func _on_step_back_pressed():
	is_playing = false
	if motion:
		asset_node.animation_position = asset_node.animation_position - 1.0 / asset_node.frame_rate + TIME_EPSILON
		invalidate()
		slider.grab_focus()


func _on_step_forward_pressed():
	is_playing = false
	if motion:
		asset_node.animation_position = asset_node.animation_position + 1.0 / asset_node.frame_rate - TIME_EPSILON
		invalidate()
		slider.grab_focus()


func _on_begin_pressed():
	is_playing = false
	if motion:
		asset_node.animation_position = 0
		invalidate()
		slider.grab_focus()


func _on_end_pressed():
	is_playing = false
	if motion:
		asset_node.animation_position = asset_node.animation_length - TIME_EPSILON
		invalidate()
		slider.grab_focus()


func _on_visibility_changed():
	TbgPlugin.trace("Visibility:%s" % visible)


func _on_viewport_size_changed():
	invalidate()
	if _custom_viewport_origin == null: # once the user start positioning the origin, don't override it
		reset_view()


func _on_zoom_percent_pressed():
	_view_zoom_reset(1)


## Returns the assets custom script (ie a script created for this asset, usually with same base name) 
## will return null if no custom script in use, unless orAttach is set.
## if orAttach is a Script object then any new script will use it as a base
func get_custom_script(node, orAttach = false, overwrite_existing = false) -> Script:
	if node.scene_file_path:
		var custom_script_path = "%s.%s" % [node.scene_file_path.get_basename(), "gd"]
		if node.script.resource_path == custom_script_path:
			return node.script
		
		if orAttach:
			if orAttach is bool:
				orAttach = node.script
			
			if overwrite_existing or not FileAccess.file_exists(custom_script_path):
				if orAttach is String:
					TbgPlugin.log("Copying %s -> %s" % [orAttach, custom_script_path])
					DirAccess.copy_absolute(orAttach, custom_script_path)
				else:
					TbgPlugin.log("Creating %s from %s" % [custom_script_path, orAttach])
					TbgPlugin.create_script(custom_script_path, orAttach)
			
			var custom_script = load(custom_script_path)
			if custom_script is Script:
				custom_script.take_over_path(custom_script_path)
				TbgPlugin.trace("Adding new script " + custom_script_path)
				TbgPlugin.set_object_script.call_deferred(asset_node, custom_script)
			else:
				TbgPlugin.error("Failed to reload resource")
			
			return custom_script
	
	return null
