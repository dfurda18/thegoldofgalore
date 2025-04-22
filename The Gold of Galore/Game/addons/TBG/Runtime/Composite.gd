@tool
## Node to manage and hold TBG.Drawings
extends Node2D
#class_name Composite

#const CompositeConfig = preload("CompositeConfig.gd")
#const Drawing = preload("Drawing.gd")

@export var config: TBG.CompositeConfig

var child_nodes: Array[TBG.Drawing] = []
var update_node_order_queued = true
@export var group_to_skin: Dictionary = {}
var group_to_skin_to_nodes: Dictionary:
	get:
		if (
			group_to_skin_to_nodes == null
			or group_to_skin_to_nodes.size() == 0
			or group_to_skin_to_nodes.keys().size() != config.group_to_skin_to_nodes.keys().size()
		):
			# Create a lookup to find nodes to show/hide
			for group in config.group_to_skin_to_nodes:
				group_to_skin_to_nodes[group] = {}
				var first_skin = true
				for skin in config.group_to_skin_to_nodes[group]:
					group_to_skin_to_nodes[group][skin] = []
					for node_name in config.group_to_skin_to_nodes[group][skin]:
						var node = get_node(node_name)
						if node != null:
							group_to_skin_to_nodes[group][skin].append(node)
							node.visible = first_skin
						else:
							print("TbgComposite: Node not found: " + str(node_name))
					first_skin = false
			
			# Initialize current state, must be done in a lambda
			var init = func():
				if not is_node_ready():
					await ready
				if group_to_skin == null:
					group_to_skin = {}
				for group_name in config.group_to_skin_to_nodes:
					var skin_to_nodes = config.group_to_skin_to_nodes[group_name]
					var skin_to_nodes_keys = skin_to_nodes.keys()
					if group_to_skin.has(group_name):
						var properValue = group_to_skin[group_name]
						# To make sure things are reset properly
						group_to_skin[group_name] = skin_to_nodes_keys[0]
						_set(group_name, properValue)
					else:
						group_to_skin[group_name] = skin_to_nodes_keys[0]
			init.call()
		return group_to_skin_to_nodes


func _ready():
	child_nodes.clear()
	for child in get_children():
		child_nodes.append(child)
	
	group_to_skin = group_to_skin.duplicate()
	group_to_skin_to_nodes


func _process(delta):
	if not update_node_order_queued:
		return
	update_node_order_queued = false
	
	# sort nodes by position_z, or if position_z is the same, sort by node_order
	child_nodes.sort_custom(sort_nodes)
	
	# iterate through children, only moving if the index is different
	var size = child_nodes.size()
	for i in range(size):
		if get_child(i) != child_nodes[i]:
			move_child(child_nodes[i], i)


# Skin managment
func _get(property):
	if group_to_skin.has(property):
		return group_to_skin[property]


func _set(property, value)->bool:
	if group_to_skin.has(property):
		var existing_value = group_to_skin[property]
		if existing_value != value:
			group_to_skin[property] = value
			var skin_to_nodes = group_to_skin_to_nodes[property]
			if skin_to_nodes.has(existing_value):
				var nodes = skin_to_nodes[existing_value]
				for node in nodes:
					node.visible = false
			if skin_to_nodes.has(value):
				var nodes = skin_to_nodes[value]
				for node in nodes:
					node.visible = true
			return true
	return false


func _get_property_list():
	var props = [{
				"name": "Skins",
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_GROUP,
			}]
	
	for group_name in config.group_to_skin_to_nodes:
		var skin_to_nodes = config.group_to_skin_to_nodes[group_name]
		var skin_to_nodes_keys = skin_to_nodes.keys()
		var hint_string = ",".join(["None"] + skin_to_nodes_keys)
		props.append(
			{
				"name": group_name,
				"type": TYPE_STRING,
				"usage": PROPERTY_USAGE_EDITOR,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": hint_string
			}
		)
	
	return props


func _notification(what):
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		var reset = func():
			group_to_skin_to_nodes = {}
			group_to_skin_to_nodes
		reset.bind().call_deferred()
		
		# Set the default skins and delay the changed skins
		for key in group_to_skin.keys():
			if not config.group_to_skin_to_nodes.has(key):
				group_to_skin.erase(key)
				continue
			var default_val = config.group_to_skin_to_nodes[key].keys()[0]
			# Always set it back to the default value
			var prev_val = group_to_skin[key]
			# Decide if we remove the entry or store it
			if prev_val != default_val:
				set.call_deferred(key, prev_val)
				set(key, default_val)
				group_to_skin[key] = prev_val
			else:
				group_to_skin.erase(key)
		


func update_node_order():
	update_node_order_queued = true


func sort_nodes(a, b):
	if a.position_z == b.position_z:
		if a.node_order == b.node_order:
			return a.skin_id < b.skin_id
		else:
			return a.node_order > b.node_order
	else:
		return a.position_z < b.position_z
