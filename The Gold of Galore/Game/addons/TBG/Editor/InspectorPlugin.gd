@tool
## Inspector plugin for certain TBG types
extends EditorInspectorPlugin

const TbgPlugin = preload("Plugin.gd")

const SUPPORTED_TYPES = [TBG.MotionCharacter, TBG.MotionConfig]


func _can_handle(object):
	if as_type(object, SUPPORTED_TYPES):
		TbgPlugin.trace("Custom inspection for %s" % object)
		return true
		
	return false


func _parse_begin(object):
	var item = as_type(object, SUPPORTED_TYPES)
	if TbgPlugin.is_external(item, TbgPlugin.instance.current_scene):
		var path = TbgPlugin.get_containing_file(item)
		if path:
			add_buttons([
				["Open \"%s\" ..." % path.get_file(), func(): 
					TbgPlugin.editor.select_file(path)
					TbgPlugin.editor.open_scene_from_path(path)
					]
				])


func _parse_property(object, type, path, hint, hint_text, usage, wide):
	if object is TBG.MotionCharacter:
		match path:
			"collision_root":
				if (object.collision_root and object.collision_shape != TBG.CollisionShape.None
						) or object.hitbox_shape != TBG.CollisionShape.None:
					add_button("Refresh Colliders", object.update_colliders)
				return false
	elif object is TBG.MotionConfig:
		match path:
			"transform":
				if not (usage & PROPERTY_USAGE_READ_ONLY):
					add_motion_config_buttons(object)
				return true
	return false


static func as_type(ob, type):
	if type is Array:
		for t in type:
			var result = as_type(ob,t)
			if result:
				return result
	else:
		if is_instance_of(ob, type):
			return ob


func add_text(text):
	var control = Label.new()
	control.text = str(text)
	add_custom_control(control)
	return control


func add_button(text, fn):
	var button = Button.new()
	button.text = str(text)
	button.pressed.connect(TbgPlugin.instance.deferred(fn))
	add_custom_control(button)
	return button


func add_buttons(items):
	var buttons = HBoxContainer.new()
	for item in items:
		if item is String:
			item = [ item ]
		
		if item is Array:
			var button = Button.new()
			button.text = str(item[0])
			var action = item[1]
			button.pressed.connect(TbgPlugin.instance.deferred(action))
			buttons.add_child(button)
	
	add_custom_control(buttons)
	return buttons


func add_motion_config_buttons(object):
	add_buttons([
		["Flip X", (func(object):
			TbgPlugin.instance.change_property(object, "scale", func():
				return Vector2(-1, 1) * object.scale
			)
			if object.rotation:
				TbgPlugin.instance.change_property(object, "rotation", func():
					return -object.rotation
				)
			).bind(object)
		],
		["Flip Y", (func(object):
			TbgPlugin.instance.change_property(object, "scale", func():
				return Vector2(1, -1) * object.scale
			)
			if object.rotation:
				TbgPlugin.instance.change_property(object, "rotation", func():
					return -object.rotation
				)
			).bind(object)
		],
		["-45º", TbgPlugin.instance.change_property.bind(object, "rotation", func():
			var res = object.rotation - PI / 4.0
			if res < -PI:
				res += TAU
			elif res > PI:
				res -= TAU
			return res
			)
		],
		["+45º", TbgPlugin.instance.change_property.bind(object, "rotation", func():
			var res = object.rotation + PI / 4.0
			if res < -PI:
				res += TAU
			elif res > PI:
				res -= TAU
			return res
			)
		],
		["Xcog", TbgPlugin.instance.change_property.bind(object, "transform", func():  
			var offset = TbgPlugin.cog_xy(TbgPlugin.get_cog(object.offset))
			offset = Transform2D(0.0, object.scale, 0.0, object.offset
					).affine_inverse() * offset
			offset.y = 0
			return Transform2D(0,-offset) * object.transform
			)
		],
		["Ycog", TbgPlugin.instance.change_property.bind(object, "transform", func(): 
			var offset = TbgPlugin.cog_xy(TbgPlugin.get_cog(object.offset))
			offset = Transform2D(0.0, object.scale, 0.0, object.offset
					).affine_inverse() * offset
			offset.x = 0
			return Transform2D(0,-offset) * object.transform
			)
		],
		["Reset", TbgPlugin.instance.change_property.bind(object, "transform", Transform2D.IDENTITY)],
	])
