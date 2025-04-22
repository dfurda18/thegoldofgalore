@tool
## Resource for MotionCharacters to use and store MotionConfigs
extends Resource
class_name MotionCharacterConfig

#const MotionConfig = preload("MotionConfig.gd")

@export var motions: Array = []
@export var modes: Array[StringName]:
	get:
		var modes: Array[StringName] = []
		for e in motions:
			if not modes.has(e.mode):
				modes.append(e.mode)
		return modes


func match_motion_config(mode: StringName, facing = null, orCreate := false) -> TBG.MotionConfig:
	if mode || orCreate:
		for e in motions:
			if mode && mode != e.mode:
				continue
			if facing && facing != e.facing:
				continue
			return e
		
		if orCreate:
			var new_motion = TBG.MotionConfig.new()
			if mode:
				new_motion.mode = mode
			if facing:
				new_motion.facing = facing
			motions.append(new_motion)
			return new_motion
	
	return null


func generate_default_motions(existing_animation_names: Array, animation_player: AnimationPlayer,
			keep_existing := false) -> Array:
	var new_motions := motions.duplicate() if keep_existing else []
	var used = new_motions.reduce(func(a,e):
		a[e.animation_name] = true
		return a
		, {})
	var unused_animation_names = existing_animation_names.filter(func(e): return not used.has(e))
	new_motions.append_array(unused_animation_names.map(func(animation_name: String):
		var config = TBG.MotionConfig.new()
		config.animation_name = animation_name
		config.loop = animation_player.get_animation(animation_name).loop_mode
		return config
	))
	# For some callback stuff
	#motions = new_motions
	return new_motions
