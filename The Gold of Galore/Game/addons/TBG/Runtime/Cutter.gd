@tool
## Node used to mask TBG.Drawing nodes
extends "./Drawing.gd"
#class_name Cutter

@export var matte_path: NodePath
@export var inverse: bool = true
var matte: Sprite2D = null
var is_dirty: bool = true


func _ready():
	matte = get_node(matte_path) as Sprite2D
	
	# We don't create the material in the import process because of a Godot 4.3 error
	material = ShaderMaterial.new()
	material.shader = preload("Cutter.tres")
	
	update_material();
	super._ready()


func _notification(what):
	super._notification(what)
	
	# HACK - To avoid unecessary data being saved (one shader subresource per cutter),
	# we reset the stored data and set it back the next frame.
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		set.call_deferred("material", material)
		material = null


func update_material():
	if not is_dirty:
		return
	is_dirty = false
	if matte == null:
		return
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("MATTE_TEXTURE", matte.texture)
	shader_material.set_shader_parameter("INVERSE", inverse)
	
	if matte.texture != null:
		var matte_global_transform := matte.get_global_transform()
		var global_transform := get_global_transform()
		var texture: Texture2D = null
		var offset = Vector2.ZERO
		if _sprite:
			texture = _sprite.texture
			offset = _sprite.offset
		if _polygon:
			texture = _polygon.texture
			offset = _polygon.offset
		var local_to_matte_uv := Transform2D.IDENTITY
		var matte_region := Vector4(0, 0, 1, 1) # X, Y min and size bounds where sampling from matte texture is valid
		if matte.texture != null:
			local_to_matte_uv = Transform2D(
				0,
				Vector2.ONE / Vector2(matte.texture.get_width(), matte.texture.get_height()),
				0,
				(
					Vector2(0.5, 0.5)
					- matte.offset / matte.texture.get_size()
				)
			)
			if matte.texture is AtlasTexture:
				var matte_atlas: AtlasTexture = matte.texture
				var atlas_scale = matte_atlas.region.size / matte_atlas.get_atlas().get_size()
				var atlas_offset = matte_atlas.region.position / matte_atlas.get_atlas().get_size()
				local_to_matte_uv = Transform2D(0, atlas_scale, 0, atlas_offset) * local_to_matte_uv
				matte_region = Vector4(atlas_offset.x, atlas_offset.y, atlas_scale.x, atlas_scale.y)
		var uv_to_matte_uv := (
			local_to_matte_uv * matte_global_transform.affine_inverse() * global_transform
		)
		shader_material.set_shader_parameter("LOCAL_TO_MATTE_UV", uv_to_matte_uv)
		shader_material.set_shader_parameter("MATTE_REGION", matte_region)


func set_dirty():
	if not is_dirty:
		is_dirty = true;
		update_material.call_deferred()
