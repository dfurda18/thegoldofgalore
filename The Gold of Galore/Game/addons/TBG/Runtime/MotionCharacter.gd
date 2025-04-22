@tool
## Node that manages and uses MotionConfigs to control its animations
extends Node2D
class_name MotionCharacter

#const Drawing = preload("Drawing.gd")
#const MotionConfig = preload("MotionConfig.gd")
#const Composite = preload("Composite.gd")
#const DrawingCollider = preload("DrawingCollider.gd")
#const DrawingPolygonCollider = preload("DrawingPolygonCollider.gd")
#const MotionCharacterConfig = preload("MotionCharacterConfig.gd")

#signal animation_changed
signal area_enter_triggered(other:Node2D, hitbox:Node2D)
signal area_exit_triggered(other:Node2D, hitbox:Node2D)
signal body_enter_triggered(other:Node2D, hitbox:Node2D)
signal body_exit_triggered(other:Node2D, hitbox:Node2D)

const NAME_MODIFIER := &" CS2D"

@export var config: TBG.MotionCharacterConfig

@export var frame_rate: int = 30
## Speed scale of the animation_player
@export_range(0.0, 2.0, 0.01, "or_less", "or_greater") var speed_scale: float = 1.0:
	get:
		return speed_scale
	set(value):
		if speed_scale != value:
			speed_scale = value
			animation_player.speed_scale = value
			if current_motion:
				animation_player.speed_scale *= current_motion.speed
			# This removes the grab of the user, we only want this if the user lets go
			#notify_property_list_changed()
			#TODO: fix this on the godot side and remove this code:
			if is_node_ready() and is_inside_tree():
				await get_tree().create_timer(0.5).timeout
			if is_equal_approx(value, animation_player.speed_scale):
				notify_property_list_changed()

@export var visible_colliders: bool = true:
	set(value):
		visible_colliders = value
		if collision_root:
			update_colliders()

## Node that the colliders will be attached to
@export var collision_root: Node2D = null:
	set(value):
		if collision_root == value:
			return
		
		if collision_shape != TBG.CollisionShape.None:
			# if setting to null, remove all nodes
			if value == null:
				# Remove previous colliders (non-serialized)
				for child in collision_root.get_children():
					if (child is TBG.DrawingCollider or child is TBG.DrawingPolygonCollider) \
							and child.owner == null:
						collision_root.remove_child(child)
						# Need to delete them
						child.queue_free()
				collision_root = value
				return
			
			# if currently null, generate colliders
			if collision_root == null:
				collision_root = value
				collision_shape = collision_shape
				return
			
			# transplant the colliders from one to another
			for child in collision_root.get_children():
				if (child is TBG.DrawingCollider or child is TBG.DrawingPolygonCollider) \
						and child.owner == null:
					child.reparent(value)
		
		collision_root = value
	get:
		return collision_root

# Design: Blanketting collision shapes on character is probably a bad idea
# Especially now that drawings can also disable their collision shapes

## The collision shape that the drawings will use on the collision_root
## Don't change during a physics step to avoid possible errors
@export var collision_shape: TBG.CollisionShape = TBG.CollisionShape.None:
	set(value):
		if collision_root == null:
			collision_shape = value
			return
		
		# if switching to null
		if value == TBG.CollisionShape.None:
			# from not null
			if collision_shape != TBG.CollisionShape.None:
				# Remove previous colliders (non-serialized)
				for child in collision_root.get_children():
					if (child is TBG.DrawingCollider or child is TBG.DrawingPolygonCollider) \
							and child.owner == null:
						collision_root.remove_child(child)
						# Need to delete them
						child.queue_free()
			collision_shape = value
			return
		
		# Deal with colliders
		_add_shapes(collision_root, collision_shape, value)
		
		collision_shape = value

## Offset for the drawing pivot
@export var pivot_offset: Vector2 = Vector2.ZERO:
	set(value):
		if pivot_offset == value:
			return
		pivot_offset = value
		# Add in offset of motion
		if current_motion:
			value += current_motion.offset
		
		skeleton.position = value
		composite.position = value
		update_colliders()

@export_group("Materials")
@export var shader_material: ShaderMaterial: 
	set(value):
		if shader_material == value:
			return
		
		shader_material = value
		
		if shader_material:
			# Using this to share conditions
			apply_to_all_sprites = apply_to_all_sprites
		else:
			composite.material = null
			for sprite in composite.get_children():
				if sprite is TBG.Drawing and not sprite is TBG.Cutter:
					sprite.use_parent_material = false
					sprite.material = null

