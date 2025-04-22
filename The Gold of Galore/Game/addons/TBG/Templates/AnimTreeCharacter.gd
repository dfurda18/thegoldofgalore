@tool
## Script that inherits from MotionCharacter to add support code
## for AnimationTree purposes. Ensures proper functions call their super
extends MotionCharacter


@onready var anim_tree : AnimationTree = $AnimationTree


# All methods can be removed if not customized, but should call upon super to
# function properly (makes sure skins and some functionality isn't overwritten)

func _get(property):
	var res = super._get(property)
	if res:
		return res
	
	# Your own code can start here
	return null


func _set(property, value) -> bool:
	var res = super._set(property, value)
	
	# Your own code can start here
	return res


func _get_property_list():
	var props = super._get_property_list()
	
	# Your own code can start here and should append to props
	return props


# MotionCharacter will handle AnimationTree bloat
func _notification(what):
	# MotionCharacter has some pre/post-save notifications that need to run
	super._notification(what)
	
	# Your own code can start here
	pass


func _ready():
	# MotionCharacter has some specific code it needs to run first
	super._ready()
	
	# Remember that this is a tool script, so code will run in editor!
	pass
