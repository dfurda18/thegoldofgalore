@tool
## Resource type for Motions and their various options that MotionCharacter chooses from
extends Resource
class_name MotionConfig

#const MotionCharacter = preload("MotionCharacter.gd")

#@export_category("Motion Preset")
## The type of motion as a string, eg Walk, Run, Idle, Jump etc.
var mode: StringName = &"":
	set(value):
		if mode != value:
			# do this before updating the value to able to retrieve the previous value
			if Engine.is_editor_hint():
				if value != "" and not TBG.MotionModes.modes.has(value):
					TBG.MotionModes.modes.append(value)
					ResourceSaver.save(TBG.MotionModes)
			
			mode = value
			emit_changed()
			notify_property_list_changed()

## The orientation of this motion.
var facing: TBG.Direction = TBG.Direction.None:
	set(value):
		if facing != value:
			facing = value
			emit_changed()

## Optional velocity represented by this motion, can be used for actual movement
## or simply to show indicative motion in the Asset Viewer.
var travel: Vector2 = Vector2.ZERO:
	set(value):
		if travel != value:
			travel = value
			emit_changed()

## The source animation name as imported. This is the primary means by which an arbitrary imported
## animation can be mapped to a consistent schema for use within a game.
var animation_name: StringName:
	set(value):
		if animation_name != value:
			animation_name = value
			emit_changed()

## The phase offset to use for the animation, allows fine tuning of motions.
var phase: float = 0.0:
	set(value):
		if phase != value:
			phase = value
			emit_changed()

## The speed multiplier for this motion.
## A zero value effectively freezes any motion, in which case the phase value can be used to select
## a particular position or pose from an animation.
## A negative value reverses the animation.
var speed: float = 1.0:
	set(value):
		if speed != value:
			speed = value
			emit_changed()

## Determines whether the animation plays once or loops repeatedly.
var loop: Animation.LoopMode = Animation.LOOP_NONE:
	set(value):
		if loop != value:
			loop = value
			emit_changed()

# an additional transform to be applied to the AssetRoot. If there is also a transform applied at 
# the AssetRoot level it will be multiplied by this transform when computing the global transform 
# of the AssetRoot.
## Mainly used for certain transformations, data is stored in offset, rotation and scale
var transform: Transform2D :
	get:
		return Transform2D(rotation, scale, 0.0, offset)
	set(value):
		offset = value.get_origin()
		rotation = value.get_rotation()
		scale = value.get_scale()
		emit_changed()

## Applies a position change on this motion to the assetRoot (additional)
var offset: Vector2 = Vector2.ZERO :
	get:
		#return transformData.position
		return offset
	set(value):
		#if transformData.position != value:
		#	transformData.position = value
		if offset != value:
			offset = value
			emit_changed()

## Applies a rotation change on this motion to the assetRoot (additional)
var rotation: float = 0.0:
	get:
		return rotation
	set(value):
		if rotation != value:
			rotation = value
			emit_changed()

## Applies a scale change on this motion to the assetRoot (multiplicative)
var scale: Vector2 = Vector2.ONE:
	get:
		return scale
	set(value):
		if scale != value:
			scale = value
			emit_changed()