@export var apply_to_all_sprites: bool = false :
	set(value):
		apply_to_all_sprites = value
		
		if shader_material == null:
			return
		
		composite.material = null if apply_to_all_sprites else shader_material
		for sprite in composite.get_children():
			if sprite is TBG.Drawing and not sprite is TBG.Cutter:
				sprite.use_parent_material = not apply_to_all_sprites
				sprite.material = shader_material if apply_to_all_sprites else null

@export_group("Hitboxes")
## Layers for hitbox colliders
@export_flags_2d_physics var hit_layers: int = 1:
	set(value):
		hit_layers = value
		var area2D = get_node_or_null("Hitboxes")
		if area2D:
			area2D.collision_layer = hit_layers

## Masks for hitbox colliders
@export_flags_2d_physics var hit_masks: int = 1:
	set(value):
		hit_masks = value
		var area2D = get_node_or_null("Hitboxes")
		if area2D:
			area2D.collision_layer = hit_masks

## Shape for hitbox colliders, use None to disable it
## Don't change during a physics step to avoid possible errors
@export var hitbox_shape: TBG.CollisionShape = TBG.CollisionShape.None:
	set(value):
		var area2D = get_node_or_null("Hitboxes")
		if value == TBG.CollisionShape.None:
			if area2D != null:
				remove_child(area2D)
				area2D.queue_free()
			hitbox_shape = value
			return
		
		if area2D == null:
			area2D = Area2D.new()
			area2D.name = &"Hitboxes"
			add_child(area2D)
			area2D.collision_layer = hit_layers
			area2D.collision_mask = hit_masks
			area2D.area_shape_entered.connect(func (areaRID, area, areaShapeID, localShapeID):
				var owner_id = area2D.shape_find_owner(localShapeID)
				var shape_node = area2D.shape_owner_get_owner(owner_id)
				area_enter_triggered.emit(area, shape_node)
				)
			area2D.area_shape_exited.connect(func (areaRID, area, areaShapeID, localShapeID):
				var owner_id = area2D.shape_find_owner(localShapeID)
				var shape_node = area2D.shape_owner_get_owner(owner_id)
				area_exit_triggered.emit(area, shape_node)
				)
			area2D.body_shape_entered.connect(func (bodyRID, body, areaShapeID, localShapeID):
				var owner_id = area2D.shape_find_owner(localShapeID)
				var shape_node = area2D.shape_owner_get_owner(owner_id)
				body_enter_triggered.emit(body, shape_node)
				)
			area2D.body_shape_exited.connect(func (bodyRID, body, areaShapeID, localShapeID):
				var owner_id = area2D.shape_find_owner(localShapeID)
				var shape_node = area2D.shape_owner_get_owner(owner_id)
				body_exit_triggered.emit(body, shape_node)
				)
		
		# Deal with colliders
		_add_shapes(area2D, hitbox_shape, value)
		
		hitbox_shape = value

@export_group("Motions")
## Motion Mode of the MotionCharacter
var mode: StringName = &"":
	get:
		return mode
	set(value):
		if value == mode:
			return
		mode = value
		var new_motion_config = config.match_motion_config(mode, facing)
		if new_motion_config != null:
			current_motion = new_motion_config

## Facing direction(s) of the MotionCharacter
var facing: TBG.Direction = 0 :
	get:
		return facing
	set(value):
		if value == facing:
			return
		facing = value
		var new_motion_config = config.match_motion_config(mode, facing)
		if new_motion_config != null:
			current_motion = new_motion_config

# current selected motion
var current_motion: TBG.MotionConfig = null:
	get:
		return current_motion
	set(value):
		current_motion = value
		
		if not is_node_ready():
			return
		animation_player.speed_scale = speed_scale
		if value == null or value.animation_name == "":
			animation_player.stop()
			return
		skeleton.transform = value.transform
		skeleton.position += pivot_offset
		composite.transform = value.transform
		composite.position += pivot_offset
		animation_player.speed_scale *= value.speed
		animation_player.get_animation(value.animation_name).loop_mode = value.loop as Animation.LoopMode
		animation_player.play(value.animation_name)
		animation_position = 0.0

# Convenience properties

var animation_player: AnimationPlayer:
	get:
		if animation_player == null:
			animation_player = get_node_or_null("AnimationPlayer")
		return animation_player

var composite: TBG.Composite:
	get:
		if composite == null:
			composite = get_node_or_null("Composite")
		return composite

