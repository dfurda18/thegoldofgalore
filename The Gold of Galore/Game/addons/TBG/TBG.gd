@tool
## Autoload class to hold and handle some data
extends Node
#class_name Tbg

# Runtime classes
const Composite = preload("Runtime/Composite.gd")
const CompositeConfig = preload("Runtime/CompositeConfig.gd")
const Cutter = preload("Runtime/Cutter.gd")
const Drawing = preload("Runtime/Drawing.gd")
const DrawingCollider = preload("Runtime/DrawingCollider.gd")
const DrawingPolygonCollider = preload("Runtime/DrawingPolygonCollider.gd")
const MotionConfig = preload("Runtime/MotionConfig.gd")
const MotionCharacterConfig = preload("Runtime/MotionCharacterConfig.gd")
const MotionCharacter = preload("Runtime/MotionCharacter.gd")
const RemoteDrawingTransform = preload("Runtime/RemoteDrawingTransform.gd")
const MotionModeResource = preload("Editor/MotionModeResource.gd")


## Enumerates the styles of auto-generated collision objects used for physics and hit-testing
enum CollisionShape {
	None, Box, Circle, Capsule, ConvexHull, ComplexFill, ComplexOutline,
}

# if changing the order, update the flag values in their respective _get_property method
## Enumerates directionality for use with [MotionConfig] and [MotionCharacter]
enum Direction {
	None	= 0, 
	Left	= 1,
	Right	= 2,
	Up		= 4,
	Down	= 8,
	In		= 16,
	Out		= 32,
}

## Enumerates some motion presets to standardize basic motion types
const _MOTIONMODES_PATH: String = "res://addons/motionModes.tres"
const _DEFAULT_MOTIONS: Array[StringName] = [
	&"None",&"Idle",&"Walk",&"Run",&"Jump",&"Crawl",&"Climb",&"Crouch",&"Action",&"Fire",
]
static var MotionModes: MotionModeResource = null :
	# Shouldn't be used outside of the getter
	set(_val):
		# Will reload the resource each time because the Getter gets called too
		if ResourceLoader.exists(_MOTIONMODES_PATH):
			var res = load(_MOTIONMODES_PATH)
			if not res is MotionModeResource:
				ResourceSaver.save(res, "res://addons/oldMotionModes.tres")
				res = MotionModeResource.new()
				res.modes.append_array(_DEFAULT_MOTIONS)
				print("Regenerated MotionModes resource!")
				ResourceSaver.save(res, _MOTIONMODES_PATH)
			MotionModes = res
	get:
		if MotionModes:
			return MotionModes
		
		if not ResourceLoader.exists(_MOTIONMODES_PATH):
			var res = MotionModeResource.new()
			res.modes.append_array(_DEFAULT_MOTIONS)
			print("Generated MotionModes resource!")
			ResourceSaver.save(res, _MOTIONMODES_PATH)
		
		# Calls the setter, apparently
		MotionModes = null
		
		return MotionModes


static var currently_saving: bool = false
signal node_post_save(node: Node)


func _enter_tree():
	if Engine.is_editor_hint():
		# Call the getter
		MotionModes


## Maps a string to a script-defined enum (does not work for native enums)
static func string_to_enum(key: String, EnumType, _default: int = -1):
	return EnumType.get(key, _default)


## Returns string form of a script-defined enum (does not work for native enums)
static func enum_to_string(EnumType, value: int, _default := "") -> String:
	for k in EnumType:
		if EnumType[k] == value:
			return k
	return _default


## Returns string form of a script-defined enum (does not work for native enums)
static func flag_to_string(EnumType, value: int, _default := "") -> String:
	var string = ""
	for k in EnumType:
		if EnumType[k] & value:
			if string != "":
				string += ", " + k
			else:
				string += k
	if string:
		return string
	return _default


static func node_matches(node: Node, rhs):
	if rhs is Callable:
		return rhs.call(node)
	
	elif rhs is Node:
		return node == rhs
	
	return is_instance_of(node, rhs)


static func find_node(node : Node, rhs):
	if node is Node:
		if node_matches(node, rhs):
			return node
		
		for child in node.get_children():
			node = find_node(child, rhs)
			if node:
				return node
	return null


static func find_nodes(node: Node, rhs, search_matching_parents := false, results := []) -> Array:
	if node is Node:
		if node_matches(node, rhs):
			results.append(node)
			if not search_matching_parents:
				return results
		
		for child in node.get_children():
			find_nodes(child, rhs, search_matching_parents, results)
	
	return results


## Returns current epoch time in seconds
static func time() -> float:
	return Time.get_ticks_msec() / 1000.0
