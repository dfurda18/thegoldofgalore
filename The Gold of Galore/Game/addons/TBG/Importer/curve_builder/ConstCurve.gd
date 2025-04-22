class_name ConstCurve

var points : Array = []

func _init(points = []):
	for point in points:
		self.points.append(point)

static func from_value(value):
	var curve = ConstCurve.new()
	curve.points.append(Point.new(0, value))
	return curve

static func from_timed_values(timed_value_points):
	var curve = ConstCurve.new()
	for timed_value_point in timed_value_points:
		curve.points.append(Point.new(timed_value_point.x - 1, timed_value_point.y))
	return curve

func get_value(time):
	if time < points[0].x:
		return points[0].y
	elif time >= points[-1].x:
		return points[-1].y
	else:
		for i in range(points.size() - 1):
			if time >= points[i].x and time < points[i + 1].x:
				return points[i].y
	
	# Instead of throwing an exception, print an error message
	push_error("Could not find value for frame " + str(time))
	return null
