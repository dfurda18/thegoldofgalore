@tool
## Custom properties for objects and dictionaries
extends VBoxContainer
#class_name PropertiesView

const TbgPlugin = preload("Plugin.gd")

## include a title (which also enables user to toggle collapse state)
@export var title: String : set = set_title

## only show these properties
var whitelist: set = set_whitelist
var object: set = set_options

signal changed

# private
var _property_list


#func _init():
	# add_theme_constant_override("separation", 1)


# Capital letter to not override existing get and set functions
static func Set(object, _name, value):
	if object is Dictionary:
		object[_name] = value
	else:
		object.set(_name, value)


static func Get(object, _name):
	if object is Dictionary:
		return object[_name]
	else:
		return object.get(_name)


func get_custom_properties(ob) -> Array:
	var props = []
	if whitelist and not whitelist.is_empty():
		for prop in whitelist:
			if ob.get(prop["name"]) != null:
				if prop["usage"] & PROPERTY_USAGE_EDITOR: 
					props.push_back(prop.duplicate())
	elif ob is Object:
		var category
		for prop in ob.get_property_list():
			if prop.usage == PROPERTY_USAGE_CATEGORY:
				category = prop.name
				continue
			
			if prop.usage & PROPERTY_USAGE_EDITOR: # not interested in non storable values
				props.push_back(prop)
	elif ob is Dictionary:
		for key in ob:
			props.push_back({
				"name": key,
				"type": typeof(object[key]),
				"usage": PROPERTY_USAGE_DEFAULT
			})
	
	return props


func on_property_list_changed():
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_property_list = null
	
	if object == null:
		return
	
	_property_list = get_custom_properties(object)
	
	for prop in _property_list:
		prop.value = object[prop.name]
		# print("\t", prop.name, ": ", prop.value)
		
		var control
		var label
		var prop_name = TbgPlugin.get_tr(prop.name.to_upper())
		
		match prop.type:
			TYPE_BOOL:
				control = CheckButton.new()
				control.text = prop_name
			TYPE_INT, TYPE_FLOAT:
				label = prop_name
				if prop.get("hint") == PROPERTY_HINT_ENUM:
					control = OptionButton.new()
					prop.list = prop.get("hint_string").split(",")
					for option in prop.list:
						var parts = option.split(":")
						var id = int(parts[1]) if parts.size() > 1 else -1
						control.add_item(TbgPlugin.format_label(parts[0]), id)
				else:
					control = SpinBox.new()
					control.allow_greater = true
					control.allow_lesser = true
					if prop.type == TYPE_FLOAT:
						var hint_string = prop.get("hint_string")
						if hint_string:
							hint_string = hint_string.split(",")
							control.min_value = float(hint_string[0]) if hint_string.size() > 0 else 0
							control.max_value = float(hint_string[1]) if hint_string.size() > 1 else 1
							control.step = float(hint_string[2]) if hint_string.size() > 2 else 0.1
						else:
							control.min_value = 0
							control.max_value = 1
							control.step = 0.1
					
					else:
						control.rounded = true
					
				control.alignment = HORIZONTAL_ALIGNMENT_RIGHT
				control.size_flags_stretch_ratio = 0.5
			TYPE_ARRAY:
				control = ItemList.new()
			TYPE_DICTIONARY, TYPE_OBJECT:
				control = TbgPlugin.Editor.PropertiesView.new()
				control.title = prop_name
				control.visible = true # collapse child groups by default
			_:
				if prop.get("hint") == PROPERTY_HINT_ENUM:
					label = prop_name
					control = OptionButton.new()
					prop.list = (prop.get("hint_string") as String).split(",")
					for option in prop.list:
						control.add_item(option)
				else:
					control = LineEdit.new()
					control.placeholder_text = prop_name
		
		if label:
			var box = HBoxContainer.new()
			var labelControl = Label.new()
			labelControl.text = str(label)
			labelControl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(labelControl)
			box.add_child(control)
			add_child(box)
		elif control is TbgPlugin.Editor.PropertiesView:
			var titleControl = Button.new()
			titleControl.alignment = HORIZONTAL_ALIGNMENT_LEFT
			titleControl.text = str("+ ", prop_name)
			add_child(titleControl)
			var box = HBoxContainer.new()
			box.add_child(Control.new())
			box.add_child(control)
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add_child(box)
			titleControl.pressed.connect(func():
				control.visible = not control.visible
				# on_property_list_changed()
				)
		
		else:
			add_child(control)
		
		if control == null:
			continue
		
		prop.control = control
		
		var _on_change
		if control is OptionButton:
			_on_change = control.item_selected
			if prop.type == TYPE_INT:
				prop.load = _delayed_load.bind(control, "selected", prop)
				prop.save = _delayed_save.bind(control, "selected", prop)
			else:
				# prop hint is enum, already string
				prop.load = _delayed_load.bind(control, "selected", prop)
				prop.save = _delayed_save.bind(control, "selected", prop)
		elif control is Button:
			_on_change = control.toggled
			prop.load = _delayed_load.bind(control, "button_pressed", prop)
			prop.save = _delayed_save.bind(control, "button_pressed", prop)
		elif control is TbgPlugin.Editor.PropertiesView:
			_on_change = control.changed
			prop.load = _delayed_load.bind(control, "object", prop)
			#prop.save = _delayed_save.bind(control, "object", prop)
		elif "value" in control:
			_on_change = control.value_changed
			prop.load = _delayed_load.bind(control, "value", prop)
			prop.save = _delayed_save.bind(control, "value", prop)
		elif "text" in control:
			_on_change = control.text_changed
			prop.load = _delayed_load.bind(control, "text", prop, _str)
			prop.save = _delayed_save.bind(control, "text", prop)
		
		if control:
			if prop.get("tip"):
				control.tooltip_text = prop.tip
			if prop.usage & PROPERTY_USAGE_READ_ONLY:
				TbgPlugin.set_read_only(control, true)
		
		if prop.get("load"):
			prop.load.call()
		
		if _on_change:
			_on_change.connect(_on_change_signal.bind(prop))