var skeleton: Node2D:
	get:
		if skeleton == null:
			skeleton = get_node_or_null("Skeleton")
		return skeleton

var animation: String:
	get:
		return animation_player.current_animation

var animation_names = null:
	get:
		animation_names = Array(animation_player.get_animation_list())
		return animation_names if animation_names else []

var is_playing : bool:
	get:
		return animation_player.is_playing()
	set(value):
		if not value:
			animation_player.pause()
		else:
			# Resumes it
			animation_player.play()

var animation_position: float:
	get:
		if current_motion:
			return current_motion.from_source_t(animation_player, animation_player.current_animation_position)
		else:
			return 0.0
	set(value):
		if not current_motion:
			return
		if animation_player.speed_scale:
			animation_player.seek(0.0)
			animation_player.advance(current_motion.to_source_t(animation_player, value) / (animation_player.speed_scale))
		else:
			animation_player.seek(minf(current_motion.to_source_t(animation_player, value), animation_length), true)

var animation_length: float:
	get:
		if current_motion:
			return animation_player.current_animation_length
		
		return 0.0


# Custom properties
func _get(property):
	if composite != null:
		return composite._get(property)
	return null


func _set(property, value) -> bool:
	if composite != null:
		if Engine.is_editor_hint():
			if has_meta("instanceSkins") and composite.group_to_skin.has(property):
				if value == " ":
					# Doesn't actually reset the skin unless the user reopens the scene
					# So assign an empty string as placeholder
					get_meta("instanceSkins").erase(property)
					return composite._set(property, "")
				get_meta("instanceSkins")[property] = value
		return composite._set(property, value)
	return false


func _get_property_list():
	var props = [{
		"name": "skin_settings",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_STORAGE,
	},
	{
		"name": "mode",
		"type": TYPE_STRING_NAME,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join([" "] + config.modes)
	},
	{
		"name": "Facing",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SUBGROUP
	},
	{
		"name": "facing",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
		"hint": PROPERTY_HINT_FLAGS,
		# Not synced with TBG.Directions, so keep that in mind
		"hint_string": "Left, Right, Up, Down, In, Out"
	}]
	if composite != null and composite.group_to_skin_to_nodes.size() > 0:
		props.append_array(composite._get_property_list())
		# If editing an instance, change the group name
		if Engine.is_editor_hint() and is_inside_tree() and get_tree().edited_scene_root != self:
			props[4]["name"] = "Instance Skins"
			for index in range(5, props.size()):
				props[index]["hint_string"] = " ," + props[index]["hint_string"]
	return props


func _get_configuration_warnings() -> PackedStringArray:
	if collision_root and composite.config.polygons.is_empty() and collision_shape in [
			TBG.CollisionShape.ConvexHull,
			TBG.CollisionShape.ComplexFill,
			TBG.CollisionShape.ComplexOutline,
	]:
		return ["[Polygon Shape is not enabled/generated] enable in the import options and/or reimport this tbg"]
	return []


#HACK: Notifies the plugin to use its own notification function.
# Also temporarily remove/add variables to reduce what is saved
# AnimationTree generates a lot of bloat by duplication AnimationPlayer data, so remove on save
func _notification(what):
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		#TbgPlugin.instance.notification(NOTIFICATION_EDITOR_PRE_SAVE)
		TBG.currently_saving = true
		
		#Check for AnimationTree
		var anim_tree : AnimationTree = get_node_or_null("AnimationTree") as AnimationTree
		if anim_tree and anim_tree.anim_player:
			anim_tree.anim_player = NodePath()
		#if not TbgPlugin.instance.options["show"]["bones"]:
		composite.transform = Transform2D()
		skeleton.owner = null
		set_bones(skeleton, true)
		set.call_deferred("speed_scale", speed_scale)
		set.call_deferred("animation_position", animation_position)
		set.call_deferred("is_playing", is_playing)
		animation_player.speed_scale = 1.0
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		#TbgPlugin.instance.notification(NOTIFICATION_EDITOR_POST_SAVE)
		TBG.currently_saving = false
		TBG.node_post_save.emit(self)
		
		var anim_tree : AnimationTree = get_node_or_null("AnimationTree") as AnimationTree
		if anim_tree and not anim_tree.anim_player:
			anim_tree.anim_player = anim_tree.get_path_to(animation_player)
		#if not TbgPlugin.instance.options["show"]["bones"]:
		composite.position = pivot_offset
		current_motion = current_motion
		skeleton.owner = self
		set_bones(skeleton, false)
		apply_to_all_sprites = apply_to_all_sprites


