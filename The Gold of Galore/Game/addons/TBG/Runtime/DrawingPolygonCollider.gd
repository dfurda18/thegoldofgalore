@tool
## Polygon colliders that can trace a TBG.Drawing, spawned by a controlling DrawingCollider
# They self terminate with their controller DrawingCollider
extends CollisionPolygon2D
#class_name DrawingPolygonCollider

#const Drawing = preload("Drawing.gd")

## Target drawing to create polygons for
@export var target_drawing: TBG.Drawing:
	set(value):
		if value._polygon != null:
			print("Polygon collision shape not supported")
			return
		# This is just in case you double assign. somehow
		if target_drawing != null:
			target_drawing.texture_changed.disconnect(queue_free_poly)
			target_drawing.local_transform_changed.disconnect(update_transform)
			target_drawing.visibility_changed.disconnect(check_visibility)
		value.texture_changed.connect(queue_free_poly)
		value.local_transform_changed.connect(update_transform)
		value.visibility_changed.connect(check_visibility)
		target_drawing = value
		update_transform()
	get:
		if is_instance_valid(target_drawing):
			return target_drawing
		
		# Freed objects valuate as true.
		if target_drawing:
			queue_free()
		return null


func update_transform() -> void:
	if target_drawing:
		global_transform = target_drawing.global_transform * Transform2D(
				0.0, Vector2.ONE, 0, target_drawing.get_rect().get_center())

func queue_free_poly() -> void:
	queue_free()


func check_visibility() -> void:
	if target_drawing and not target_drawing.visible:
		queue_free()
