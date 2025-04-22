@tool
## Colliders that attempt to encompass a specific TBG.Drawing node
extends CollisionShape2D
#class_name DrawingCollider

#const Drawing = preload("Drawing.gd")
#const DrawingPolygonCollider = preload("DrawingPolygonCollider.gd")


## Target drawing to create colliders for
@export var target_drawing: TBG.Drawing:
	set(value):
		if value._polygon != null:
			print("Polygon collision shape not supported")
			return
		if target_drawing:
			target_drawing.texture_changed.disconnect(update_shape)
			target_drawing.local_transform_changed.disconnect(update_transform)
			target_drawing.visibility_changed.disconnect(update_enabled)
		value.texture_changed.connect(update_shape)
		value.local_transform_changed.connect(update_transform)
		value.visibility_changed.connect(update_enabled)
		target_drawing = value
		update_enabled()
	
	get:
		if is_instance_valid(target_drawing):
			return target_drawing
		
		# Freed objects valuate as true.
		if target_drawing:
			queue_free()
			if Engine.is_editor_hint():
				print("Drawing of %s freed!" % name)
		return null

## Shape this collider uses
@export var collision_shape: TBG.CollisionShape:
	set(value):
		collision_shape = value
		update_shape()

var drawing_rect: Rect2
# Only relevant for sideways capsules
var shapeRot: float = 0.0


## Update the shape's shape and transform
func update_shape() -> void:
	if disabled or not target_drawing or is_queued_for_deletion():
		return
	drawing_rect = target_drawing.get_rect()
	shapeRot = 0.0
	
	match collision_shape:
		TBG.CollisionShape.Box:
			shape = RectangleShape2D.new()
			shape.size = drawing_rect.size
		TBG.CollisionShape.Circle:
			shape = CircleShape2D.new()
			shape.radius = max(drawing_rect.size.x, drawing_rect.size.y) * 0.5
		TBG.CollisionShape.Capsule:
			shape = CapsuleShape2D.new()
			if drawing_rect.size.x > drawing_rect.size.y:
				shape.height = drawing_rect.size.x
				shape.radius = drawing_rect.size.y * 0.5
				shapeRot = PI * 0.5
			else:
				shape.height = drawing_rect.size.y
				shape.radius = drawing_rect.size.x * 0.5
		TBG.CollisionShape.ComplexFill:
			# this node itself won't have collision shapes,
			# but will generate new ones, this means this mode is CPU intensive
			var polygons = _get_collision_shapes()
			shape = null
			var count = 1
			for poly in polygons:
				var collider = TBG.DrawingPolygonCollider.new()
				collider.name = name + " (Copy %s)" % count
				count += 1
				collider.polygon = poly
				get_parent().add_child(collider)
				collider.target_drawing = target_drawing
		TBG.CollisionShape.ConvexHull:
			var points = _get_collision_shapes()
			if points.is_empty():
				shape = null
			else:
				shape = ConvexPolygonShape2D.new()
				shape.points = points
		TBG.CollisionShape.ComplexOutline:
			var segments = _get_collision_shapes()
			if segments.is_empty():
				shape = null
			else:
				shape = ConcavePolygonShape2D.new()
				shape.segments = segments
	update_transform()


func update_transform() -> void:
	if not disabled and target_drawing:
		global_transform = target_drawing.global_transform * Transform2D(
				shapeRot, Vector2.ONE, 0, drawing_rect.get_center())


## Response to visibility change signal
func update_enabled() -> void:
	if target_drawing and disabled != not target_drawing.visible:
		disabled = not target_drawing.visible
		if disabled:
			shape = null
		else:
			update_shape()


# Complex collision shape code

func _get_collision_shapes()->Array:
	if target_drawing == null:
		return []
	
	var polygons = _get_collision_polygons()
	if not polygons:
		return []
	match collision_shape:
		TBG.CollisionShape.ComplexFill:
			return polygons
		TBG.CollisionShape.ConvexHull:
			var all_points = PackedVector2Array()
			for polygon in polygons:
				all_points.append_array(polygon)
			
			if not all_points.is_empty() and not test_convex(all_points):
				all_points = Geometry2D.convex_hull(all_points)
			return TBG.DrawingCollider.remove_short_segments(all_points, 0.0)
		TBG.CollisionShape.ComplexOutline:
			var all_segments = PackedVector2Array()
			for polygon in polygons:
				var segments = PackedVector2Array()
				segments.resize(polygon.size()*2)
				for i in polygon.size()-1:
					segments[i*2] = polygon[i]
					segments[i*2+1] = polygon[i+1]
				segments[segments.size()-2] = polygon[polygon.size()-1]
				segments[segments.size()-1] = polygon[0]
				all_segments.append_array(segments)
			
			return all_segments
	
	return []


func _get_collision_polygons():
	# Get polygon data
	if target_drawing._sprite.texture == null:
		return []
	var polys = target_drawing.composite.config.polygons.get(
			"p-%s" % target_drawing._sprite.texture.resource_name, [])
	return polys


static func remove_short_segments(points, epsilon = 1.0):
	epsilon = epsilon * epsilon
	var dst = PackedVector2Array()
	dst.resize(points.size())
	var n = 0
	var last = points[points.size()-1]
	for p in points:
		if (p - last).length_squared() > epsilon:
			dst[n] = p
			last = p
			n += 1
	
	dst.resize(n)
	return dst


# this is the same test Godot uses internally	
static func test_convex(points):
	var n = points.size()
	for i in n:
		var j = (i + 1) % n
		var k = (j + 1) % n
		
		var a = points[j] - points[i]
		var b = points[k] - points[i]
		if a.cross(b) < 0:
			return false
	return true
