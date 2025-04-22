@tool
## Node that can propogate its transform to a TBG.Drawing
extends Node2D
#class_name RemoteDrawingTransform

#const Drawing = preload("Drawing.gd")

@export var remote_sprite_path: NodePath
var remote_sprite: TBG.Drawing
var skeleton : Skeleton2D


func _ready():
	remote_sprite = get_node_or_null(remote_sprite_path) as TBG.Drawing;
	# Hacky way, but it works
	skeleton = remote_sprite.composite.get_node_or_null("../Skeleton")
	# Makes sure it only starts after being started properly
	call_deferred("set_notify_transform", true)


func _notification(what):
	if not is_node_ready() or not is_inside_tree():
		return
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		# Current bug in Godot causes this notification to not work properly
		# you need to call this as a workaround
		# https://github.com/godotengine/godot/issues/67640#issuecomment-1284370297
		get_global_transform()
		if not remote_sprite or not skeleton:
			return
		var new_transform = get_relative_transform_to_parent(skeleton)
		remote_sprite.rotation = new_transform.get_rotation()
		remote_sprite.position = new_transform.get_origin()
		remote_sprite.skew = new_transform.get_skew()
		# Special, since the sprite itself tracks a different scale per-texture applied.
		remote_sprite.base_scale = new_transform.get_scale()
		remote_sprite.local_transform_changed.emit()