func _ready():
	if has_meta("instanceSkins"):
		var skin_settings = get_meta("instanceSkins")
		for skin in skin_settings:
			composite._set(skin, skin_settings[skin])
	
	# Because this part isn't exported, we need to assign it on ready
	var anim_tree := get_node_or_null("AnimationTree") as AnimationTree
	if anim_tree and not anim_tree.anim_player:
		anim_tree.anim_player = anim_tree.get_path_to(animation_player)
	# HACK: Duplicate all animations and the animation library so loop settings are local to this instance
	if not Engine.is_editor_hint():
		var animation_library: AnimationLibrary = animation_player.get_animation_library("").duplicate()
		for animation_name in animation_library.get_animation_list():
			var animation = animation_library.get_animation(animation_name).duplicate()
			animation_library.add_animation(animation_name, animation)
		
		animation_player.remove_animation_library("")
		animation_player.add_animation_library("", animation_library)
		
		remove_meta("instanceSkins")
	# If an instance, initialize skin_settings and disable bone rendering
	elif get_tree().edited_scene_root != self:
		set_bones(skeleton, false)
		if not has_meta("instanceSkins"):
			set_meta("instanceSkins", {})
	
	# Search the motions for loop mode, grab the first one you have, sorted based on if motion mode or not
	var loop_modes = config.motions.reduce(func(a: Dictionary, e: TBG.MotionConfig):
		if animation_player.has_animation(e.animation_name) and not a.has(e.animation_name):
			a[e.animation_name] = e.loop
		return a
		, {})
	for animation_name in loop_modes:
		animation_player.get_animation(animation_name).loop_mode = loop_modes[animation_name]
	
	# Rest of initialization
	if config.motions.is_empty():
		config.motions = config.generate_default_motions(animation_names, animation_player)
	
	skeleton.position = pivot_offset
	composite.position = pivot_offset
	
	current_motion = current_motion
	is_playing = is_playing
	collision_shape = collision_shape
	hitbox_shape = hitbox_shape


# To remove stuff from the save data
func set_bones(node: Node, visible_bones) -> void:
	if node is Bone2D:
		node["editor_settings/show_bone_gizmo"] = visible_bones
	for child in node.get_children():
		set_bones(child, visible_bones)


# Helper function to handle adding and removing shapes for collision_root and hitboxes
func _add_shapes(root: Node2D, prevShape: TBG.CollisionShape, curShape: TBG.CollisionShape) -> void:
	# Get rid of polygon colliders
	if prevShape == TBG.CollisionShape.ComplexFill and prevShape != curShape:
		for child in root.get_children():
			if child is TBG.DrawingPolygonCollider:
				root.remove_child(child)
				child.queue_free()
	
	# Add new colliders
	var drawings = composite.get_children()
	for drawing in drawings:
		var collider = root.get_node_or_null(drawing.name + NAME_MODIFIER)
		
		if drawing is Polygon2D:
			# Skip polygons - TODO: Add colliders to the bones instead
			continue
		
		# Make sure it's a drawing
		if drawing is TBG.Drawing:
			# Don't do drawings that have no collider enabled
			if not drawing.has_associated_collider:
				# If refreshing, check if a node needs to be deleted
				if collider:
					root.remove_child(collider)
					collider.queue_free()
				continue
			
			# If a node is missing, add it
			if collider == null:
				collider = TBG.DrawingCollider.new()
				root.add_child(collider)
				collider.name = drawing.name + NAME_MODIFIER
				collider.target_drawing = drawing
				collider.visible = visible_colliders
			# If the same shape, no need to update the existing one (hence the else)
			elif curShape == prevShape:
				continue
			
			# Update this for each case
			collider.collision_shape = curShape


# Forces an update to the colliders, if they are enabled
func update_colliders() -> void:
	collision_shape = collision_shape
	hitbox_shape = hitbox_shape
	
	if collision_root and collision_shape != TBG.CollisionShape.None:
		for child in collision_root.get_children():
			if (child is TBG.DrawingCollider or child is TBG.DrawingPolygonCollider) \
				and child.owner == null:
				child.update_transform()
				child.visible = visible_colliders
	
	if hitbox_shape != TBG.CollisionShape.None:
		var area2D = get_node_or_null("Hitboxes")
		if area2D:
			for child in area2D.get_children():
				if (child is TBG.DrawingCollider or child is TBG.DrawingPolygonCollider) \
					and child.owner == null:
					child.update_transform()
					child.visible = visible_colliders