# functions to bind variables to
# ensures references are stored when scripts are changed while the editor is running
func _delayed_load(control, key : String, prop, _func = null):
	if _func:
		control.set(key, _func.call(Get(object, prop.name)))
	else:
		control.set(key, Get(object, prop.name))


func _delayed_save(control, key : String, prop, _func = null):
	if _func:
		Set(object, prop.name, _func.call(control.get(key)))
	else:
		Set(object, prop.name, control.get(key))


# Passthrough used in the above
func _str(val):
	return str(val)


func _on_change_signal(x = null, prop = null):
	if is_inside_tree():
		if prop == null:
			prop = x
		if prop.get("save"):
			prop.save.call()
			TbgPlugin.trace("Property %s = %s " % [prop.name, object[prop.name]])
		changed.emit()


func set_whitelist(list):
	if whitelist == list:
		return
	
	whitelist = list
	on_property_list_changed()


func set_title(str):
	if title == str:
		return
	
	title = str
	on_property_list_changed()


func set_options(ob):
	if object == ob:
		return
	
	if is_instance_valid(object) and object is Object:
		object.property_list_changed.disconnect(on_property_list_changed)
	
	object = ob
	on_property_list_changed()
	
	if object is Object and not object.property_list_changed.is_connected(on_property_list_changed):
		object.property_list_changed.connect(on_property_list_changed)


func revert():
	for prop in _property_list:
		if prop.load:
			object[prop.name] = prop.value
	_load()


func _load():
	for prop in _property_list:
		if prop.load:
			prop.load.call()


func _save():
	for prop in _property_list:
		if prop.save:
			prop.save.call()