# Custom property list
var _property_reference_character: TBG.MotionCharacter
func _get_property_list():
	var defaultGroup = "Data"
	var usage = PROPERTY_USAGE_DEFAULT
	var mode_hint_string = ",".join(TBG.MotionModes.modes)
	var animation_name_hint_string = ""
	if _property_reference_character and is_instance_valid(_property_reference_character):
		animation_name_hint_string = ",".join(_property_reference_character.animation_names)
		if not _property_reference_character.scene_file_path.ends_with(".tscn"):
			usage |= PROPERTY_USAGE_READ_ONLY
	
	#HACK: This function is called when saving to determine what is saved.
	# So we can check if we're in this saving state and only allow changed variables to get saved
	if TBG.currently_saving:
		# Could fetch the default value in _init(), before the saved data is loaded
		var builder = [
			{
				"name": "mode",
				"type": TYPE_STRING,
				"usage": usage,
				"defaultValue": &""
			},
			{
				"name": "facing",
				"type": TYPE_INT,
				"usage": usage,
				"defaultValue": 0
			},
			{
				"name": "travel",
				"type": TYPE_VECTOR2,
				"usage": usage,
				"defaultValue": Vector2.ZERO
			},
			{
				"name": "animation_name",
				"type": TYPE_STRING,
				"usage": usage,
				"defaultValue": &""
			},
			{
				"name": "phase",
				"type": TYPE_FLOAT,
				"usage": usage,
				"defaultValue": 0.0
			},
			{
				"name": "speed",
				"type": TYPE_FLOAT,
				"usage": usage,
				"defaultValue": 1.0
			},
			{
				"name": "loop",
				"type": TYPE_INT,
				"usage": usage,
				"defaultValue": 0
			},
			{
				"name": "offset",
				"type": TYPE_VECTOR2,
				"usage": usage,
				"defaultValue": Vector2.ZERO
			},
			{
				"name": "rotation",
				"type": TYPE_FLOAT,
				"usage": usage,
				"defaultValue": 0.0
			},
			{
				"name": "scale",
				"type": TYPE_VECTOR2,
				"usage": usage,
				"defaultValue": Vector2.ONE
			}
		]
		
		var count = 0
		while count < builder.size():
			if builder[count]["defaultValue"] == get(builder[count]["name"]):
				builder.remove_at(count)
				continue
			builder[count].erase("defaultValue")
			count += 1
		
		return builder
	else:
		return [
			{
				"name": defaultGroup,
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_GROUP,
			},
			{
				"name": "mode",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_ENUM_SUGGESTION,
				"hint_string": mode_hint_string,
				"usage": usage,
			},
			{
				"name": "Facing",
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_SUBGROUP,
			},
			{
				"name": "facing",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_FLAGS,
				# Not synced with TBG.Directions, so keep that in mind
				"hint_string": "Left, Right, Up, Down, In, Out",
				"usage": usage,
			},
			{
				"name": defaultGroup,
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_GROUP,
			},
			{
				"name": "travel",
				"type": TYPE_VECTOR2,
				"usage": usage,
			},
			{
				"name": "animation_name",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": animation_name_hint_string,
				"usage": usage,
			},
			{
				"name": "phase",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0, 360, 5, degrees",
				"usage": usage,
			},
			{
				"name": "speed",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0, 2.0, 0.01, or_less, or_greater",
				"usage": usage,
			},
			{
				"name": "loop",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "None,Linear,PingPong",
				"usage": usage,
			},
			{
				"name": "transform",
				"type": TYPE_TRANSFORM2D,
				"usage": PROPERTY_USAGE_EDITOR,
			},
			{
				"name": "Transform Data",
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_GROUP,
			},
			{
				"name": "offset",
				"type": TYPE_VECTOR2,
				"usage": usage,
			},
			{
				"name": "rotation",
				"type": TYPE_FLOAT,
				"usage": usage,
			},
			{
				"name": "scale",
				"type": TYPE_VECTOR2,
				"usage": usage,
			},
		]


func _to_string():
	var string := ""
	if mode:
		string += mode
		if facing:
			string += "/%s" % TBG.flag_to_string(TBG.Direction, facing)
	
	if animation_name:
		if string:
			string += " =>"
		string += ' "%s"' % animation_name
	
	if string:
		return string
	return "<empty>"


func to_source_t(animation_player: AnimationPlayer, t: float) -> float:
	var length = animation_player.get_animation(animation_name).length
	if length == null:
		return 0
	
	t += length * phase / 360
	
	match loop:
		Animation.LoopMode.LOOP_NONE:
			# for negative values offset by one interval
			if t < 0:
				t += length
		Animation.LoopMode.LOOP_LINEAR:
			t = fposmod(t, length)
		Animation.LoopMode.LOOP_PINGPONG:
			t = fposmod(t, length * 2)
			if t > length:
				t = length * 2 - t
	
	# clamp
	t = min(max(0, t), length)
	return t


func from_source_t(animation_player: AnimationPlayer, t: float) -> float:
	var length = animation_player.get_animation(animation_name).length
	if length == null || speed == 0:
		return 0
	
	t -= length * phase / 360
	
	match loop:
		Animation.LoopMode.LOOP_LINEAR:
			t = fposmod(t, length)
		Animation.LoopMode.LOOP_PINGPONG:
			t = fposmod(t, length * 2)
			if t > length:
				t = length * 2 - t
	
	return t
